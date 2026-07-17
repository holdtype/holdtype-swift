import AVFoundation
import HoldTypeDomain
import UIKit

/// Capture-safe warning feedback for the final minute. Haptics are always
/// delivered; audible pips are restricted to routes that are normally worn by
/// one person so the microphone does not record the built-in speaker.
@MainActor
final class IOSRecordingLimitWarningFeedback {
    static let shared = IOSRecordingLimitWarningFeedback()

    private var player: AVAudioPlayer?

    func play(
        _ warning: VoiceSessionWarning,
        audioCuesEnabled: Bool
    ) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle =
            warning.urgency == .red ? .rigid : .light
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()

        guard audioCuesEnabled, Self.hasPrivateOutputRoute() else {
            return
        }

        let cue: IOSVoiceBoundaryCue =
            warning.urgency == .red ? .start : .successStop
        guard let nextPlayer = try? AVAudioPlayer(
            data: IOSVoiceBoundaryCueAudio.waveData(for: cue)
        ) else {
            return
        }
        player?.stop()
        player = nextPlayer
        nextPlayer.prepareToPlay()
        nextPlayer.play()
    }

    private static func hasPrivateOutputRoute() -> Bool {
        for output in AVAudioSession.sharedInstance().currentRoute.outputs {
            switch output.portType {
            case .headphones,
                 .bluetoothA2DP,
                 .bluetoothHFP,
                 .bluetoothLE,
                 .builtInReceiver:
                return true
            default:
                continue
            }
        }
        return false
    }
}
