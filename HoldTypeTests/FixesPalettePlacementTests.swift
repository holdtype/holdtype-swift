import CoreGraphics
import Testing
@testable import HoldType

@MainActor
struct FixesPalettePlacementTests {
    private let primary = FixesPaletteScreenGeometry(
        frame: CGRect(x: 0, y: 0, width: 1_000, height: 800),
        visibleFrame: CGRect(x: 0, y: 24, width: 1_000, height: 752),
        isPrimary: true
    )

    @Test func convertsAccessibilityTopLeftCoordinatesToAppKitCoordinates() {
        let rect = FixesPaletteCoordinateConverter.appKitRect(
            from: .accessibility(
                CGRect(x: 200, y: 100, width: 80, height: 20)
            ),
            primaryScreenFrame: primary.frame
        )

        #expect(rect == CGRect(x: 200, y: 680, width: 80, height: 20))
    }

    @Test func leavesAppKitCoordinatesUnchanged() {
        let input = CGRect(x: 200, y: 680, width: 80, height: 20)

        let rect = FixesPaletteCoordinateConverter.appKitRect(
            from: .appKit(input),
            primaryScreenFrame: primary.frame
        )

        #expect(rect == input)
    }

    @Test func centersPaletteInVisibleAreaContainingAnchor() {
        let frame = FixesPalettePlacement.panelFrame(
            panelSize: CGSize(width: 360, height: 300),
            anchor: .appKit(
                CGRect(x: 450, y: 500, width: 20, height: 20)
            ),
            screens: [primary]
        )

        #expect(frame == CGRect(x: 320, y: 250, width: 360, height: 300))
    }

    @Test func centersPaletteRegardlessOfAnchorVerticalPosition() {
        let frame = FixesPalettePlacement.panelFrame(
            panelSize: CGSize(width: 360, height: 300),
            anchor: .appKit(
                CGRect(x: 450, y: 100, width: 20, height: 20)
            ),
            screens: [primary]
        )

        #expect(frame == CGRect(x: 320, y: 250, width: 360, height: 300))
    }

    @Test func centersPaletteEvenWhenAnchorIsNearScreenEdges() {
        let leftFrame = FixesPalettePlacement.panelFrame(
            panelSize: CGSize(width: 360, height: 300),
            anchor: .appKit(
                CGRect(x: 2, y: 500, width: 1, height: 20)
            ),
            screens: [primary]
        )
        let rightFrame = FixesPalettePlacement.panelFrame(
            panelSize: CGSize(width: 360, height: 300),
            anchor: .appKit(
                CGRect(x: 998, y: 500, width: 1, height: 20)
            ),
            screens: [primary]
        )

        #expect(leftFrame.minX == 320)
        #expect(rightFrame.maxX == 680)
    }

    @Test func usesSecondaryVisibleFrameAfterGlobalCoordinateConversion() {
        let secondary = FixesPaletteScreenGeometry(
            frame: CGRect(x: 1_000, y: -200, width: 800, height: 1_000),
            visibleFrame: CGRect(x: 1_000, y: -176, width: 800, height: 952),
            isPrimary: false
        )

        let frame = FixesPalettePlacement.panelFrame(
            panelSize: CGSize(width: 360, height: 300),
            anchor: .accessibility(
                CGRect(x: 1_300, y: 50, width: 20, height: 20)
            ),
            screens: [primary, secondary]
        )

        #expect(frame.minX >= secondary.visibleFrame.minX + 8)
        #expect(frame.maxX <= secondary.visibleFrame.maxX - 8)
        #expect(frame.minY >= secondary.visibleFrame.minY + 8)
        #expect(frame.maxY <= secondary.visibleFrame.maxY - 8)
    }

    @Test func constrainsPaletteSizeOnUnusuallySmallVisibleFrame() {
        let smallScreen = FixesPaletteScreenGeometry(
            frame: CGRect(x: 0, y: 0, width: 280, height: 220),
            visibleFrame: CGRect(x: 0, y: 0, width: 280, height: 200),
            isPrimary: true
        )

        let frame = FixesPalettePlacement.panelFrame(
            panelSize: CGSize(width: 360, height: 392),
            anchor: .appKit(CGRect(x: 100, y: 100, width: 1, height: 1)),
            screens: [smallScreen]
        )

        #expect(frame == CGRect(x: 8, y: 8, width: 264, height: 184))
    }

    @Test func fallsBackToRequestedSizeWhenNoScreensAreAvailable() {
        let frame = FixesPalettePlacement.panelFrame(
            panelSize: CGSize(width: 360, height: 392),
            anchor: .appKit(.zero),
            screens: []
        )

        #expect(frame == CGRect(x: 0, y: 0, width: 360, height: 392))
    }
}
