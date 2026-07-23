import Testing
@testable import HoldType

struct KeyboardShortcutSettingsPresentationTests {
    @Test func fixesFailureDoesNotChangeRegisteredDictationStatus() {
        let dictation = HotkeySettingsPresentation(
            status: .registered(.defaultDictation)
        )
        let fixes = HotkeySettingsPresentation(
            fixesStatus: .unavailable(
                message: "Could not register Option+J for Fixes."
            )
        )

        #expect(dictation.statusText == "Global hotkey active.")
        #expect(
            dictation.shortcutText
                == GlobalHotkeyConfiguration.defaultDictation.displayText
        )
        #expect(fixes.shortcutText == "⌥J")
        #expect(fixes.statusText == "Fixes shortcut unavailable.")
        #expect(
            fixes.detailText
                == "Could not register Option+J for Fixes. Use Fixes… in the menu."
        )
    }

    @Test func dictationFailureDoesNotChangeRegisteredFixesStatus() {
        let dictation = HotkeySettingsPresentation(
            status: .unavailable(message: "Dictation unavailable.")
        )
        let fixes = HotkeySettingsPresentation(fixesStatus: .registered)

        #expect(dictation.statusText == "Global hotkey unavailable.")
        #expect(fixes.shortcutText == "⌥J")
        #expect(fixes.statusText == "Fixes shortcut active.")
        #expect(
            fixes.detailText
                == "Press the shortcut to open Fixes for the current text field."
        )
    }

    @Test func fixesNotRegisteredHasItsOwnInactiveState() {
        let fixes = HotkeySettingsPresentation(
            fixesStatus: .notRegistered
        )

        #expect(fixes.shortcutText == "⌥J")
        #expect(fixes.statusText == "Fixes shortcut not active.")
        #expect(
            fixes.detailText
                == "Use Fixes… in the menu until the shortcut is available."
        )
    }
}
