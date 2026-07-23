import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSVoiceDraftTextActionDiagnosticsTests {
    @Test func voiceFixSuccessTimeoutAndBlockedInputAreContentFree()
        async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "HoldType-VoiceFixDiagnostics-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let repository = IOSVoiceDraftRepository(
            applicationSupportDirectoryURL:
                root.appendingPathComponent("Drafts", isDirectory: true)
        )
        let draftOwner = IOSVoiceDraftOwner(repository: repository)
        #expect(await draftOwner.refresh())
        #expect(
            await draftOwner.accept(
                try IOSV1AcceptedOutputDeliveryRecord(
                    resultID: UUID(),
                    sourceAttemptID: UUID(),
                    acceptedText: "VOICE-SOURCE-CANARY-4812",
                    createdAt: Date(timeIntervalSince1970: 1)
                ),
                mode: .append
            )
        )
        let store = HoldTypeIOS.IOSRuntimeDiagnosticsStore(
            process: .app,
            rootDirectoryURL:
                root.appendingPathComponent("Diagnostics", isDirectory: true)
        )
        let diagnostics = HoldTypeIOS.IOSRuntimeTextFixDiagnosticClient {
            event in
            store.record(event)
        }
        let owner = IOSVoiceDraftTextActionOwner(
            draftOwner: draftOwner,
            client: IOSVoiceDraftTextActionClient { action, _ in
                if action.kind == .translate {
                    return .failure(.timedOut)
                }
                return .success("VOICE-RESULT-CANARY-9357")
            },
            diagnostics: diagnostics
        )
        let translate = TextFixCatalog.defaults.actions[0]
        let fix = TextFixCatalog.defaults.actions[1]

        #expect(owner.submit(fix))
        #expect(!owner.submit(translate))
        try await waitForVoiceFix { !owner.isProcessing }
        #expect(owner.submit(translate))
        try await waitForVoiceFix { !owner.isProcessing }

        let emptyRepository = IOSVoiceDraftRepository(
            applicationSupportDirectoryURL:
                root.appendingPathComponent("EmptyDraft", isDirectory: true)
        )
        let emptyDraftOwner = IOSVoiceDraftOwner(
            repository: emptyRepository
        )
        #expect(await emptyDraftOwner.refresh())
        let blockedOwner = IOSVoiceDraftTextActionOwner(
            draftOwner: emptyDraftOwner,
            client: IOSVoiceDraftTextActionClient { _, _ in
                .success("Must not execute")
            },
            diagnostics: diagnostics
        )
        #expect(!blockedOwner.submit(fix))

        let lines = try store.recentLines(limit: 20)
        #expect(lines.containsVoiceFix(.output, .succeeded))
        #expect(lines.containsVoiceFix(.result, .timedOut))
        #expect(lines.containsVoiceFix(.eligibility, .blocked))
        #expect(lines.containsVoiceFix(.eligibility, .busy))
        #expect(lines.allSatisfy { $0.contains("action_tag=") })
        #expect(
            lines.allSatisfy {
                !$0.contains("VOICE-SOURCE-CANARY-4812")
                    && !$0.contains("VOICE-RESULT-CANARY-9357")
                    && !$0.contains(fix.id)
                    && !$0.contains(translate.id)
            }
        )
    }
}

@MainActor
private func waitForVoiceFix(
    _ condition: @escaping @MainActor () -> Bool
) async throws {
    for _ in 0..<200 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Timed out waiting for Voice Fix diagnostics.")
}

private extension [String] {
    func containsVoiceFix(
        _ stage: HoldTypeIOS.IOSDiagnosticTextFixStage,
        _ outcome: HoldTypeIOS.IOSDiagnosticTextFixOutcome
    ) -> Bool {
        contains {
            $0.contains("stage=\(stage.rawValue)")
                && $0.contains("outcome=\(outcome.rawValue)")
        }
    }
}
