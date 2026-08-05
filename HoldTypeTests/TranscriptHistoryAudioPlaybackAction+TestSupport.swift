import Foundation
@testable import HoldType

extension TranscriptHistoryAudioPlaybackAction {
    static var bypassingDecoderValidation: Self {
        Self(
            audioReadiness: TranscriptHistoryAudioReadiness(
                isPlayableAudioFile: { _ in true }
            )
        )
    }
}
