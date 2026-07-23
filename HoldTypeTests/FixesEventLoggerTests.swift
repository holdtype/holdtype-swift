import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct FixesEventLoggerTests {
    @Test func runtimeEventsUseOnlyClosedFieldsAndActionIdentity() throws {
        let identifierCanary = "custom.ID-CANARY-660"
        let promptCanary = "PROMPT-CANARY-017"
        let action = try TextFixAction(
            id: identifierCanary,
            kind: .customPrompt,
            title: "Private title",
            icon: .custom,
            prompt: promptCanary
        )
        let recorder = FixesDiagnosticsRuntimeLogRecorder()
        let logger = OSLogFixesEventLogger(runtimeLogRecorder: recorder)
        let identity = FixesActionIdentity(action: action)

        logger.record(.capture(outcome: .blockedSecureField))
        logger.record(
            .availability(outcome: .blockedConsentRequired)
        )
        logger.record(
            .action(identity: identity, outcome: .timedOutProvider)
        )

        #expect(
            recorder.events == [
                RuntimeDiagnosticEvent(
                    category: "fixes",
                    name: "capture",
                    severity: .error,
                    fields: ["outcome": "blocked_secure_field"]
                ),
                RuntimeDiagnosticEvent(
                    category: "fixes",
                    name: "availability",
                    severity: .error,
                    fields: ["outcome": "blocked_consent_required"]
                ),
                RuntimeDiagnosticEvent(
                    category: "fixes",
                    name: "action",
                    severity: .error,
                    fields: [
                        "action_tag": identity.formatted,
                        "outcome": "timed_out_provider",
                    ]
                ),
            ]
        )
        #expect(
            recorder.events.allSatisfy {
                Set($0.fields.keys).isSubset(
                    of: ["action_tag", "outcome"]
                )
            }
        )
        #expect(!String(describing: recorder.events).contains(identifierCanary))
        #expect(!String(describing: recorder.events).contains(promptCanary))
    }

    @Test func terminalMappingUsesClosedTimeoutCancellationAndStageOutcomes() {
        #expect(
            FixesActionOutcome.terminal(
                for: OpenAITextTransformationServiceError.timedOut,
                stage: .provider
            ) == .timedOutProvider
        )
        #expect(
            FixesActionOutcome.terminal(
                for: FocusedTextTargetError.replacementTimedOut,
                stage: .replacement
            ) == .timedOutReplacement
        )
        #expect(
            FixesActionOutcome.terminal(
                for: CancellationError(),
                stage: .provider
            ) == .cancelled
        )
        #expect(
            FixesActionOutcome.terminal(
                for: FixesDiagnosticsTestError.provider,
                stage: .provider
            ) == .failedProvider
        )
        #expect(
            FixesActionOutcome.terminal(
                for: FixesDiagnosticsTestError.replacement,
                stage: .replacement
            ) == .failedReplacement
        )
    }
}

enum FixesDiagnosticsTestError: Error {
    case provider
    case replacement
}
