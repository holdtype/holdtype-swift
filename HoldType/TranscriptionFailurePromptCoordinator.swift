import Combine
import SwiftUI

enum TranscriptionFailurePromptDecision: Hashable {
    case retry(FailedTranscriptionAttempt.ID)
    case transcribeAgain(FailedTranscriptionAttempt.ID)
    case openSettings(SettingsNavigationItem)
    case dismiss
}

enum TranscriptionFailurePromptActions {
    static func actions(for presentation: DictationFailurePresentation) -> [TranscriptionFailurePromptDecision] {
        var actions: [TranscriptionFailurePromptDecision] = []

        if let settingsTarget = presentation.settingsTarget {
            actions.append(.openSettings(settingsTarget))
        }

        if let failedAttemptID = presentation.failedAttemptID {
            if presentation.canRetry {
                actions.append(.retry(failedAttemptID))
            } else if presentation.requiresDuplicateRetryConfirmation {
                actions.append(.transcribeAgain(failedAttemptID))
            }
        }

        actions.append(.dismiss)
        return actions
    }
}

enum TranscriptionFailurePromptCopy {
    static let repeatTranscriptionConfirmation =
        "The previous request may already have completed. Sending this saved recording again could create a duplicate transcription."

    static func informativeText(for presentation: DictationFailurePresentation) -> String {
        let message = presentation.message.trimmingCharacters(in: .whitespacesAndNewlines)
        var paragraphs = [
            message.isEmpty ? "The recording was not transcribed." : message
        ]

        if presentation.canRetry {
            paragraphs.append("The recording was saved for retry.")
        } else if presentation.requiresDuplicateRetryConfirmation {
            paragraphs.append("The recording was saved in Transcript History.")
        }

        return paragraphs.joined(separator: "\n\n")
    }

