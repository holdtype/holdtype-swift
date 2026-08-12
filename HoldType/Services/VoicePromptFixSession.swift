import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

struct VoicePromptFixInstruction: Equatable {
    let text: String
    let recoveryAttemptID: FailedTranscriptionAttempt.ID
}

protocol VoicePromptRecordingPreflighting {
    func requestMicrophonePermissionIfNeeded() async -> MicrophonePermissionStatus?
}

extension RecordingSetupPreflight: VoicePromptRecordingPreflighting {}

@MainActor
protocol VoicePromptFixCapturing: AnyObject {
    func start(
        settings: AppSettings,
        credential: OpenAICredential,
        automaticCompletionStarted: @escaping @MainActor () -> Void,
        automaticCompletion: @escaping @MainActor (Result<VoicePromptFixInstruction, Error>) -> Void
    ) async throws
    func finish() async throws -> VoicePromptFixInstruction
    func completeApplication()
    func failApplication()
    func cancel()
}

@MainActor
final class VoicePromptFixSession: VoicePromptFixCapturing {
    static let maximumDuration: TimeInterval = 60

    private enum Phase: Equatable {
        case idle
        case preparing
        case recording
        case processing
        case awaitingApplication
    }

    private let recorder: any AudioRecorderService
    private let setupPreflight: any VoicePromptRecordingPreflighting
    private let transcriptionService: any OpenAITranscriptionServing
    private let transcriptPipeline: DictationTranscriptPipeline
    private let recoveryStore: any TranscriptionFailureRecoveryRecording
    private let captureJournal: any RecordingCaptureJournaling
    private let recordingCache: any RecordingCacheLifecycleHandling
    private let usageRecorder: any TranscriptionUsageRecording
    private let transcriptionIDGenerator: () -> UUID
    private let voiceWorkReservation: VoiceWorkReservation

    private var phase = Phase.idle
    private var settings: AppSettings?
    private var credential: OpenAICredential?
    private var captureLease: RecordingCaptureLease?
    private var recoveryAttemptID: FailedTranscriptionAttempt.ID?
    private var automaticTask: Task<Void, Never>?
    private var automaticCompletionStarted: (@MainActor () -> Void)?
    private var automaticCompletion: (@MainActor (Result<VoicePromptFixInstruction, Error>) -> Void)?

    convenience init() {
        self.init(
            recorder: AVFoundationAudioRecorderService(),
            setupPreflight: RecordingSetupPreflight(),
            transcriptionService: OpenAITranscriptionService(),
            textCorrectionService: TranscriptTextCorrectionService(),
            recoveryStore: TranscriptionFailureRecoveryStore.shared,
            captureJournal: RecordingCaptureJournal.shared,
            recordingCache: RecordingCacheService.shared,
            usageRecorder: OpenAIUsageStore.shared,
            voiceWorkReservation: .shared
        )
    }

    init(
        recorder: any AudioRecorderService,
        setupPreflight: any VoicePromptRecordingPreflighting,
        transcriptionService: any OpenAITranscriptionServing,
        textCorrectionService: any TextCorrectionServing,
        recoveryStore: any TranscriptionFailureRecoveryRecording,
        captureJournal: any RecordingCaptureJournaling,
        recordingCache: any RecordingCacheLifecycleHandling,
        usageRecorder: any TranscriptionUsageRecording,
        transcriptionIDGenerator: @escaping () -> UUID = UUID.init,
        voiceWorkReservation: VoiceWorkReservation
    ) {
        self.recorder = recorder
        self.setupPreflight = setupPreflight
        self.transcriptionService = transcriptionService
        self.transcriptPipeline = DictationTranscriptPipeline(
            textCorrectionService: textCorrectionService,
            translationService: TranscriptTranslationService()
        )
        self.recoveryStore = recoveryStore
        self.captureJournal = captureJournal
        self.recordingCache = recordingCache
        self.usageRecorder = usageRecorder
        self.transcriptionIDGenerator = transcriptionIDGenerator
        self.voiceWorkReservation = voiceWorkReservation
    }

