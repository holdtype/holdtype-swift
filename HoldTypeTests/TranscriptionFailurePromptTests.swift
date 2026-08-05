import Foundation
import Testing
@testable import HoldType
struct TranscriptionFailurePromptTests {
    @Test func timeoutFailureOffersRetryAndDismissOnly() throws {
        let failedAttemptID = try #require(UUID(uuidString: "5EFCABEB-F538-4D6D-81D1-E621431B8E62"))
        let presentation = DictationFailurePresentation(
            title: FailedTranscriptionReason.timedOut.title,
            message: FailedTranscriptionReason.timedOut.message,
            failedAttemptID: failedAttemptID,
            canRetry: true,
            showsRecoveryPrompt: true
        )

        let actions = TranscriptionFailurePromptActions.actions(for: presentation)

        #expect(presentation.showsRecoveryPrompt)
        #expect(actions == [.retry(failedAttemptID), .dismiss])
        #expect(actionTitles(for: actions) == ["Try Again", "Dismiss"])
    }

    @Test func apiKeyFailureOffersSettingsBeforeRetryAndDismiss() throws {
        let failedAttemptID = try #require(UUID(uuidString: "38971F76-E4D6-4862-BC60-D338CEFE2B2D"))
        let presentation = DictationFailurePresentation(
            title: FailedTranscriptionReason.invalidAPIKey.title,
            message: FailedTranscriptionReason.invalidAPIKey.message,
            failedAttemptID: failedAttemptID,
            settingsTarget: .openAI,
            canRetry: true,
            showsRecoveryPrompt: true
        )

        let actions = TranscriptionFailurePromptActions.actions(for: presentation)

        #expect(actions == [.openSettings(.openAI), .retry(failedAttemptID), .dismiss])
        #expect(actionTitles(for: actions) == ["Open OpenAI Settings", "Try Again", "Dismiss"])
    }

    @Test func settingsOnlyFailureDoesNotShowFakeRetry() {
        let presentation = DictationFailurePresentation(
            title: FailedTranscriptionReason.apiKeyUnavailable.title,
            message: FailedTranscriptionReason.apiKeyUnavailable.message,
            settingsTarget: .openAI,
            canRetry: true,
            showsRecoveryPrompt: true
        )

        let actions = TranscriptionFailurePromptActions.actions(for: presentation)

        #expect(actions == [.openSettings(.openAI), .dismiss])
        #expect(actionTitles(for: actions) == ["Open OpenAI Settings", "Dismiss"])
    }

    @Test func promptCopyExplainsSavedRetryAttemptWithoutHistoryShortcut() throws {
        let failedAttemptID = try #require(UUID(uuidString: "2F630CA6-014E-4139-BF18-2A6C1F2D6C94"))
        let presentation = DictationFailurePresentation(
            title: FailedTranscriptionReason.networkUnavailable.title,
            message: FailedTranscriptionReason.networkUnavailable.message,
            failedAttemptID: failedAttemptID,
            canRetry: true,
            showsRecoveryPrompt: true
        )

        let informativeText = TranscriptionFailurePromptCopy.informativeText(for: presentation)
        let actionTitles = actionTitles(for: TranscriptionFailurePromptActions.actions(for: presentation))

        #expect(informativeText.contains("The network is unavailable."))
        #expect(informativeText.contains("saved for retry"))
        #expect(informativeText.contains("Transcript History") == false)
        #expect(actionTitles.contains("Transcript History") == false)
    }

    @Test func uncertainOutcomeOffersConfirmationGatedTranscribeAgain() throws {
        let failedAttemptID = try #require(UUID(uuidString: "2F630CA6-014E-4139-BF18-2A6C1F2D6C95"))
        let presentation = DictationFailurePresentation(
            title: FailedTranscriptionReason.providerOutcomeUncertain.title,
            message: FailedTranscriptionReason.providerOutcomeUncertain.message,
            failedAttemptID: failedAttemptID,
            requiresDuplicateRetryConfirmation: true,
            showsRecoveryPrompt: true
        )

        let actions = TranscriptionFailurePromptActions.actions(for: presentation)
        let informativeText = TranscriptionFailurePromptCopy.informativeText(for: presentation)

        #expect(actions == [.transcribeAgain(failedAttemptID), .dismiss])
        #expect(actionTitles(for: actions) == ["Transcribe Again…", "Dismiss"])
        #expect(informativeText.contains("saved in Transcript History"))
        #expect(informativeText.contains("saved for retry") == false)
        #expect(
            TranscriptionFailurePromptCopy.repeatTranscriptionConfirmation
                == "This will submit the saved recording for transcription again."
        )
    }

    @Test func recordingTooShortPresentationDoesNotRequestFrontmostPrompt() {
        let presentation = DictationFailurePresentation(
            title: "Recording too short",
            message: "Recording was too short. Try speaking for a little longer."
        )

        #expect(presentation.showsRecoveryPrompt == false)
        #expect(TranscriptionFailurePromptActions.actions(for: presentation) == [.dismiss])
    }

    @MainActor
    @Test func debugFailureLaunchMapsExpectedReasonsAndSchedulesPresentation() {
        var scheduledPresentation: (@MainActor () -> Void)?
        var presentedReasons: [FailedTranscriptionReason] = []

        DebugTranscriptionFailurePromptLaunch.requestIfNeeded(
            environment: [DebugTranscriptionFailurePromptLaunch.environmentKey: "timeout"],
            presentFailure: { reason in
                presentedReasons.append(reason)
            },
            schedulePresentation: { presentation in
                scheduledPresentation = presentation
            }
        )

        #expect(DebugTranscriptionFailurePromptLaunch.reason(from: "invalid-api-key") == .invalidAPIKey)
        #expect(DebugTranscriptionFailurePromptLaunch.reason(from: "network") == .networkUnavailable)
        #expect(DebugTranscriptionFailurePromptLaunch.reason(from: "uncertain") == .providerOutcomeUncertain)
        #expect(presentedReasons.isEmpty)

        scheduledPresentation?()

        #expect(presentedReasons == [.timedOut])
    }

    private func actionTitles(for actions: [TranscriptionFailurePromptDecision]) -> [String] {
        actions.map { TranscriptionFailurePromptCopy.buttonTitle(for: $0) }
    }
}
