//
//  TranscriptionFailurePromptCoordinator.swift
//  HoldType
//
//  Created by Codex on 7/8/26.
//

import AppKit
import Combine

enum TranscriptionFailurePromptDecision: Equatable {
    case retry(FailedTranscriptionAttempt.ID)
    case openSettings(SettingsNavigationItem)
    case dismiss
}

enum TranscriptionFailurePromptActions {
    static func actions(for presentation: DictationFailurePresentation) -> [TranscriptionFailurePromptDecision] {
        var actions: [TranscriptionFailurePromptDecision] = []

        if let settingsTarget = presentation.settingsTarget {
            actions.append(.openSettings(settingsTarget))
        }

        if let failedAttemptID = presentation.failedAttemptID,
           presentation.canRetry {
            actions.append(.retry(failedAttemptID))
        }

        actions.append(.dismiss)
        return actions
    }
}

enum TranscriptionFailurePromptCopy {
    static func informativeText(for presentation: DictationFailurePresentation) -> String {
        let message = presentation.message.trimmingCharacters(in: .whitespacesAndNewlines)
        var paragraphs = [
            message.isEmpty ? "The recording was not transcribed." : message
        ]

        if presentation.failedAttemptID != nil {
            paragraphs.append("The recording was saved for retry.")
        }

        return paragraphs.joined(separator: "\n\n")
    }

    static func buttonTitle(for decision: TranscriptionFailurePromptDecision) -> String {
        switch decision {
        case .retry:
            return "Try Again"
        case .openSettings(let item):
            return settingsActionTitle(for: item)
        case .dismiss:
            return "Dismiss"
        }
    }

    private static func settingsActionTitle(for item: SettingsNavigationItem) -> String {
        switch item {
        case .openAI:
            return "Open OpenAI Settings"
        case .transcription:
            return "Open Transcription Settings"
        case .translation:
            return "Open Translation Settings"
        default:
            return "Open Settings"
        }
    }
}

@MainActor
protocol TranscriptionFailurePromptPresenting {
    func requestRecoveryDecision(
        for presentation: DictationFailurePresentation
    ) -> TranscriptionFailurePromptDecision
}

@MainActor
protocol TranscriptionFailurePromptCoordinating: AnyObject {
    func start()
    func stop()
}

@MainActor
final class TranscriptionFailurePromptCoordinator: TranscriptionFailurePromptCoordinating {
    private let dictationRuntime: DictationRuntime
    private let presenter: any TranscriptionFailurePromptPresenting
    private let settingsPresenter: any SetupSettingsPresenting
    private var failureStateCancellable: AnyCancellable?
    private var pendingPresentationTask: Task<Void, Never>?
    private var isPresenting = false

    convenience init(dictationRuntime: DictationRuntime) {
        self.init(
            dictationRuntime: dictationRuntime,
            presenter: NativeTranscriptionFailurePromptPresenter(),
            settingsPresenter: SettingsWindowPresenter.shared
        )
    }

    init(
        dictationRuntime: DictationRuntime,
        presenter: any TranscriptionFailurePromptPresenting,
        settingsPresenter: any SetupSettingsPresenting
    ) {
        self.dictationRuntime = dictationRuntime
        self.presenter = presenter
        self.settingsPresenter = settingsPresenter
    }

    func start() {
        guard failureStateCancellable == nil else {
            return
        }

        failureStateCancellable = dictationRuntime.$failurePresentation
            .combineLatest(dictationRuntime.$status)
            .sink { [weak self] presentation, status in
                Task { @MainActor in
                    self?.schedulePresentationIfNeeded(presentation, status: status)
                }
            }

        schedulePresentationIfNeeded(
            dictationRuntime.failurePresentation,
            status: dictationRuntime.status
        )
    }

    func stop() {
        failureStateCancellable?.cancel()
        failureStateCancellable = nil
        pendingPresentationTask?.cancel()
        pendingPresentationTask = nil
        isPresenting = false
    }

    private func schedulePresentationIfNeeded(
        _ presentation: DictationFailurePresentation?,
        status: DictationStatus
    ) {
        pendingPresentationTask?.cancel()
        pendingPresentationTask = nil

        guard let presentation,
              presentation.showsRecoveryPrompt,
              status.isTerminalFailure,
              !isPresenting else {
            return
        }

        pendingPresentationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled,
                  dictationRuntime.failurePresentation == presentation,
                  dictationRuntime.status.isTerminalFailure else {
                return
            }

            pendingPresentationTask = nil
            present(presentation)
        }
    }

    private func present(_ presentation: DictationFailurePresentation) {
        guard !isPresenting else {
            return
        }

        isPresenting = true
        let decision = presenter.requestRecoveryDecision(for: presentation)
        isPresenting = false
        handle(decision)
    }

    private func handle(_ decision: TranscriptionFailurePromptDecision) {
        switch decision {
        case .retry(let id):
            Task {
                await dictationRuntime.retryFailedTranscription(
                    id: id,
                    outputMode: .followAutomaticInsertion
                )
            }
        case .openSettings(let item):
            settingsPresenter.show(focusing: item)
        case .dismiss:
            dictationRuntime.dismissFailurePresentation()
        }
    }
}

@MainActor
struct NativeTranscriptionFailurePromptPresenter: TranscriptionFailurePromptPresenting {
    func requestRecoveryDecision(
        for presentation: DictationFailurePresentation
    ) -> TranscriptionFailurePromptDecision {
        let shouldRestoreAccessoryAfterPrompt = !hasVisibleAppWindow
        let actions = TranscriptionFailurePromptActions.actions(for: presentation)

        AppWindowActivation.showRegularApp()

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = presentation.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Transcription failed"
            : presentation.title
        alert.informativeText = TranscriptionFailurePromptCopy.informativeText(for: presentation)

        for action in actions {
            alert.addButton(withTitle: TranscriptionFailurePromptCopy.buttonTitle(for: action))
        }

        bringAlertToFront(alert)
        let response = alert.runModal()
        let decision = decision(for: response, actions: actions)

        if shouldRestoreAccessoryAfterPrompt, !decision.opensSettings {
            AppWindowActivation.restoreAccessoryIfNoVisibleAppWindows(excluding: alert.window)
        }

        return decision
    }

    private func decision(
        for response: NSApplication.ModalResponse,
        actions: [TranscriptionFailurePromptDecision]
    ) -> TranscriptionFailurePromptDecision {
        let buttonIndex = response.rawValue - NSApplication.ModalResponse.alertFirstButtonReturn.rawValue
        guard actions.indices.contains(buttonIndex) else {
            return .dismiss
        }

        return actions[buttonIndex]
    }

    private func bringAlertToFront(_ alert: NSAlert) {
        let alertWindow = alert.window
        alertWindow.level = .modalPanel
        alertWindow.collectionBehavior = alertWindow.collectionBehavior.union(.moveToActiveSpace)
        alertWindow.makeKeyAndOrderFront(nil)
        alertWindow.orderFrontRegardless()
    }

    private var hasVisibleAppWindow: Bool {
        NSApplication.shared.windows.contains { window in
            window.isVisible
                && !window.isMiniaturized
                && window.canBecomeKey
        }
    }
}

private extension TranscriptionFailurePromptDecision {
    var opensSettings: Bool {
        if case .openSettings = self {
            return true
        }

        return false
    }
}

private extension DictationStatus {
    var isTerminalFailure: Bool {
        if case .failure = self {
            return true
        }

        return false
    }
}
