import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct AppSettingsRetentionTests {
    @Test func loadsRecordingCachePolicyModesAndNormalizesCount() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        var settings = AppSettings.defaults
        settings.recordingCachePolicy = .unlimited

        store.save(settings)
        #expect(store.load().recordingCachePolicy == .unlimited)

        defaults.set("keepLast", forKey: AppSettingsStore.keyPrefix + "recordingCachePolicyMode")
        defaults.set(0, forKey: AppSettingsStore.keyPrefix + "recordingCacheRetainedRecordingLimit")

        #expect(store.load().recordingCachePolicy == .keepLast(1))
    }

    @Test func projectsRawRetentionConfigurationWithoutOwningPersistence() {
        var settings = AppSettings.defaults
        settings.saveTranscriptHistory = false
        settings.recordingCachePolicy = .keepLast(0)

        let configuration = settings.retentionConfiguration

        #expect(configuration.historyEnabled == false)
        #expect(configuration.recordingCachePolicy == .keepLast(0))
        #expect(configuration.recordingCachePolicy.normalized == .keepLast(1))
    }

    @Test func recordingCachePolicyPersistenceKeepsTheLegacyTwoKeySchema() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let modeKey = AppSettingsStore.keyPrefix + "recordingCachePolicyMode"
        let countKey = AppSettingsStore.keyPrefix + "recordingCacheRetainedRecordingLimit"
        let store = AppSettingsStore(userDefaults: defaults)

        defaults.set(42, forKey: countKey)
        #expect(store.load().recordingCachePolicy == .deleteImmediately)
        #expect(defaults.integer(forKey: countKey) == 42)

        defaults.set("unknown-mode", forKey: modeKey)
        #expect(store.load().recordingCachePolicy == .deleteImmediately)
        #expect(defaults.string(forKey: modeKey) == "unknown-mode")
        #expect(defaults.integer(forKey: countKey) == 42)

        defaults.set("keepLast", forKey: modeKey)
        defaults.set("not-an-int", forKey: countKey)
        #expect(
            store.load().recordingCachePolicy ==
                .keepLast(RecordingCachePolicy.defaultRetainedRecordingLimit)
        )
        #expect(defaults.string(forKey: countKey) == "not-an-int")

        defaults.set(Int.min, forKey: countKey)
        #expect(store.load().recordingCachePolicy == .keepLast(1))
        #expect(defaults.object(forKey: countKey) as? Int == Int.min)

        defaults.set(Int.max, forKey: countKey)
        #expect(store.load().recordingCachePolicy == .keepLast(999))
        #expect(defaults.object(forKey: countKey) as? Int == Int.max)

        var settings = AppSettings.defaults
        settings.recordingCachePolicy = .keepLast(1_000)
        store.save(settings)
        #expect(defaults.string(forKey: modeKey) == "keepLast")
        #expect(defaults.integer(forKey: countKey) == 999)

        settings.recordingCachePolicy = .unlimited
        store.save(settings)
        #expect(defaults.string(forKey: modeKey) == "unlimited")
        #expect(defaults.object(forKey: countKey) == nil)

        defaults.set(77, forKey: countKey)
        settings.recordingCachePolicy = .deleteImmediately
        store.save(settings)
        #expect(defaults.string(forKey: modeKey) == "deleteImmediately")
        #expect(defaults.object(forKey: countKey) == nil)
    }

    @Test func transcriptHistoryDefaultMigrationPreservesEveryLegacyState() {
        let historyKey = AppSettingsStore.keyPrefix + "saveTranscriptHistory"
        let markerKey = "holdtype.migrations.transcriptHistoryDefaultEnabled"

        func makeStore(savedValue: Bool?, markerValue: Bool?) -> (
            UserDefaults,
            String,
            AppSettingsStore
        ) {
            let (defaults, suiteName) = makeIsolatedUserDefaults()
            if let savedValue {
                defaults.set(savedValue, forKey: historyKey)
            }
            if let markerValue {
                defaults.set(markerValue, forKey: markerKey)
            }
            return (defaults, suiteName, AppSettingsStore(userDefaults: defaults))
        }

        var fixtures: [(UserDefaults, String)] = []
        defer {
            for (defaults, suiteName) in fixtures {
                defaults.removePersistentDomain(forName: suiteName)
            }
        }

        let missing = makeStore(savedValue: nil, markerValue: nil)
        fixtures.append((missing.0, missing.1))
        #expect(missing.2.load().saveTranscriptHistory)
        #expect(missing.0.bool(forKey: markerKey))
        #expect(missing.0.object(forKey: historyKey) == nil)

        let enabled = makeStore(savedValue: true, markerValue: nil)
        fixtures.append((enabled.0, enabled.1))
        #expect(enabled.2.load().saveTranscriptHistory)
        #expect(enabled.0.bool(forKey: markerKey))
        #expect(enabled.0.bool(forKey: historyKey))

        let legacyDisabled = makeStore(savedValue: false, markerValue: nil)
        fixtures.append((legacyDisabled.0, legacyDisabled.1))
        #expect(legacyDisabled.2.load().saveTranscriptHistory)
        #expect(legacyDisabled.0.bool(forKey: markerKey))
        #expect(legacyDisabled.0.bool(forKey: historyKey))

        let explicitDisabled = makeStore(savedValue: false, markerValue: true)
        fixtures.append((explicitDisabled.0, explicitDisabled.1))
        #expect(explicitDisabled.2.load().saveTranscriptHistory == false)
        #expect(explicitDisabled.0.bool(forKey: markerKey))
        #expect(explicitDisabled.0.bool(forKey: historyKey) == false)

        let migratedMissing = makeStore(savedValue: nil, markerValue: true)
        fixtures.append((migratedMissing.0, migratedMissing.1))
        #expect(migratedMissing.2.load().saveTranscriptHistory)
        #expect(migratedMissing.0.object(forKey: historyKey) == nil)
    }
}
