import Foundation
import Testing
@testable import HoldType

struct AppSettingsDockPresenceTests {
    @Test func dockPresenceIsHiddenByDefault() {
        #expect(AppSettings.defaults.showInDock == false)

        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        #expect(AppSettingsStore(userDefaults: defaults).load().showInDock == false)
    }

    @Test func dockPresencePersistsBothUserChoices() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        var settings = AppSettings.defaults

        settings.showInDock = true
        store.save(settings)
        #expect(store.load().showInDock)

        settings.showInDock = false
        store.save(settings)
        #expect(store.load().showInDock == false)
    }

    @Test func invalidPersistedDockPresenceFallsBackWithoutRewritingIt() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = AppSettingsStore.keyPrefix + "showInDock"
        defaults.set("not-a-bool", forKey: key)

        #expect(AppSettingsStore(userDefaults: defaults).load().showInDock == false)
        #expect(defaults.string(forKey: key) == "not-a-bool")
    }
}
