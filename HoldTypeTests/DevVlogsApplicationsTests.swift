import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsApplicationsTests {
    @Test func selectedAppsIsTheSafeDefaultAndNeedsAnEntryToBeEffective() {
        let policy = DevVlogsApplicationPolicy.defaultPolicy

        #expect(policy.mode == .onlySelectedApps)
        #expect(policy.selectedApps.isEmpty)
        #expect(policy.excludedApps.isEmpty)
        #expect(policy.hasEffectiveEligibility == false)
    }

    @Test func allAppsPolicyIsEffectiveWithoutExclusions() {
        let policy = DevVlogsApplicationPolicy(
            mode: .allAppsExceptExcludedApps,
            selectedApps: [],
            excludedApps: []
        )

        #expect(policy.hasEffectiveEligibility == true)
        #expect(policy.activeApplications.isEmpty)
    }

    @Test func policyUsesBundleIdentifiersForDuplicateAndRemovalIdentity() throws {
        var policy = DevVlogsApplicationPolicy.defaultPolicy
        let firstSnapshot = try application("com.apple.dt.Xcode", "Xcode")
        let renamedSnapshot = try application("com.apple.dt.Xcode", "Xcode Beta")

        try policy.add(firstSnapshot)
        #expect(throws: DevVlogsApplicationPolicyError.duplicateBundleIdentifier) {
            try policy.add(renamedSnapshot)
        }

        policy.remove(bundleIdentifier: renamedSnapshot.bundleIdentifier)
        #expect(policy.selectedApps.isEmpty)
    }

    @Test func switchingPoliciesKeepsBothListsAndReturnsToTheSaferModeImmediately() throws {
        let selected = try application("com.apple.dt.Xcode", "Xcode")
        let excluded = try application("com.apple.Notes", "Notes")
        var policy = DevVlogsApplicationPolicy(
            mode: .onlySelectedApps,
            selectedApps: [selected],
            excludedApps: []
        )

        policy.setMode(.allAppsExceptExcludedApps)
        try policy.add(excluded)
        policy.setMode(.onlySelectedApps)

        #expect(policy.activeApplications == [selected])
        #expect(policy.selectedApps == [selected])
        #expect(policy.excludedApps == [excluded])
    }

    @Test func disabledFeatureCannotMutateApplicationPolicy() throws {
        let store = DevVlogsSettingsStore(isEnabled: false)

        #expect(throws: DevVlogsApplicationPolicyError.featureDisabled) {
            try store.addApplication(application("com.apple.dt.Xcode", "Xcode"))
        }
        #expect(store.applicationPolicy == .defaultPolicy)
    }

    @Test func applicationPolicyPersistsBothListsAndMode() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }

        let store = DevVlogsSettingsStore(userDefaults: userDefaults)
        store.setEnabled(true)
        try store.addApplication(application("com.apple.dt.Xcode", "Xcode"))
        try store.confirmAllAppsExceptExcludedApps()
        try store.addApplication(application("com.apple.Notes", "Notes"))

        let reloadedStore = DevVlogsSettingsStore(userDefaults: userDefaults)
        #expect(reloadedStore.applicationPolicy.mode == .allAppsExceptExcludedApps)
        #expect(reloadedStore.applicationPolicy.selectedApps.map(\.bundleIdentifier) == ["com.apple.dt.Xcode"])
        #expect(reloadedStore.applicationPolicy.excludedApps.map(\.bundleIdentifier) == ["com.apple.Notes"])
        #expect(reloadedStore.applicationPolicy.hasEffectiveEligibility == true)
    }

    @Test func corruptPolicyUsesSafeFallbackWithoutOverwritingStoredBytes() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let corruptData = Data("not a Dev Vlogs policy".utf8)
        userDefaults.set(corruptData, forKey: DevVlogsSettingsStore.applicationPolicyStorageKey)

        let store = DevVlogsSettingsStore(userDefaults: userDefaults)

        #expect(store.applicationPolicy == .defaultPolicy)
        #expect(store.applicationPolicyLoadMessage?.contains("preserved") == true)
        #expect(userDefaults.data(forKey: DevVlogsSettingsStore.applicationPolicyStorageKey) == corruptData)
    }

    @Test func unknownSchemaUsesSafeFallbackWithoutOverwritingStoredBytes() throws {
        let (userDefaults, suiteName) = try makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let unsupportedData = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 2,
            "mode": "allAppsExceptExcludedApps",
            "selectedApps": [],
            "excludedApps": []
        ])
        userDefaults.set(unsupportedData, forKey: DevVlogsSettingsStore.applicationPolicyStorageKey)

        let store = DevVlogsSettingsStore(userDefaults: userDefaults)

        #expect(store.applicationPolicy == .defaultPolicy)
        #expect(store.applicationPolicyLoadMessage?.contains("preserved") == true)
        #expect(userDefaults.data(forKey: DevVlogsSettingsStore.applicationPolicyStorageKey) == unsupportedData)
    }

    @Test func resolverAcceptsAnApplicationBundleWithAnExecutable() throws {
        let applicationURL = try makeTemporaryApplicationBundle(bundleIdentifier: "com.example.DevVlogsTest")
        defer { try? FileManager.default.removeItem(at: applicationURL.deletingLastPathComponent()) }

        let application = try #require(
            try? BundleDevVlogsApplicationResolver().resolveApplication(at: applicationURL).get()
        )

        #expect(application.bundleIdentifier == "com.example.DevVlogsTest")
        #expect(application.displayName == "DevVlogsTest")
    }

    @Test func resolverRejectsANonApplicationURL() {
        let result = BundleDevVlogsApplicationResolver().resolveApplication(
            at: URL(fileURLWithPath: "/tmp/DevVlogsApplicationsTests.txt")
        )

        #expect(result == .failure(.notAnApplicationBundle))
    }

    @Test func resolverRejectsAnApplicationBundleWithoutABundleIdentifier() throws {
        let applicationURL = try makeTemporaryApplicationBundle(bundleIdentifier: nil)
        defer { try? FileManager.default.removeItem(at: applicationURL.deletingLastPathComponent()) }

        let result = BundleDevVlogsApplicationResolver().resolveApplication(at: applicationURL)

        #expect(result == .failure(.missingBundleIdentifier))
    }

    @Test func resolverRejectsAnApplicationBundleWithoutAnExecutable() throws {
        let applicationURL = try makeTemporaryApplicationBundle(
            bundleIdentifier: "com.example.DevVlogsTest",
            includesExecutable: false
        )
        defer { try? FileManager.default.removeItem(at: applicationURL.deletingLastPathComponent()) }

        let result = BundleDevVlogsApplicationResolver().resolveApplication(at: applicationURL)

        #expect(result == .failure(.notAnApplicationBundle))
    }

    private func application(_ bundleIdentifier: String, _ displayName: String) throws -> DevVlogsApplication {
        try #require(DevVlogsApplication(bundleIdentifier: bundleIdentifier, displayName: displayName))
    }

    private func makeIsolatedUserDefaults() throws -> (UserDefaults, String) {
        let suiteName = "DevVlogsApplicationsTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        userDefaults.removePersistentDomain(forName: suiteName)
        return (userDefaults, suiteName)
    }

    private func makeTemporaryApplicationBundle(
        bundleIdentifier: String?,
        includesExecutable: Bool = true
    ) throws -> URL {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("DevVlogsApplicationsTests-\(UUID().uuidString)", isDirectory: true)
        let applicationURL = rootURL.appendingPathComponent("DevVlogsTest.app", isDirectory: true)
        let contentsURL = applicationURL.appendingPathComponent("Contents", isDirectory: true)
        let macOSURL = contentsURL.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOSURL, withIntermediateDirectories: true)

        var info: [String: Any] = [
            "CFBundlePackageType": "APPL",
            "CFBundleExecutable": "DevVlogsTestExecutable",
            "CFBundleName": "DevVlogsTest"
        ]
        if let bundleIdentifier {
            info["CFBundleIdentifier"] = bundleIdentifier
        }
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try infoData.write(to: contentsURL.appendingPathComponent("Info.plist"))

        if includesExecutable {
            let executableURL = macOSURL.appendingPathComponent("DevVlogsTestExecutable")
            try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executableURL)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: executableURL.path
            )
        }

        return applicationURL
    }
}
