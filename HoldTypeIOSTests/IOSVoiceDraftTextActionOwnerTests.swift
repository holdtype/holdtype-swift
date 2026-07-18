import Foundation
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSVoiceDraftTextActionOwnerTests {
    @Test func repeatedActionsUseLatestDraftAndIgnoreAnOverlappingTap()
        async throws {
        try await withRepository { repository in
            let draftOwner = IOSVoiceDraftOwner(repository: repository)
            #expect(await draftOwner.refresh())
            #expect(
                await draftOwner.accept(
                    try accepted(1, text: "Original"),
                    mode: .append
                )
            )
            let harness = IOSVoiceDraftTextActionHarness()
            let owner = IOSVoiceDraftTextActionOwner(
                draftOwner: draftOwner,
                client: IOSVoiceDraftTextActionClient {
                    action,
                    text in
                    await harness.perform(action, text: text)
                }
            )

            #expect(owner.submit(.correct))
            #expect(owner.isProcessing)
            #expect(!owner.submit(.translate))
            try await waitUntil { !owner.isProcessing }
            #expect(draftOwner.text == "Improved 1: Original")
            #expect(owner.outcome == .completed(.correct, changed: true))
            #expect(
                owner.outcome?.accessibilityAnnouncement == "Draft improved"
            )

            #expect(owner.submit(.correct))
            try await waitUntil { !owner.isProcessing }
            #expect(
                draftOwner.text
                    == "Improved 2: Improved 1: Original"
            )
            #expect(harness.inputs == ["Original", "Improved 1: Original"])
            #expect(await draftOwner.undo())
            #expect(draftOwner.text == "Improved 1: Original")
        }
    }

    @Test func providerFailureLeavesDraftUntouchedAndReleasesTheGate()
        async throws {
        try await withRepository { repository in
            let draftOwner = IOSVoiceDraftOwner(repository: repository)
            #expect(await draftOwner.refresh())
            #expect(
                await draftOwner.accept(
                    try accepted(1, text: "Keep this"),
                    mode: .append
                )
            )
            let owner = IOSVoiceDraftTextActionOwner(
                draftOwner: draftOwner,
                client: IOSVoiceDraftTextActionClient { _, _ in
                    .failure(.timedOut)
                }
            )

            #expect(owner.submit(.translate))
            try await waitUntil { !owner.isProcessing }
            #expect(draftOwner.text == "Keep this")
            #expect(draftOwner.operation == .idle)
            #expect(owner.outcome == .failed(.translate, .timedOut))
            #expect(
                owner.outcome?.accessibilityAnnouncement == "Draft unchanged"
            )
            #expect(owner.submit(.translate))
            try await waitUntil { !owner.isProcessing }
        }
    }

    private func withRepository(
        operation: (IOSVoiceDraftRepository) async throws -> Void
    ) async throws {
        let root = FileManager.default.temporaryDirectory.appending(
            path: "holdtype-draft-action-owner-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        try await operation(
            IOSVoiceDraftRepository(applicationSupportDirectoryURL: root)
        )
    }

    private func accepted(
        _ index: Int,
        text: String
    ) throws -> IOSV1AcceptedOutputDeliveryRecord {
        try IOSV1AcceptedOutputDeliveryRecord(
            resultID: identifier(index),
            sourceAttemptID: UUID(),
            acceptedText: text,
            createdAt: Date(timeIntervalSince1970: TimeInterval(index))
        )
    }

    private func identifier(_ index: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                index
            )
        )!
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for Draft text action.")
    }
}

@MainActor
private final class IOSVoiceDraftTextActionHarness {
    private(set) var inputs: [String] = []

    func perform(
        _ action: IOSVoiceDraftTextAction,
        text: String
    ) async -> IOSVoiceDraftTextActionResolution {
        inputs.append(text)
        try? await Task.sleep(for: .milliseconds(20))
        return switch action {
        case .correct:
            .success("Improved \(inputs.count): \(text)")
        case .translate:
            .success("Translated \(inputs.count): \(text)")
        }
    }
}
