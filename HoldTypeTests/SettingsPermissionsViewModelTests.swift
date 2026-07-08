import Foundation
import Testing
@testable import HoldType

@MainActor
struct SettingsPermissionsViewModelTests {

    @Test func visiblePollingRefreshesSystemPermissionsInBothDirections() async {
        let microphoneClient = FakeSettingsMicrophonePermissionClient(status: .denied)
        let accessibilityClient = FakeSettingsAccessibilityPermissionClient(isTrusted: false)
        let inputMonitoringClient = FakeSettingsInputMonitoringPermissionClient(status: .denied)
        let model = makeModel(
            microphoneClient: microphoneClient,
            accessibilityClient: accessibilityClient,
            inputMonitoringClient: inputMonitoringClient
        )

        model.startVisiblePermissionsPolling()

        microphoneClient.status = .allowed
        accessibilityClient.isTrusted = true
        inputMonitoringClient.status = .allowed
        await waitUntil {
            model.microphonePermissionStatus == .allowed
                && model.accessibilityPermissionStatus == .trusted
                && model.inputMonitoringPermissionStatus == .allowed
        }

        microphoneClient.status = .denied
        accessibilityClient.isTrusted = false
        inputMonitoringClient.status = .denied
        await waitUntil {
            model.microphonePermissionStatus == .denied
                && model.accessibilityPermissionStatus == .notTrusted
                && model.inputMonitoringPermissionStatus == .denied
        }

        model.stopVisiblePermissionsPolling()
        #expect(model.microphonePermissionStatus == .denied)
        #expect(model.accessibilityPermissionStatus == .notTrusted)
        #expect(model.inputMonitoringPermissionStatus == .denied)
    }

    @Test func initializationChecksInputMonitoringBeforeAccessibility() {
        var order: [String] = []
        let accessibilityClient = FakeSettingsAccessibilityPermissionClient(isTrusted: true)
        let inputMonitoringClient = FakeSettingsInputMonitoringPermissionClient(status: .allowed)
        accessibilityClient.onStatusRead = {
            order.append("accessibility")
        }
        inputMonitoringClient.onStatusRead = {
            order.append("inputMonitoring")
        }

        _ = makeModel(
            accessibilityClient: accessibilityClient,
            inputMonitoringClient: inputMonitoringClient
        )

        #expect(order == ["inputMonitoring", "accessibility"])
    }

    @Test func refreshChecksInputMonitoringBeforeAccessibility() {
        var order: [String] = []
        let accessibilityClient = FakeSettingsAccessibilityPermissionClient(isTrusted: true)
        let inputMonitoringClient = FakeSettingsInputMonitoringPermissionClient(status: .allowed)
        let model = makeModel(
            accessibilityClient: accessibilityClient,
            inputMonitoringClient: inputMonitoringClient
        )
        accessibilityClient.onStatusRead = {
            order.append("accessibility")
        }
        inputMonitoringClient.onStatusRead = {
            order.append("inputMonitoring")
        }

        model.refreshOnAppearOrFocus()

        #expect(order == ["inputMonitoring", "accessibility"])
    }

    @Test func stopVisiblePermissionsPollingStopsFurtherUpdates() async {
        let accessibilityClient = FakeSettingsAccessibilityPermissionClient(isTrusted: false)
        let model = makeModel(accessibilityClient: accessibilityClient)

        model.startVisiblePermissionsPolling()
        accessibilityClient.isTrusted = true
        await waitUntil {
            model.accessibilityPermissionStatus == .trusted
        }

        model.stopVisiblePermissionsPolling()
        accessibilityClient.isTrusted = false
        for _ in 0..<20 {
            await Task.yield()
        }

        #expect(model.accessibilityPermissionStatus == .trusted)
    }

    @Test func refreshAfterSettingsChangeRefreshesSystemPermissionsOnly() {
        let microphoneClient = FakeSettingsMicrophonePermissionClient(status: .denied)
        let accessibilityClient = FakeSettingsAccessibilityPermissionClient(isTrusted: false)
        let inputMonitoringClient = FakeSettingsInputMonitoringPermissionClient(status: .denied)
        let model = makeModel(
            microphoneClient: microphoneClient,
            accessibilityClient: accessibilityClient,
            inputMonitoringClient: inputMonitoringClient
        )

        microphoneClient.status = .allowed
        accessibilityClient.isTrusted = true
        inputMonitoringClient.status = .allowed
        model.refreshAfterSettingsChange()

        #expect(model.microphonePermissionStatus == .allowed)
        #expect(model.accessibilityPermissionStatus == .trusted)
        #expect(model.inputMonitoringPermissionStatus == .allowed)
    }

    @Test func inputMonitoringActionRequestsAccessBeforeOpeningSettingsWhenDenied() {
        let inputMonitoringClient = FakeSettingsInputMonitoringPermissionClient(status: .denied)
        var recoveryLaunchCount = 0
        let model = makeModel(
            inputMonitoringClient: inputMonitoringClient,
            inputMonitoringRecoveryLauncher: {
                recoveryLaunchCount += 1
                return true
            }
        )

        model.handleInputMonitoringPermissionAction()

        #expect(inputMonitoringClient.requestCount == 1)
        #expect(recoveryLaunchCount == 1)
        #expect(inputMonitoringClient.openSettingsCount == 1)
        #expect(model.inputMonitoringPermissionStatus == .denied)
    }

