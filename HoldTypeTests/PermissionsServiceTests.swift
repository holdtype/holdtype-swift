//
//  PermissionsServiceTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/20/26.
//

import Testing
import CoreGraphics
import AppKit
import Foundation
import IOKit.hid
@testable import HoldType

struct PermissionsServiceTests {

    @Test func currentStatusMapsAuthorizationStates() {
        #expect(
            MicrophonePermissionService(
                client: FakeMicrophonePermissionClient(authorizationStatus: .allowed)
            ).currentStatus() == .allowed
        )
        #expect(
            MicrophonePermissionService(
                client: FakeMicrophonePermissionClient(authorizationStatus: .denied)
            ).currentStatus() == .denied
        )
        #expect(
            MicrophonePermissionService(
                client: FakeMicrophonePermissionClient(authorizationStatus: .notDetermined)
            ).currentStatus() == .notDetermined
        )
    }

    @Test func unavailableAudioInputBlocksRecordingBeforeAuthorizationState() {
        let client = FakeMicrophonePermissionClient(
            hasAvailableAudioInput: false,
            authorizationStatus: .allowed
        )
        let service = MicrophonePermissionService(client: client)

        #expect(service.currentStatus() == .unavailable)
        #expect(service.currentStatus().canRecord == false)
    }

    @Test func requestPermissionSkipsPromptForTerminalStates() {
        let allowedClient = FakeMicrophonePermissionClient(authorizationStatus: .allowed)
        let deniedClient = FakeMicrophonePermissionClient(authorizationStatus: .denied)

        MicrophonePermissionService(client: allowedClient).requestPermission { status in
            #expect(status == .allowed)
        }
        MicrophonePermissionService(client: deniedClient).requestPermission { status in
            #expect(status == .denied)
        }

        #expect(allowedClient.requestCount == 0)
        #expect(deniedClient.requestCount == 0)
    }

    @Test func requestPermissionUsesCallbackWhenNotDetermined() {
        let client = FakeMicrophonePermissionClient(
            authorizationStatus: .notDetermined,
            requestResults: [true]
        )
        let service = MicrophonePermissionService(client: client)

        service.requestPermission { status in
            #expect(status == .allowed)
        }

        #expect(client.requestCount == 1)
    }

    @Test func unavailableAudioInputDoesNotRequestPermission() {
        let client = FakeMicrophonePermissionClient(
            hasAvailableAudioInput: false,
            authorizationStatus: .notDetermined,
            requestResults: [true]
        )
        let service = MicrophonePermissionService(client: client)

        service.requestPermission { status in
            #expect(status == .unavailable)
        }

        #expect(client.requestCount == 0)
    }

    @Test func microphoneSettingsCopyNamesStatusAndBoundedActions() {
        #expect(MicrophonePermissionStatus.allowed.settingsStatusText == "Microphone: Allowed")
        #expect(MicrophonePermissionStatus.allowed.settingsActionTitle == nil)
        #expect(MicrophonePermissionStatus.allowed.settingsDescription.contains("choose a dictation action"))

        #expect(MicrophonePermissionStatus.denied.settingsStatusText == "Microphone: Not Allowed")
        #expect(MicrophonePermissionStatus.denied.settingsActionTitle == "Open Microphone Settings")
        #expect(MicrophonePermissionStatus.denied.settingsDescription.contains("System Settings"))

        #expect(MicrophonePermissionStatus.notDetermined.settingsStatusText == "Microphone: Permission Needed")
        #expect(MicrophonePermissionStatus.notDetermined.settingsActionTitle == "Request Microphone Access")

        #expect(MicrophonePermissionStatus.unavailable.settingsStatusText == "Microphone: Unavailable")
        #expect(MicrophonePermissionStatus.unavailable.settingsActionTitle == nil)
        #expect(MicrophonePermissionStatus.unavailable.settingsDescription.contains("no microphone input"))
    }

    @Test func accessibilityStatusMapsTrustWithoutPrompting() {
        let trustedClient = FakeAccessibilityPermissionClient(isTrusted: true)
        let notTrustedClient = FakeAccessibilityPermissionClient(isTrusted: false)

        #expect(AccessibilityPermissionService(client: trustedClient).currentStatus() == .trusted)
        #expect(
            AccessibilityPermissionService(client: notTrustedClient).currentStatus() == .notTrusted
        )
        #expect(AccessibilityPermissionStatus.trusted.canInsertTextIntoActiveApp)
        #expect(AccessibilityPermissionStatus.notTrusted.canInsertTextIntoActiveApp == false)
        #expect(trustedClient.promptRequests == [false])
        #expect(notTrustedClient.promptRequests == [false])
    }

    @Test func accessibilitySettingsOpenerIsSeparateFromStatusCheck() {
        let client = FakeAccessibilityPermissionClient(isTrusted: false, opensSettings: true)
        let service = AccessibilityPermissionService(client: client)

        #expect(service.currentStatus() == .notTrusted)
        #expect(client.openSettingsCount == 0)
        #expect(service.openAccessibilitySettings())
        #expect(client.openSettingsCount == 1)
        #expect(client.promptRequests == [false])
    }

    @Test func accessibilityRequestUsesPromptingTrustCheck() {
        let client = FakeAccessibilityPermissionClient(isTrusted: false)
        let service = AccessibilityPermissionService(client: client)

        #expect(service.requestPermission() == .notTrusted)
        #expect(client.promptRequests == [true, false])
        #expect(client.openSettingsCount == 0)
    }

    @Test func accessibilitySettingsCopyNamesStatus() {
        #expect(AccessibilityPermissionStatus.trusted.settingsStatusText == "Accessibility: Allowed")
        #expect(AccessibilityPermissionStatus.trusted.settingsSystemImage == "checkmark.circle")
        #expect(AccessibilityPermissionStatus.trusted.settingsDescription.contains("insert text"))

        #expect(AccessibilityPermissionStatus.notTrusted.settingsStatusText == "Accessibility: Not Allowed")
        #expect(AccessibilityPermissionStatus.notTrusted.settingsSystemImage == "exclamationmark.triangle")
        #expect(AccessibilityPermissionStatus.notTrusted.settingsDescription.contains("Automatic insertion"))
        #expect(AccessibilityPermissionStatus.notTrusted.settingsActionTitle == "Request Accessibility Access")
        #expect(AccessibilityPermissionStatus.notTrusted.settingsInstruction?.contains("click +") == true)
        #expect(AccessibilityPermissionStatus.notTrusted.settingsInstruction?.contains("remove the old HoldType row") == true)
        #expect(AccessibilityPermissionStatus.notTrusted.settingsInstruction?.contains("request access again") == true)
    }

    #if DEBUG
    @MainActor
    @Test func debugAccessibilityRecoveryDoesNothingWithoutEnvironmentFlag() {
        let client = FakeAccessibilityPermissionClient(isTrusted: false)
        let service = AccessibilityPermissionService(client: client)

        DebugAccessibilityPermissionRecovery.requestIfNeeded(
            environment: [:],
            permissionService: service
        )

        #expect(client.promptRequests == [])
        #expect(client.openSettingsCount == 0)
    }

    @MainActor
    @Test func debugAccessibilityRecoveryPromptsCurrentAppAndOpensSettingsWhenFlagged() {
        let client = FakeAccessibilityPermissionClient(isTrusted: false, opensSettings: true)
        let service = AccessibilityPermissionService(client: client)

        DebugAccessibilityPermissionRecovery.requestIfNeeded(
            environment: [DebugAccessibilityPermissionRecovery.environmentKey: "1"],
            permissionService: service
        )

        #expect(client.promptRequests == [true, false])
        #expect(client.openSettingsCount == 1)
    }
    #endif

    @Test func inputMonitoringStatusMapsAuthorizationStates() {
        #expect(
            InputMonitoringPermissionService(
                client: FakeInputMonitoringPermissionClient(authorizationStatus: .allowed)
            ).currentStatus() == .allowed
        )
        #expect(
            InputMonitoringPermissionService(
                client: FakeInputMonitoringPermissionClient(authorizationStatus: .denied)
            ).currentStatus() == .denied
        )
        #expect(
            InputMonitoringPermissionService(
                client: FakeInputMonitoringPermissionClient(authorizationStatus: .notDetermined)
            ).currentStatus() == .notDetermined
        )
    }

    @Test func inputMonitoringRequestAndSettingsActionsAreBounded() {
        let notDeterminedClient = FakeInputMonitoringPermissionClient(
            authorizationStatus: .notDetermined,
            requestResult: true
        )
        let deniedClient = FakeInputMonitoringPermissionClient(
            authorizationStatus: .denied,
            opensSettings: true
        )

        #expect(
            InputMonitoringPermissionService(client: notDeterminedClient).requestPermission()
                == .allowed
        )
        #expect(notDeterminedClient.requestCount == 1)

        let deniedService = InputMonitoringPermissionService(client: deniedClient)
        #expect(deniedService.openInputMonitoringSettings())
        #expect(deniedClient.openSettingsCount == 1)
    }

    @Test func systemInputMonitoringClientUsesHIDStatusBeforeCoreGraphicsListenEventGrant() {
        let client = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { true },
            checkHIDAccess: { kIOHIDAccessTypeDenied },
            requestListenEventAccess: { false },
            requestHIDAccess: { false },
            openURL: { _ in false }
        )

        #expect(client.authorizationStatus() == .denied)
    }

    @Test func systemInputMonitoringClientFallsBackToHIDUnknownWhenCoreGraphicsIsNotGranted() {
        let client = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { false },
            checkHIDAccess: { kIOHIDAccessTypeUnknown },
            requestListenEventAccess: { false },
            requestHIDAccess: { false },
            openURL: { _ in false }
        )

        #expect(client.authorizationStatus() == .notDetermined)
    }

    @Test func systemInputMonitoringRequestUsesHIDBeforeCoreGraphicsFallback() {
        var didRequestCoreGraphicsAccess = false
        var didRequestHIDManagerRegistration = false
        var didRequestEventTapRegistration = false
        var didRequestAppKitMonitorRegistration = false
        var hidResults = [kIOHIDAccessTypeGranted]
        let grantedClient = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { false },
            checkHIDAccess: {
                hidResults.isEmpty ? kIOHIDAccessTypeDenied : hidResults.removeFirst()
            },
            requestListenEventAccess: {
                didRequestCoreGraphicsAccess = true
                return true
            },
            requestHIDAccess: {
                return true
            },
            requestHIDManagerRegistration: {
                didRequestHIDManagerRegistration = true
                return true
            },
            requestEventTapRegistration: {
                didRequestEventTapRegistration = true
                return true
            },
            requestAppKitMonitorRegistration: {
                didRequestAppKitMonitorRegistration = true
                return true
            },
            openURL: { _ in false }
        )

        #expect(grantedClient.requestAccess())
        #expect(didRequestHIDManagerRegistration)
        #expect(didRequestCoreGraphicsAccess)
        #expect(didRequestEventTapRegistration)
        #expect(didRequestAppKitMonitorRegistration)

        var didRequestHIDAccess = false
        didRequestHIDManagerRegistration = false
        didRequestAppKitMonitorRegistration = false
        let fallbackClient = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { false },
            checkHIDAccess: { kIOHIDAccessTypeDenied },
            requestListenEventAccess: {
                didRequestCoreGraphicsAccess = true
                return true
            },
            requestHIDAccess: {
                didRequestHIDAccess = true
                return false
            },
            requestHIDManagerRegistration: {
                didRequestHIDManagerRegistration = true
                return false
            },
            requestEventTapRegistration: {
                didRequestEventTapRegistration = true
                return false
            },
            requestAppKitMonitorRegistration: {
                didRequestAppKitMonitorRegistration = true
                return false
            },
            openURL: { _ in false }
        )

        #expect(fallbackClient.requestAccess() == false)
        #expect(didRequestHIDAccess)
        #expect(didRequestHIDManagerRegistration)
        #expect(didRequestCoreGraphicsAccess)
        #expect(didRequestEventTapRegistration)
        #expect(didRequestAppKitMonitorRegistration)
    }

    @Test func systemInputMonitoringRequestCallsHIDRequestEvenWhenHIDStatusAlreadyGranted() {
        var didRequestHIDAccess = false
        var didRequestHIDManagerRegistration = false
        var didRequestCoreGraphicsAccess = false
        var didRequestEventTapRegistration = false
        var didRequestAppKitMonitorRegistration = false
        let client = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { false },
            checkHIDAccess: { kIOHIDAccessTypeGranted },
            requestListenEventAccess: {
                didRequestCoreGraphicsAccess = true
                return false
            },
            requestHIDAccess: {
                didRequestHIDAccess = true
                return true
            },
            requestHIDManagerRegistration: {
                didRequestHIDManagerRegistration = true
                return true
            },
            requestEventTapRegistration: {
                didRequestEventTapRegistration = true
                return false
            },
            requestAppKitMonitorRegistration: {
                didRequestAppKitMonitorRegistration = true
                return false
            },
            openURL: { _ in false }
        )

        #expect(client.requestAccess())
        #expect(didRequestHIDAccess)
        #expect(didRequestHIDManagerRegistration)
        #expect(didRequestCoreGraphicsAccess)
        #expect(didRequestEventTapRegistration)
        #expect(didRequestAppKitMonitorRegistration)
    }

    @Test func systemInputMonitoringRequestUsesHIDRecheckForFinalResultAfterProbes() {
        var hidResults = [kIOHIDAccessTypeGranted]
        var didRequestCoreGraphicsAccess = false
        var didRequestEventTapRegistration = false
        var didRequestAppKitMonitorRegistration = false
        let client = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { false },
            checkHIDAccess: {
                hidResults.isEmpty ? kIOHIDAccessTypeDenied : hidResults.removeFirst()
            },
            requestListenEventAccess: {
                didRequestCoreGraphicsAccess = true
                return false
            },
            requestHIDAccess: { false },
            requestHIDManagerRegistration: { true },
            requestEventTapRegistration: {
                didRequestEventTapRegistration = true
                return false
            },
            requestAppKitMonitorRegistration: {
                didRequestAppKitMonitorRegistration = true
                return false
            },
            openURL: { _ in false }
        )

        #expect(client.requestAccess())
        #expect(didRequestCoreGraphicsAccess)
        #expect(didRequestEventTapRegistration)
        #expect(didRequestAppKitMonitorRegistration)
    }

    @Test func systemInputMonitoringRequestRunsHIDManagerBeforeCoreGraphicsProbe() {
        var hidResults = [kIOHIDAccessTypeGranted]
        var requestOrder: [String] = []
        var didRequestEventTapRegistration = false
        let client = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { false },
            checkHIDAccess: {
                hidResults.isEmpty ? kIOHIDAccessTypeDenied : hidResults.removeFirst()
            },
            requestListenEventAccess: {
                requestOrder.append("coreGraphics")
                return false
            },
            requestHIDAccess: { false },
            requestHIDManagerRegistration: {
                requestOrder.append("hidManager")
                return true
            },
            requestEventTapRegistration: {
                didRequestEventTapRegistration = true
                return false
            },
            requestAppKitMonitorRegistration: {
                requestOrder.append("appKit")
                return false
            },
            openURL: { _ in false }
        )

        #expect(client.requestAccess())
        #expect(requestOrder == ["hidManager", "coreGraphics", "appKit"])
        #expect(didRequestEventTapRegistration)
    }

    @Test func systemInputMonitoringRequestDoesNotTreatCoreGraphicsGrantAsInputMonitoringAllowed() {
        var didRequestCoreGraphicsAccess = false
        let client = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { true },
            checkHIDAccess: { kIOHIDAccessTypeDenied },
            requestListenEventAccess: {
                didRequestCoreGraphicsAccess = true
                return true
            },
            requestHIDAccess: { false },
            requestHIDManagerRegistration: { false },
            requestEventTapRegistration: { true },
            requestAppKitMonitorRegistration: { true },
            openURL: { _ in false }
        )

        #expect(client.requestAccess() == false)
        #expect(didRequestCoreGraphicsAccess)
    }

    @Test func systemInputMonitoringRequestUsesEventTapAndAppKitRegistrationFallbacks() {
        var requestHIDManagerRegistrationCount = 0
        var requestEventTapRegistrationCount = 0
        var requestAppKitMonitorRegistrationCount = 0
        let client = SystemInputMonitoringPermissionClient(
            preflightListenEventAccess: { false },
            checkHIDAccess: { kIOHIDAccessTypeDenied },
            requestListenEventAccess: { false },
            requestHIDAccess: { false },
            requestHIDManagerRegistration: {
                requestHIDManagerRegistrationCount += 1
                return false
            },
            requestEventTapRegistration: {
                requestEventTapRegistrationCount += 1
                return false
            },
            requestAppKitMonitorRegistration: {
                requestAppKitMonitorRegistrationCount += 1
                return false
            },
            openURL: { _ in false }
        )

        #expect(client.requestAccess() == false)
        #expect(requestHIDManagerRegistrationCount == 1)
        #expect(requestEventTapRegistrationCount == 1)
        #expect(requestAppKitMonitorRegistrationCount == 1)
    }

    @Test func inputMonitoringAppKitMonitorProbeUsesKeyboardEventMask() {
        #expect(InputMonitoringAppKitMonitorRegistrationProbe.eventMask.contains(.keyDown))
        #expect(InputMonitoringAppKitMonitorRegistrationProbe.eventMask.contains(.flagsChanged))
    }

    @Test func inputMonitoringHIDManagerProbeMatchesKeyboardDevices() {
        let matching = InputMonitoringHIDManagerRegistrationProbe.keyboardDeviceMatching as NSDictionary
        let usagePage = matching[kIOHIDDeviceUsagePageKey] as? NSNumber
        let usage = matching[kIOHIDDeviceUsageKey] as? NSNumber

        #expect(usagePage?.intValue == Int(kHIDPage_GenericDesktop))
        #expect(usage?.intValue == Int(kHIDUsage_GD_Keyboard))
        #expect(InputMonitoringHIDManagerRegistrationProbe.registrationRunLoopDuration > 0)
    }

    @Test func inputMonitoringRegistrationProbeUsesKeyboardEventMask() {
        #expect(
            InputMonitoringEventTapRegistrationProbe.registrationEventMask
                == CGEventMask(1 << CGEventType.keyDown.rawValue)
                    | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        )
    }

    @MainActor
    @Test func inputMonitoringLaunchRecoveryRequestsBeforeSetupWhenFlagged() {
        let client = FakeInputMonitoringPermissionClient(
            authorizationStatus: .denied,
            opensSettings: true
        )
        let service = InputMonitoringPermissionService(client: client)
        var activateCount = 0

        InputMonitoringPermissionLaunchRecovery.requestIfNeeded(
            environment: [
                InputMonitoringPermissionLaunchRecovery.requestEnvironmentKey: "1",
                InputMonitoringPermissionLaunchRecovery.openSettingsEnvironmentKey: "1"
            ],
            permissionService: service,
            activateApp: {
                activateCount += 1
            },
            scheduleRequestAfterActivation: { request in
                request()
            },
            terminateProcess: {}
        )

        #expect(activateCount == 1)
        #expect(client.requestCount == 1)
        #expect(client.openSettingsCount == 1)
    }

    @MainActor
    @Test func inputMonitoringLaunchRecoveryDefersRequestUntilAfterActivation() {
        let client = FakeInputMonitoringPermissionClient(
            authorizationStatus: .denied,
            opensSettings: true
        )
        let service = InputMonitoringPermissionService(client: client)
        var activateCount = 0
        var scheduledRequest: (@MainActor () -> Void)?

        InputMonitoringPermissionLaunchRecovery.requestIfNeeded(
            environment: [
                InputMonitoringPermissionLaunchRecovery.requestEnvironmentKey: "1",
                InputMonitoringPermissionLaunchRecovery.openSettingsEnvironmentKey: "1"
            ],
            permissionService: service,
            activateApp: {
                activateCount += 1
            },
            scheduleRequestAfterActivation: { request in
                scheduledRequest = request
            },
            terminateProcess: {}
        )

        #expect(activateCount == 1)
        #expect(client.requestCount == 0)
        #expect(client.openSettingsCount == 0)

        scheduledRequest?()

        #expect(client.requestCount == 1)
        #expect(client.openSettingsCount == 1)
    }

    @Test func inputMonitoringSettingsCopyNamesStatusAndActions() {
        #expect(InputMonitoringPermissionStatus.allowed.settingsStatusText == "Input Monitoring: Allowed")
        #expect(InputMonitoringPermissionStatus.allowed.settingsActionTitle == nil)
        #expect(InputMonitoringPermissionStatus.allowed.settingsInstruction == nil)
        #expect(InputMonitoringPermissionStatus.allowed.settingsSystemImage == "checkmark.circle")

        #expect(InputMonitoringPermissionStatus.denied.settingsStatusText == "Input Monitoring: Not Allowed")
        #expect(InputMonitoringPermissionStatus.denied.settingsActionTitle == "Open Input Monitoring Settings")
        #expect(InputMonitoringPermissionStatus.denied.settingsInstruction?.contains("HoldType") == true)
        #expect(InputMonitoringPermissionStatus.denied.settingsInstruction?.contains("fallback") == true)
        #expect(InputMonitoringPermissionStatus.denied.settingsDescription.contains("System Settings"))
        #expect(InputMonitoringPermissionStatus.denied.settingsDescription.contains("Menu recording is not blocked"))
        #expect(InputMonitoringPermissionStatus.denied.settingsManualFallbackWarning?.contains("click +") == true)
        #expect(
            InputMonitoringPermissionStatus.denied.settingsManualFallbackWarning?.contains("HoldType.app") == true
        )

        #expect(InputMonitoringPermissionStatus.notDetermined.settingsStatusText == "Input Monitoring: Permission Needed")
        #expect(InputMonitoringPermissionStatus.notDetermined.settingsActionTitle == "Request Input Monitoring Access")
        #expect(InputMonitoringPermissionStatus.notDetermined.settingsInstruction?.contains("HoldType") == true)
        #expect(InputMonitoringPermissionStatus.notDetermined.settingsInstruction?.contains("fallback") == true)
        #expect(
            InputMonitoringPermissionStatus.notDetermined.settingsManualFallbackWarning?.contains("enable the toggle")
                == true
        )
    }
}

