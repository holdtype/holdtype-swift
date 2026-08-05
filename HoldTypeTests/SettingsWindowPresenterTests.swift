import Testing
@testable import HoldType

@MainActor
struct SettingsPresentationCoordinatorTests {

    @Test func settingsWindowTitleFallsBackToDefaultSection() {
        #expect(SettingsWindowTitle.title(for: nil) == "HoldType: Permissions")
    }

    @Test func settingsWindowTitleUsesSelectedSection() {
        #expect(SettingsWindowTitle.title(for: .openAI) == "HoldType: API key")
        #expect(SettingsWindowTitle.title(for: .cache) == "HoldType: Recording Cache")
    }

    @Test func focusedWindowRefreshTokenChangesEveryRequest() {
        let navigation = SettingsNavigation()

        #expect(navigation.focusRefreshToken == 0)

        navigation.requestFocusedWindowRefresh()
        navigation.requestFocusedWindowRefresh()

        #expect(navigation.focusRefreshToken == 2)
    }

    @Test func queuedPresentationRunsAfterTheSwiftUIActionIsInstalled() {
        let navigation = SettingsNavigation()
        let coordinator = SettingsPresentationCoordinator(navigation: navigation)
        var presentationCount = 0

        coordinator.show(focusing: .openAI)

        #expect(navigation.selectedItem == .openAI)
        #expect(presentationCount == 0)

        coordinator.install {
            presentationCount += 1
        }

        #expect(presentationCount == 1)
    }
}
