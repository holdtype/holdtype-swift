//
//  DictationSessionController.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

protocol TranscriptOutputDelivering {
    func deliver(_ request: OutputDeliveryRequest) async throws -> TextInsertionResult
}

extension TextInsertionService: TranscriptOutputDelivering {}

enum FailedTranscriptionRetryOutputMode: Equatable {
    case saveOnly
    case followAutomaticInsertion
}

private struct PendingFailedTranscriptionRetry {
    let id: FailedTranscriptionAttempt.ID
    let credential: OpenAICredential?
    let outputMode: FailedTranscriptionRetryOutputMode
}

protocol RecordingStopTailSleeping {
    func sleep(seconds: TimeInterval) async throws
}

struct TaskRecordingStopTailSleeper: RecordingStopTailSleeping {
    func sleep(seconds: TimeInterval) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

@MainActor
final class DictationSessionController {
    static let savedRecordingActionsUnavailableMessage =
        "Finish the current dictation before using a saved recording."
    private static let maximumDurationClassificationTolerance: TimeInterval = 0.5
    private static let recordingLimitSavingStatusText =
        "Recording limit reached. Saving recording..."
    private static let recordingLimitTranscribingStatusText =
        "Recording limit reached. Recording saved to History; transcribing..."
    private static let recordingLimitSaveFailedStatusText =
        "Text was accepted, but the recording that reached the limit could not be marked as saved."

    private let recorder: any AudioRecorderService
    private let transcriptionService: any OpenAITranscriptionServing
    private let textCorrectionService: any TextCorrectionServing
    private let translationService: any TranscriptTranslationServing
    private let settingsProvider: () -> AppSettings
    private let transcriptOutput: any TranscriptOutputDelivering
    private let cuePlayer: any DictationCuePlaying
    private let historyAudioPlaybackStopper: any TranscriptHistoryAudioPlaybackStopping
    private let recordingDurationMonitor: any RecordingDurationMonitoring
    private let privateAudioOutputRouteProvider: any PrivateAudioOutputRouteProviding
    private let transcriptHistory: any TranscriptRecoveryHistoryRecording
    private let transcriptionFailureRecovery: any TranscriptionFailureRecoveryRecording
    private let activeTextContextReader: any ActiveTextContextReading
    private let transcriptionUsageRecorder: any TranscriptionUsageRecording
    private let transcriptionIDGenerator: () -> UUID
    private let recordingCache: any RecordingCacheLifecycleHandling
    private let recordingStopTailSleeper: any RecordingStopTailSleeping
    private let eventLogger: any DictationEventLogging
    private let credentialResolverForUngatedActions: (any OpenAICredentialResolving)?

    private var isPerformingAction = false
    private var nextSessionID = 0
    private var activeSessionID: Int?
    private var activeOutputIntent: DictationOutputIntent?
    private var activeCredential: OpenAICredential?
    private var activeRecordingStopTailTask: Task<Void, Error>?
    private var pendingFailedTranscriptionRetry: PendingFailedTranscriptionRetry?
    private var pendingMaximumDurationCompletion = false
    private var activeRecoveryCheckpointID: FailedTranscriptionAttempt.ID?
    private var activeRecordingDurationLimit: RecordingDurationLimit?

    private(set) var recordingCountdown: VoiceSessionCountdown? {
        didSet {
            recordingCountdownDidChange?(recordingCountdown)
        }
    }

    var statusDidChange: (@MainActor (DictationStatus) -> Void)?
    var lastTranscriptTextDidChange: (@MainActor (String?) -> Void)?
    var outputStatusTextDidChange: (@MainActor (String?) -> Void)?
    var failurePresentationDidChange: (@MainActor (DictationFailurePresentation?) -> Void)?
    var recordingCountdownDidChange: (@MainActor (VoiceSessionCountdown?) -> Void)?

    private(set) var status: DictationStatus {
        didSet {
            statusDidChange?(status)
        }
    }
    private(set) var lastTranscriptText: String? {
        didSet {
            lastTranscriptTextDidChange?(lastTranscriptText)
        }
    }
    private(set) var outputStatusText: String? {
        didSet {
            outputStatusTextDidChange?(outputStatusText)
        }
    }
    private(set) var failurePresentation: DictationFailurePresentation? {
        didSet {
            failurePresentationDidChange?(failurePresentation)
        }
    }

    var voiceAttemptOutcome: VoiceAttemptOutcome? {
        if let statusOutcome = status.voiceAttemptOutcome {
            return statusOutcome
        }

        guard case .failure = status,
              let presentation = failurePresentation,
              presentation.canRetry,
              let failedAttemptID = presentation.failedAttemptID,
              let retainedAttempt = transcriptionFailureRecovery.failedAttempts.first(
                  where: { $0.id == failedAttemptID }
              ),
              retainedAttempt.reason.canRetry else {
            return nil
        }

        return .recoverableFailure
    }