    static func buttonTitle(for decision: TranscriptionFailurePromptDecision) -> String {
        switch decision {
        case .retry:
            return "Retry Transcription"
        case .transcribeAgain:
            return "Transcribe Again…"
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
protocol TranscriptionFailurePromptCoordinating: AnyObject {
    func start()
    func stop()
}

@MainActor
final class TranscriptionFailurePromptCoordinator: ObservableObject, TranscriptionFailurePromptCoordinating {
    static let shared = TranscriptionFailurePromptCoordinator()

    @Published private(set) var presentation: DictationFailurePresentation?

    private let dictationRuntime: DictationRuntime
    private let settingsPresenter: any SetupSettingsPresenting
    private var failureStateCancellable: AnyCancellable?
    private var pendingPresentationTask: Task<Void, Never>?
    private var openPromptWindow: (() -> Void)?

    init(
        dictationRuntime: DictationRuntime = .shared,
        settingsPresenter: any SetupSettingsPresenting = SettingsPresentationCoordinator.shared
    ) {
        self.dictationRuntime = dictationRuntime
        self.settingsPresenter = settingsPresenter
    }

    func install(openPromptWindow: @escaping () -> Void) {
        self.openPromptWindow = openPromptWindow
        if presentation != nil {
            openPromptWindow()
        }
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
        presentation = nil
    }

    func resolve(_ decision: TranscriptionFailurePromptDecision) {
        guard presentation != nil else {
            return
        }

        presentation = nil
        switch decision {
        case .retry(let id):
            Task {
                await dictationRuntime.retryFailedTranscription(
                    id: id,
                    outputMode: .followAutomaticInsertion
                )
            }
        case .transcribeAgain(let id):
            Task {
                await dictationRuntime.retryUncertainTranscription(
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

    func dismissIfNeeded() {
        resolve(.dismiss)
    }

    private func schedulePresentationIfNeeded(
        _ failurePresentation: DictationFailurePresentation?,
        status: DictationStatus
    ) {
        pendingPresentationTask?.cancel()
        pendingPresentationTask = nil

        guard let failurePresentation,
              failurePresentation.showsRecoveryPrompt,
              status.isTerminalFailure,
              presentation == nil else {
            return
        }

        pendingPresentationTask = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled,
                  dictationRuntime.failurePresentation == failurePresentation,
                  dictationRuntime.status.isTerminalFailure else {
                return
            }

            pendingPresentationTask = nil
            presentation = failurePresentation
            openPromptWindow?()
        }
    }
}

struct TranscriptionFailurePromptScene: Scene {
    static let identifier = "holdtype.transcription-failure"

    var body: some Scene {
        Window("Transcription failed", id: Self.identifier) {
            TranscriptionFailurePromptAlertHost(coordinator: .shared)
        }
        .defaultSize(width: 1, height: 1)
        .windowResizability(.contentSize)
    }
}

private struct TranscriptionFailurePromptAlertHost: View {
    @ObservedObject var coordinator: TranscriptionFailurePromptCoordinator
    @Environment(\.dismiss) private var dismiss
    @State private var presentation: DictationFailurePresentation?
    @State private var isRecoveryAlertPresented = false
    @State private var isDuplicateRetryConfirmationPresented = false
    @State private var isTransitioningToDuplicateRetryConfirmation = false

    var body: some View {
        ZStack {
            Color.clear
                .frame(width: 1, height: 1)
                .alert(
                    presentation?.title ?? "Transcription failed",
                    isPresented: recoveryAlertBinding
                ) {
                    recoveryActions
                } message: {
                    Text(recoveryMessage)
                }

            Color.clear
                .frame(width: 1, height: 1)
                .alert(
                    "Transcribe this recording again?",
                    isPresented: duplicateRetryConfirmationBinding
                ) {
                    Button("Transcribe Again") {
                        guard let action = duplicateRetryAction else {
                            return
                        }
                        resolve(action)
                    }
                    .keyboardShortcut(.defaultAction)

                    Button("Cancel", role: .cancel) {
                        isRecoveryAlertPresented = presentation != nil
                    }
                    .keyboardShortcut(.cancelAction)
                } message: {
                    Text(TranscriptionFailurePromptCopy.repeatTranscriptionConfirmation)
                }
        }
        .onAppear(perform: synchronizePresentation)
        .onChange(of: coordinator.presentation) { _, _ in
            synchronizePresentation()
        }
        .onDisappear {
            coordinator.dismissIfNeeded()
        }
    }

    private var recoveryAlertBinding: Binding<Bool> {
        Binding(
            get: { isRecoveryAlertPresented },
            set: { isPresented in
                isRecoveryAlertPresented = isPresented
                guard !isPresented, !isTransitioningToDuplicateRetryConfirmation else {
                    return
                }
                resolve(.dismiss)
            }
        )
    }

    private var duplicateRetryConfirmationBinding: Binding<Bool> {
        Binding(
            get: { isDuplicateRetryConfirmationPresented },
            set: { isPresented in
                isDuplicateRetryConfirmationPresented = isPresented
                guard !isPresented, presentation != nil else {
                    return
                }
                isRecoveryAlertPresented = true
            }
        )
    }

    @ViewBuilder
    private var recoveryActions: some View {
        ForEach(actions, id: \.self) { action in
            recoveryButton(for: action)
        }
    }

    private var recoveryMessage: String {
        guard let presentation else {
            return ""
        }

        return TranscriptionFailurePromptCopy.informativeText(for: presentation)
    }

    private var actions: [TranscriptionFailurePromptDecision] {
        guard let presentation else {
            return [.dismiss]
        }

        return TranscriptionFailurePromptActions.actions(for: presentation)
    }

    private var duplicateRetryAction: TranscriptionFailurePromptDecision? {
        actions.first { action in
            if case .transcribeAgain = action {
                return true
            }
            return false
        }
    }

    @ViewBuilder
    private func recoveryButton(for action: TranscriptionFailurePromptDecision) -> some View {
        switch action {
        case .dismiss:
            Button(TranscriptionFailurePromptCopy.buttonTitle(for: action), role: .cancel) {
                resolve(action)
            }
            .keyboardShortcut(.cancelAction)
        case .transcribeAgain:
            Button(TranscriptionFailurePromptCopy.buttonTitle(for: action)) {
                isTransitioningToDuplicateRetryConfirmation = true
                isRecoveryAlertPresented = false
                Task { @MainActor in
                    await Task.yield()
                    isTransitioningToDuplicateRetryConfirmation = false
                    isDuplicateRetryConfirmationPresented = true
                }
            }
            .keyboardShortcut(.defaultAction)
        default:
            Button(TranscriptionFailurePromptCopy.buttonTitle(for: action)) {
                resolve(action)
            }
            .keyboardShortcut(action == actions.first ? .defaultAction : .cancelAction)
        }
    }

    private func synchronizePresentation() {
        presentation = coordinator.presentation
        isRecoveryAlertPresented = presentation != nil
    }

    private func resolve(_ decision: TranscriptionFailurePromptDecision) {
        coordinator.resolve(decision)
        dismiss()
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
