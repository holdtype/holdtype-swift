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

    @Test func preferredCameraPersistsWithItsIdentityAndDisplayName() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let camera = DevVlogsCamera(id: "camera-id", label: "Desk Camera")
        let store = DevVlogsSettingsStore(userDefaults: userDefaults)
        store.setPreferredCamera(camera)

        let reloadedStore = DevVlogsSettingsStore(userDefaults: userDefaults)
        #expect(reloadedStore.preferredCamera == camera)
        #expect(reloadedStore.readiness == .off)
    }

    @Test func disconnectedPreferredCameraRemainsRememberedWithoutFallback() {
        let preferredCamera = DevVlogsCamera(id: "remembered", label: "Desk Camera")
        let store = DevVlogsSettingsStore(isEnabled: true, preferredCamera: preferredCamera)
        let otherAvailableCamera = DevVlogsCamera(id: "other", label: "External Camera")

        #expect(store.preferredCamera == preferredCamera)
        #expect(store.preferredCamera != otherAvailableCamera)
        #expect(store.readiness == .setupRequired)
    }

    private func makeIsolatedUserDefaults() throws -> (UserDefaults, String) {
        let suiteName = "DevVlogsSettingsStoreTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return (userDefaults, suiteName)
    }
}
