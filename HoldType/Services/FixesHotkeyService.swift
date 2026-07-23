import Carbon.HIToolbox
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

final class CarbonFixesHotkeyService: FixesHotkeyListening {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var handlerBox: FixesHotkeyHandlerBox?

    var isListening: Bool {
        hotKeyRef != nil
    }

    func start(handler: @escaping () -> Void) throws {
        stop()

        let handlerBox = FixesHotkeyHandlerBox(handler: handler)
        self.handlerBox = handlerBox

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: FixesHotkeyCarbonRegistration.eventKind
        )
        var newEventHandlerRef: EventHandlerRef?
        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            fixesHotkeyEventHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(handlerBox).toOpaque(),
            &newEventHandlerRef
        )

        guard installStatus == noErr else {
            self.handlerBox = nil
            throw FixesHotkeyServiceError.registrationFailed(
                status: installStatus
            )
        }

        var newHotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(
            signature: FixesHotkeyCarbonID.signature,
            id: FixesHotkeyCarbonID.id
        )
        let registerStatus = RegisterEventHotKey(
            FixesHotkeyCarbonRegistration.keyCode,
            FixesHotkeyCarbonRegistration.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &newHotKeyRef
        )

        guard registerStatus == noErr else {
            if let newEventHandlerRef {
                RemoveEventHandler(newEventHandlerRef)
            }
            self.handlerBox = nil
            throw FixesHotkeyServiceError.registrationFailed(
                status: registerStatus
            )
        }

        eventHandlerRef = newEventHandlerRef
        hotKeyRef = newHotKeyRef
    }

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }

        self.hotKeyRef = nil
        self.eventHandlerRef = nil
        handlerBox = nil
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
            CarbonFixesHotkeyService()
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

    var errorDescription: String? {
        "Could not register Option+J for Fixes."
    }
}

enum FixesHotkeyCarbonRegistration {
    static let keyCode = UInt32(kVK_ANSI_J)
    static let modifiers = UInt32(optionKey)
    static let eventKind = UInt32(kEventHotKeyReleased)
}

private enum FixesHotkeyCarbonID {
    static let signature: OSType = 0x48544658
    static let id: UInt32 = 2
}

private final class FixesHotkeyHandlerBox {
    let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }
}

private func fixesHotkeyEventHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event, let userData else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr,
          hotKeyID.signature == FixesHotkeyCarbonID.signature,
          hotKeyID.id == FixesHotkeyCarbonID.id
    else {
        return noErr
    }

    let handlerBox = Unmanaged<FixesHotkeyHandlerBox>
        .fromOpaque(userData)
        .takeUnretainedValue()
    handlerBox.handler()
    return noErr
}
