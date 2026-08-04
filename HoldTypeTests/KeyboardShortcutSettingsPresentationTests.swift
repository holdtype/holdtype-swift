import Foundation
import Testing
@testable import HoldType

struct KeyboardShortcutSettingsPresentationTests {
    @Test func shortcutConfigurationContainsAllEditableActions() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let configuration = ShortcutConfiguration.defaults
        let store = ShortcutConfigurationStore(userDefaults: defaults)

        #expect(store.load() == configuration)
        #expect(defaults.data(forKey: ShortcutConfigurationStore.key) != nil)
        #expect(configuration[.dictation] == .defaultDictation)
        #expect(configuration[.translation] == .translationDictation)
        #expect(configuration[.fixes] == .fixesPalette)
        #expect(configuration[.pasteLastResult] == .appClipboardPaste)
    }

    @Test func duplicateAssignmentsAreRejectedBeforePersistence() throws {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var configuration = ShortcutConfiguration.defaults
        configuration.fixes = configuration.dictation
        let store = ShortcutConfigurationStore(userDefaults: defaults)

        #expect(throws: ShortcutConfigurationError.duplicate(.dictation)) {
            try store.save(configuration)
        }
        #expect(store.load() == .defaults)
    }

    @Test func customAssignmentsPersistAndRoundTrip() throws {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        var configuration = ShortcutConfiguration.defaults
        configuration.dictation = GlobalHotkeyShortcut(
            modifiers: [.control, .option],
            key: "D",
            keyCode: 2
        )
        let store = ShortcutConfigurationStore(userDefaults: defaults)

        try store.save(configuration)

        #expect(store.load() == configuration)
    }
}