private final class FakeMicrophonePermissionClient: MicrophonePermissionClient {
    private(set) var requestCount = 0
    private var requestResults: [Bool]

    var hasAvailableAudioInput: Bool
    var currentAuthorizationStatus: MicrophoneAuthorizationStatus

    init(
        hasAvailableAudioInput: Bool = true,
        authorizationStatus: MicrophoneAuthorizationStatus,
        requestResults: [Bool] = []
    ) {
        self.hasAvailableAudioInput = hasAvailableAudioInput
        self.currentAuthorizationStatus = authorizationStatus
        self.requestResults = requestResults
    }

    func authorizationStatus() -> MicrophoneAuthorizationStatus {
        currentAuthorizationStatus
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        requestCount += 1
        completion(requestResults.first ?? false)
        if !requestResults.isEmpty {
            requestResults.removeFirst()
        }
    }
}

private final class FakeAccessibilityPermissionClient: AccessibilityPermissionClient {
    private(set) var openSettingsCount = 0
    private(set) var promptRequests: [Bool] = []

    var isTrusted: Bool
    var opensSettings: Bool

    init(isTrusted: Bool, opensSettings: Bool = false) {
        self.isTrusted = isTrusted
        self.opensSettings = opensSettings
    }

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        promptRequests.append(promptIfNeeded)
        return isTrusted
    }

    func openAccessibilitySettings() -> Bool {
        openSettingsCount += 1
        return opensSettings
    }
}

private final class FakeInputMonitoringPermissionClient: InputMonitoringPermissionClient {
    private(set) var requestCount = 0
    private(set) var openSettingsCount = 0

    private var currentAuthorizationStatus: InputMonitoringAuthorizationStatus
    private let requestResult: Bool
    private let opensSettings: Bool

    init(
        authorizationStatus: InputMonitoringAuthorizationStatus,
        requestResult: Bool = false,
        opensSettings: Bool = false
    ) {
        currentAuthorizationStatus = authorizationStatus
        self.requestResult = requestResult
        self.opensSettings = opensSettings
    }

    func authorizationStatus() -> InputMonitoringAuthorizationStatus {
        currentAuthorizationStatus
    }

    func requestAccess() -> Bool {
        requestCount += 1
        if requestResult {
            currentAuthorizationStatus = .allowed
        }
        return requestResult
    }

    func openInputMonitoringSettings() -> Bool {
        openSettingsCount += 1
        return opensSettings
    }
}
