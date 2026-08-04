import Carbon.HIToolbox
import CoreGraphics
import Foundation

protocol FixesHotkeyListening: AnyObject {
    var isListening: Bool { get }

    func start(handler: @escaping () -> Void) throws
    func stop()
}

enum FixesHotkeyRegistrationStatus: Equatable {
    case notRegistered
    case registered
    case unavailable(message: String)
}

struct FixesHotkeyEventMapper {
    private let shortcut: GlobalHotkeyShortcut
    private var isShortcutPressed = false

    init(shortcut: GlobalHotkeyShortcut) {
        self.shortcut = shortcut
    }

    mutating func event(
        type: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags
    ) -> Bool {
        switch type {
        case .keyDown:
            guard !isShortcutPressed,
                  Int64(shortcut.keyCode) == keyCode,
                  flags.contains(shortcut.eventFlags)
            else {
                return false
            }
            isShortcutPressed = true
            return false
        case .keyUp:
            guard isShortcutPressed,
                  Int64(shortcut.keyCode) == keyCode
            else {
                return false
            }
            isShortcutPressed = false
            return true
        default:
            return false
        }
    }

    mutating func reset() {
        isShortcutPressed = false
    }
}

final class CGEventFixesHotkeyService: FixesHotkeyListening {
    private let configurationStore: ShortcutConfigurationStore
    private var hotKeyRef: EventHotKeyRef?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var handler: (() -> Void)?
    private var eventMapper = FixesHotkeyEventMapper(
        shortcut: .fixesPalette
    )

    var isListening: Bool {
        hotKeyRef != nil && eventTap != nil
    }

    init(configurationStore: ShortcutConfigurationStore = ShortcutConfigurationStore()) {
        self.configurationStore = configurationStore
    }

    func start(handler: @escaping () -> Void) throws {
        stop()

        let shortcut = configurationStore.load().fixes
        var newHotKeyRef: EventHotKeyRef?
        let registrationStatus = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            EventHotKeyID(
                signature: FixesHotkeyCarbonID.signature,
                id: FixesHotkeyCarbonID.id
            ),
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )
        guard registrationStatus == noErr, let newHotKeyRef else {
            throw FixesHotkeyServiceError.registrationFailed(
                status: registrationStatus
            )
        }

        let eventMask = CGEventMask(
            (1 << CGEventType.keyDown.rawValue)
                | (1 << CGEventType.keyUp.rawValue)
        )
        guard let newEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: fixesHotkeyEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            UnregisterEventHotKey(newHotKeyRef)
            throw FixesHotkeyServiceError.registrationUnavailable(
                message: "Input Monitoring is required for the Fixes shortcut."
            )
        }

        guard let newRunLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            newEventTap,
            0
        ) else {
            CFMachPortInvalidate(newEventTap)
            UnregisterEventHotKey(newHotKeyRef)
            throw FixesHotkeyServiceError.registrationUnavailable(
                message: "Could not start the Fixes shortcut listener."
            )
        }

        hotKeyRef = newHotKeyRef
        eventTap = newEventTap
        runLoopSource = newRunLoopSource
        eventMapper = FixesHotkeyEventMapper(shortcut: shortcut)
        self.handler = handler
        CFRunLoopAddSource(CFRunLoopGetMain(), newRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newEventTap, enable: true)
    }

    func stop() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }

        self.hotKeyRef = nil
        self.eventTap = nil
        self.runLoopSource = nil
        handler = nil
        eventMapper.reset()
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        if eventMapper.event(
            type: type,
            keyCode: event.getIntegerValueField(.keyboardEventKeycode),
            flags: event.flags
        ) {
            handler?()
        }
        return Unmanaged.passUnretained(event)
    }

    deinit {
        stop()
    }
}

@MainActor
final class FixesHotkeyCoordinator {
    private let hotkeyService: any FixesHotkeyListening
    private var isStarted = false

    private(set) var registrationStatus:
        FixesHotkeyRegistrationStatus = .notRegistered

    init(
        hotkeyService: any FixesHotkeyListening =
            CGEventFixesHotkeyService()
    ) {
        self.hotkeyService = hotkeyService
    }

    func start(handler: @escaping () -> Void) {
        guard !isStarted else {
            return
        }
        isStarted = true

        do {
            try hotkeyService.start(handler: handler)
            registrationStatus = .registered
        } catch {
            hotkeyService.stop()
            registrationStatus = .unavailable(
                message: Self.userFacingMessage(for: error)
            )
        }
    }

    func stop() {
        hotkeyService.stop()
        isStarted = false
        registrationStatus = .notRegistered
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(
               in: .whitespacesAndNewlines
           ).isEmpty {
            return description
        }
        return error.localizedDescription
    }
}

enum FixesHotkeyServiceError: Error, Equatable, LocalizedError {
    case registrationFailed(status: OSStatus)
    case registrationUnavailable(message: String)

    var errorDescription: String? {
        switch self {
        case .registrationFailed:
            return "Could not register the Fixes shortcut."
        case .registrationUnavailable(let message):
            return message
        }
    }
}

private enum FixesHotkeyCarbonID {
    static let signature: OSType = 0x48544658
    static let id: UInt32 = 2
}

private func fixesHotkeyEventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let service = Unmanaged<CGEventFixesHotkeyService>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return service.handle(type: type, event: event)
}
