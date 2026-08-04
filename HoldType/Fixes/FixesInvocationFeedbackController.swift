import AppKit
import SwiftUI

@MainActor
protocol FixesInvocationFeedbackPresenting: AnyObject {
    func show(message: String)
    func hide()
}

@MainActor
final class FixesInvocationFeedbackController: FixesInvocationFeedbackPresenting {
    nonisolated static let defaultDisplayDuration: TimeInterval = 4

    private let displayDuration: TimeInterval
    private let outsideClickMonitor: any FixesPaletteOutsideClickMonitoring
    private let screenProvider: @MainActor () -> [NSScreen]
    private let mouseLocationProvider: @MainActor () -> CGPoint
    private var panel: FixesInvocationFeedbackPanel?
    private var dismissWorkItem: DispatchWorkItem?

    convenience init(displayDuration: TimeInterval = defaultDisplayDuration) {
        self.init(
            displayDuration: displayDuration,
            outsideClickMonitor: FixesPaletteOutsideClickMonitor(),
            screenProvider: { NSScreen.screens },
            mouseLocationProvider: { NSEvent.mouseLocation }
        )
    }

    init(
        displayDuration: TimeInterval,
        outsideClickMonitor: any FixesPaletteOutsideClickMonitoring,
        screenProvider: @escaping @MainActor () -> [NSScreen],
        mouseLocationProvider: @escaping @MainActor () -> CGPoint
    ) {
        self.displayDuration = max(0, displayDuration)
        self.outsideClickMonitor = outsideClickMonitor
        self.screenProvider = screenProvider
        self.mouseLocationProvider = mouseLocationProvider
    }

    var isVisible: Bool {
        panel?.isVisible == true
    }

    var presentedPanel: NSPanel? {
        panel
    }

    func show(message: String) {
        hide()

        let presentation = FixesInvocationFeedbackPresentation(message: message)
        let hostingView = NSHostingView(
            rootView: FixesInvocationFeedbackView(
                presentation: presentation,
                onDismiss: { [weak self] in
                    self?.hide()
                }
            )
        )
        hostingView.frame = CGRect(
            x: 0,
            y: 0,
            width: FixesInvocationFeedbackView.contentWidth,
            height: 1
        )
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        hostingView.frame = CGRect(origin: .zero, size: size)

        let panel = makePanel(size: size)
        panel.contentView = hostingView
        panel.setFrame(centeredFrame(for: size), display: false)
        self.panel = panel
        outsideClickMonitor.start(panel: panel) { [weak self] in
            self?.hide()
        }
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()

        guard displayDuration > 0 else {
            return
        }
        let dismissWorkItem = DispatchWorkItem { [weak self] in
            self?.hide()
        }
        self.dismissWorkItem = dismissWorkItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + displayDuration,
            execute: dismissWorkItem
        )
    }

    func hide() {
        dismissWorkItem?.cancel()
        dismissWorkItem = nil
        outsideClickMonitor.stop()
        panel?.onDismiss = nil
        panel?.makeFirstResponder(nil)
        panel?.resignKey()
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
    }

    private func makePanel(size: CGSize) -> FixesInvocationFeedbackPanel {
        let panel = FixesInvocationFeedbackPanel(
            contentRect: CGRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        panel.onDismiss = { [weak self] in
            self?.hide()
        }
        return panel
    }

    private func centeredFrame(for size: CGSize) -> CGRect {
        let mouseLocation = mouseLocationProvider()
        let screens = screenProvider()
        let screen = screens.first { $0.frame.contains(mouseLocation) }
            ?? screens.first
        let visibleFrame = screen?.visibleFrame ?? .zero
        return CGRect(
            x: visibleFrame.midX - (size.width / 2),
            y: visibleFrame.midY - (size.height / 2),
            width: size.width,
            height: size.height
        )
    }
}

private final class FixesInvocationFeedbackPanel: NSPanel {
    var onDismiss: (() -> Void)?

    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }

    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }
}
