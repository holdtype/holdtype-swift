import Foundation
import Testing
@testable import HoldType

struct AppSettingsTextFixesConsentTests {
    @Test func defaultsDoNotImplyTextFixesConsent() {
        let settings = AppSettings.defaults

        #expect(settings.textFixesConsentVersion == 0)
        #expect(!settings.hasCurrentTextFixesConsent)
    }

    @Test func consentIsVersionedAndFailsClosed() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        let key = AppSettingsStore.keyPrefix + "textFixesConsentVersion"
        var settings = AppSettings.defaults

        settings.setTextFixesConsentAccepted(true)
        store.save(settings)

        #expect(
            defaults.integer(forKey: key)
                == AppSettings.currentTextFixesConsentVersion
        )
        #expect(store.load().hasCurrentTextFixesConsent)

        defaults.set(
            AppSettings.currentTextFixesConsentVersion + 1,
            forKey: key
        )
        #expect(!store.load().hasCurrentTextFixesConsent)

        defaults.set(true, forKey: key)
        #expect(store.load().textFixesConsentVersion == 0)
        #expect(!store.load().hasCurrentTextFixesConsent)

        defaults.set(1.9, forKey: key)
        #expect(store.load().textFixesConsentVersion == 0)
        #expect(!store.load().hasCurrentTextFixesConsent)

        settings.setTextFixesConsentAccepted(false)
        store.save(settings)
        #expect(defaults.integer(forKey: key) == 0)
        #expect(!store.load().hasCurrentTextFixesConsent)
    }
}
