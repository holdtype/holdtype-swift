//
//  InputMonitoringPermissionService.swift
//  HoldType
//
//  Created by Codex on 7/18/26.
//

import AppKit
import ApplicationServices
import IOKit.hid
import OSLog

enum InputMonitoringAuthorizationStatus: Equatable {
    case allowed
    case denied
    case notDetermined
}

enum InputMonitoringPermissionStatus: Equatable {
    case allowed
    case denied
    case notDetermined

    var settingsStatusText: String {
        switch self {
        case .allowed:
            return "Input Monitoring: Allowed"
        case .denied:
            return "Input Monitoring: Not Allowed"
        case .notDetermined:
            return "Input Monitoring: Permission Needed"
        }
    }

    var settingsDescription: String {
        switch self {
        case .allowed:
            return "Global shortcuts that require key monitoring can listen outside HoldType."
        case .denied:
            return "Some global shortcut modes may be unavailable until Input Monitoring is allowed in System Settings. Menu recording is not blocked."
        case .notDetermined:
            return "Allow Input Monitoring when prompted only if a global shortcut mode asks for it."
        }
    }

    var settingsSystemImage: String {
        switch self {
        case .allowed:
            return "checkmark.circle"
        case .denied:
            return "xmark.octagon"
        case .notDetermined:
            return "exclamationmark.triangle"
        }
    }

    var settingsActionTitle: String? {
        switch self {
        case .allowed:
            return nil
        case .denied:
            return "Open Input Monitoring Settings"
        case .notDetermined:
            return "Request Input Monitoring Access"
        }
    }

    var settingsInstruction: String? {
        switch self {
        case .allowed:
            return nil
        case .denied, .notDetermined:
            return """
            After the settings pane opens, enable HoldType. If HoldType is not listed, quit and \
            reopen HoldType, try this action again, then use + only as a fallback to add the \
            running HoldType.app.
            """
        }
    }

    var settingsManualFallbackWarning: String? {
        switch self {
        case .allowed:
            return nil
        case .denied, .notDetermined:
            return """
            HoldType is still not listed or still not allowed. In Input Monitoring, click +, \
            choose the running HoldType.app, then enable the toggle.
            """
        }
    }
}

protocol InputMonitoringPermissionClient {
    func authorizationStatus() -> InputMonitoringAuthorizationStatus
    func requestAccess() -> Bool
    func openInputMonitoringSettings() -> Bool
}

struct SystemInputMonitoringPermissionClient: InputMonitoringPermissionClient {
    private let preflightListenEventAccess: () -> Bool
    private let checkHIDAccess: () -> IOHIDAccessType
    private let requestListenEventAccess: () -> Bool
    private let requestHIDAccess: () -> Bool
    private let requestHIDManagerRegistration: () -> Bool
    private let requestEventTapRegistration: () -> Bool
    private let requestAppKitMonitorRegistration: () -> Bool
    private let openURL: (URL) -> Bool

    init(
        preflightListenEventAccess: @escaping () -> Bool = {
            CGPreflightListenEventAccess()
        },
        checkHIDAccess: @escaping () -> IOHIDAccessType = {
            IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        },
        requestListenEventAccess: @escaping () -> Bool = {
            CGRequestListenEventAccess()
        },
        requestHIDAccess: @escaping () -> Bool = {
            IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        },
        requestHIDManagerRegistration: @escaping () -> Bool = {
            InputMonitoringHIDManagerRegistrationProbe().requestRegistration()
        },
        requestEventTapRegistration: @escaping () -> Bool = {
            InputMonitoringEventTapRegistrationProbe().requestRegistration()
        },
        requestAppKitMonitorRegistration: @escaping () -> Bool = {
            InputMonitoringAppKitMonitorRegistrationProbe().requestRegistration()
        },
        openURL: @escaping (URL) -> Bool = { url in
            NSWorkspace.shared.open(url)
        }
    ) {
        self.preflightListenEventAccess = preflightListenEventAccess
        self.checkHIDAccess = checkHIDAccess
        self.requestListenEventAccess = requestListenEventAccess
        self.requestHIDAccess = requestHIDAccess
        self.requestHIDManagerRegistration = requestHIDManagerRegistration
        self.requestEventTapRegistration = requestEventTapRegistration
        self.requestAppKitMonitorRegistration = requestAppKitMonitorRegistration
        self.openURL = openURL
    }

    func authorizationStatus() -> InputMonitoringAuthorizationStatus {
        let accessType = checkHIDAccess()

        if accessType == kIOHIDAccessTypeGranted {
            return .allowed
        }

        if accessType == kIOHIDAccessTypeDenied {
            return .denied
        }

        return .notDetermined
    }

