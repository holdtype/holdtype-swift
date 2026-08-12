import Foundation

@MainActor
enum VoiceWorkOwner: Equatable {
    case dictation
    case voicePromptFix
}

@MainActor
final class VoiceWorkReservation {
    static let shared = VoiceWorkReservation()

    private(set) var owner: VoiceWorkOwner?

    func acquire(_ requestedOwner: VoiceWorkOwner) -> Bool {
        guard owner == nil else {
            return false
        }
        owner = requestedOwner
        return true
    }

    func release(_ releasingOwner: VoiceWorkOwner) {
        guard owner == releasingOwner else {
            return
        }
        owner = nil
    }
}
