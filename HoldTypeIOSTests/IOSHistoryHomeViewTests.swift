import Foundation
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSHistoryHomeViewTests {
    @Test func copyWritesTheExactSelectedTextOnce() {
        var copiedTexts: [String] = []
        let actions = IOSHistoryRowActions(
            copyText: { copiedTexts.append($0) }
        )
        let text = "  Exact text\nwith emoji 🫡 and punctuation!?  "

        actions.copy(text)

        #expect(copiedTexts == [text])
    }

    @Test func playbackAvailabilityAndActionUseTheSelectedResultID() {
        let playableID = UUID()
        let unavailableID = UUID()
        var playedIDs: [UUID] = []
        let actions = IOSHistoryRowActions(
            copyText: { _ in },
            isPlaybackAvailable: { $0 == playableID },
            playRecording: { playedIDs.append($0) }
        )

        #expect(actions.canPlay(resultID: playableID))
        #expect(!actions.canPlay(resultID: unavailableID))

        actions.play(resultID: playableID)

        #expect(playedIDs == [playableID])
    }
}
