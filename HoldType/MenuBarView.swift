//
//  MenuBarView.swift
//  HoldType
//
//  Created by Eugene Potapenko on 6/20/26.
//

import HoldTypeDomain
import SwiftUI

struct MenuBarView: View {
    private static let menuWidth: CGFloat = 420

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    @StateObject private var dictationRuntime: DictationRuntime
    @State private var duplicateRetryID: FailedTranscriptionAttempt.ID?

    init(
        dictationRuntime: DictationRuntime? = nil
    ) {
        _dictationRuntime = StateObject(wrappedValue: dictationRuntime ?? .shared)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(presentation.appTitle)
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            Text(presentation.statusText)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            if presentation.showsFailureRecoveryActions {
                failureRecoverySection(dictationRuntime.failurePresentation)
            }

            Divider()

            MenuBarActionButton(
                title: presentation.recordingActionTitle,
                shortcutHint: presentation.recordingActionShortcutHint,
                isEnabled: presentation.isRecordingActionEnabled
            ) {
                performRecordingAction()
            }

            MenuBarActionButton(
                title: presentation.translationActionTitle,
                shortcutHint: presentation.translationActionShortcutHint,
                isEnabled: presentation.isTranslationActionEnabled
            ) {
                performTranslationRecordingAction()
            }

            MenuBarActionButton(
                title: presentation.pasteLastResultTitle,
                shortcutHint: presentation.pasteLastResultActionShortcutHint,
                isEnabled: presentation.isPasteLastResultEnabled
            ) {
                pasteLastResult()
            }

            Divider()

            ForEach(MenuBarPresentation.utilityActions, id: \.self) { action in
                MenuBarActionButton(title: action.title) {
                    performUtilityAction(action)
                }
            }

            Divider()

            MenuBarActionButton(title: MenuBarPresentation.quitTitle) {
                MenuBarQuitRequest.requestAfterMenuDismissal {
                    dismiss()
                }
            }
        }
        .frame(width: Self.menuWidth)
        .padding(.vertical, 8)
        .confirmationDialog(
            "Transcribe this recording again?",
            isPresented: duplicateRetryConfirmationIsPresented
        ) {
            Button("Transcribe Again") {
                if let duplicateRetryID {
                    retryUncertainTranscription(id: duplicateRetryID)
                }
                duplicateRetryID = nil
            }
            Button("Cancel", role: .cancel) {
                duplicateRetryID = nil
            }
        } message: {
            Text(TranscriptionFailurePromptCopy.repeatTranscriptionConfirmation)
        }
    }

    private var presentation: MenuBarPresentation {
        MenuBarPresentation(
            dictationStatus: dictationRuntime.status,
            failurePresentation: dictationRuntime.failurePresentation,
            outputStatusText: dictationRuntime.outputStatusText,
            recordingCountdown: dictationRuntime.recordingCountdown,
            settings: dictationRuntime.appSettings,
            shortcutConfiguration: dictationRuntime.shortcutConfiguration,
            isLastResultPasteAvailable: dictationRuntime.isLastResultPasteAvailable
        )
    }

    private func performRecordingAction() {
        dismiss()
        Task {
            await dictationRuntime.performRecordingAction()
        }
    }

    private func performTranslationRecordingAction() {
        dismiss()
        Task {
            await dictationRuntime.performRecordingAction(intent: .translate)
        }
    }

    private func pasteLastResult() {
        dismiss()
        Task {
            await dictationRuntime.pasteLastResult()
        }
    }

    private func performUtilityAction(
        _ action: MenuBarPresentation.UtilityAction
    ) {
        switch action {
        case .devVlogs:
            openDevVlogs()
        case .editFixes:
            openFixesEditor()
        case .history:
            openTranscriptHistory()
        case .settings:
            openSettingsScene()
        }
    }

    private func openDevVlogs() {
        DevVlogsWindowRequest.openAfterMenuDismissal(
            dismissMenu: {
                dismiss()
            },
            openDevVlogs: {
                openWindow(id: DevVlogsScene.identifier)
            }
        )
    }

    private func openFixesEditor() {
        FixesEditorWindowRequest.reopen(
            dismissMenu: {
                dismiss()
            },
            dismissExistingEditor: {
                dismissWindow(id: FixesEditorScene.identifier)
            },
            openFreshEditor: {
                openWindow(id: FixesEditorScene.identifier)
            }
        )
    }

    private func openTranscriptHistory() {
        TranscriptHistoryWindowRequest.openAfterMenuDismissal(
            dismissMenu: {
                dismiss()
            },
            openHistory: {
                openWindow(id: TranscriptHistoryScene.identifier)
            }
        )
    }

    @ViewBuilder
    private func failureRecoverySection(_ failurePresentation: DictationFailurePresentation?) -> some View {
        Divider()

        if let failedAttemptID = failurePresentation?.failedAttemptID,
           failurePresentation?.canRetry == true {
            MenuBarActionButton(title: "Retry Transcription") {
                retryFailedTranscription(id: failedAttemptID)
            }
        }

        if let failedAttemptID = failurePresentation?.failedAttemptID,
           failurePresentation?.requiresDuplicateRetryConfirmation == true {
            MenuBarActionButton(title: "Transcribe Again…") {
                duplicateRetryID = failedAttemptID
            }
        }

        if let settingsTarget = failurePresentation?.settingsTarget {
            MenuBarActionButton(title: settingsActionTitle(for: settingsTarget)) {
                openSettingsScene(focusing: settingsTarget)
            }
        }

        MenuBarActionButton(title: "Dismiss") {
            dismiss()
            dictationRuntime.dismissFailurePresentation()
        }
    }

    private func retryFailedTranscription(id: FailedTranscriptionAttempt.ID) {
        dismiss()
        Task {
            await dictationRuntime.retryFailedTranscription(
                id: id,
                outputMode: .followAutomaticInsertion
            )
        }
    }

    private var duplicateRetryConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { duplicateRetryID != nil },
            set: { isPresented in
                if !isPresented {
                    duplicateRetryID = nil
                }
            }
        )
    }

    private func retryUncertainTranscription(id: FailedTranscriptionAttempt.ID) {
        dismiss()
        Task {
            await dictationRuntime.retryUncertainTranscription(
                id: id,
                outputMode: .followAutomaticInsertion
            )
        }
    }

    private func settingsActionTitle(for item: SettingsNavigationItem) -> String {
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

    private func openSettingsScene(focusing item: SettingsNavigationItem? = nil) {
        SettingsSceneRequest.openAfterMenuDismissal(
            focusing: item,
            dismissMenu: {
                dismiss()
            },
            openSettings: {
                openWindow(id: SettingsScene.identifier)
            }
        )
    }
}

