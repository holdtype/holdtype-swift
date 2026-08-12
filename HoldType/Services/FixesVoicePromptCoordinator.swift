import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

@MainActor
final class FixesVoicePromptCoordinator {
    private let captureSession: any VoicePromptFixCapturing
    private let targetService: FocusedTextTargetService
    private let replacementService: any FocusedTextReplacing
    private let executionService: any TextFixExecuting
    private let panelPresenter: any FixesPalettePanelPresenting

    private var activeTask: Task<Void, Never>?
    private var snapshot: FocusedTextTargetSnapshot?
    private var settings: AppSettings?
    private var credential: OpenAICredential?
    private var model: FixesPaletteModel?
    private var onSuccess: (@MainActor () -> Void)?
    private var pendingAutomaticCompletion: Result<VoicePromptFixInstruction, Error>?
    private(set) var isActive = false

    init(
        captureSession: any VoicePromptFixCapturing,
        targetService: FocusedTextTargetService,
        replacementService: any FocusedTextReplacing,
        executionService: any TextFixExecuting,
        panelPresenter: any FixesPalettePanelPresenting
    ) {
        self.captureSession = captureSession
        self.targetService = targetService
        self.replacementService = replacementService
        self.executionService = executionService
        self.panelPresenter = panelPresenter
    }

    func start(
        snapshot: FocusedTextTargetSnapshot,
        settings: AppSettings,
        credential: OpenAICredential,
        model: FixesPaletteModel,
        onSuccess: @escaping @MainActor () -> Void
    ) {
        guard !isActive, activeTask == nil else {
            return
        }
        do {
            try targetService.validate(snapshot)
        } catch {
            model.updateStatus(
                .staleTarget(message: Self.userFacingMessage(for: error))
            )
            return
        }

        isActive = true
        self.snapshot = snapshot
        self.settings = settings
        self.credential = credential
        self.model = model
        self.onSuccess = onSuccess
        model.updateStatus(.preparingVoicePrompt)
        activeTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                try await self.captureSession.start(
                    settings: settings,
                    credential: credential,
                    automaticCompletionStarted: { [weak self] in
                        self?.model?.updateStatus(.transcribingVoicePrompt)
                    },
                    automaticCompletion: { [weak self] result in
                        self?.handleAutomaticCompletion(result)
                    }
                )
                guard self.isActive else {
                    return
                }
                if self.model?.status == .preparingVoicePrompt {
                    self.model?.updateStatus(.recordingVoicePrompt)
                }
            } catch is CancellationError {
                return
            } catch {
                self.fail(error, instructionWasAccepted: false)
            }
            self.activeTask = nil
            self.consumePendingAutomaticCompletion()
        }
    }

    func stop() {
        guard isActive,
              activeTask == nil,
              model?.status == .recordingVoicePrompt else {
            return
        }
        model?.updateStatus(.transcribingVoicePrompt)
        activeTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            do {
                let instruction = try await self.captureSession.finish()
                try await self.apply(instruction)
            } catch is CancellationError {
                return
            } catch {
                self.fail(error, instructionWasAccepted: false)
            }
            self.activeTask = nil
        }
    }

    func cancel() {
        guard isActive || activeTask != nil else {
            return
        }
        isActive = false
        activeTask?.cancel()
        activeTask = nil
        captureSession.cancel()
        executionService.cancelActiveExecution()
        clearContext()
    }

    private func handleAutomaticCompletion(
        _ result: Result<VoicePromptFixInstruction, Error>
    ) {
        guard isActive else {
            return
        }
        guard activeTask == nil else {
            pendingAutomaticCompletion = result
            return
        }
        processAutomaticCompletion(result)
    }

    private func consumePendingAutomaticCompletion() {
        guard let pendingAutomaticCompletion else {
            return
        }
        self.pendingAutomaticCompletion = nil
        processAutomaticCompletion(pendingAutomaticCompletion)
    }

    private func processAutomaticCompletion(
        _ result: Result<VoicePromptFixInstruction, Error>
    ) {
        activeTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            switch result {
            case .success(let instruction):
                do {
                    try await self.apply(instruction)
                } catch is CancellationError {
                    return
                } catch {
                    self.fail(error, instructionWasAccepted: true)
                }
            case .failure(let error):
                self.fail(error, instructionWasAccepted: false)
            }
            self.activeTask = nil
        }
    }

    private func apply(_ instruction: VoicePromptFixInstruction) async throws {
        guard isActive,
              let snapshot,
              let settings,
              let credential else {
            throw VoicePromptFixSessionError.sessionUnavailable
        }
        do {
            try targetService.validate(snapshot)
            model?.updateStatus(.applyingVoicePrompt)
            let output = try await executionService.executeVoicePrompt(
                instruction.text,
                sourceText: snapshot.sourceText,
                settings: settings,
                credential: credential
            )
            try Task.checkCancellation()
            try targetService.validate(snapshot)
            panelPresenter.releaseKeyboardFocus()
            try await replacementService.replace(snapshot: snapshot, with: output)
            try Task.checkCancellation()
            captureSession.completeApplication()
            isActive = false
            let completion = onSuccess
            clearContext()
            completion?()
        } catch {
            captureSession.failApplication()
            throw error
        }
    }

    private func fail(_ error: Error, instructionWasAccepted: Bool) {
        guard isActive else {
            return
        }
        if instructionWasAccepted {
            captureSession.failApplication()
        }
        isActive = false
        if let targetError = error as? FocusedTextTargetError,
           targetError == .stale {
            model?.updateStatus(
                .staleTarget(message: Self.userFacingMessage(for: error))
            )
        } else {
            model?.updateStatus(
                .failure(
                    message: Self.userFacingMessage(for: error),
                    allowsRetry: snapshot.map(snapshotStillValid) == true
                )
            )
        }
        clearContext(keepingModel: true)
    }

    private func snapshotStillValid(_ snapshot: FocusedTextTargetSnapshot) -> Bool {
        (try? targetService.validate(snapshot)) != nil
    }

    private func clearContext(keepingModel: Bool = false) {
        snapshot = nil
        settings = nil
        credential = nil
        onSuccess = nil
        pendingAutomaticCompletion = nil
        if !keepingModel {
            model = nil
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        return "Voice Prompt could not complete this Fix."
    }
}
