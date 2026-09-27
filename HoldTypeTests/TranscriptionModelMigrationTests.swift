import Foundation
import Testing
@testable import HoldType

struct TranscriptionModelMigrationTests {
    @Test(arguments: ["gpt-4o-transcribe", "  gpt-4o-transcribe\n"])
    func migratesOldStandardOnce(saved: String) throws {
        try withDefaults { defaults in
            defaults.set(saved, forKey: "holdtype.settings.transcriptionModel")
            defaults.set("ru", forKey: "holdtype.settings.customLanguageCode")
            let store = AppSettingsStore(userDefaults: defaults)
            #expect(store.load().transcriptionModel == "gpt-transcribe")
            #expect(defaults.string(forKey: "holdtype.settings.transcriptionModel") == "gpt-transcribe")
            #expect(defaults.string(forKey: "holdtype.settings.customLanguageCode") == "ru")
            defaults.set("gpt-4o-transcribe", forKey: "holdtype.settings.transcriptionModel")
            #expect(store.load().transcriptionModel == "gpt-4o-transcribe")
        }
    }

    @Test(arguments: ["gpt-transcribe", "custom-model", "gpt-4o-mini-transcribe", "", "  "])
    func preservesOtherChoices(saved: String) throws {
        try withDefaults { defaults in
            defaults.set(saved, forKey: "holdtype.settings.transcriptionModel")
            #expect(AppSettingsStore(userDefaults: defaults).load().transcriptionModel == saved)
            #expect(AppSettingsStore(userDefaults: defaults).load().transcriptionModel == saved)
        }
    }

    @Test func freshInstallUsesCurrentDefault() throws {
        try withDefaults { defaults in
            #expect(AppSettingsStore(userDefaults: defaults).load().transcriptionModel == "gpt-transcribe")
        }
    }

    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "holdtype.migration-tests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }
}
