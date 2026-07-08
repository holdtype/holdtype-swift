import Testing
@testable import HoldType

struct SettingsSetupWarningTests {

    @Test func permissionsWarningListsOnlyRemainingPermissionSetupItems() {
        let warning = SettingsSetupWarning.permissions(
            from: AppSetupStatus(
                microphonePermissionStatus: .notDetermined,
                accessibilityPermissionStatus: .notTrusted,
                inputMonitoringPermissionStatus: .denied,
                settings: .defaults
            )
        )

        #expect(warning?.title == "Required setup is incomplete")
        #expect(warning?.detailLines == ["Microphone", "Accessibility"])
    }

    @Test func permissionsWarningIsNilWhenRequiredSetupIsComplete() {
        let warning = SettingsSetupWarning.permissions(
            from: AppSetupStatus(
                microphonePermissionStatus: .allowed,
                accessibilityPermissionStatus: .trusted,
                inputMonitoringPermissionStatus: .denied,
                settings: .defaults
            )
        )

        #expect(warning == nil)
    }

    @Test func openAIWarningReflectsMissingOrUnavailableKey() {
        #expect(
            SettingsSetupWarning.openAI(apiKeyAvailability: .missing)?.title
                == "OpenAI API key required"
        )
        #expect(
            SettingsSetupWarning.openAI(apiKeyAvailability: .unavailable("Keychain unavailable."))?.message
                == "Keychain unavailable."
        )
        #expect(SettingsSetupWarning.openAI(apiKeyAvailability: .saved) == nil)
    }
}
