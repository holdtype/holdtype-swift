import AppKit
import SwiftUI

@MainActor
protocol MenuBarPopoverPresenting: AnyObject {
    var isShown: Bool { get }
    var onClose: (@MainActor () -> Void)? { get set }

    func show(relativeTo button: NSStatusBarButton)
    func close()
}

@MainActor
final class NativeMenuBarPopoverPresenter:
    NSObject,
    MenuBarPopoverPresenting,
    NSPopoverDelegate
{
    private let popover: NSPopover
    var onClose: (@MainActor () -> Void)?

    var isShown: Bool {
        popover.isShown
    }

    override init() {
        popover = NSPopover()
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
    }

    func installContent(dismissMenu: @escaping @MainActor () -> Void) {
        let hostingController = NSHostingController(
            rootView: MenuBarView(dismissMenu: dismissMenu)
        )
        hostingController.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hostingController
    }

    func show(relativeTo button: NSStatusBarButton) {
        popover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
    }

    func close() {
        popover.performClose(nil)
    }

    func popoverDidClose(_ notification: Notification) {
        onClose?()
    }
}

@MainActor
final class MenuBarStatusItemController: NSObject {
    private let statusBar: NSStatusBar
    private let popoverPresenter: any MenuBarPopoverPresenting
    private let prepareFixesTarget: @MainActor () -> Void
    private let clearFixesTarget: @MainActor () -> Void
    private var statusItem: NSStatusItem?

    var statusButton: NSStatusBarButton? {
        statusItem?.button
    }

    static func live(
        fixesRuntime: FixesRuntime = .shared
    ) -> MenuBarStatusItemController {
        let popoverPresenter = NativeMenuBarPopoverPresenter()
        let controller = MenuBarStatusItemController(
            statusBar: .system,
            popoverPresenter: popoverPresenter,
            prepareFixesTarget: {
                fixesRuntime.prepareMenuTarget()
            },
            clearFixesTarget: {
                fixesRuntime.clearPreparedMenuTarget()
            }
        )
        popoverPresenter.installContent { [weak popoverPresenter] in
            popoverPresenter?.close()
        }
        return controller
    }

    init(
        statusBar: NSStatusBar,
        popoverPresenter: any MenuBarPopoverPresenting,
        prepareFixesTarget: @escaping @MainActor () -> Void,
        clearFixesTarget: @escaping @MainActor () -> Void
    ) {
        self.statusBar = statusBar
        self.popoverPresenter = popoverPresenter
        self.prepareFixesTarget = prepareFixesTarget
        self.clearFixesTarget = clearFixesTarget
        super.init()
        popoverPresenter.onClose = clearFixesTarget
    }

    func start() {
        guard statusItem == nil else {
            return
        }

        let statusItem = statusBar.statusItem(
            withLength: NSStatusItem.squareLength
        )
        guard let button = statusItem.button else {
            statusBar.removeStatusItem(statusItem)
            return
        }

        button.image = NSImage(
            systemSymbolName: HoldTypeMenuBarIdentity.systemImageName,
            accessibilityDescription: nil
        )
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.toolTip = HoldTypeMenuBarIdentity.helpText
        button.setAccessibilityLabel(HoldTypeMenuBarIdentity.title)
        button.setAccessibilityHelp(HoldTypeMenuBarIdentity.helpText)
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.sendAction(on: [.leftMouseDown])
        self.statusItem = statusItem
    }

    func stop() {
        if popoverPresenter.isShown {
            popoverPresenter.close()
        }
        clearFixesTarget()

        if let statusItem {
            statusItem.button?.target = nil
            statusItem.button?.action = nil
            statusBar.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popoverPresenter.isShown {
            popoverPresenter.close()
            return
        }

        prepareFixesTarget()
        popoverPresenter.show(relativeTo: sender)
        if !popoverPresenter.isShown {
            clearFixesTarget()
        }
    }
}
