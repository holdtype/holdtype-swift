import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct FixesRuntimeDiagnosticsTests {
    @Test func successfulRuntimeFlowNeverRecordsSensitiveCanaries() async throws {
        let sourceCanary = "SOURCE-CANARY-318"
        let promptCanary = "PROMPT-CANARY-490"
        let resultCanary = "RESULT-CANARY-762"
        let keyCanary = "sk-key-canary-884"
        let identifierCanary = "custom.ID-CANARY-445"
        let recorder = FixesDiagnosticsRuntimeLogRecorder()
        let fixture = try makeFixesRuntimeDiagnosticsFixture(
            actionID: identifierCanary,
            sourceText: sourceCanary,
            prompt: promptCanary,
            result: resultCanary,
            apiKey: keyCanary,
            eventLogger: OSLogFixesEventLogger(
                runtimeLogRecorder: recorder
            )
        )

        try await activate(fixture)
        try await waitUntil {
            fixture.replacement.calls.count == 1
        }

        #expect(fixture.execution.calls.first?.sourceText == sourceCanary)
        #expect(fixture.execution.calls.first?.action.prompt == promptCanary)
        #expect(fixture.replacement.calls.first?.output == resultCanary)
        #expect(
            recorder.events.map(\.fields) == [
                ["outcome": "succeeded"],
                ["outcome": "ready"],
                [
                    "action_tag": fixture.actionTag,
                    "outcome": "started",
                ],
                [
                    "action_tag": fixture.actionTag,
                    "outcome": "succeeded",
                ],
            ]
        )

        let serializedEvents = String(describing: recorder.events)
        for canary in [
            sourceCanary,
            promptCanary,
            resultCanary,
            keyCanary,
            identifierCanary,
        ] {
            #expect(!serializedEvents.contains(canary))
        }
    }

    @Test func blockedCaptureAndConsentUseClosedOutcomes() async throws {
        let secureRecorder = FixesDiagnosticsEventRecorder()
        let secureFixture = try makeFixesRuntimeDiagnosticsFixture(
            isSecure: true,
            eventLogger: secureRecorder
        )

        secureFixture.runtime.showPalette()
        try await waitUntil {
            secureFixture.panel.model != nil
        }

        #expect(
            secureRecorder.events == [
                .capture(outcome: .blockedSecureField),
                .availability(outcome: .blockedTargetUnavailable),
            ]
        )

        let consentRecorder = FixesDiagnosticsEventRecorder()
        let consentFixture = try makeFixesRuntimeDiagnosticsFixture(
            hasCurrentConsent: false,
            eventLogger: consentRecorder
        )
        consentFixture.runtime.showPalette()
        try await waitUntil {
            consentFixture.panel.model != nil
        }

        #expect(
            consentRecorder.events == [
                .capture(outcome: .succeeded),
                .availability(outcome: .blockedConsentRequired),
            ]
        )
    }

    @Test func runtimeEmitsClosedFailureTimeoutStaleAndCancelOutcomes() async throws {
        let failure = try await terminalOutcome(
            executionError: FixesDiagnosticsTestError.provider
        )
        #expect(failure == .failedProvider)

        let timeout = try await terminalOutcome(
            executionError: OpenAITextTransformationServiceError.timedOut
        )
        #expect(timeout == .timedOutProvider)

        let replacement = try await terminalOutcome(
            replacementError: FixesDiagnosticsTestError.replacement
        )
        #expect(replacement == .failedReplacement)

        let staleRecorder = FixesDiagnosticsEventRecorder()
        let staleFixture = try makeFixesRuntimeDiagnosticsFixture(
            eventLogger: staleRecorder
        )
        staleFixture.runtime.showPalette()
        try await waitUntil {
            staleFixture.panel.model != nil
        }
        staleFixture.targetClient.replaceText("changed")
        try activatePresentedAction(staleFixture)
        #expect(lastActionOutcome(in: staleRecorder.events) == .stale)

        let cancelRecorder = FixesDiagnosticsEventRecorder()
        let cancelFixture = try makeFixesRuntimeDiagnosticsFixture(
            eventLogger: cancelRecorder
        )
        cancelFixture.execution.delay = .seconds(30)
        try await activate(cancelFixture)
        try await waitUntil {
            cancelFixture.execution.calls.count == 1
        }
        cancelFixture.runtime.dismissPalette()
        try await waitUntil {
            lastActionOutcome(in: cancelRecorder.events) == .cancelled
        }
    }

    private func terminalOutcome(
        executionError: Error? = nil,
        replacementError: Error? = nil
    ) async throws -> FixesActionOutcome? {
        let recorder = FixesDiagnosticsEventRecorder()
        let fixture = try makeFixesRuntimeDiagnosticsFixture(
            eventLogger: recorder
        )
        fixture.execution.error = executionError
        fixture.replacement.error = replacementError
        try await activate(fixture)
        try await waitUntil {
            guard let outcome = lastActionOutcome(in: recorder.events) else {
                return false
            }
            return outcome != .started
        }
        return lastActionOutcome(in: recorder.events)
    }

    private func activate(
        _ fixture: FixesRuntimeDiagnosticsFixture
    ) async throws {
        fixture.runtime.showPalette()
        try await waitUntil {
            fixture.panel.model != nil
        }
        try activatePresentedAction(fixture)
    }

    private func activatePresentedAction(
        _ fixture: FixesRuntimeDiagnosticsFixture
    ) throws {
        let model = try #require(fixture.panel.model)
        model.selectAction(id: fixture.actionID)
        model.activateSelection()
    }

    private func lastActionOutcome(
        in events: [FixesLogEvent]
    ) -> FixesActionOutcome? {
        for event in events.reversed() {
            if case .action(_, let outcome) = event {
                return outcome
            }
        }
        return nil
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<200 {
            if condition() {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Timed out waiting for Fixes diagnostics state")
    }
}