    func requestAccess() -> Bool {
        let hidRequestResult = requestHIDAccess()
        let hidManagerRegistrationResult = requestHIDManagerRegistration()
        let coreGraphicsRequestResult = requestListenEventAccess() || preflightListenEventAccess()
        let eventTapRegistrationResult = requestEventTapRegistration()
        let appKitMonitorRegistrationResult = requestAppKitMonitorRegistration()
        let finalResult = checkHIDAccess() == kIOHIDAccessTypeGranted
        InputMonitoringDebugLogger.record(
            coreGraphicsRequestResult: coreGraphicsRequestResult,
            hidRequestResult: hidRequestResult,
            hidManagerRegistrationResult: hidManagerRegistrationResult,
            eventTapRegistrationResult: eventTapRegistrationResult,
            appKitMonitorRegistrationResult: appKitMonitorRegistrationResult,
            finalResult: finalResult
        )
        return finalResult
    }

    func openInputMonitoringSettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        ) else {
            return false
        }

        return openURL(url)
    }
}

struct InputMonitoringAppKitMonitorRegistrationProbe {
    static let eventMask: NSEvent.EventTypeMask = [.keyDown, .flagsChanged]

    func requestRegistration() -> Bool {
        guard let monitor = NSEvent.addGlobalMonitorForEvents(matching: Self.eventMask, handler: { _ in }) else {
            return false
        }

        NSEvent.removeMonitor(monitor)
        return true
    }
}

struct InputMonitoringHIDManagerRegistrationProbe {
    static let registrationRunLoopDuration: CFTimeInterval = 0.35
    static let keyboardDeviceMatching = [
        kIOHIDDeviceUsagePageKey: NSNumber(value: Int(kHIDPage_GenericDesktop)),
        kIOHIDDeviceUsageKey: NSNumber(value: Int(kHIDUsage_GD_Keyboard))
    ] as CFDictionary

    func requestRegistration() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        IOHIDManagerSetDeviceMatching(manager, Self.keyboardDeviceMatching)
        IOHIDManagerRegisterInputValueCallback(manager, inputMonitoringHIDValueCallback, nil)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        CFRunLoopRunInMode(CFRunLoopMode.defaultMode, Self.registrationRunLoopDuration, false)
        IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerUnscheduleFromRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)
        return result == kIOReturnSuccess
    }
}

private func inputMonitoringHIDValueCallback(
    _ context: UnsafeMutableRawPointer?,
    _ result: IOReturn,
    _ sender: UnsafeMutableRawPointer?,
    _ value: IOHIDValue
) {}

struct InputMonitoringEventTapRegistrationProbe {
    static let registrationEventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        | CGEventMask(1 << CGEventType.flagsChanged.rawValue)

    func requestRegistration() -> Bool {
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: Self.registrationEventMask,
            callback: inputMonitoringRegistrationProbeCallback,
            userInfo: nil
        ) else {
            return false
        }

        guard let runLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            eventTap,
            0
        ) else {
            CFMachPortInvalidate(eventTap)
            return false
        }

        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CFMachPortInvalidate(eventTap)
        return true
    }
}

private func inputMonitoringRegistrationProbeCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    Unmanaged.passUnretained(event)
}

private enum InputMonitoringDebugLogger {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app.holdtype.HoldType",
        category: "Permissions"
    )

    static func record(
        coreGraphicsRequestResult: Bool?,
        hidRequestResult: Bool?,
        hidManagerRegistrationResult: Bool?,
        eventTapRegistrationResult: Bool?,
        appKitMonitorRegistrationResult: Bool?,
        finalResult: Bool
    ) {
        guard ProcessInfo.processInfo.environment["HOLDTYPE_DEBUG_PERMISSIONS"] == "1" else {
            return
        }

        logger.notice(
            """
            Input Monitoring request: \
            cg=\(description(for: coreGraphicsRequestResult), privacy: .public), \
            hid=\(description(for: hidRequestResult), privacy: .public), \
            hidManager=\(description(for: hidManagerRegistrationResult), privacy: .public), \
            tap=\(description(for: eventTapRegistrationResult), privacy: .public), \
            appKit=\(description(for: appKitMonitorRegistrationResult), privacy: .public), \
            allowed=\(finalResult, privacy: .public)
            """
        )
    }

    private static func description(for result: Bool?) -> String {
        switch result {
        case .some(true):
            return "true"
        case .some(false):
            return "false"
        case nil:
            return "skipped"
        }
    }
}

struct InputMonitoringPermissionService {
    private let client: InputMonitoringPermissionClient

    init(client: InputMonitoringPermissionClient = SystemInputMonitoringPermissionClient()) {
        self.client = client
    }

    func currentStatus() -> InputMonitoringPermissionStatus {
        switch client.authorizationStatus() {
        case .allowed:
            return .allowed
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        }
    }

    func requestPermission() -> InputMonitoringPermissionStatus {
        client.requestAccess() ? .allowed : currentStatus()
    }

    @discardableResult
    func openInputMonitoringSettings() -> Bool {
        client.openInputMonitoringSettings()
    }
}
