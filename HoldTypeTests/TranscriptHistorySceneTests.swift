import Testing
@testable import HoldType

@MainActor
struct TranscriptHistorySceneTests {
    @Test func historySceneUsesStableWindowIdentifier() {
        #expect(TranscriptHistoryScene.identifier == "holdtype.transcript-history")
    }
}
