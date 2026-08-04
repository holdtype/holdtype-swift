import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct OpenAIUsageStorePricingBackfillTests {
    @Test func loadingBackfillsOnlyEligibleGptTranscribeRecordsOnce() throws {
        let timestamp = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let eligibleID = try #require(UUID(uuidString: "D1B2B2F4-FF6C-4663-BDE2-511B1E48A21C"))
        let unknownID = try #require(UUID(uuidString: "3C564AA2-3A8C-4661-8D6D-A5F85D3E8A84"))
        let knownID = try #require(UUID(uuidString: "9F8779BB-D813-47D9-B1A7-7EDC302C9BEB"))
        let persistence = BackfillUsagePersistence(
            data: try encodedRows([
                [
                    "id": eligibleID.uuidString,
                    "timestamp": timestamp.timeIntervalSinceReferenceDate,
                    "model": "gpt-transcribe",
                    "durationSeconds": 60,
                ],
                [
                    "id": unknownID.uuidString,
                    "timestamp": timestamp.timeIntervalSinceReferenceDate,
                    "model": "custom-model",
                    "durationSeconds": 60,
                ],
                [
                    "id": knownID.uuidString,
                    "timestamp": timestamp.timeIntervalSinceReferenceDate,
                    "model": "gpt-transcribe",
                    "durationSeconds": 60,
                    "priceUSDPerMinute": 0.01,
                    "estimatedCostUSD": 0.01,
                    "pricingSource": "legacy reviewed price",
                ],
            ])
        )
        let store = OpenAIUsageStore(
            persistence: persistence,
            calendar: calendar(),
            now: { timestamp }
        )

        let entriesByID = Dictionary(uniqueKeysWithValues: store.entries.map { ($0.id, $0) })
        let backfilled = try #require(entriesByID[eligibleID])
        let unknown = try #require(entriesByID[unknownID])
        let known = try #require(entriesByID[knownID])

        #expect(backfilled.priceUSDPerMinute == 0.0045)
        #expect(backfilled.estimatedCostUSD == 0.0045)
        #expect(unknown.priceUSDPerMinute == nil)
        #expect(known.priceUSDPerMinute == 0.01)
        #expect(persistence.saveCount == 1)

        _ = try store.load()

        #expect(persistence.saveCount == 1)
    }

    private func calendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func encodedRows(_ rows: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
    }
}

private final class BackfillUsagePersistence: OpenAIUsagePersistence {
    var data: Data?
    var saveCount = 0

    init(data: Data?) {
        self.data = data
    }

    func loadData(forKey key: String) throws -> Data? {
        data
    }

    func saveData(_ data: Data, forKey key: String) throws {
        saveCount += 1
        self.data = data
    }

    func removeData(forKey key: String) throws {
        data = nil
    }
}
