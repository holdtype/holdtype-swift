public enum VoiceAttemptStage: Equatable, Sendable {
    case recordingFinalization
    case transcription
    case postProcessing
    case outputDelivery
}
