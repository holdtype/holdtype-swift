import AppKit
import Testing
@testable import HoldType

@MainActor
struct MenuBarStatusItemControllerTests {
    @Test func statusButtonCapturesBeforeShowingPopover() throws {
        var events: [String] = []
        let popover = TestMenuBarPopoverPresenter {
            events.append($0)
        }
        let controller = MenuBarStatusItemController(
            statusBar: .system,
            popoverPresenter: popover,
            prepareFixesTarget: {
                events.append("capture")
            },
            clearFixesTarget: {
                events.append("clear")
            }
        )
        defer { controller.stop() }
        controller.start()
        let button = try #require(controller.statusButton)

        button.performClick(nil)

        #expect(events == ["capture", "show"])
    }

    @Test func statusButtonUsesMouseDownAndAccessibilityMetadata() throws {
        var events: [String] = []
        let popover = TestMenuBarPopoverPresenter {
            events.append($0)
        }
        let controller = MenuBarStatusItemController(
            statusBar: .system,
            popoverPresenter: popover,
            prepareFixesTarget: {
                events.append("capture")
            },
            clearFixesTarget: {
                events.append("clear")
            }
        )
        defer { controller.stop() }
        controller.start()
        let button = try #require(controller.statusButton)

        let configuredMask = button.sendAction(on: [.leftMouseUp])
        button.sendAction(on: [.leftMouseDown])
        #expect(
            configuredMask
                == Int(NSEvent.EventTypeMask.leftMouseDown.rawValue)
        )
        #expect(
            button.accessibilityLabel()
                == HoldTypeMenuBarIdentity.title
        )
        #expect(
            button.accessibilityHelp()
                == HoldTypeMenuBarIdentity.helpText
        )
        #expect(button.image != nil)
        #expect(button.toolTip == HoldTypeMenuBarIdentity.helpText)
        #expect(events.isEmpty)
    }

    @Test func secondActivationClosesWithoutRecapturing() throws {
        var events: [String] = []
        let popover = TestMenuBarPopoverPresenter {
            events.append($0)
        }
        let controller = MenuBarStatusItemController(
            statusBar: .system,
            popoverPresenter: popover,
            prepareFixesTarget: {
                events.append("capture")
            },
            clearFixesTarget: {
                events.append("clear")
            }
        )
        defer { controller.stop() }
        controller.start()
        let button = try #require(controller.statusButton)

        button.performClick(nil)
        button.performClick(nil)

        #expect(events == ["capture", "show", "close", "clear"])
    }
}

@MainActor
private final class TestMenuBarPopoverPresenter:
    MenuBarPopoverPresenting
{
    private let recordEvent: (String) -> Void
    var onClose: (@MainActor () -> Void)?
    private(set) var isShown = false

    init(recordEvent: @escaping (String) -> Void) {
        self.recordEvent = recordEvent
    }

    func show(relativeTo button: NSStatusBarButton) {
        recordEvent("show")
        isShown = true
    }

    func close() {
        guard isShown else {
            return
        }
        recordEvent("close")
        isShown = false
        onClose?()
    }
}
