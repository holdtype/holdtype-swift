//
//  HoldTypeTests.swift
//  HoldTypeTests
//
//  Created by Eugene Potapenko on 6/20/26.
//

import AppKit
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

struct DictationStatusTests {

    @Test func projectsOnlyRuntimeWorkWithoutTranscriptOrErrorPayloads() {
        #expect(DictationStatus.idle.voiceWorkPhase == .inactive)
        #expect(DictationStatus.recording.voiceWorkPhase == .listening)
        #expect(DictationStatus.transcribing.voiceWorkPhase == .processing)
        #expect(DictationStatus.success(transcript: "First result").voiceWorkPhase == .inactive)
        #expect(DictationStatus.success(transcript: "Second result").voiceWorkPhase == .inactive)
        #expect(DictationStatus.failure(message: "First failure").voiceWorkPhase == .inactive)
        #expect(DictationStatus.failure(message: "Second failure").voiceWorkPhase == .inactive)
    }

    @Test func exposesMenuTextForCoreStates() {
        #expect(DictationStatus.idle.menuStatusText == "Ready")
        #expect(DictationStatus.recording.menuStatusText == "Recording…")
        #expect(DictationStatus.transcribing.menuStatusText == "Transcribing…")
        #expect(DictationStatus.success(transcript: "Hello").menuStatusText == "Ready")
        #expect(
            DictationStatus.failure(message: "Recording was too short. Try speaking for a little longer.")
                .menuStatusText == "Error: Recording too short"
        )
        #expect(
            DictationStatus.failure(message: "Transcription needs an OpenAI API key saved in Settings.")
                .menuStatusText == "API key required"
        )
    }

    @Test func exposesRecordingActionForCurrentState() {
        #expect(DictationStatus.idle.recordingActionTitle == "Transcribe")
        #expect(DictationStatus.recording.recordingActionTitle == "Stop Recording")
        #expect(DictationStatus.transcribing.recordingActionTitle == "Transcribe")
        #expect(DictationStatus.transcribing.isRecordingActionEnabled == false)
        #expect(DictationStatus.idle.recordingActionShortcutHint == "Hold Right ⌘")
        #expect(DictationStatus.recording.recordingActionShortcutHint == nil)
    }

    @Test func carriesSuccessAndFailureDetails() {
        #expect(DictationStatus.success(transcript: "Typed text").lastTranscriptText == "Typed text")
        #expect(DictationStatus.success(transcript: "Typed text").detailText == "Typed text")
        #expect(DictationStatus.failure(message: "Missing permission").detailText == "Missing permission")
        #expect(DictationStatus.recording.detailText == "Microphone recording is active.")
    }

    @Test func exposesOnlyNormalizedSuccessTranscript() {
        let status = DictationStatus.success(transcript: "  Typed text\n")

        #expect(status.lastTranscriptText == "Typed text")
        #expect(status.detailText == "Typed text")
    }

    @Test func longTranscriptKeepsFullLastTranscriptState() {
        let transcript = String(repeating: "a", count: 160)
        let status = DictationStatus.success(transcript: transcript)

        #expect(status.lastTranscriptText == transcript)
    }

    @Test func onlyNonEmptyNormalizedSuccessTranscriptIsRetained() {
        #expect(DictationStatus.idle.lastTranscriptText == nil)
        #expect(DictationStatus.success(transcript: "").lastTranscriptText == nil)
        #expect(DictationStatus.success(transcript: "  \n\t  ").lastTranscriptText == nil)
        #expect(DictationStatus.success(transcript: "Typed text").lastTranscriptText == "Typed text")
    }

    @Test func projectsOnlyANonEmptySuccessAsAReadyAttemptResult() {
        let statuses: [DictationStatus] = [
            .idle,
            .recording,
            .transcribing,
            .failure(message: "Failure"),
            .success(transcript: ""),
            .success(transcript: "  \n\t  "),
            .success(transcript: "  First accepted text\n"),
            .success(transcript: "Second accepted text"),
        ]
        let projectedOutcomes = statuses.compactMap(\.voiceAttemptOutcome)

        #expect(projectedOutcomes == [.resultReady, .resultReady])
        #expect(projectedOutcomes.contains(.interrupted) == false)
        #expect(projectedOutcomes.contains(.expired) == false)
    }

    @Test func whitespaceOnlySuccessTranscriptShowsEmptyState() {
        let status = DictationStatus.success(transcript: "  \n\t  ")

        #expect(status.lastTranscriptText == nil)
        #expect(status.detailText == "No transcript available.")
    }

    @Test func placeholderRecordingActionTogglesOnlyStartAndStopStates() {
        #expect(DictationStatus.idle.placeholderRecordingActionResult == .recording)
        #expect(DictationStatus.recording.placeholderRecordingActionResult == .idle)
        #expect(DictationStatus.transcribing.placeholderRecordingActionResult == .transcribing)
        #expect(DictationStatus.success(transcript: "Typed text").placeholderRecordingActionResult == .recording)
        #expect(DictationStatus.failure(message: "Missing permission").placeholderRecordingActionResult == .recording)
    }
}

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
    private(set) var hideCount = 0

    var lastPresentation: FloatingIndicatorPresentation? {
        presentations.last ?? nil
    }

    func update(with presentation: FloatingIndicatorPresentation?) {
        presentations.append(presentation)
    }

    func hide() {
        hideCount += 1
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

struct QuitConfirmationTests {

    @Test func mapsCancelAndQuitDecisionsToTerminationReplies() {
        #expect(QuitConfirmationPolicy.terminationReply(for: .cancel) == .terminateCancel)
        #expect(QuitConfirmationPolicy.terminationReply(for: .quit) == .terminateNow)
    }

    @Test func quitCopyWarnsWhenLaunchAtLoginIsNotEnabled() {
        let informativeText = QuitConfirmationCopy.informativeText(launchAtLoginStatus: .disabled)

        #expect(informativeText.contains("will stop listening"))
        #expect(informativeText.contains("will not be available after restart"))
    }

    @Test func quitCopyDoesNotAddRestartWarningWhenLaunchAtLoginIsEnabled() {
        let informativeText = QuitConfirmationCopy.informativeText(launchAtLoginStatus: .enabled)

        #expect(informativeText.contains("will stop listening"))
        #expect(informativeText.contains("will not be available after restart") == false)
    }

    @MainActor
    @Test func menuQuitDismissesBeforeSchedulingTermination() {
        var events: [String] = []
        var scheduledTermination: (@MainActor () -> Void)?

        MenuBarQuitRequest.requestAfterMenuDismissal(
            dismissMenu: {
                events.append("dismiss")
            },
            scheduleTermination: { terminate in
                events.append("schedule")
                scheduledTermination = terminate
            },
            terminate: {
                events.append("terminate")
            }
        )

        #expect(events == ["dismiss", "schedule"])
        scheduledTermination?()
        #expect(events == ["dismiss", "schedule", "terminate"])
    }

    @MainActor
    @Test func applicationDelegateUsesInjectedQuitConfirmationPresenter() {
        let presenter = FakeQuitConfirmationPresenter(decision: .cancel)
        let delegate = HoldTypeAppDelegate(quitConfirmationPresenter: presenter)

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
        #expect(presenter.requestCount == 1)

        presenter.decision = .quit

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
        #expect(presenter.requestCount == 2)
    }

    @MainActor
    @Test func applicationDelegateSkipsQuitConfirmationForUpdaterRelaunch() {
        let presenter = FakeQuitConfirmationPresenter(decision: .cancel)
        let delegate = HoldTypeAppDelegate(
            quitConfirmationPresenter: presenter,
            isUpdaterRelaunchInProgress: { true }
        )

        #expect(delegate.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
        #expect(presenter.requestCount == 0)
    }

    @MainActor
    @Test func applicationDelegateStartsAndStopsRuntimeComponentsForNormalLaunch() {
        var startCount = 0
        var stopCount = 0
        var clearHistoryCount = 0
        let promptCoordinator = FakeTranscriptionFailurePromptCoordinator()
        let delegate = HoldTypeAppDelegate(
            quitConfirmationPresenter: FakeQuitConfirmationPresenter(decision: .quit),
            transcriptionFailurePromptCoordinator: promptCoordinator,
            launchEnvironment: [:],
            clearTranscriptHistory: {
                clearHistoryCount += 1
            },
            startRuntimeComponents: {
                startCount += 1
            },
            stopRuntimeComponents: {
                stopCount += 1
            }
        )

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        #expect(startCount == 1)
        #expect(stopCount == 1)
        #expect(clearHistoryCount == 1)
        #expect(promptCoordinator.startCount == 1)
        #expect(promptCoordinator.stopCount == 1)
    }

    @MainActor
    @Test func applicationDelegateSkipsRuntimeComponentsForInputMonitoringRecoveryLaunch() {
        var startCount = 0
        var stopCount = 0
        var clearHistoryCount = 0
        let promptCoordinator = FakeTranscriptionFailurePromptCoordinator()
        let delegate = HoldTypeAppDelegate(
            quitConfirmationPresenter: FakeQuitConfirmationPresenter(decision: .quit),
            transcriptionFailurePromptCoordinator: promptCoordinator,
            launchEnvironment: [InputMonitoringPermissionLaunchRecovery.requestEnvironmentKey: "1"],
            clearTranscriptHistory: {
                clearHistoryCount += 1
            },
            startRuntimeComponents: {
                startCount += 1
            },
            stopRuntimeComponents: {
                stopCount += 1
            }
        )

        delegate.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
        delegate.applicationWillTerminate(Notification(name: NSApplication.willTerminateNotification))

        #expect(startCount == 0)
        #expect(stopCount == 0)
        #expect(clearHistoryCount == 0)
        #expect(promptCoordinator.startCount == 0)
        #expect(promptCoordinator.stopCount == 0)
    }
}

@MainActor
private final class FakeQuitConfirmationPresenter: QuitConfirmationPresenting {
    var decision: QuitConfirmationDecision
    private(set) var requestCount = 0

    init(decision: QuitConfirmationDecision) {
        self.decision = decision
    }

    func requestQuitConfirmation() -> QuitConfirmationDecision {
        requestCount += 1
        return decision
    }
}

@MainActor
private final class FakeTranscriptionFailurePromptCoordinator: TranscriptionFailurePromptCoordinating {
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start() {
        startCount += 1
    }

    func stop() {
        stopCount += 1
    }
}
