import Testing
@testable import HoldType

struct PermissionsSettingsSectionVisibilityTests {

    @Test func compactRequiredSetupHidesAllowedMicrophoneWhenAccessibilityStillNeedsAction() {
        let visibility = PermissionsSettingsSectionVisibility(
            microphonePermissionStatus: .allowed,
            accessibilityPermissionStatus: .notTrusted,
            showsCompletedRequiredPermissions: false,
            showsInputMonitoringStatus: false
        )

        #expect(visibility.showsMicrophoneStatus == false)
        #expect(visibility.showsAccessibilityStatus)
        #expect(visibility.showsCompletedState == false)
    }

    @Test func compactRequiredSetupShowsCompletedStateWhenNoRemainingRowsAreVisible() {
        let visibility = PermissionsSettingsSectionVisibility(
            microphonePermissionStatus: .allowed,
            accessibilityPermissionStatus: .trusted,
            showsCompletedRequiredPermissions: false,
            showsInputMonitoringStatus: false
        )

        #expect(visibility.showsMicrophoneStatus == false)
        #expect(visibility.showsAccessibilityStatus == false)
        #expect(visibility.showsCompletedState)
    }

    @Test func fullSettingsStillShowsCompletedPermissionRows() {
        let visibility = PermissionsSettingsSectionVisibility(
            microphonePermissionStatus: .allowed,
            accessibilityPermissionStatus: .trusted,
            showsCompletedRequiredPermissions: true,
            showsInputMonitoringStatus: true
        )

        #expect(visibility.showsMicrophoneStatus)
        #expect(visibility.showsAccessibilityStatus)
        #expect(visibility.showsCompletedState == false)
    }
}
