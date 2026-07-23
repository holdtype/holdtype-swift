import AppKit
import Testing
@testable import HoldType

@MainActor
struct HoldTypeApplicationMenuTests {
    @Test func applicationMenuRoutesCommandQThroughNormalTermination() throws {
        let application = NSApplication.shared
        let menu = HoldTypeApplicationMenu.make(
            application: application
        )
        let applicationMenu = try #require(menu.items.first?.submenu)
        let quitItem = try #require(
            applicationMenu.item(
                withTitle: MenuBarPresentation.quitTitle
            )
        )

        #expect(
            applicationMenu.title == HoldTypeMenuBarIdentity.title
        )
        #expect(quitItem.action == #selector(NSApplication.terminate(_:)))
        #expect(quitItem.target === application)
        #expect(quitItem.keyEquivalent == "q")
        #expect(quitItem.keyEquivalentModifierMask == [.command])
    }
}