    init(
        recorder: any AudioRecorderService = AVFoundationAudioRecorderService(),
        transcriptionService: any OpenAITranscriptionServing = OpenAITranscriptionService(),
        textCorrectionService: any TextCorrectionServing = TranscriptTextCorrectionService(),
        translationService: any TranscriptTranslationServing = TranscriptTranslationService(),
        settingsProvider: @escaping () -> AppSettings = { AppSettingsStore().load() },
        transcriptOutput: any TranscriptOutputDelivering = TextInsertionService(),
        cuePlayer: any DictationCuePlaying = NativeDictationCuePlayer.shared,
        historyAudioPlaybackStopper: any TranscriptHistoryAudioPlaybackStopping =
            TranscriptHistoryAudioPlayer.shared,
        recordingDurationMonitor: (any RecordingDurationMonitoring)? = nil,
        privateAudioOutputRouteProvider: any PrivateAudioOutputRouteProviding =
            CoreAudioPrivateOutputRouteProvider(),
        transcriptHistory: (any TranscriptRecoveryHistoryRecording)? = nil,
        transcriptionFailureRecovery: (any TranscriptionFailureRecoveryRecording)? = nil,
        activeTextContextReader: (any ActiveTextContextReading)? = nil,
        transcriptionUsageRecorder: (any TranscriptionUsageRecording)? = nil,
        transcriptionIDGenerator: @escaping () -> UUID = UUID.init,
        recordingCache: any RecordingCacheLifecycleHandling = RecordingCacheService.shared,
        recordingStopTailSleeper: any RecordingStopTailSleeping = TaskRecordingStopTailSleeper(),
        eventLogger: any DictationEventLogging = OSLogDictationEventLogger(),
        credentialResolverForUngatedActions: (any OpenAICredentialResolving)? = nil,
        initialStatus: DictationStatus = .idle,
        lastTranscriptText: String? = nil,
        outputStatusText: String? = nil
    ) {
        self.recorder = recorder
        self.transcriptionService = transcriptionService
        self.textCorrectionService = textCorrectionService
        self.translationService = translationService
        self.settingsProvider = settingsProvider
        self.transcriptOutput = transcriptOutput
        self.cuePlayer = cuePlayer
        self.historyAudioPlaybackStopper = historyAudioPlaybackStopper
        self.recordingDurationMonitor = recordingDurationMonitor
            ?? ContinuousRecordingDurationMonitor()
        self.privateAudioOutputRouteProvider = privateAudioOutputRouteProvider
        self.transcriptHistory = transcriptHistory ?? TranscriptRecoveryHistoryStore.shared
        self.transcriptionFailureRecovery = transcriptionFailureRecovery
            ?? TranscriptionFailureRecoveryStore.shared
        self.activeTextContextReader = activeTextContextReader ?? ActiveTextContextService()
        self.transcriptionUsageRecorder = transcriptionUsageRecorder ?? OpenAIUsageStore.shared
        self.transcriptionIDGenerator = transcriptionIDGenerator
        self.recordingCache = recordingCache
        self.recordingStopTailSleeper = recordingStopTailSleeper
        self.eventLogger = eventLogger
        self.credentialResolverForUngatedActions = credentialResolverForUngatedActions
        self.status = initialStatus
        self.lastTranscriptText = lastTranscriptText.flatMap {
            AcceptedTranscript.nonEmptyNormalizedText(from: $0)
        }
            ?? initialStatus.lastTranscriptText
        self.outputStatusText = outputStatusText
        self.failurePresentation = nil
        self.recordingCountdown = nil

        recorder.setAutomaticStopHandler { [weak self] result in
            self?.handleAutomaticRecorderStop(result)
        }
    }

    func performRecordingAction(
        intent: DictationOutputIntent = .standard,
        credential: OpenAICredential? = nil
    ) async {
        guard beginExclusiveAction() else {
            return
        }

        defer { completeExclusiveAction() }

        switch status.voiceWorkPhase {
        case .inactive:
            await startRecording(intent: intent, credential: credential)
        case .listening:
            await stopRecordingAndTranscribe(intent: intent, credential: credential)
        case .arming, .ready, .finalizing, .processing:
            return
        }
    }

    func cancelRecording() {
        switch status.voiceWorkPhase {
        case .listening:
            guard !isPerformingAction || activeRecordingStopTailTask != nil else {
                return
            }

            activeRecordingStopTailTask?.cancel()
            activeRecordingStopTailTask = nil
            recorder.cancelRecording()
            stopRecordingDurationMonitoring()
            pendingMaximumDurationCompletion = false
            cancelActiveSession()
            activeCredential = nil
            outputStatusText = nil
            failurePresentation = nil

            switch recorder.currentStatus {
            case .failed(let message):
                status = .failure(message: message)
            default:
                status = .idle
            }
        case .processing:
            markActiveRecoveryCheckpointInterrupted()
            transcriptionService.cancelActiveTranscription()
            textCorrectionService.cancelActiveCorrection()
            translationService.cancelActiveTranslation()
            cancelActiveSession()
            outputStatusText = nil
            failurePresentation = nil
            status = .idle
        case .inactive, .arming, .ready, .finalizing:
            return
        }
    }

    func dismissFailurePresentation() {
        failurePresentation = nil
        if case .failure = status {
            status = .idle
        }
    }

    func retryFailedTranscription(
        id: FailedTranscriptionAttempt.ID,
        credential: OpenAICredential? = nil,
        outputMode: FailedTranscriptionRetryOutputMode = .saveOnly
    ) async {
        guard status.voiceWorkPhase != .listening else {
            outputStatusText = Self.savedRecordingActionsUnavailableMessage
            return
        }

        let retry = PendingFailedTranscriptionRetry(
            id: id,
            credential: credential,
            outputMode: outputMode
        )

        guard beginExclusiveAction() else {
            pendingFailedTranscriptionRetry = retry
            return
        }

        defer { completeExclusiveAction() }

        await performFailedTranscriptionRetry(retry)
    }

