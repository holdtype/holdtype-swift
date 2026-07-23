import AppKit

@MainActor
enum HoldTypeApplicationMenu {
    static func make(
        application: NSApplication = .shared
    ) -> NSMenu {
        let mainMenu = NSMenu()
        let applicationMenuItem = NSMenuItem()
        let applicationMenu = NSMenu(
            title: HoldTypeMenuBarIdentity.title
        )
        let quitItem = NSMenuItem(
            title: "Quit \(HoldTypeMenuBarIdentity.title)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = application
        applicationMenu.addItem(quitItem)
        applicationMenuItem.submenu = applicationMenu
        mainMenu.addItem(applicationMenuItem)
        return mainMenu
    }
}
