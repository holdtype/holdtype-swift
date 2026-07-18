//
//  PermissionsService.swift
//  HoldType
//
//  Created by Codex on 6/20/26.
//

import AppKit
import ApplicationServices
import AVFoundation
import IOKit.hid
import OSLog

enum MicrophonePermissionStatus: Equatable {
    case allowed
    case denied
    case notDetermined
    case unavailable

    var canRecord: Bool {
        self == .allowed
    }

    var settingsStatusText: String {
        switch self {
        case .allowed:
            return "Microphone: Allowed"
        case .denied:
            return "Microphone: Not Allowed"
        case .notDetermined:
            return "Microphone: Permission Needed"
        case .unavailable:
            return "Microphone: Unavailable"
        }
    }

    var settingsDescription: String {
        switch self {
        case .allowed:
            return "Recording can start after you choose a dictation action."
        case .denied:
            return "Recording is blocked until microphone access is allowed in System Settings."
        case .notDetermined:
            return "Request microphone access before starting dictation."
        case .unavailable:
            return "Recording is blocked because no microphone input is available."
        }
    }

    var settingsSystemImage: String {
        switch self {
        case .allowed:
            return "checkmark.circle"
        case .denied, .unavailable:
            return "xmark.octagon"
        case .notDetermined:
            return "exclamationmark.triangle"
        }
    }

    var settingsActionTitle: String? {
        switch self {
        case .allowed, .unavailable:
            return nil
        case .denied:
            return "Open Microphone Settings"
        case .notDetermined:
            return "Request Microphone Access"
        }
    }
}

enum MicrophoneAuthorizationStatus: Equatable {
    case allowed
    case denied
    case notDetermined
}

protocol MicrophonePermissionClient {
    var hasAvailableAudioInput: Bool { get }

    func authorizationStatus() -> MicrophoneAuthorizationStatus
    func requestAccess(completion: @escaping (Bool) -> Void)
}

struct AVFoundationMicrophonePermissionClient: MicrophonePermissionClient {
    var hasAvailableAudioInput: Bool {
        AVCaptureDevice.default(for: .audio) != nil
    }

    func authorizationStatus() -> MicrophoneAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .allowed
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio, completionHandler: completion)
    }
}

struct MicrophonePermissionService {
    private let client: MicrophonePermissionClient

    init(client: MicrophonePermissionClient = AVFoundationMicrophonePermissionClient()) {
        self.client = client
    }

    func currentStatus() -> MicrophonePermissionStatus {
        guard client.hasAvailableAudioInput else {
            return .unavailable
        }

        return status(for: client.authorizationStatus())
    }

    func requestPermission(completion: @escaping (MicrophonePermissionStatus) -> Void) {
        guard client.hasAvailableAudioInput else {
            completion(.unavailable)
            return
        }

        switch client.authorizationStatus() {
        case .allowed:
            completion(.allowed)
        case .denied:
            completion(.denied)
        case .notDetermined:
            client.requestAccess { isAllowed in
                completion(isAllowed ? .allowed : .denied)
            }
        }
    }

    private func status(for authorizationStatus: MicrophoneAuthorizationStatus) -> MicrophonePermissionStatus {
        switch authorizationStatus {
        case .allowed:
            return .allowed
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        }
    }

    @discardableResult
    func openMicrophoneSettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        ) else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }
}

enum AccessibilityPermissionStatus: Equatable {
    case trusted
    case notTrusted

    var canInsertTextIntoActiveApp: Bool {
        self == .trusted
    }

    var settingsDescription: String {
        switch self {
        case .trusted:
            return "Automatic insertion and Paste Last Result can insert text into the active app."
        case .notTrusted:
            return "Automatic insertion and Paste Last Result need Accessibility permission. Transcription can still save recovery text."
        }
    }

    var settingsActionTitle: String? {
        canInsertTextIntoActiveApp ? nil : "Request Accessibility Access"
    }

    var settingsInstruction: String? {
        switch self {
        case .trusted:
            return nil
        case .notTrusted:
            return "Enable HoldType in System Settings. If it is not listed, click + and choose the running HoldType app. If HoldType is listed but this still says Not Allowed after you turn it on, remove the old HoldType row with - and request access again so macOS adds the current app."
        }
    }

    var settingsStatusText: String {
        switch self {
        case .trusted:
            return "Accessibility: Allowed"
        case .notTrusted:
            return "Accessibility: Not Allowed"
        }
    }

    var settingsSystemImage: String {
        canInsertTextIntoActiveApp ? "checkmark.circle" : "exclamationmark.triangle"
    }

}

protocol AccessibilityPermissionClient {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool
    func openAccessibilitySettings() -> Bool
}

struct AXAccessibilityPermissionClient: AccessibilityPermissionClient {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        guard promptIfNeeded else {
            return AXIsProcessTrusted()
        }

        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        let options = [promptKey: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() -> Bool {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else {
            return false
        }

        return NSWorkspace.shared.open(url)
    }
}

struct AccessibilityPermissionService {
    private let client: AccessibilityPermissionClient

    init(client: AccessibilityPermissionClient = AXAccessibilityPermissionClient()) {
        self.client = client
    }

    func currentStatus() -> AccessibilityPermissionStatus {
        client.isProcessTrusted(promptIfNeeded: false) ? .trusted : .notTrusted
    }

    func requestPermission() -> AccessibilityPermissionStatus {
        client.isProcessTrusted(promptIfNeeded: true) ? .trusted : currentStatus()
    }

    @discardableResult
    func openAccessibilitySettings() -> Bool {
        client.openAccessibilitySettings()
    }
}

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