    private func performFailedTranscriptionRetry(_ retry: PendingFailedTranscriptionRetry) async {
        guard let attempt = transcriptionFailureRecovery.failedAttempts.first(where: { $0.id == retry.id }) else {
            outputStatusText = TranscriptionFailureRecoveryError.attemptUnavailable.localizedDescription
            return
        }
        guard attempt.canRetry else {
            outputStatusText = attempt.state == .saved
                ? "This saved recording is already transcribed."
                : "This saved recording is not available for retry."
            return
        }

        outputStatusText = nil
        failurePresentation = nil
        var sessionID: Int?

        do {
            let credential = try resolvedCredential(providedCredential: retry.credential)
            sessionID = beginSession(intent: .standard)
            activeCredential = credential
            status = .transcribing
            let settings = settingsProvider()
            let transcriptionID = transcriptionIDGenerator()
            let transcriptionRequest = try makeAudioTranscriptionRequest(
                audioFileURL: attempt.audioFileURL,
                settings: settings,
                context: nil
            )
            activeRecoveryCheckpointID = attempt.id
            try transcriptionFailureRecovery.sealProviderDispatch(id: attempt.id)
            eventLogger.record(.transcriptionStarted)
            let rawTranscript = try await transcriptionService.transcribe(
                transcriptionRequest,
                credential: credential
            )
            eventLogger.record(.transcriptionSucceeded)
            guard let sessionID, isCurrentSession(sessionID) else {
                return
            }

            let transcribedTranscript = try Self.acceptedTranscript(from: rawTranscript)
            transcriptionFailureRecovery.recordProviderAccepted(
                id: attempt.id,
                acceptedTranscriptText: transcribedTranscript.text
            )
            recordSuccessfulTranscriptionUsage(
                transcriptionID: transcriptionID,
                model: transcriptionRequest.model,
                audioDuration: attempt.audioDuration
            )
            let correctedTranscriptText = await correctedTranscriptText(
                from: transcribedTranscript,
                settings: settings,
                credential: credential
            )
            guard isCurrentSession(sessionID) else {
                return
            }

            let acceptedTranscript = try Self.acceptedTranscript(from: correctedTranscriptText)
            let retainsMaximumDurationRecording =
                attempt.completionKind == .maximumDuration
            var savedRecordingUpdateFailed = false
            if retainsMaximumDurationRecording {
                do {
                    try transcriptionFailureRecovery.markSaved(
                        id: retry.id,
                        acceptedTranscriptText: acceptedTranscript.text
                    )
                } catch {
                    savedRecordingUpdateFailed = true
                }
            }

            lastTranscriptText = acceptedTranscript.text
            status = .success(transcript: acceptedTranscript.text)
            failurePresentation = nil

            if !retainsMaximumDurationRecording {
                recordRecoveryHistory(
                    acceptedTranscript,
                    settings: settings,
                    audioDuration: attempt.audioDuration,
                    cachedAudioFileURL: nil
                )
                do {
                    _ = try transcriptionFailureRecovery.removeFailedAttempt(id: retry.id)
                } catch {
                    outputStatusText = TranscriptionFailureRecoveryError.deleteFailed.localizedDescription
                }
            }
            if activeRecoveryCheckpointID == attempt.id {
                activeRecoveryCheckpointID = nil
            }

            let deliveryRequest = OutputDeliveryRequest(
                acceptedTranscript: acceptedTranscript,
                preferences: outputDeliveryPreferences(
                    from: settings,
                    retryOutputMode: retry.outputMode
                )
            )
            do {
                let deliveryStatusText = try await transcriptOutput.deliver(deliveryRequest).statusText
                outputStatusText = savedRecordingUpdateFailed
                    ? Self.recordingLimitSaveFailedStatusText
                    : deliveryStatusText
            } catch {
                guard isCurrentSession(sessionID) else {
                    return
                }

                recordFailure(error, at: .outputDelivery)
                outputStatusText = Self.userFacingMessage(for: error)
            }

            finishSession(sessionID)
        } catch {
            if let sessionID, !isCurrentSession(sessionID) {
                return
            }

            let reason = FailedTranscriptionReason(error: error)
            try? transcriptionFailureRecovery.updateFailedAttempt(id: retry.id, reason: reason)
            if activeRecoveryCheckpointID == attempt.id {
                activeRecoveryCheckpointID = nil
            }
            if let sessionID {
                finishSession(sessionID)
            }
            recordFailure(error, at: .transcription)
            let message = Self.userFacingMessage(for: error)
            status = .failure(message: message)
            failurePresentation = failurePresentation(
                message: message,
                error: error,
                failedAttempt: transcriptionFailureRecovery.failedAttempts.first { $0.id == retry.id },
                showsRecoveryPrompt: true
            )
        }
    }

    private func beginExclusiveAction() -> Bool {
        guard !isPerformingAction else {
            return false
        }

        isPerformingAction = true
        return true
    }

    private func completeExclusiveAction() {
        isPerformingAction = false
        runPendingFailedTranscriptionRetryIfNeeded()
    }

    private func runPendingFailedTranscriptionRetryIfNeeded() {
        guard !isPerformingAction,
              let retry = pendingFailedTranscriptionRetry else {
            return
        }

        pendingFailedTranscriptionRetry = nil
        guard status.voiceWorkPhase != .listening else {
            outputStatusText = Self.savedRecordingActionsUnavailableMessage
            return
        }

        Task { @MainActor in
            await retryFailedTranscription(
                id: retry.id,
                credential: retry.credential,
                outputMode: retry.outputMode
            )
        }
    }

    private func outputDeliveryPreferences(
        from settings: AppSettings,
        retryOutputMode: FailedTranscriptionRetryOutputMode
    ) -> OutputDeliveryPreferences {
        switch retryOutputMode {
        case .saveOnly:
            var preferences = settings.outputDeliveryPreferences
            preferences.automaticInsertionPreferenceEnabled = false
            return preferences
        case .followAutomaticInsertion:
            return settings.outputDeliveryPreferences
        }
    }

    private func beginSession(intent: DictationOutputIntent) -> Int {
        nextSessionID += 1
        activeSessionID = nextSessionID
        activeOutputIntent = intent
        return nextSessionID
    }

    private func currentOrNewSessionID(intent: DictationOutputIntent) -> Int {
        if let activeSessionID {
            return activeSessionID
        }

        return beginSession(intent: intent)
    }

    private func currentOutputIntent(fallback: DictationOutputIntent) -> DictationOutputIntent {
        let outputIntent = (activeOutputIntent ?? .standard).merged(with: fallback)
        activeOutputIntent = outputIntent
        return outputIntent
    }

    private func isCurrentSession(_ sessionID: Int) -> Bool {
        activeSessionID == sessionID
    }

    private func finishSession(_ sessionID: Int) {
        guard activeSessionID == sessionID else {
            return
        }

        activeSessionID = nil
        activeOutputIntent = nil
        activeCredential = nil
        pendingMaximumDurationCompletion = false
        activeRecordingDurationLimit = nil
    }

    private func cancelActiveSession() {
        activeSessionID = nil
        activeOutputIntent = nil
        activeCredential = nil
        pendingMaximumDurationCompletion = false
        activeRecordingDurationLimit = nil
    }

    private func startRecording(intent: DictationOutputIntent, credential: OpenAICredential?) async {
        outputStatusText = nil
        failurePresentation = nil
        let settings = settingsProvider()
        if intent == .translate,
           let translationIssue = settings.translationConfigurationIssue {
            let message = Self.userFacingMessage(for: translationIssue)
            failurePresentation = failurePresentation(
                message: message,
                error: translationIssue,
                failedAttempt: nil
            )
            status = .failure(message: message)
            return
        }

        do {
            activeCredential = try resolvedCredential(providedCredential: credential)
        } catch {
            let message = Self.userFacingMessage(for: error)
            failurePresentation = failurePresentation(message: message, error: error, failedAttempt: nil)
            status = .failure(message: message)
            return
        }

        let sessionID = beginSession(intent: intent)
        let recordingDurationLimit = settings.recordingDurationLimit
        activeRecordingDurationLimit = recordingDurationLimit
        pendingMaximumDurationCompletion = false
        eventLogger.record(.recordingStartRequested)

        do {
            historyAudioPlaybackStopper.stopPlayback()
            try await recorder.startRecording(
                maximumDuration: recordingDurationLimit.duration
            )
            guard isCurrentSession(sessionID) else {
                return
            }

            status = .recording
            eventLogger.record(.recordingStarted)
            playCue(.startRecording, settings: settings)
            startRecordingDurationMonitoring(sessionID: sessionID, settings: settings)
        } catch {
            stopRecordingDurationMonitoring()
            finishSession(sessionID)
            eventLogger.record(.recordingStartFailed(category: Self.operatorLogCategory(for: error)))
            status = .failure(message: Self.userFacingMessage(for: error))
        }
    }

