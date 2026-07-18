import HoldTypeDomain
import Testing
@testable import HoldType

struct SettingsNavigationItemTests {

    @Test func permissionsIsTheFirstAndDefaultSettingsSection() {
        #expect(SettingsNavigationItem.allCases.first == .permissions)
        #expect(SettingsNavigationItem.allCases.map(\.title) == [
            "Permissions",
            "API key",
            "Billing",
            "Transcription",
            "Text Correction",
            "Translation",
            "Dictionary",
            "Shortcut",
            "Behavior",
            "Recording Cache",
            "Updates",
            "Diagnostics",
        ])
    }

    @Test func recoveryDestinationAdapterMapsOnlySupportedMacOSRoutes() {
        #expect(SettingsNavigationItem(recoveryDestination: .openAI) == .openAI)
        #expect(SettingsNavigationItem(recoveryDestination: .transcription) == .transcription)
        #expect(SettingsNavigationItem(recoveryDestination: .translation) == .translation)
        #expect(SettingsNavigationItem(recoveryDestination: .microphoneAndPrivacy) == nil)
    }
}
