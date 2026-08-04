import Foundation
import Testing
@testable import HoldType

@MainActor
struct FixesRecentUseStoreTests {
    @Test func recordsSuccessfulActionsMostRecentFirst() {
        let (userDefaults, suiteName) = makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        var dates = [
            Date(timeIntervalSince1970: 10),
            Date(timeIntervalSince1970: 20),
            Date(timeIntervalSince1970: 30),
        ]
        let store = FixesRecentUseStore(
            userDefaults: userDefaults,
            now: { dates.removeFirst() }
        )

        store.recordSuccessfulUse(of: "default.fix")
        store.recordSuccessfulUse(of: "default.summarize")
        store.recordSuccessfulUse(of: "default.fix")

        #expect(store.recentActionIDs() == ["default.fix", "default.summarize"])
    }

    @Test func corruptStoredDataDoesNotProduceRecentActions() {
        let (userDefaults, suiteName) = makeIsolatedUserDefaults()
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        userDefaults.set(
            Data("not recent use records".utf8),
            forKey: FixesRecentUseStore.defaultStorageKey
        )
        let store = FixesRecentUseStore(userDefaults: userDefaults)

        #expect(store.recentActionIDs().isEmpty)
    }
}