    private func stopRecordingAndTranscribe(
        intent: DictationOutputIntent,
        credential: OpenAICredential?,
        automaticCompletion: AudioRecorderAutomaticCompletion? = nil,
        automaticReasonAwaitingArtifact: AudioRecorderAutomaticCompletionReason? = nil
    ) async {
        outputStatusText = nil
        failurePresentation = nil
        let sessionID = currentOrNewSessionID(intent: intent)
        let outputIntent = currentOutputIntent(fallback: intent)
        var stage: VoiceAttemptStage = .recordingFinalization
        var completedArtifact: AudioRecordingArtifact?
        var completedRecordingSettings: AppSettings?
        var recoveryCheckpoint: FailedTranscriptionAttempt?
        var checkpointAttempted = false
        var allowsRecordingCacheHandling = true
        var resolvedAutomaticCompletion = automaticCompletion
        defer {
            if allowsRecordingCacheHandling {
                updateCompletedRecordingCacheIfNeeded(
                    artifact: completedArtifact,
                    settings: completedRecordingSettings
                )
            }
        }

        do {
            let settings = settingsProvider()
            let recordingDurationLimit = activeRecordingDurationLimit
                ?? settings.recordingDurationLimit
            let artifact: AudioRecordingArtifact
            if let automaticCompletion = resolvedAutomaticCompletion {
                artifact = automaticCompletion.artifact
                switch automaticCompletion.reason {
                case .maximumDuration:
                    outputStatusText = Self.recordingLimitSavingStatusText
                case .unexpected:
                    outputStatusText = "Recording ended unexpectedly. Saving recording..."
                }
            } else if let automaticReasonAwaitingArtifact {
                switch automaticReasonAwaitingArtifact {
                case .maximumDuration:
                    outputStatusText = Self.recordingLimitSavingStatusText
                case .unexpected:
                    outputStatusText = "Recording ended unexpectedly. Saving recording..."
                }
                artifact = try await recorder.stopRecording()
                resolvedAutomaticCompletion = AudioRecorderAutomaticCompletion(
                    artifact: artifact,
                    reason: automaticReasonAwaitingArtifact
                )
            } else {
                eventLogger.record(.recordingStopRequested)
                try await waitForRecordingStopTail(settings: settings)
                artifact = try await recorder.stopRecording()
            }
            if let automaticCompletion = resolvedAutomaticCompletion,
               automaticCompletion.reason != .maximumDuration,
               recorder.lastFinalizationReachedMaximumDuration
                || Self.finalizedArtifactReachedMaximumDuration(
                    artifact,
                    limit: recordingDurationLimit
                ) {
                let recorderReportedSuccess: Bool?
                switch automaticCompletion.reason {
                case .maximumDuration:
                    recorderReportedSuccess = automaticCompletion.recorderReportedSuccess
                case .unexpected(let reportedSuccess):
                    recorderReportedSuccess = reportedSuccess
                }
                resolvedAutomaticCompletion = AudioRecorderAutomaticCompletion(
                    artifact: artifact,
                    reason: .maximumDuration,
                    recorderReportedSuccess: recorderReportedSuccess
                )
                pendingMaximumDurationCompletion = false
                outputStatusText = Self.recordingLimitSavingStatusText
                eventLogger.record(.recordingLimitReached)
            }
            if resolvedAutomaticCompletion == nil,
               recorder.lastFinalizationReachedMaximumDuration {
                resolvedAutomaticCompletion = AudioRecorderAutomaticCompletion(
                    artifact: artifact,
                    reason: .maximumDuration
                )
                pendingMaximumDurationCompletion = false
                outputStatusText = Self.recordingLimitSavingStatusText
                eventLogger.record(.recordingLimitReached)
            }
            if resolvedAutomaticCompletion == nil,
               pendingMaximumDurationCompletion {
                resolvedAutomaticCompletion = AudioRecorderAutomaticCompletion(
                    artifact: artifact,
                    reason: .maximumDuration
                )
                pendingMaximumDurationCompletion = false
                outputStatusText = Self.recordingLimitSavingStatusText
                eventLogger.record(.recordingLimitReached)
            }
            if resolvedAutomaticCompletion == nil,
               automaticReasonAwaitingArtifact == nil,
               Self.finalizedArtifactReachedMaximumDuration(
                   artifact,
                   limit: recordingDurationLimit
               ) {
                // Key-up may win the exact-once boundary just before the
                // recorder delegate or controller watchdog. Preserve the
                // product-level maximum reason from the finalized artifact so
                // that scheduling order cannot change retention semantics.
                resolvedAutomaticCompletion = AudioRecorderAutomaticCompletion(
                    artifact: artifact,
                    reason: .maximumDuration
                )
                outputStatusText = Self.recordingLimitSavingStatusText
                eventLogger.record(.recordingLimitReached)
            }
            completedArtifact = artifact
            stopRecordingDurationMonitoring()
            eventLogger.record(
                .recordingStopped(duration: artifact.duration, byteCount: artifact.byteCount)
            )

            completedRecordingSettings = settings

            guard isCurrentSession(sessionID) else {
                return
            }

            // An automatic recorder boundary owns its feedback immediately,
            // before persistence, configuration, credentials, or provider
            // work can fail.
            if resolvedAutomaticCompletion?.reason == .maximumDuration {
                playCue(.recordingLimitReached, settings: settings)
            } else if resolvedAutomaticCompletion != nil {
                playCue(.stopRecording, settings: settings)
            }

            let transcriptionSettings = transcriptionSettings(
                for: outputIntent,
                settings: settings
            )
            completedRecordingSettings = transcriptionSettings
            // From this boundary onward a finalized, non-empty artifact owns
            // a recoverable transcription attempt, even if the durable copy
            // itself fails and we must expose the emergency original.
            stage = .transcription
            allowsRecordingCacheHandling = false
            checkpointAttempted = true
            recoveryCheckpoint = try transcriptionFailureRecovery.recordProcessingCheckpoint(
                audioFileURL: artifact.fileURL,
                settings: transcriptionSettings,
                audioDuration: artifact.duration,
                completionKind: resolvedAutomaticCompletion?.reason == .maximumDuration
                    ? .maximumDuration
                    : .standard
            )
            activeRecoveryCheckpointID = recoveryCheckpoint?.id
            allowsRecordingCacheHandling = true
            if resolvedAutomaticCompletion?.reason == .maximumDuration {
                outputStatusText = Self.recordingLimitTranscribingStatusText
            } else if let reason = resolvedAutomaticCompletion?.reason,
                      case .unexpected = reason {
                outputStatusText = "Recording ended unexpectedly. Recording saved to History; transcribing..."
            }

            if outputIntent == .translate,
               let translationIssue = settings.translationConfigurationIssue {
                stage = .postProcessing
                throw translationIssue
            }

            if resolvedAutomaticCompletion == nil {
                playCue(.stopRecording, settings: settings)
            }
            status = .transcribing

            let credential = try resolvedCredential(providedCredential: credential)
            activeCredential = credential
            let context = activeTextContextReader.currentContext(settings: transcriptionSettings)
            let transcriptionID = transcriptionIDGenerator()
            let transcriptionRequest = try makeAudioTranscriptionRequest(
                audioFileURL: recoveryCheckpoint?.audioFileURL ?? artifact.fileURL,
                settings: transcriptionSettings,
                context: context
            )
            if let recoveryCheckpoint {
                try transcriptionFailureRecovery.sealProviderDispatch(
                    id: recoveryCheckpoint.id
                )
            }
            eventLogger.record(.transcriptionStarted)
            let rawTranscript = try await transcriptionService.transcribe(
                transcriptionRequest,
                credential: credential
            )
            eventLogger.record(.transcriptionSucceeded)
            guard isCurrentSession(sessionID) else {
                return
            }

            let transcribedTranscript = try Self.acceptedTranscript(from: rawTranscript)
            if let recoveryCheckpoint {
                transcriptionFailureRecovery.recordProviderAccepted(
                    id: recoveryCheckpoint.id,
                    acceptedTranscriptText: transcribedTranscript.text
                )
            }
            recordSuccessfulTranscriptionUsage(
                transcriptionID: transcriptionID,
                model: transcriptionRequest.model,
                audioDuration: artifact.duration
            )
            stage = .postProcessing
            let correctedTranscriptText = await correctedTranscriptText(
                from: transcribedTranscript,
                settings: settings,
                credential: credential
            )
            guard isCurrentSession(sessionID) else {
                return
            }

            let outputText = try await postActionTranscriptText(
                from: correctedTranscriptText,
                intent: outputIntent,
                settings: settings,
                credential: credential
            )
            guard isCurrentSession(sessionID) else {
                return
            }

            let acceptedTranscript = try Self.acceptedTranscript(from: outputText)
            let retainsMaximumDurationRecording =
                resolvedAutomaticCompletion?.reason == .maximumDuration
            var savedRecordingUpdateFailed = false
            if retainsMaximumDurationRecording, let recoveryCheckpoint {
                do {
                    try transcriptionFailureRecovery.markSaved(
                        id: recoveryCheckpoint.id,
                        acceptedTranscriptText: acceptedTranscript.text
                    )
                } catch {
                    savedRecordingUpdateFailed = true
                }
            }

            lastTranscriptText = acceptedTranscript.text
            status = .success(transcript: acceptedTranscript.text)
            failurePresentation = nil
            if !retainsMaximumDurationRecording {
                recordRecoveryHistory(
                    acceptedTranscript,
                    settings: settings,
                    audioDuration: artifact.duration,
                    cachedAudioFileURL: artifact.fileURL
                )
            }
            if let recoveryCheckpoint {
                if !retainsMaximumDurationRecording {
                    do {
                        _ = try transcriptionFailureRecovery.removeFailedAttempt(id: recoveryCheckpoint.id)
                    } catch {
                        outputStatusText = TranscriptionFailureRecoveryError.deleteFailed.localizedDescription
                    }
                }
                if activeRecoveryCheckpointID == recoveryCheckpoint.id {
                    activeRecoveryCheckpointID = nil
                }
            }

            stage = .outputDelivery
            let deliveryRequest = OutputDeliveryRequest(
                acceptedTranscript: acceptedTranscript,
                preferences: settings.outputDeliveryPreferences
            )
            do {
                let deliveryStatusText = try await transcriptOutput.deliver(deliveryRequest).statusText
                outputStatusText = savedRecordingUpdateFailed
                    ? Self.recordingLimitSaveFailedStatusText
                    : deliveryStatusText
            } catch {
                guard isCurrentSession(sessionID) else {
                    return
                }

                recordFailure(error, at: stage)
                outputStatusText = Self.userFacingMessage(for: error)
            }

            finishSession(sessionID)
        } catch is CancellationError {
            if let recoveryCheckpoint {
                try? transcriptionFailureRecovery.updateFailedAttempt(
                    id: recoveryCheckpoint.id,
                    reason: .processingInterrupted
                )
                if activeRecoveryCheckpointID == recoveryCheckpoint.id {
                    activeRecoveryCheckpointID = nil
                }
            }
            guard isCurrentSession(sessionID) else {
                return
            }

            recorder.cancelRecording()
            stopRecordingDurationMonitoring()
            finishSession(sessionID)
            activeCredential = nil
            outputStatusText = nil
            failurePresentation = nil
            status = .idle
        } catch {
            guard isCurrentSession(sessionID) else {
                return
            }

            let recoveryResult: (
                attempt: FailedTranscriptionAttempt?,
                allowsRecordingCacheHandling: Bool
            )
            if let recoveryCheckpoint {
                let reason = FailedTranscriptionReason(error: error)
                try? transcriptionFailureRecovery.updateFailedAttempt(
                    id: recoveryCheckpoint.id,
                    reason: reason
                )
                if activeRecoveryCheckpointID == recoveryCheckpoint.id {
                    activeRecoveryCheckpointID = nil
                }
                recoveryResult = (
                    transcriptionFailureRecovery.failedAttempts.first {
                        $0.id == recoveryCheckpoint.id
                    },
                    true
                )
            } else if checkpointAttempted,
                      let completedArtifact,
                      let completedRecordingSettings {
                recoveryResult = (
                    transcriptionFailureRecovery.retainEmergencyFallback(
                        audioFileURL: completedArtifact.fileURL,
                        settings: completedRecordingSettings,
                        audioDuration: completedArtifact.duration,
                        reason: .other,
                        completionKind: resolvedAutomaticCompletion?.reason == .maximumDuration
                            ? .maximumDuration
                            : .standard
                    ),
                    false
                )
            } else {
                recoveryResult = recordFailedTranscriptionAttempt(
                    error,
                    at: stage,
                    artifact: completedArtifact,
                    settings: completedRecordingSettings
                )
            }
            allowsRecordingCacheHandling = recoveryResult.allowsRecordingCacheHandling
            stopRecordingDurationMonitoring()
            finishSession(sessionID)
            recordFailure(error, at: stage)
            let message = Self.userFacingMessage(for: error)
            if checkpointAttempted, recoveryCheckpoint == nil {
                outputStatusText = message
            }
            status = .failure(message: message)
            failurePresentation = failurePresentation(
                message: message,
                error: error,
                failedAttempt: recoveryResult.attempt,
                showsRecoveryPrompt: stage == .transcription
            )
        }
    }