    func start(
        settings: AppSettings,
        credential: OpenAICredential,
        automaticCompletionStarted: @escaping @MainActor () -> Void,
        automaticCompletion: @escaping @MainActor (Result<VoicePromptFixInstruction, Error>) -> Void
    ) async throws {
        guard phase == .idle,
              voiceWorkReservation.acquire(.voicePromptFix) else {
            throw VoicePromptFixSessionError.voiceWorkUnavailable
        }
        phase = .preparing

        do {
            if let permission = await setupPreflight.requestMicrophonePermissionIfNeeded(),
               permission != .allowed {
                throw VoicePromptFixSessionError.microphoneUnavailable(
                    message: permission.settingsDescription
                )
            }
            try Task.checkCancellation()

            self.settings = settings
            self.credential = credential
            self.automaticCompletionStarted = automaticCompletionStarted
            self.automaticCompletion = automaticCompletion
            let lease = recorder.acceptsPreparedRecordingFileURL
                ? try captureJournal.prepareCapture(
                    settings: settings,
                    maximumDuration: Self.maximumDuration
                )
                : nil
            captureLease = lease
            recorder.setAutomaticStopHandler { [weak self] result in
                self?.handleAutomaticStop(result)
            }
            try await recorder.startRecording(
                maximumDuration: Self.maximumDuration,
                outputFileURL: lease?.audioFileURL
            )
            phase = .recording
        } catch {
            discardPreparedCapture()
            resetSession()
            throw error
        }
    }

    func finish() async throws -> VoicePromptFixInstruction {
        guard phase == .recording else {
            throw VoicePromptFixSessionError.notRecording
        }
        phase = .processing
        do {
            let outcome = try await recorder.stopRecordingOutcome()
            return try await process(outcome.artifact)
        } catch {
            finishWithFailure(error)
            throw error
        }
    }

    func completeApplication() {
        if let recoveryAttemptID {
            try? recoveryStore.removeFailedAttempt(id: recoveryAttemptID)
        }
        resetSession()
    }

    func failApplication() {
        if let recoveryAttemptID {
            try? recoveryStore.updateFailedAttempt(
                id: recoveryAttemptID,
                reason: .voicePromptFailed
            )
        }
        resetSession()
    }

    func cancel() {
        automaticTask?.cancel()
        transcriptionService.cancelActiveTranscription()
        transcriptPipeline.cancelActivePostProcessing()
        switch phase {
        case .preparing:
            discardPreparedCapture()
        case .recording:
            recorder.cancelRecording()
            discardPreparedCapture()
        case .processing, .awaitingApplication:
            if let recoveryAttemptID {
                try? recoveryStore.removeFailedAttempt(id: recoveryAttemptID)
            }
        case .idle:
            break
        }
        resetSession()
    }

    private func handleAutomaticStop(
        _ result: Result<AudioRecorderAutomaticCompletion, AudioRecorderServiceError>
    ) {
        guard phase == .recording else {
            return
        }
        phase = .processing
        automaticCompletionStarted?()
        let completionHandler = automaticCompletion
        automaticTask = Task { @MainActor [weak self] in
            guard let self else {
                return
            }
            let processed: Result<VoicePromptFixInstruction, Error>
            do {
                let completion = try result.get()
                processed = .success(try await self.process(completion.artifact))
            } catch {
                self.finishWithFailure(error)
                processed = .failure(error)
            }
            completionHandler?(processed)
            self.automaticTask = nil
        }
    }

