import Foundation

@MainActor
protocol FixesRecentUseStoring: AnyObject {
    func recentActionIDs() -> [String]
    func recordSuccessfulUse(of actionID: String)
}

@MainActor
final class FixesRecentUseStore: FixesRecentUseStoring {
    nonisolated static let defaultStorageKey = "holdtype.fixes.recent-use"
    nonisolated static let maximumStoredActions = 100

    private let userDefaults: UserDefaults
    private let storageKey: String
    private let now: () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = FixesRecentUseStore.defaultStorageKey,
        now: @escaping () -> Date = Date.init,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        self.now = now
        self.encoder = encoder
        self.decoder = decoder
    }

    func recentActionIDs() -> [String] {
        var seenActionIDs: Set<String> = []
        return records()
            .sorted { $0.lastUsedAt > $1.lastUsedAt }
            .compactMap { record in
                guard seenActionIDs.insert(record.actionID).inserted else {
                    return nil
                }
                return record.actionID
            }
    }

    func recordSuccessfulUse(of actionID: String) {
        var updatedRecords = records()
        updatedRecords.removeAll { $0.actionID == actionID }
        updatedRecords.append(
            FixesRecentUseRecord(actionID: actionID, lastUsedAt: now())
        )
        updatedRecords.sort { $0.lastUsedAt > $1.lastUsedAt }
        updatedRecords = Array(
            updatedRecords.prefix(Self.maximumStoredActions)
        )

        guard let data = try? encoder.encode(updatedRecords) else {
            return
        }
        userDefaults.set(data, forKey: storageKey)
    }

    private func records() -> [FixesRecentUseRecord] {
        guard let data = userDefaults.data(forKey: storageKey),
              let records = try? decoder.decode(
                  [FixesRecentUseRecord].self,
                  from: data
              )
        else {
            return []
        }
        return records
    }
}

private struct FixesRecentUseRecord: Codable, Equatable {
    let actionID: String
    let lastUsedAt: Date
}
