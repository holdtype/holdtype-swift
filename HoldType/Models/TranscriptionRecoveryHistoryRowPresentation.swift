struct TranscriptionRecoveryHistoryRowPresentation: Equatable {
    let title: String
    let message: String
    let systemImage: String
    let showsProgress: Bool
    let showsSettings: Bool
    let showsRetry: Bool
    let showsDuplicateRetry: Bool
    let showsSaveRetry: Bool
    let saveRetryTitle: String

    init(attempt: FailedTranscriptionAttempt) {
        switch attempt.state {
        case .processing:
            title = attempt.completionKind == .voicePrompt
                ? "Processing Voice Prompt…"
                : "Transcribing…"
            message = attempt.completionKind == .voicePrompt
                ? "HoldType is processing the saved Voice Prompt recording."
                : "HoldType is transcribing the saved recording."
            systemImage = "waveform"
            showsProgress = true
            showsSettings = false
            showsRetry = false
            showsDuplicateRetry = false
            showsSaveRetry = false
            saveRetryTitle = "Retry Save"
        case .failed:
            if attempt.completionKind == .voicePrompt {
                title = "Voice Prompt Saved Recording"
                message = attempt.reason.message
            } else if attempt.reason == .savedStatePersistenceFailed {
                title = "Transcribed — save incomplete"
                message = attempt.acceptedTranscriptText ?? attempt.reason.message
            } else if attempt.reason == .postProcessingFailedAfterProviderAcceptance {
                title = "Raw transcription recovered — post-processing failed"
                message = attempt.acceptedTranscriptText ?? attempt.reason.message
            } else if attempt.reason == .providerOutcomeUncertain {
                title = attempt.reason.title
                message = attempt.reason.message
            } else if attempt.reason == .recoveryOwnershipPersistenceFailed
                        || attempt.reason == .providerDispatchPersistenceFailed {
                title = "Recording — save incomplete"
                message = attempt.reason.message
            } else {
                title = "Not transcribed"
                message = attempt.reason.message
            }
            systemImage = "exclamationmark.triangle"
            showsProgress = false
            showsSettings = attempt.reason.settingsTarget != nil
            showsRetry = attempt.canRetry
            showsDuplicateRetry = attempt.requiresDuplicateRetryConfirmation
            showsSaveRetry = (
                attempt.reason == .savedStatePersistenceFailed
                    && attempt.acceptedTranscriptText != nil
            ) || attempt.reason == .recoveryOwnershipPersistenceFailed
                || attempt.reason == .providerDispatchPersistenceFailed
                || (
                    attempt.reason == .postProcessingFailedAfterProviderAcceptance
                        && attempt.acceptedTranscriptText != nil
                )
            saveRetryTitle = attempt.reason
                == .postProcessingFailedAfterProviderAcceptance
                ? "Save Raw Transcription"
                : "Retry Save"
        case .saved:
            title = attempt.reason == .postProcessingFailedAfterProviderAcceptance
                ? "Raw transcription saved — post-processing failed"
                : "Saved and transcribed"
            message = attempt.acceptedTranscriptText ?? "Transcription completed."
            systemImage = "checkmark.circle.fill"
            showsProgress = false
            showsSettings = false
            showsRetry = false
            showsDuplicateRetry = false
            showsSaveRetry = false
            saveRetryTitle = "Retry Save"
        }
    }
}
