import AppKit
import Testing
@testable import HoldType

@MainActor
struct SettingsWindowPresenterTests {

    @Test func settingsWindowTitleFallsBackToDefaultSection() {
        #expect(SettingsWindowTitle.title(for: nil) == "HoldType: Permissions")
    }

    @Test func settingsWindowTitleUsesSelectedSection() {
        #expect(SettingsWindowTitle.title(for: .openAI) == "HoldType: API key")
        #expect(SettingsWindowTitle.title(for: .cache) == "HoldType: Recording Cache")
    }

    @Test func translationFocusClearsInitialTextEntryFocus() {
        #expect(SettingsWindowFocusBehavior.shouldClearInitialTextEntryFocus(for: .translation))
    }

    @Test func nonTranslationFocusKeepsInitialTextEntryFocusPolicy() {
        #expect(!SettingsWindowFocusBehavior.shouldClearInitialTextEntryFocus(for: nil))
        #expect(!SettingsWindowFocusBehavior.shouldClearInitialTextEntryFocus(for: .openAI))
        #expect(!SettingsWindowFocusBehavior.shouldClearInitialTextEntryFocus(for: .permissions))
    }

    @Test func focusedWindowRefreshTokenChangesEveryRequest() {
        let navigation = SettingsWindowNavigation()

        #expect(navigation.focusRefreshToken == 0)

        navigation.requestFocusedWindowRefresh()
        navigation.requestFocusedWindowRefresh()

        #expect(navigation.focusRefreshToken == 2)
    }

    @Test func windowDidBecomeKeyRequestsFocusedSettingsRefresh() {
        let navigation = SettingsWindowNavigation()
        let presenter = SettingsWindowPresenter(navigation: navigation)

        presenter.windowDidBecomeKey(
            Notification(name: NSWindow.didBecomeKeyNotification)
        )

        #expect(navigation.focusRefreshToken == 1)
    }
}
