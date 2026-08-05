import SwiftUI

struct SettingsScene: Scene {
    static let identifier = "holdtype.settings"

    var body: some Scene {
        Window(SettingsWindowTitle.title(for: .permissions), id: Self.identifier) {
            SettingsWindowRoot()
        }
        .defaultSize(width: 900, height: 620)
        .windowResizability(.contentMinSize)
    }
}

private struct SettingsWindowRoot: View {
    var body: some View {
        SettingsView(
            navigation: SettingsPresentationCoordinator.shared.navigation,
            hotkeyStatusProvider: {
                DictationRuntime.shared.refreshHotkeyRegistrationStatus()
                return DictationRuntime.shared.hotkeyRegistrationStatus
            },
            fixesHotkeyStatusProvider: {
                FixesRuntime.shared.hotkeyRegistrationStatus
            }
        )
        .frame(minWidth: 720, minHeight: 480)
    }
}