    private func process(
        _ artifact: AudioRecordingArtifact
    ) async throws -> VoicePromptFixInstruction {
        guard let settings, let credential else {
            throw VoicePromptFixSessionError.sessionUnavailable
        }
        let checkpoint = try recoveryStore.recordProcessingCheckpoint(
            audioFileURL: artifact.fileURL,
            settings: settings,
            audioDuration: artifact.duration,
            completionKind: .voicePrompt
        )
        recoveryAttemptID = checkpoint.id
        let releasedArtifact = try releaseCapture(
            artifact,
            recoveryAttemptID: checkpoint.id
        )
        try? recordingCache.handleCompletedRecording(
            releasedArtifact,
            policy: .deleteImmediately
        )

        let request = try transcriptPipeline.makeAudioTranscriptionRequest(
            audioFileURL: checkpoint.audioFileURL,
            settings: settings,
            context: nil
        )
        try recoveryStore.sealProviderDispatch(id: checkpoint.id)
        let rawTranscript = try await transcriptionService.transcribe(
            request,
            credential: credential
        )
        let accepted = try AcceptedTranscript(rawText: rawTranscript)
        recordUsage(model: request.model, duration: artifact.duration)
        let corrected = await transcriptPipeline.correctedTranscriptText(
            from: accepted,
            settings: settings,
            credential: credential
        )
        guard let instruction = AcceptedTranscript.nonEmptyNormalizedText(from: corrected),
              instruction.utf8.count <= TextTransformationRequest.maximumPromptUTF8ByteCount else {
            throw VoicePromptFixSessionError.instructionTooLarge
        }
        phase = .awaitingApplication
        return VoicePromptFixInstruction(
            text: instruction,
            recoveryAttemptID: checkpoint.id
        )
    }

    private func releaseCapture(
        _ artifact: AudioRecordingArtifact,
        recoveryAttemptID: FailedTranscriptionAttempt.ID
    ) throws -> AudioRecordingArtifact {
        guard let captureLease else {
            return artifact
        }
        let released = try captureJournal.releaseCapture(
            captureLease,
            artifact: artifact,
            recoveryAttemptID: recoveryAttemptID
        )
        self.captureLease = nil
        return released
    }

    private func finishWithFailure(_ error: Error) {
        if let recoveryAttemptID {
            let reason = error is VoicePromptFixSessionError
                ? FailedTranscriptionReason.voicePromptFailed
                : FailedTranscriptionReason(error: error)
            try? recoveryStore.updateFailedAttempt(id: recoveryAttemptID, reason: reason)
            if let captureLease {
                try? captureJournal.retireCaptureAfterRecovery(
                    captureLease,
                    recoveryAttemptID: recoveryAttemptID
                )
            }
        } else {
            discardPreparedCapture()
        }
        resetSession()
    }

    private func recordUsage(model: String, duration: TimeInterval) {
        guard let usage = try? SuccessfulTranscriptionUsage(
            transcriptionID: transcriptionIDGenerator(),
            model: model,
            audioDuration: duration
        ) else {
            return
        }
        usageRecorder.recordSuccessfulTranscriptionUsage(usage)
    }

    private func discardPreparedCapture() {
        if let captureLease {
            try? captureJournal.discardCapture(captureLease)
        }
        captureLease = nil
    }

    private func resetSession() {
        recorder.setAutomaticStopHandler(nil)
        phase = .idle
        settings = nil
        credential = nil
        captureLease = nil
        recoveryAttemptID = nil
        automaticCompletionStarted = nil
        automaticCompletion = nil
        voiceWorkReservation.release(.voicePromptFix)
    }
}

enum VoicePromptFixSessionError: Error, Equatable, LocalizedError {
    case voiceWorkUnavailable
    case microphoneUnavailable(message: String)
    case notRecording
    case sessionUnavailable
    case instructionTooLarge

    var errorDescription: String? {
        switch self {
        case .voiceWorkUnavailable:
            return "Finish the current dictation before starting a Voice Prompt."
        case .microphoneUnavailable(let message):
            return message
        case .notRecording, .sessionUnavailable:
            return "The Voice Prompt recording is no longer available."
        case .instructionTooLarge:
            return "The spoken instruction is too long for one Fix."
        }
    }
}
