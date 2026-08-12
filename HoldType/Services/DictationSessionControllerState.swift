import HoldTypeOpenAI

struct PendingFailedTranscriptionRetry {
    let id: FailedTranscriptionAttempt.ID
    let credential: OpenAICredential?
    let outputMode: FailedTranscriptionRetryOutputMode
    let authorization: FailedTranscriptionRetryAuthorization
}

enum DeferredRecordingTerminalOutcome {
    case automatic(
        Result<AudioRecorderAutomaticCompletion, AudioRecorderServiceError>
    )
    case maximumDurationAwaitingArtifact
}
