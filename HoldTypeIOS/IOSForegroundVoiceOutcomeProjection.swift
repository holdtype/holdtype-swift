import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence

@MainActor
enum IOSForegroundVoiceOutcomeProjection {
    static func warning(
        _ notice: IOSV1ForegroundVoiceAcceptanceNotice?
    ) -> IOSForegroundVoiceWarning? {
        switch notice {
        case nil:
            nil
        case .historyWriteFailed:
            .historySaveFailed
        case .localCleanupPending,
             .historyWriteFailedAndLocalCleanupPending:
            .localCleanupPending
        }
    }

    static func recovery(
        capture: IOSV1ForegroundVoiceCaptureRecoveryObservation,
        pending: IOSV1PendingRecordingObservation?
    ) -> IOSForegroundVoiceRecovery {
        switch capture {
        case .recoverable:
            return .captureRecoverOrDiscard
        case .discardOnly:
            return .captureDiscardOnly
        case .blocked:
            return .blocked
        case .empty:
            break
        }

        guard let pending else { return .none }
        guard pending.availability == .available else { return .blocked }
        switch pending.recording.phase {
        case .readyForTranscription, .failed:
            return .pendingRetryOrDiscard
        case .transcribing, .postProcessing, .outputDelivery,
             .acceptedCleanup:
            return .blocked
        }
    }

    static func stage(
        for pending: IOSV1PendingRecordingObservation?
    ) -> VoiceAttemptStage? {
        guard let pending else { return nil }
        switch pending.recording.phase {
        case .readyForTranscription, .failed:
            return .transcription
        case .transcribing:
            return .transcription
        case .postProcessing:
            return .postProcessing
        case .outputDelivery, .acceptedCleanup:
            return .outputDelivery
        }
    }

    static func failure(
        for reason: IOSV1ForegroundVoiceCaptureInvalidReason
    ) -> IOSForegroundVoiceFailure {
        switch reason {
        case .tooShort, .empty: .tooShort
        case .maximumDurationReached: .maximumDuration
        case .invalidMedia: .operationFailed
        }
    }

    static func failure(
        for failure: IOSForegroundVoiceProcessingFailure
    ) -> IOSForegroundVoiceFailure {
        switch failure {
        case .localPersistence: .localRecovery
        case .invalidConfiguration, .providerConsentUnavailable,
             .credentialRejected, .networkUnavailable, .networkFailure,
             .timedOut, .providerUnavailable, .invalidRecording,
             .invalidResponse, .cancelled:
            .operationFailed
        }
    }
}
