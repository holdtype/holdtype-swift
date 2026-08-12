import AppKit
import Combine
import SwiftUI

enum FixesPaletteKeyboardCommand: Equatable {
    case moveUp
    case moveDown
    case activate
    case dismiss

    init?(event: NSEvent) {
        guard event.type == .keyDown,
              event.modifierFlags.intersection([.command, .control, .option]).isEmpty
        else {
            return nil
        }

        switch event.keyCode {
        case 126:
            self = .moveUp
        case 125:
            self = .moveDown
        case 36, 76:
            self = .activate
        case 53:
            self = .dismiss
        default:
            return nil
        }
    }
}

@MainActor
protocol FixesPalettePanelPresenting: AnyObject {
    func show(
        model: FixesPaletteModel,
        accessibilityAnchorRect: CGRect?
    )
    func releaseKeyboardFocus()
    func hide()
}

@MainActor
final class FixesPalettePanelController: FixesPalettePanelPresenting {
    // User-approved AppKit boundary: this type provides only the nonactivating
    // presentation shell. FixesPaletteView owns all visible popup content in SwiftUI.
    nonisolated static let defaultPanelSize = CGSize(width: 360, height: 140)

    private let panelSize: CGSize
    private let outsideClickMonitor: any FixesPaletteOutsideClickMonitoring
    private let screenGeometryProvider: @MainActor () -> [FixesPaletteScreenGeometry]
    private let mouseLocationProvider: @MainActor () -> CGPoint

    private var panel: FixesPalettePanel?
    private var hostingView: NSHostingView<FixesPaletteView>?
    private var model: FixesPaletteModel?
    private var accessibilityAnchorRect: CGRect?
    private var modelObservation: AnyCancellable?
    private var resizeWorkItem: DispatchWorkItem?

    convenience init(panelSize: CGSize = defaultPanelSize) {
        self.init(
            panelSize: panelSize,
            outsideClickMonitor: FixesPaletteOutsideClickMonitor(),
            screenGeometryProvider: {
                NSScreen.screens.enumerated().map { index, screen in
                    FixesPaletteScreenGeometry(
                        frame: screen.frame,
                        visibleFrame: screen.visibleFrame,
                        isPrimary: index == 0
                    )
                }
            },
            mouseLocationProvider: {
                NSEvent.mouseLocation
            }
        )
    }

    init(
        panelSize: CGSize,
        outsideClickMonitor: any FixesPaletteOutsideClickMonitoring,
        screenGeometryProvider: @escaping @MainActor () -> [FixesPaletteScreenGeometry],
        mouseLocationProvider: @escaping @MainActor () -> CGPoint
    ) {
        self.panelSize = panelSize
        self.outsideClickMonitor = outsideClickMonitor
        self.screenGeometryProvider = screenGeometryProvider
        self.mouseLocationProvider = mouseLocationProvider
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    var presentedPanel: NSPanel? {
        panel
    }

    func show(
        model: FixesPaletteModel,
        accessibilityAnchorRect: CGRect?
    ) {
        hide()

        let panel = makePanel()
        let hostingView = NSHostingView(
            rootView: FixesPaletteView(model: model)
        )
        hostingView.frame = CGRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()
        let initialHeight = max(1, hostingView.fittingSize.height)
        let initialSize = CGSize(width: panelSize.width, height: initialHeight)
        hostingView.frame = CGRect(origin: .zero, size: initialSize)
        panel.setFrame(
            panelFrame(
                size: initialSize,
                accessibilityAnchorRect: accessibilityAnchorRect
            ),
            display: false
        )

        self.panel = panel
        self.hostingView = hostingView
        self.model = model
        self.accessibilityAnchorRect = accessibilityAnchorRect
        modelObservation = model.objectWillChange.sink { [weak self] _ in
            self?.scheduleContentResize()
        }

        panel.onKeyboardCommand = { [weak self] command in
            self?.handleKeyboardCommand(command) == true
        }
        outsideClickMonitor.start(panel: panel) { [weak self] in
            self?.requestOutsideDismissal()
        }

        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        scheduleContentResize()
    }

    func releaseKeyboardFocus() {
        panel?.makeFirstResponder(nil)
        panel?.resignKey()
    }

    func hide() {
        outsideClickMonitor.stop()
        panel?.onKeyboardCommand = nil
        panel?.orderOut(nil)
        panel?.contentView = nil
        modelObservation = nil
        resizeWorkItem?.cancel()
        resizeWorkItem = nil
        panel = nil
        hostingView = nil
        model = nil
        accessibilityAnchorRect = nil
    }

    @discardableResult
    func handleKeyboardCommand(_ command: FixesPaletteKeyboardCommand) -> Bool {
        guard let model else {
            return false
        }

        switch command {
        case .moveUp:
            model.moveSelection(.up)
        case .moveDown:
            model.moveSelection(.down)
        case .activate:
            model.activateSelection()
        case .dismiss:
            requestDismissal()
        }
        return true
    }

    private func requestDismissal() {
        guard let model else {
            hide()
            return
        }

        hide()
        model.requestDismissal()
    }

    private func requestOutsideDismissal() {
        guard model?.allowsOutsideDismissal == true else {
            return
        }
        requestDismissal()
    }

    private func makePanel() -> FixesPalettePanel {
        let panel = FixesPalettePanel(
            contentRect: CGRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovable = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .transient,
        ]
        panel.animationBehavior = .utilityWindow
        return panel
    }

    private func panelFrame(
        size: CGSize,
        accessibilityAnchorRect: CGRect?
    ) -> CGRect {
        let anchor: FixesPaletteAnchor
        if let accessibilityAnchorRect {
            anchor = .accessibility(accessibilityAnchorRect)
        } else {
            let mouseLocation = mouseLocationProvider()
            anchor = .appKit(
                CGRect(
                    x: mouseLocation.x,
                    y: mouseLocation.y,
                    width: 1,
                    height: 1
                )
            )
        }

        return FixesPalettePlacement.panelFrame(
            panelSize: size,
            anchor: anchor,
            screens: screenGeometryProvider()
        )
    }

    private func scheduleContentResize() {
        resizeWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else {
                return
            }

            self.resizeToContent()
        }
        resizeWorkItem = workItem
        DispatchQueue.main.async(execute: workItem)
    }

    private func resizeToContent() {
        guard let panel,
              let hostingView
        else {
            return
        }

        hostingView.layoutSubtreeIfNeeded()
        let fittingHeight = max(1, hostingView.fittingSize.height)
        let size = CGSize(width: panelSize.width, height: fittingHeight)
        let frame = panelFrame(
            size: size,
            accessibilityAnchorRect: accessibilityAnchorRect
        )
        panel.setFrame(frame, display: true)
        hostingView.frame = panel.contentView?.bounds ?? CGRect(
            origin: .zero,
            size: size
        )
    }
}

private final class FixesPalettePanel: NSPanel {
    var onKeyboardCommand: ((FixesPaletteKeyboardCommand) -> Bool)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func sendEvent(_ event: NSEvent) {
        if let command = FixesPaletteKeyboardCommand(event: event),
           onKeyboardCommand?(command) == true {
            return
        }

        super.sendEvent(event)
    }
}
