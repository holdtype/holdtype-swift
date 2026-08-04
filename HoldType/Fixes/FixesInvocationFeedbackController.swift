import AppKit
import SwiftUI

@MainActor
protocol FixesInvocationFeedbackPresenting: AnyObject {
    func show(message: String)
    func hide()
}

@MainActor
final class FixesInvocationFeedbackController: FixesInvocationFeedbackPresenting {
    nonisolated static let defaultDisplayDuration: TimeInterval = 1.8

    private let displayDuration: TimeInterval
    private var panel: NSPanel?
    private var dismissWorkItem: DispatchWorkItem?

    init(displayDuration: TimeInterval = defaultDisplayDuration) {
        self.displayDuration = max(0, displayDuration)
    }

    func show(message: String) {
        hide()

        let hostingView = NSHostingView(
            rootView: FixesInvocationFeedbackView(message: message)
        )
        hostingView.layoutSubtreeIfNeeded()
        let size = hostingView.fittingSize
        hostingView.frame = CGRect(origin: .zero, size: size)

        let panel = makePanel(size: size)
        panel.contentView = hostingView
        panel.setFrame(centeredFrame(for: size), display: false)
        panel.orderFrontRegardless()
        self.panel = panel

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
        panel?.orderOut(nil)
        panel?.contentView = nil
        panel = nil
    }

    private func makePanel(size: CGSize) -> NSPanel {
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
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.animationBehavior = .utilityWindow
        return panel
    }

    private func centeredFrame(for size: CGSize) -> CGRect {
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouseLocation) }
            ?? NSScreen.main
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
    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
