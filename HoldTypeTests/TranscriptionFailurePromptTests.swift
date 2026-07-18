import AppKit
import HoldTypeDomain
import HoldTypeOpenAI
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
        #expect(presentedReasons.isEmpty)

        scheduledPresentation?()

        #expect(presentedReasons == [.timedOut])
    }

    @MainActor
    @Test func recoveryPromptWaitsForTerminalFailureStateBeforePresenting() async throws {
        let failedAttemptID = try #require(UUID(uuidString: "0B86A1D4-7C2C-4B9A-AC93-B71A2A7590B1"))
        let runtime = DictationRuntime(
            controller: DictationSessionController(initialStatus: .transcribing),
            appSettingsStore: AppSettingsStore(userDefaults: makeUserDefaults()),
            credentialResolver: MissingPromptCredentialResolver(),
            hotkeyService: FakeGlobalHotkeyService()
        )
        let floatingPresenter = PromptFloatingIndicatorPresenter()
        let floatingCoordinator = FloatingIndicatorCoordinator(
            dictationRuntime: runtime,
            appSettingsStore: AppSettingsStore(userDefaults: makeUserDefaults()),
            presenter: floatingPresenter
        )
        var observedPromptStatuses: [DictationStatus] = []
        var observedPromptIndicators: [FloatingIndicatorPresentation?] = []
        let promptPresenter = InspectingTranscriptionFailurePromptPresenter {
            observedPromptStatuses.append(runtime.status)
            observedPromptIndicators.append(floatingPresenter.lastPresentation)
        }
        let promptCoordinator = TranscriptionFailurePromptCoordinator(
            dictationRuntime: runtime,
            presenter: promptPresenter,
            settingsPresenter: PromptSettingsPresenter()
        )

        promptCoordinator.start()
        floatingCoordinator.start()

        #expect(floatingPresenter.lastPresentation?.phase == .transcribing)

        await runtime.retryFailedTranscription(
            id: failedAttemptID,
            outputMode: .followAutomaticInsertion
        )
        await yieldUntil { promptPresenter.requestCount == 1 }

        let promptSawOnlyFailure = observedPromptStatuses.allSatisfy { $0.isFailure }

        #expect(promptPresenter.requestCount == 1)
        #expect(promptSawOnlyFailure)
        #expect(observedPromptIndicators == [nil])

        promptCoordinator.stop()
        floatingCoordinator.stop()
    }

    private func actionTitles(for actions: [TranscriptionFailurePromptDecision]) -> [String] {
        actions.map { TranscriptionFailurePromptCopy.buttonTitle(for: $0) }
    }

    private func makeUserDefaults() -> UserDefaults {
        let userDefaults = UserDefaults(
            suiteName: "holdtype.TranscriptionFailurePromptTests.\(UUID().uuidString)"
        )
        #expect(userDefaults != nil)
        return userDefaults!
    }

    @MainActor
    private func yieldUntil(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<40 {
            if condition() {
                return
            }

            await Task.yield()
        }
    }
}
private struct MissingPromptCredentialResolver: OpenAICredentialResolving {
    func resolveOpenAICredential() throws -> OpenAICredential {
        throw OpenAICredentialResolutionError.missingAPIKey
    }
}

@MainActor
private final class InspectingTranscriptionFailurePromptPresenter: TranscriptionFailurePromptPresenting {
    private let onRequest: @MainActor () -> Void
    private(set) var requestCount = 0

    init(onRequest: @escaping @MainActor () -> Void) {
        self.onRequest = onRequest
    }

    func requestRecoveryDecision(
        for presentation: DictationFailurePresentation
    ) -> TranscriptionFailurePromptDecision {
        requestCount += 1
        onRequest()
        return .dismiss
    }
}

@MainActor
private final class PromptFloatingIndicatorPresenter: FloatingIndicatorPresenting {
    private(set) var presentations: [FloatingIndicatorPresentation?] = []

    var lastPresentation: FloatingIndicatorPresentation? {
        presentations.last ?? nil
    }

    func update(with presentation: FloatingIndicatorPresentation?) {
        presentations.append(presentation)
    }

    func hide() {
        presentations.append(nil)
    }
}

@MainActor
private final class PromptSettingsPresenter: SetupSettingsPresenting {
    func show(focusing item: SettingsNavigationItem?) {}

    func showAfterMenuDismissal(focusing item: SettingsNavigationItem?) {}

    func showAfterSystemPermissionPrompt(focusing item: SettingsNavigationItem?) {}
}

private extension DictationStatus {
    var isFailure: Bool {
        if case .failure = self {
            return true
        }

        return false
    }
}