@MainActor
enum FixesEditorWindowRequest {
    static let menuDismissalDelay: Duration = .milliseconds(250)
    static let editorCloseDelay: Duration = .milliseconds(350)

    static func reopen(
        dismissMenu: () -> Void,
        dismissExistingEditor: @escaping () -> Void,
        openFreshEditor: @escaping @MainActor () -> Void
    ) {
        reopen(
            dismissMenu: dismissMenu,
            dismissExistingEditor: dismissExistingEditor,
            scheduleAfterMenuDismissal: scheduleAfterMenuDismissal,
            scheduleAfterEditorClose: scheduleAfterEditorClose,
            activateApplication: AppWindowActivation.showRegularApp,
            openFreshEditor: openFreshEditor
        )
    }

    static func reopen(
        dismissMenu: () -> Void,
        dismissExistingEditor: @escaping () -> Void,
        scheduleAfterMenuDismissal: @escaping (@escaping @MainActor () -> Void) -> Void,
        scheduleAfterEditorClose: @escaping (@escaping @MainActor () -> Void) -> Void,
        activateApplication: @escaping @MainActor () -> Void,
        openFreshEditor: @escaping @MainActor () -> Void
    ) {
        dismissMenu()
        scheduleAfterMenuDismissal {
            dismissExistingEditor()
            scheduleAfterEditorClose {
                activateApplication()
                openFreshEditor()
            }
        }
    }

    private static func scheduleAfterMenuDismissal(
        _ action: @escaping @MainActor () -> Void
    ) {
        schedule(after: menuDismissalDelay, action)
    }

    private static func scheduleAfterEditorClose(
        _ action: @escaping @MainActor () -> Void
    ) {
        schedule(after: editorCloseDelay, action)
    }

    private static func schedule(
        after delay: Duration,
        _ openFreshEditor: @escaping @MainActor () -> Void
    ) {
        Task { @MainActor in
            try? await Task.sleep(for: delay)
            openFreshEditor()
        }
    }
}

@MainActor
enum MenuBarQuitRequest {
    static let delayAfterMenuDismissal: Duration = .milliseconds(100)

    static func requestAfterMenuDismissal(dismissMenu: () -> Void) {
        requestAfterMenuDismissal(
            dismissMenu: dismissMenu,
            scheduleTermination: scheduleTerminationAfterMenuDismissal,
            terminate: {
                NSApplication.shared.terminate(nil)
            }
        )
    }

    static func requestAfterMenuDismissal(
        dismissMenu: () -> Void,
        scheduleTermination: (@escaping @MainActor () -> Void) -> Void,
        terminate: @escaping @MainActor () -> Void
    ) {
        dismissMenu()
        scheduleTermination(terminate)
    }

    private static func scheduleTerminationAfterMenuDismissal(
        _ terminate: @escaping @MainActor () -> Void
    ) {
        Task { @MainActor in
            try? await Task.sleep(for: delayAfterMenuDismissal)
            terminate()
        }
    }
}

private struct MenuBarActionButton: View {
    let title: String
    var shortcutHint: String?
    var isEnabled = true
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 24)

                if let shortcutHint {
                    Text(shortcutHint)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .font(.body)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(rowBackground)
            .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if isHovered && isEnabled {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.accentColor.opacity(0.16))
                .padding(.horizontal, 8)
        }
    }
}

#Preview {
    MenuBarView()
}
