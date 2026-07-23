import Foundation
import Testing

@MainActor
struct KeyboardFixExtensionDiagnosticsTests {
    @Test func eligibilityAndRequestBridgeFailuresUseClosedOutcomes()
        throws {
        let diagnostics = try KeyboardFixDiagnosticFixture()
        defer { diagnostics.remove() }
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime(diagnostics: diagnostics.client)
        runtime.start()
        let action = KeyboardFixBridgeConfiguration.translateIdentifier

        fixture.hasFullAccess = false
        runtime.activate(actionIdentifier: action)
        fixture.hasFullAccess = true
        fixture.dictationIsBusy = true
        runtime.activate(actionIdentifier: action)
        fixture.dictationIsBusy = false
        fixture.shouldFailPublishingRequest = true
        runtime.activate(actionIdentifier: action)

        let lines = try diagnostics.store.recentLines(limit: 20)
        #expect(lines.containsTextFix(.eligibility, .blocked))
        #expect(lines.containsTextFix(.eligibility, .busy))
        #expect(lines.containsTextFix(.request, .bridgeUnavailable))
        #expect(lines.allSatisfy { !$0.contains(action) })
        #expect(
            lines.allSatisfy {
                !$0.contains(fixture.target?.selectedText ?? "")
            }
        )
    }

    @Test func successfulApplicationRecordsRequestLaunchAndOutput()
        throws {
        let diagnostics = try KeyboardFixDiagnosticFixture()
        defer { diagnostics.remove() }
        let fixture = try KeyboardFixExtensionRuntimeFixture()
        let runtime = fixture.makeRuntime(diagnostics: diagnostics.client)
        runtime.start()

        runtime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.translateIdentifier
        )
        try fixture.publishSuccess()
        runtime.poll()

        let lines = try diagnostics.store.recentLines(limit: 20)
        #expect(lines.containsTextFix(.request, .started))
        #expect(lines.containsTextFix(.launch, .started))
        #expect(lines.containsTextFix(.output, .succeeded))
        #expect(lines.allSatisfy { $0.containsNoPrivateFixFields })
    }

    @Test func staleCancelAndTimeoutPathsRemainDistinct() throws {
        let diagnostics = try KeyboardFixDiagnosticFixture()
        defer { diagnostics.remove() }

        let staleFixture = try KeyboardFixExtensionRuntimeFixture()
        let staleRuntime = staleFixture.makeRuntime(
            diagnostics: diagnostics.client
        )
        staleRuntime.start()
        staleRuntime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.translateIdentifier
        )
        try staleFixture.publishSuccess()
        staleFixture.target = KeyboardFixExtensionTarget(
            documentIdentifier: "new-document",
            selectedText: "new selection"
        )
        staleRuntime.poll()

        let cancelFixture = try KeyboardFixExtensionRuntimeFixture()
        let cancelRuntime = cancelFixture.makeRuntime(
            diagnostics: diagnostics.client
        )
        cancelRuntime.start()
        cancelRuntime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.fixIdentifier
        )
        cancelRuntime.cancelActiveRequest()
        try cancelFixture.acknowledgeCancellation()

        let timeoutFixture = try KeyboardFixExtensionRuntimeFixture()
        let timeoutRuntime = timeoutFixture.makeRuntime(
            diagnostics: diagnostics.client
        )
        timeoutRuntime.start()
        timeoutRuntime.activate(
            actionIdentifier:
                KeyboardFixBridgeConfiguration.translateIdentifier
        )
        timeoutFixture.now = try timeoutFixture.requireRequest().expiresAt
        timeoutRuntime.poll()

        let lines = try diagnostics.store.recentLines(limit: 50)
        #expect(lines.containsTextFix(.target, .stale))
        #expect(lines.containsTextFix(.result, .cancelled))
        #expect(lines.containsTextFix(.cancellation, .acknowledged))
        #expect(lines.containsTextFix(.result, .timedOut))
    }
}

private final class KeyboardFixDiagnosticFixture {
    let root: URL
    let store: IOSRuntimeDiagnosticsStore

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "HoldType-KeyboardFixDiagnostics-\(UUID().uuidString)",
            isDirectory: true
        )
        store = IOSRuntimeDiagnosticsStore(
            process: .keyboard,
            rootDirectoryURL: root
        )
    }

    var client: IOSRuntimeTextFixDiagnosticClient {
        IOSRuntimeTextFixDiagnosticClient { [store] event in
            store.record(event)
        }
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

private extension [String] {
    func containsTextFix(
        _ stage: IOSDiagnosticTextFixStage,
        _ outcome: IOSDiagnosticTextFixOutcome
    ) -> Bool {
        contains {
            $0.contains("stage=\(stage.rawValue)")
                && $0.contains("outcome=\(outcome.rawValue)")
        }
    }
}

private extension String {
    var containsNoPrivateFixFields: Bool {
        !contains("source=")
            && !contains("prompt=")
            && !contains("result=")
            && !contains("api_key=")
            && !contains("provider_body=")
    }
}