    @Test func inputMonitoringActionRequestsAccessBeforeOpeningSettingsWhenNotDetermined() {
        let inputMonitoringClient = FakeSettingsInputMonitoringPermissionClient(status: .notDetermined)
        var recoveryLaunchCount = 0
        let model = makeModel(
            inputMonitoringClient: inputMonitoringClient,
            inputMonitoringRecoveryLauncher: {
                recoveryLaunchCount += 1
                return true
            }
        )

        model.handleInputMonitoringPermissionAction()

        #expect(inputMonitoringClient.requestCount == 1)
        #expect(recoveryLaunchCount == 1)
        #expect(inputMonitoringClient.openSettingsCount == 1)
        #expect(model.inputMonitoringPermissionStatus == .notDetermined)
    }

    @Test func inputMonitoringActionEscalatesManualFallbackAfterRepeatedFailures() {
        let inputMonitoringClient = FakeSettingsInputMonitoringPermissionClient(status: .denied)
        let model = makeModel(inputMonitoringClient: inputMonitoringClient)

        model.handleInputMonitoringPermissionAction()

        #expect(model.showsInputMonitoringManualFallbackWarning == false)

        model.handleInputMonitoringPermissionAction()

        #expect(inputMonitoringClient.requestCount == 2)
        #expect(model.inputMonitoringPermissionStatus == .denied)
        #expect(model.showsInputMonitoringManualFallbackWarning == true)
    }

    @Test func inputMonitoringManualFallbackWarningResetsWhenAllowed() {
        let inputMonitoringClient = FakeSettingsInputMonitoringPermissionClient(status: .denied)
        let model = makeModel(inputMonitoringClient: inputMonitoringClient)

        model.handleInputMonitoringPermissionAction()
        model.handleInputMonitoringPermissionAction()
        #expect(model.showsInputMonitoringManualFallbackWarning == true)

        inputMonitoringClient.status = .allowed
        model.refreshAfterSettingsChange()

        #expect(model.inputMonitoringPermissionStatus == .allowed)
        #expect(model.showsInputMonitoringManualFallbackWarning == false)

        inputMonitoringClient.status = .denied
        model.handleInputMonitoringPermissionAction()

        #expect(model.showsInputMonitoringManualFallbackWarning == false)
    }

    private func makeModel(
        microphoneClient: FakeSettingsMicrophonePermissionClient = FakeSettingsMicrophonePermissionClient(
            status: .allowed
        ),
        accessibilityClient: FakeSettingsAccessibilityPermissionClient = FakeSettingsAccessibilityPermissionClient(
            isTrusted: true
        ),
        inputMonitoringClient: FakeSettingsInputMonitoringPermissionClient = FakeSettingsInputMonitoringPermissionClient(
            status: .allowed
        ),
        inputMonitoringRecoveryLauncher: @escaping @MainActor () -> Bool = { true }
    ) -> SettingsPermissionsViewModel {
        SettingsPermissionsViewModel(
            microphonePermissionService: MicrophonePermissionService(client: microphoneClient),
            accessibilityPermissionService: AccessibilityPermissionService(client: accessibilityClient),
            inputMonitoringPermissionService: InputMonitoringPermissionService(client: inputMonitoringClient),
            inputMonitoringRecoveryLauncher: inputMonitoringRecoveryLauncher,
            visiblePollingIntervalNanoseconds: 0
        )
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<100 where !condition() {
            await Task.yield()
        }
    }
}

private final class FakeSettingsMicrophonePermissionClient: MicrophonePermissionClient {
    var hasAvailableAudioInput = true
    var status: MicrophoneAuthorizationStatus

    init(status: MicrophoneAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() -> MicrophoneAuthorizationStatus {
        status
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        status = .allowed
        completion(true)
    }
}

private final class FakeSettingsAccessibilityPermissionClient: AccessibilityPermissionClient {
    private(set) var openSettingsCount = 0
    private(set) var promptRequests: [Bool] = []
    var onStatusRead: (() -> Void)?

    var isTrusted: Bool

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        promptRequests.append(promptIfNeeded)
        onStatusRead?()
        return isTrusted
    }

    func openAccessibilitySettings() -> Bool {
        openSettingsCount += 1
        return true
    }
}

private final class FakeSettingsInputMonitoringPermissionClient: InputMonitoringPermissionClient {
    private(set) var requestCount = 0
    private(set) var openSettingsCount = 0
    var onStatusRead: (() -> Void)?

    var status: InputMonitoringAuthorizationStatus

    init(status: InputMonitoringAuthorizationStatus) {
        self.status = status
    }

    func authorizationStatus() -> InputMonitoringAuthorizationStatus {
        onStatusRead?()
        return status
    }

    func requestAccess() -> Bool {
        requestCount += 1
        return status == .allowed
    }

    func openInputMonitoringSettings() -> Bool {
        openSettingsCount += 1
        return true
    }
}
