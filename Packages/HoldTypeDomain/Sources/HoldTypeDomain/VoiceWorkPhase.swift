/// The current phase of active voice work.
///
/// Setup availability, attempt outcomes, delivery state, recovery data, and
/// platform presentation remain separate concerns.
public enum VoiceWorkPhase: Equatable, Sendable {
    case inactive
    case arming
    case ready
    case listening
    case finalizing
    case processing
}
