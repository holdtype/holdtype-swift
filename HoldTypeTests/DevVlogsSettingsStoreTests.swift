import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsSettingsStoreTests {
    @Test func defaultsToOffForAnEmptyPreferenceStore() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = DevVlogsSettingsStore(userDefaults: userDefaults)

        #expect(store.isEnabled == false)
        #expect(store.readiness == .off)
    }

    @Test func enablingPersistsSetupRequiredState() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = DevVlogsSettingsStore(userDefaults: userDefaults)
        store.setEnabled(true)

        #expect(store.isEnabled == true)
        #expect(store.readiness == .setupRequired)
        #expect(DevVlogsSettingsStore(userDefaults: userDefaults).isEnabled == true)
    }

    @Test func disablingReturnsToOffAndPersistsTheChange() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = DevVlogsSettingsStore(userDefaults: userDefaults)
        store.setEnabled(true)
        store.setEnabled(false)

        #expect(store.readiness == .off)
        #expect(DevVlogsSettingsStore(userDefaults: userDefaults).readiness == .off)
    }

    private func makeIsolatedUserDefaults() throws -> (UserDefaults, String) {
        let suiteName = "DevVlogsSettingsStoreTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return (userDefaults, suiteName)
    }
}