    private func markActiveRecoveryCheckpointInterrupted() {
        guard let activeRecoveryCheckpointID else {
            return
        }

        try? transcriptionFailureRecovery.updateFailedAttempt(
            id: activeRecoveryCheckpointID,
            reason: .processingInterrupted
        )
        self.activeRecoveryCheckpointID = nil
    }

    private func handleAutomaticRecorderStop(
        _ result: Result<AudioRecorderAutomaticCompletion, AudioRecorderServiceError>
    ) {
        guard status.voiceWorkPhase == .listening else {
            return
        }
        if case .success(let completion) = result {
            let recorderReportedSuccess: Bool?
            switch completion.reason {
            case .maximumDuration:
                recorderReportedSuccess = completion.recorderReportedSuccess
            case .unexpected(let reportedSuccess):
                recorderReportedSuccess = reportedSuccess
            }
            if recorderReportedSuccess == false {
                eventLogger.record(
                    .recordingEndedUnexpectedly(
                        recorderReportedSuccess: false
                    )
                )
            }
        }
        guard beginExclusiveAction() else {
            if case .success(let completion) = result,
               completion.reason == .maximumDuration {
                pendingMaximumDurationCompletion = true
            }
            return
        }

        pendingMaximumDurationCompletion = false
        stopRecordingDurationMonitoring()
        let intent = activeOutputIntent ?? .standard
        let credential = activeCredential

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            defer { self.completeExclusiveAction() }

            switch result {
            case .success(let completion):
                switch completion.reason {
                case .maximumDuration:
                    self.eventLogger.record(.recordingLimitReached)
                case .unexpected(let recorderReportedSuccess):
                    if recorderReportedSuccess {
                        self.eventLogger.record(
                            .recordingEndedUnexpectedly(
                                recorderReportedSuccess: true
                            )
                        )
                    }
                }
                await self.stopRecordingAndTranscribe(
                    intent: intent,
                    credential: credential,
                    automaticCompletion: completion
                )
            case .failure(let error):
                guard let sessionID = self.activeSessionID else {
                    return
                }

                self.finishSession(sessionID)
                self.recordFailure(error, at: .recordingFinalization)
                let message = Self.userFacingMessage(for: error)
                self.status = .failure(message: message)
                self.failurePresentation = self.failurePresentation(
                    message: message,
                    error: error,
                    failedAttempt: nil
                )
            }
        }
    }

