/// Product-owned setup area where a recoverable issue can be resolved.
/// This value is not a UI route, system URL, action, or bridge message.
public enum RecoveryDestination: Equatable, Sendable {
    case openAI
    case transcription
    case translation
    case keyboard
    case fullAccess
    case microphoneAndPrivacy
}
