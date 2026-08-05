import AppKit
import SwiftUI
import Testing
@testable import HoldType

@MainActor
struct FixesInvocationFeedbackControllerTests {
    @Test func presentsAnInteractiveFixedWidthDialog() throws {
        let monitor = FeedbackOutsideClickMonitor()
        let controller = makeController(
            displayDuration: 0,
            outsideClickMonitor: monitor
        )

        controller.show(message: "Fixes is not available in this text field.")
        defer { controller.hide() }

        let panel = try #require(controller.presentedPanel)
        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.canBecomeKey)
        #expect(panel.canBecomeMain == false)
        #expect(panel.ignoresMouseEvents == false)
        #expect(panel.frame.width == FixesInvocationFeedbackView.contentWidth)
        #expect(panel.frame.height > 100)
        #expect(panel.contentView is NSHostingView<FixesInvocationFeedbackView>)
        #expect(monitor.isMonitoring)
    }

    @Test func escapeDismissesTheDialogAndStopsOutsideClickMonitoring() throws {
        let monitor = FeedbackOutsideClickMonitor()
        let controller = makeController(
            displayDuration: 0,
            outsideClickMonitor: monitor
        )
        controller.show(message: "Fixes is not available in this text field.")

        let panel = try #require(controller.presentedPanel)
        panel.cancelOperation(nil)

        #expect(controller.presentedPanel == nil)
        #expect(controller.isVisible == false)
        #expect(monitor.isMonitoring == false)
    }

    @Test func outsideClickDismissesTheDialog() {
        let monitor = FeedbackOutsideClickMonitor()
        let controller = makeController(
            displayDuration: 0,
            outsideClickMonitor: monitor
        )
        controller.show(message: "Fixes is not available in this text field.")

        monitor.fireOutsideClick()

        #expect(controller.presentedPanel == nil)
        #expect(monitor.isMonitoring == false)
    }

    @Test func displayDurationDismissesTheDialog() async throws {
        let monitor = FeedbackOutsideClickMonitor()
        let controller = makeController(
            displayDuration: 0.01,
            outsideClickMonitor: monitor
        )
        controller.show(message: "Fixes is not available in this text field.")

        try await Task.sleep(for: .milliseconds(100))

        #expect(controller.presentedPanel == nil)
        #expect(monitor.isMonitoring == false)
    }

    private func makeController(
        displayDuration: TimeInterval,
        outsideClickMonitor: FeedbackOutsideClickMonitor
    ) -> FixesInvocationFeedbackController {
        FixesInvocationFeedbackController(
            displayDuration: displayDuration,
            outsideClickMonitor: outsideClickMonitor,
            screenProvider: { NSScreen.screens },
            mouseLocationProvider: { NSEvent.mouseLocation }
        )
    }
}

@MainActor
private final class FeedbackOutsideClickMonitor: FixesPaletteOutsideClickMonitoring {
    private(set) var isMonitoring = false
    private var onOutsideClick: (@MainActor () -> Void)?

    func start(
        panel: NSPanel,
        onOutsideClick: @escaping @MainActor () -> Void
    ) {
        _ = panel
        isMonitoring = true
        self.onOutsideClick = onOutsideClick
    }

    func stop() {
        isMonitoring = false
        onOutsideClick = nil
    }

    func fireOutsideClick() {
        onOutsideClick?()
    }
}