    private func handleRecordingMaximumDurationWatchdog() {
        guard status.voiceWorkPhase == .listening else {
            return
        }
        guard beginExclusiveAction() else {
            pendingMaximumDurationCompletion = true
            return
        }

        pendingMaximumDurationCompletion = false
        recordingCountdown = nil
        let intent = activeOutputIntent ?? .standard
        let credential = activeCredential
        eventLogger.record(.recordingLimitReached)

        Task { @MainActor [weak self] in
            guard let self else {
                return
            }

            defer { self.completeExclusiveAction() }
            await self.stopRecordingAndTranscribe(
                intent: intent,
                credential: credential,
                automaticReasonAwaitingArtifact: .maximumDuration
            )
        }
    }

    private func waitForRecordingStopTail(settings: AppSettings) async throws {
        let duration = settings.recordingStopTailDuration.duration
        guard duration > 0 else {
            return
        }

        eventLogger.record(.recordingStopTailStarted(duration: duration))
        let tailTask = Task { @MainActor in
            try await recordingStopTailSleeper.sleep(seconds: duration)
        }
        activeRecordingStopTailTask = tailTask
        defer {
            activeRecordingStopTailTask = nil
        }

        try await tailTask.value
        eventLogger.record(.recordingStopTailFinished(duration: duration))
    }

    private func playCue(_ cue: DictationCue, settings: AppSettings) {
        guard settings.soundEnabled else {
            return
        }

        cuePlayer.play(cue)
    }

    private func startRecordingDurationMonitoring(
        sessionID: Int,
        settings: AppSettings
    ) {
        recordingCountdown = nil
        let schedule = VoiceSessionWarningSchedule(
            limit: settings.recordingDurationLimit
        )
        recordingDurationMonitor.start(
            maximumDurationWholeSeconds: schedule.maximumDurationWholeSeconds
        ) { [weak self] elapsedWholeSecond in
            guard let self,
                  self.isCurrentSession(sessionID),
                  self.status.voiceWorkPhase == .listening else {
                return
            }

            if elapsedWholeSecond >= schedule.maximumDurationWholeSeconds {
                self.handleRecordingMaximumDurationWatchdog()
                return
            }

            self.recordingCountdown = schedule.countdown(
                atElapsedWholeSecond: elapsedWholeSecond
            )
            guard let warning = schedule.warning(
                atElapsedWholeSecond: elapsedWholeSecond
            ),
                settings.soundEnabled,
                self.privateAudioOutputRouteProvider.isPrivateAudioOutputRoute()
            else {
                return
            }

            self.cuePlayer.play(.recordingLimitWarning(warning.urgency))
        }
    }

    private func stopRecordingDurationMonitoring() {
        recordingDurationMonitor.stop()
        recordingCountdown = nil
    }

