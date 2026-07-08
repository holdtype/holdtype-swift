import Foundation
import Testing
@testable import HoldType

struct AppSetupStatusTests {

    @Test func missingRequiredRecordingSetupBlocksRecordingAndPrefersFirstRelevantSettingsSection() {
        let status = AppSetupStatus(
            microphonePermissionStatus: .notDetermined,
            accessibilityPermissionStatus: .notTrusted,
            inputMonitoringPermissionStatus: .notDetermined,
            settings: .defaults
        )

        #expect(status.canStartRecording == false)
        #expect(status.preferredRecordingSettingsItem == .permissions)
        #expect(status.recordingBlockers.map(\.kind) == [.microphone, .accessibility])
        #expect(status.recordingBlockedMessage.contains("Complete required setup"))
    }

    @Test func inputMonitoringDoesNotRequireStartupAttentionOrBlockManualRecording() {
        let status = AppSetupStatus(
            microphonePermissionStatus: .allowed,
            accessibilityPermissionStatus: .trusted,
            inputMonitoringPermissionStatus: .denied,
            settings: .defaults
        )

        #expect(status.requiresStartupAttention == false)
        #expect(status.canStartRecording)
        #expect(status.startupAttentionItems.isEmpty)
        #expect(status.recordingBlockers.isEmpty)
        #expect(status.preferredStartupSettingsItem == .permissions)
    }

    @Test func resolvedMicrophoneStillLeavesPermissionsAttentionForAccessibilityOnly() {
        let status = AppSetupStatus(
            microphonePermissionStatus: .allowed,
            accessibilityPermissionStatus: .notTrusted,
            inputMonitoringPermissionStatus: .denied,
            settings: .defaults
        )

        #expect(status.requiresStartupAttention)
        #expect(status.startupAttentionItems.map(\.kind) == [.accessibility])
        #expect(status.preferredStartupSettingsItem == .permissions)
    }

    @Test func providerChecksInputMonitoringBeforeAccessibility() {
        var order: [String] = []
        let provider = AppSetupStatusProvider(
            microphonePermissionService: MicrophonePermissionService(
                client: SetupOrderMicrophonePermissionClient()
            ),
            accessibilityPermissionService: AccessibilityPermissionService(
                client: SetupOrderAccessibilityPermissionClient {
                    order.append("accessibility")
                }
            ),
            inputMonitoringPermissionService: InputMonitoringPermissionService(
                client: SetupOrderInputMonitoringPermissionClient {
                    order.append("inputMonitoring")
                }
            )
        )

        _ = provider.currentStatus(settings: .defaults)

        #expect(order == ["inputMonitoring", "accessibility"])
    }

    @Test func missingAccessibilityDoesNotBlockRecordingWhenDependentBehaviorIsDisabled() {
        var settings = AppSettings.defaults
        settings.automaticallyInsertTranscripts = false
        settings.useActiveTextContext = false

        let status = AppSetupStatus(
            microphonePermissionStatus: .allowed,
            accessibilityPermissionStatus: .notTrusted,
            inputMonitoringPermissionStatus: .allowed,
            settings: settings
        )

        #expect(status.requiresStartupAttention)
        #expect(status.canStartRecording)
        #expect(status.startupAttentionItems.map(\.kind) == [.accessibility])
        #expect(status.recordingBlockers.isEmpty)
    }
}

private struct SetupOrderMicrophonePermissionClient: MicrophonePermissionClient {
    var hasAvailableAudioInput: Bool { true }

    func authorizationStatus() -> MicrophoneAuthorizationStatus {
        .allowed
    }

    func requestAccess(completion: @escaping (Bool) -> Void) {
        completion(true)
    }
}

private struct SetupOrderAccessibilityPermissionClient: AccessibilityPermissionClient {
    let onStatusRead: () -> Void

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        onStatusRead()
        return true
    }

    func openAccessibilitySettings() -> Bool {
        true
    }
}

private struct SetupOrderInputMonitoringPermissionClient: InputMonitoringPermissionClient {
    let onStatusRead: () -> Void

    func authorizationStatus() -> InputMonitoringAuthorizationStatus {
        onStatusRead()
        return .allowed
    }

    func requestAccess() -> Bool {
        true
    }

    func openInputMonitoringSettings() -> Bool {
        true
    }
}
