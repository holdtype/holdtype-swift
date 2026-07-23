import SwiftUI
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSVoiceDraftTextTargetTests {
    @Test func viewportCapturePreservesTheUITextViewUTF16Selection() throws {
        let text = "A 👩🏽‍💻 selection"
        let selectedRange = (text as NSString).range(of: "👩🏽‍💻")
        var captured: IOSVoiceDraftTextTargetSnapshot?
        let viewport = IOSVoiceDraftTextViewport(
            text: .constant(text),
            isFocused: .constant(true),
            showsJumpToLatest: .constant(false),
            isEditable: true,
            contentChange: .initial,
            scrollToLatestRequest: 0,
            usesAccessibilitySize: false,
            reduceMotion: false,
            onTargetSnapshotChange: { captured = $0 }
        )
        let textView = IOSVoiceDraftUITextView()
        textView.text = text
        textView.selectedRange = selectedRange

        viewport.makeCoordinator().captureTargetSnapshot(from: textView)

        let snapshot = try #require(captured)
        #expect(snapshot.text == text)
        #expect(snapshot.selectedUTF16Range == selectedRange)
    }

    @Test func captureRejectsOutOfBoundsAndSplitScalarRanges() {
        let text = "A😀B"

        #expect(
            IOSVoiceDraftTextTargetSnapshot(
                text: text,
                selectedRange: NSRange(location: 5, length: 1)
            ) == nil
        )
        #expect(
            IOSVoiceDraftTextTargetSnapshot(
                text: text,
                selectedRange: NSRange(location: 1, length: 1)
            ) == nil
        )
    }
}