    private static func finalizedArtifactReachedMaximumDuration(
        _ artifact: AudioRecordingArtifact,
        limit: RecordingDurationLimit
    ) -> Bool {
        let threshold = limit.duration
            - maximumDurationClassificationTolerance
        return artifact.duration.isFinite && artifact.duration >= threshold
    }

    private func recordRecoveryHistory(
        _ acceptedTranscript: AcceptedTranscript,
        settings: AppSettings,
        audioDuration: TimeInterval?,
        cachedAudioFileURL: URL?
    ) {
        let request = settings.acceptedTranscriptHistoryRequest(
            acceptedTranscript: acceptedTranscript,
            audioDuration: audioDuration,
            cachedAudioFileURL: cachedAudioFileURL
        )

        do {
            try transcriptHistory.recordAcceptedTranscript(request)
        } catch {
            outputStatusText = Self.userFacingMessage(for: error)
        }
    }

    private func recordFailedTranscriptionAttempt(
        _ error: Error,
        at stage: VoiceAttemptStage,
        artifact: AudioRecordingArtifact?,
        settings: AppSettings?
    ) -> (attempt: FailedTranscriptionAttempt?, allowsRecordingCacheHandling: Bool) {
        guard stage == .transcription,
              let artifact,
              let settings else {
            return (nil, true)
        }

        let reason = FailedTranscriptionReason(error: error)
        guard reason.shouldRecordFailedAttempt else {
            return (nil, true)
        }

        do {
            return (
                try transcriptionFailureRecovery.recordFailedAttempt(
                    audioFileURL: artifact.fileURL,
                    settings: settings,
                    audioDuration: artifact.duration,
                    reason: reason
                ),
                true
            )
        } catch {
            outputStatusText = Self.userFacingMessage(for: error)
            return (nil, false)
        }
    }

    private func recordSuccessfulTranscriptionUsage(
        transcriptionID: UUID,
        model: String,
        audioDuration: TimeInterval?
    ) {
        guard let audioDuration,
              let usage = try? SuccessfulTranscriptionUsage(
                  transcriptionID: transcriptionID,
                  model: model,
                  audioDuration: audioDuration
              ) else {
            return
        }

        transcriptionUsageRecorder.recordSuccessfulTranscriptionUsage(usage)
    }

    private func updateCompletedRecordingCacheIfNeeded(
        artifact: AudioRecordingArtifact?,
        settings: AppSettings?
    ) {
        guard let artifact, let settings else {
            return
        }

        updateRecordingCache(for: artifact, settings: settings)
    }

    private func updateRecordingCache(for artifact: AudioRecordingArtifact, settings: AppSettings) {
        do {
            try recordingCache.handleCompletedRecording(
                artifact,
                policy: settings.recordingCachePolicy
            )
            eventLogger.record(.recordingCacheHandled(policy: settings.recordingCachePolicy))
        } catch {
            eventLogger.record(.recordingCacheFailed(category: Self.operatorLogCategory(for: error)))
            guard outputStatusText == nil else {
                return
            }

            outputStatusText = Self.userFacingMessage(for: error)
        }
    }

    private func correctedTranscriptText(
        from transcript: AcceptedTranscript,
        settings: AppSettings,
        credential: OpenAICredential
    ) async -> String {
        let request = TextCorrectionRequest(
            acceptedTranscript: transcript,
            correctionConfiguration: settings.textCorrectionConfiguration,
            postProcessingConfiguration: settings.transcriptPostProcessingConfiguration
        )
        do {
            return try await textCorrectionService.correct(
                request,
                credential: credential
            )
        } catch {
            return transcript.text
        }
    }

    private func transcriptionSettings(for intent: DictationOutputIntent, settings: AppSettings) -> AppSettings {
        guard intent == .translate,
              settings.translationShortcutEnabled,
              settings.translationSourceMode == .override,
              settings.isTranslationSourceConfigurationValid else {
            return settings
        }

        var transcriptionSettings = settings
        transcriptionSettings.language = settings.translationSourceLanguage
        transcriptionSettings.customLanguageCode = settings.customTranslationSourceLanguageCode
        return transcriptionSettings
    }

    private func makeAudioTranscriptionRequest(
        audioFileURL: URL,
        settings: AppSettings,
        context: TranscriptionPromptContext?
    ) throws -> AudioTranscriptionRequest {
        do {
            return try settings.audioTranscriptionRequest(
                audioFileURL: audioFileURL,
                context: context
            )
        } catch AudioTranscriptionRequest.ValidationError.invalidCustomLanguageCode(let code) {
            throw OpenAITranscriptionServiceError.invalidRecording(
                .invalidCustomLanguageCode(code)
            )
        }
    }

    private func postActionTranscriptText(
        from transcript: String,
        intent: DictationOutputIntent,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        guard intent == .translate else {
            return transcript
        }

        guard settings.translationShortcutEnabled else {
            return transcript
        }

        guard settings.canRunTranslation else {
            throw OpenAITextTranslationServiceError.invalidLanguageConfiguration
        }

        let acceptedTranscript: AcceptedTranscript
        do {
            acceptedTranscript = try AcceptedTranscript(rawText: transcript)
        } catch {
            throw OpenAITextTranslationServiceError.emptyTranslation
        }
        let request = TextTranslationRequest(
            acceptedTranscript: acceptedTranscript,
            translationConfiguration: settings.translationConfiguration,
            transcriptionConfiguration: settings.transcriptionConfiguration
        )
        let translatedTranscript = try await translationService.translate(
            request,
            credential: credential
        )
        guard let acceptedTranslation = AcceptedTranscript.nonEmptyNormalizedText(
            from: translatedTranscript
        ) else {
            throw OpenAITextTranslationServiceError.emptyTranslation
        }

        return finalTranslatedTranscriptText(acceptedTranslation, settings: settings)
    }

    private func finalTranslatedTranscriptText(_ transcript: String, settings: AppSettings) -> String {
        guard settings.localTextCleanupEnabled else {
            return transcript
        }

        return TranscriptTextPostProcessor.normalizedInformalTypography(from: transcript)
    }

    private func resolvedCredential(providedCredential: OpenAICredential?) throws -> OpenAICredential {
        if let providedCredential {
            return providedCredential
        }

        if let activeCredential {
            return activeCredential
        }

        guard let credentialResolverForUngatedActions else {
            throw OpenAITranscriptionServiceError.missingAPIKey
        }

        do {
            return try credentialResolverForUngatedActions.resolveOpenAICredential()
        } catch let error as OpenAICredentialResolutionError {
            throw error.transcriptionServiceError
        } catch {
            throw OpenAITranscriptionServiceError.apiKeyUnavailable
        }
    }

