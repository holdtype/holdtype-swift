import Carbon.HIToolbox
import Testing
@testable import HoldType

@MainActor
struct FixesHotkeyServiceTests {
    @Test func shortcutUsesOptionJPresentation() {
        let shortcut = GlobalHotkeyShortcut.fixesPalette

        #expect(shortcut.modifiers == [.option])
        #expect(shortcut.key == "J")
        #expect(shortcut.displayText == "Option+J")
        #expect(shortcut.menuKeyEquivalentText == "⌥J")
    }

    @Test func carbonRegistrationUsesOptionJOnRelease() {
        #expect(
            FixesHotkeyCarbonRegistration.keyCode
                == UInt32(kVK_ANSI_J)
        )
        #expect(
            FixesHotkeyCarbonRegistration.modifiers
                == UInt32(optionKey)
        )
        #expect(
            FixesHotkeyCarbonRegistration.eventKind
                == UInt32(kEventHotKeyReleased)
        )
    }

    @Test func coordinatorRegistersOnceAndForwardsActions() {
        let service = FakeFixesHotkeyService()
        let coordinator = FixesHotkeyCoordinator(hotkeyService: service)
        var invocationCount = 0

        coordinator.start {
            invocationCount += 1
        }
        coordinator.start {
            invocationCount += 100
        }
        service.trigger()

        #expect(service.startCount == 1)
        #expect(service.isListening)
        #expect(coordinator.registrationStatus == .registered)
        #expect(invocationCount == 1)

        coordinator.stop()
        #expect(!service.isListening)
        #expect(coordinator.registrationStatus == .notRegistered)
    }

    @Test func registrationFailureIsIndependentAndVisible() {
        let service = FakeFixesHotkeyService(
            startError: FixesHotkeyServiceError.registrationFailed(
                status: OSStatus(eventHotKeyExistsErr)
            )
        )
        let coordinator = FixesHotkeyCoordinator(hotkeyService: service)

        coordinator.start {}

        #expect(!service.isListening)
        #expect(
            coordinator.registrationStatus
                == FixesHotkeyRegistrationStatus.unavailable(
                    message: "Could not register Option+J for Fixes."
                )
        )
    }
}

private final class FakeFixesHotkeyService: FixesHotkeyListening {
    private let startError: Error?
    private var handler: (() -> Void)?

    private(set) var isListening = false
    private(set) var startCount = 0

    init(startError: Error? = nil) {
        self.startError = startError
    }

    func start(handler: @escaping () -> Void) throws {
        startCount += 1
        if let startError {
            throw startError
        }
        self.handler = handler
        isListening = true
    }

    func stop() {
        handler = nil
        isListening = false
    }

    func trigger() {
        handler?()
    }
}
