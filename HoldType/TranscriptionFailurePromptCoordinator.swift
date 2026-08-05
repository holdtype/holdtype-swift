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
    static let repeatTranscriptionConfirmation = "This will submit the saved recording for transcription again."

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
            return "Try Again"
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
            TranscriptionFailurePromptWindowContent(coordinator: .shared)
        }
        .defaultSize(width: 460, height: 240)
        .windowResizability(.contentSize)
    }
}

private struct TranscriptionFailurePromptWindowContent: View {
    @ObservedObject var coordinator: TranscriptionFailurePromptCoordinator
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if let presentation = coordinator.presentation {
                TranscriptionFailurePromptDialog(
                    presentation: presentation,
                    onResolve: resolve
                )
            } else {
                Color.clear.frame(width: 1, height: 1)
            }
        }
        .onDisappear {
            coordinator.dismissIfNeeded()
        }
    }

    private func resolve(_ decision: TranscriptionFailurePromptDecision) {
        coordinator.resolve(decision)
        dismiss()
    }
}

private struct TranscriptionFailurePromptDialog: View {
    let presentation: DictationFailurePresentation
    let onResolve: (TranscriptionFailurePromptDecision) -> Void
    @State private var isShowingDuplicateRetryConfirmation = false

    private var actions: [TranscriptionFailurePromptDecision] {
        TranscriptionFailurePromptActions.actions(for: presentation)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Label(presentation.title, systemImage: "exclamationmark.triangle.fill")
                .font(.headline)

            Text(TranscriptionFailurePromptCopy.informativeText(for: presentation))
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)

            HStack {
                Spacer()

                ForEach(actions, id: \.self) { action in
                    actionButton(for: action)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .confirmationDialog(
            "Transcribe this recording again?",
            isPresented: $isShowingDuplicateRetryConfirmation
        ) {
            Button("Transcribe Again") {
                if let action = actions.first(where: {
                    if case .transcribeAgain = $0 { return true }
                    return false
                }) {
                    onResolve(action)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(TranscriptionFailurePromptCopy.repeatTranscriptionConfirmation)
        }
    }

    @ViewBuilder
    private func actionButton(for action: TranscriptionFailurePromptDecision) -> some View {
        switch action {
        case .retry:
            Button(TranscriptionFailurePromptCopy.buttonTitle(for: action)) {
                onResolve(action)
            }
            .keyboardShortcut(.defaultAction)
        case .dismiss:
            Button(TranscriptionFailurePromptCopy.buttonTitle(for: action)) {
                onResolve(action)
            }
            .keyboardShortcut(.cancelAction)
        case .transcribeAgain:
            Button(TranscriptionFailurePromptCopy.buttonTitle(for: action)) {
                isShowingDuplicateRetryConfirmation = true
            }
        case .openSettings:
            Button(TranscriptionFailurePromptCopy.buttonTitle(for: action)) {
                onResolve(action)
            }
        }
    }
}

#Preview("Ambiguous provider result") {
    TranscriptionFailurePromptDialog(
        presentation: DictationFailurePresentation(
            title: FailedTranscriptionReason.providerOutcomeUncertain.title,
            message: FailedTranscriptionReason.providerOutcomeUncertain.message,
            failedAttemptID: UUID(),
            requiresDuplicateRetryConfirmation: true,
            showsRecoveryPrompt: true
        ),
        onResolve: { _ in }
    )
}

private extension DictationStatus {
    var isTerminalFailure: Bool {
        if case .failure = self {
            return true
        }

        return false
    }
}