    private static func acceptedTranscript(from rawText: String) throws -> AcceptedTranscript {
        do {
            return try AcceptedTranscript(rawText: rawText)
        } catch AcceptedTranscript.ValidationError.emptyText {
            throw OpenAITranscriptionServiceError.emptyTranscript
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }

        return error.localizedDescription
    }

    private func failurePresentation(
        message: String,
        error: Error,
        failedAttempt: FailedTranscriptionAttempt?,
        showsRecoveryPrompt: Bool = false
    ) -> DictationFailurePresentation {
        if let translationIssue = error as? TranslationConfigurationIssue {
            return DictationFailurePresentation(
                title: translationIssue.title,
                message: message,
                settingsTarget: .translation
            )
        }

        let reason = failedAttempt?.reason ?? FailedTranscriptionReason(error: error)
        return DictationFailurePresentation(
            title: reason.title,
            message: failedAttempt == nil ? message : reason.message,
            failedAttemptID: failedAttempt?.id,
            settingsTarget: reason.settingsTarget,
            canRetry: reason.canRetry,
            showsRecoveryPrompt: showsRecoveryPrompt
        )
    }

    private func recordFailure(_ error: Error, at stage: VoiceAttemptStage) {
        let category = Self.operatorLogCategory(for: error)

        switch stage {
        case .recordingFinalization:
            eventLogger.record(.recordingStopFailed(category: category))
        case .transcription:
            eventLogger.record(.transcriptionFailed(category: category))
        case .postProcessing:
            eventLogger.record(.postProcessingFailed(category: category))
        case .outputDelivery:
            eventLogger.record(.outputDeliveryFailed(category: category))
        }
    }

    private static func operatorLogCategory(for error: Error) -> String {
        if let error = error as? AudioRecorderServiceError {
            return error.operatorLogCategory
        }

        if let error = error as? OpenAITranscriptionServiceError {
            return error.operatorLogCategory
        }

        if let error = error as? OpenAITextCorrectionServiceError {
            return error.operatorLogCategory
        }

        if let error = error as? OpenAITextTranslationServiceError {
            return error.operatorLogCategory
        }

        if let error = error as? TextInsertionServiceError {
            return error.operatorLogCategory
        }

        if let error = error as? RecordingCacheServiceError {
            return error.operatorLogCategory
        }

        if let error = error as? TranslationConfigurationIssue {
            return error.operatorLogCategory
        }

        return "unknown"
    }
}

private extension AudioRecorderServiceError {
    var operatorLogCategory: String {
        switch self {
        case .alreadyRecording:
            return "already_recording"
        case .notRecording:
            return "not_recording"
        case .microphonePermissionDenied:
            return "microphone_permission_denied"
        case .recordingUnavailable:
            return "recording_unavailable"
        case .temporaryFileUnavailable:
            return "temporary_file_unavailable"
        case .startFailed:
            return "start_failed"
        case .stopFailed:
            return "stop_failed"
        case .cancelCleanupFailed:
            return "cancel_cleanup_failed"
        case .missingRecordingFile:
            return "missing_recording_file"
        case .emptyRecording:
            return "empty_recording"
        case .recordingTooShort:
            return "recording_too_short"
        case .recordingTimedOut:
            return "recording_timed_out"
        }
    }
}

private extension OpenAITextCorrectionServiceError {
    var operatorLogCategory: String {
        switch self {
        case .missingAPIKey:
            return "missing_api_key"
        case .apiKeyUnavailable:
            return "api_key_unavailable"
        case .invalidRequest:
            return "invalid_request"
        case .timedOut:
            return "timeout"
        case .networkUnavailable:
            return "network_unavailable"
        case .networkFailure:
            return "network_failure"
        case .cancelled:
            return "cancelled"
        case .invalidAPIKey:
            return "invalid_api_key"
        case .rateLimited:
            return "rate_limited"
        case .providerUnavailable:
            return "provider_unavailable"
        case .badRequest:
            return "bad_request"
        case .providerRejected(let statusCode):
            return "provider_rejected_\(statusCode)"
        case .invalidResponse:
            return "invalid_response"
        case .emptyCorrection:
            return "empty_correction"
        }
    }
}

private extension OpenAITextTranslationServiceError {
    var operatorLogCategory: String {
        switch self {
        case .missingAPIKey:
            return "missing_api_key"
        case .apiKeyUnavailable:
            return "api_key_unavailable"
        case .invalidRequest:
            return "invalid_request"
        case .timedOut:
            return "timeout"
        case .networkUnavailable:
            return "network_unavailable"
        case .networkFailure:
            return "network_failure"
        case .cancelled:
            return "cancelled"
        case .invalidAPIKey:
            return "invalid_api_key"
        case .rateLimited:
            return "rate_limited"
        case .providerUnavailable:
            return "provider_unavailable"
        case .badRequest:
            return "bad_request"
        case .invalidLanguageConfiguration:
            return "invalid_language_configuration"
        case .providerRejected(let statusCode):
            return "provider_rejected_\(statusCode)"
        case .invalidResponse:
            return "invalid_response"
        case .emptyTranslation:
            return "empty_translation"
        }
    }
}

private extension TranslationConfigurationIssue {
    var operatorLogCategory: String {
        switch self {
        case .invalidSourceLanguage:
            return "invalid_translation_source_language"
        case .missingTargetLanguage:
            return "missing_translation_target_language"
        }
    }
}

private extension TextInsertionServiceError {
    var operatorLogCategory: String {
        switch self {
        case .emptyAppClipboardText:
            return "empty_app_clipboard_text"
        case .textEventUnavailable:
            return "text_event_unavailable"
        case .textInsertionFailed:
            return "text_insertion_failed"
        case .textInsertionTimedOut:
            return "text_insertion_timed_out"
        }
    }
}

private extension RecordingCacheServiceError {
    var operatorLogCategory: String {
        switch self {
        case .directoryUnavailable:
            return "directory_unavailable"
        case .listingFailed:
            return "listing_failed"
        case .unsupportedRecordingURL:
            return "unsupported_recording_url"
        case .deleteFailed:
            return "delete_failed"
        case .clearFailed:
            return "clear_failed"
        }
    }
}
