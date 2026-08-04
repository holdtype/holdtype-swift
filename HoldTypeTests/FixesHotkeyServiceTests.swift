import Carbon.HIToolbox
import CoreGraphics
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

    @Test func bareJDoesNotActivateFixes() {
        var mapper = FixesHotkeyEventMapper(shortcut: .fixesPalette)

        let keyDown = mapper.event(
            type: .keyDown,
            keyCode: Int64(kVK_ANSI_J),
            flags: []
        )
        let keyUp = mapper.event(
            type: .keyUp,
            keyCode: Int64(kVK_ANSI_J),
            flags: []
        )

        #expect(!keyDown)
        #expect(!keyUp)
    }

    @Test func optionJActivatesOnceOnRelease() {
        var mapper = FixesHotkeyEventMapper(shortcut: .fixesPalette)

        let keyDown = mapper.event(
            type: .keyDown,
            keyCode: Int64(kVK_ANSI_J),
            flags: [.maskAlternate]
        )
        let repeatedKeyDown = mapper.event(
            type: .keyDown,
            keyCode: Int64(kVK_ANSI_J),
            flags: [.maskAlternate]
        )
        let keyUp = mapper.event(
            type: .keyUp,
            keyCode: Int64(kVK_ANSI_J),
            flags: [.maskAlternate]
        )
        let repeatedKeyUp = mapper.event(
            type: .keyUp,
            keyCode: Int64(kVK_ANSI_J),
            flags: []
        )

        #expect(!keyDown)
        #expect(!repeatedKeyDown)
        #expect(keyUp)
        #expect(!repeatedKeyUp)
    }

    @Test func configuredShortcutRequiresEveryConfiguredModifier() {
        let shortcut = GlobalHotkeyShortcut(
            modifiers: [.control, .option],
            key: "J",
            keyCode: UInt16(kVK_ANSI_J)
        )
        var mapper = FixesHotkeyEventMapper(shortcut: shortcut)

        _ = mapper.event(
            type: .keyDown,
            keyCode: Int64(kVK_ANSI_J),
            flags: [.maskAlternate]
        )
        let incompleteRelease = mapper.event(
            type: .keyUp,
            keyCode: Int64(kVK_ANSI_J),
            flags: []
        )
        _ = mapper.event(
            type: .keyDown,
            keyCode: Int64(kVK_ANSI_J),
            flags: [.maskControl, .maskAlternate]
        )
        let confirmedRelease = mapper.event(
            type: .keyUp,
            keyCode: Int64(kVK_ANSI_J),
            flags: []
        )

        #expect(!incompleteRelease)
        #expect(confirmedRelease)
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
                    message: "Could not register the Fixes shortcut."
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
