//
//  OpenAIUsageStoreTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/22/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct OpenAIUsageStoreTests {

    @Test func appendPersistsNewestFirstUsageEvents() throws {
        let persistence = FakeOpenAIUsagePersistence()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let store = OpenAIUsageStore(
            persistence: persistence,
            calendar: makeCalendar(),
            now: { now }
        )
        let olderEvent = try OpenAIUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 21, hour: 10),
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        let newerEvent = try OpenAIUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 22, hour: 10),
            model: "gpt-4o-mini-transcribe",
            durationSeconds: 120
        )

        try store.append(olderEvent)
        try store.append(newerEvent)

        #expect(store.entries.map(\.id) == [newerEvent.id, olderEvent.id])
        #expect(try store.load().map(\.id) == [newerEvent.id, olderEvent.id])
        #expect(persistence.savedData != nil)
    }

    @Test func appendPrunesEventsOutsideRetentionWindow() throws {
        let persistence = FakeOpenAIUsagePersistence()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let store = OpenAIUsageStore(
            persistence: persistence,
            retentionDays: 2,
            calendar: makeCalendar(),
            now: { now }
        )
        let retainedEvent = try OpenAIUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 21, hour: 10),
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        let prunedEvent = try OpenAIUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 19, hour: 10),
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )

        try store.append(retainedEvent)
        try store.append(prunedEvent)

        #expect(store.entries.map(\.id) == [retainedEvent.id])
    }

    @Test func recordSuccessfulTranscriptionUsageUsesCurrentPricingAndClock() throws {
        let persistence = FakeOpenAIUsagePersistence()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let store = OpenAIUsageStore(
            persistence: persistence,
            calendar: makeCalendar(),
            now: { now }
        )
        let transcriptionID = try #require(
            UUID(uuidString: "D92652ED-9594-4534-8AA7-F80AEEA89663")
        )
        let usage = try SuccessfulTranscriptionUsage(
            transcriptionID: transcriptionID,
            model: "gpt-4o-mini-transcribe",
            audioDuration: 180
        )

        store.recordSuccessfulTranscriptionUsage(usage)

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.id == transcriptionID)
        #expect(store.entries.first?.timestamp == now)
        #expect(store.entries.first?.model == "gpt-4o-mini-transcribe")
        #expect(store.entries.first?.durationSeconds == 180)
        #expect(isClose(store.entries.first?.estimatedCostUSD, 0.009))
    }

    @Test func repeatedTranscriptionIDKeepsTheFirstFrozenEvent() throws {
        let persistence = FakeOpenAIUsagePersistence()
        var now = makeDate(year: 2026, month: 6, day: 22, hour: 10)
        let store = OpenAIUsageStore(persistence: persistence, now: { now })
        let transcriptionID = try #require(
            UUID(uuidString: "C5133E89-5F95-485D-B7D9-6A20D93AE98A")
        )
        let firstUsage = try SuccessfulTranscriptionUsage(
            transcriptionID: transcriptionID,
            model: "gpt-4o-transcribe",
            audioDuration: 30
        )
        let conflictingReplay = try SuccessfulTranscriptionUsage(
            transcriptionID: transcriptionID,
            model: "gpt-4o-mini-transcribe",
            audioDuration: 90
        )

        store.recordSuccessfulTranscriptionUsage(firstUsage)
        now = makeDate(year: 2026, month: 6, day: 23, hour: 10)
        store.recordSuccessfulTranscriptionUsage(conflictingReplay)

        #expect(store.entries.map(\.id) == [transcriptionID])
        #expect(store.entries.first?.timestamp == makeDate(year: 2026, month: 6, day: 22, hour: 10))
        #expect(store.entries.first?.model == "gpt-4o-transcribe")
        #expect(store.entries.first?.durationSeconds == 30)
        #expect(store.entries.first?.priceUSDPerMinute == 0.006)
        #expect(persistence.saveCount == 1)
    }

    @Test func failedSaveRemainsVisibleWhenAnOlderIDIsReplayed() throws {
        let persistence = FakeOpenAIUsagePersistence()
        let store = OpenAIUsageStore(persistence: persistence)
        let firstUsage = try SuccessfulTranscriptionUsage(
            transcriptionID: try #require(UUID(uuidString: "511BB044-397E-49E4-B87A-0C7368C9AD34")),
            model: "gpt-4o-transcribe",
            audioDuration: 30
        )
        let failedUsage = try SuccessfulTranscriptionUsage(
            transcriptionID: try #require(UUID(uuidString: "DD5208C1-1B74-4A23-9681-3BBF41D4D72B")),
            model: "gpt-4o-mini-transcribe",
            audioDuration: 60
        )

        store.recordSuccessfulTranscriptionUsage(firstUsage)
        persistence.saveError = OpenAIUsagePersistenceTestError.saveFailed
        store.recordSuccessfulTranscriptionUsage(failedUsage)
        let failedMessage = store.storageErrorMessage
        persistence.saveError = nil

        store.recordSuccessfulTranscriptionUsage(firstUsage)

        #expect(store.entries.map(\.id) == [firstUsage.transcriptionID])
        #expect(failedMessage == "OpenAI usage estimate could not be saved.")
        #expect(store.storageErrorMessage == failedMessage)
        #expect(persistence.saveCount == 2)
    }

    @Test func clearRemovesUsageEstimateOnlyFromLocalStore() throws {
        let persistence = FakeOpenAIUsagePersistence()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let store = OpenAIUsageStore(
            persistence: persistence,
            calendar: makeCalendar(),
            now: { now }
        )
        let event = try OpenAIUsagePricing.current.makeEvent(
            timestamp: now,
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        try store.append(event)

        try store.clear()

        #expect(store.entries.isEmpty)
        #expect(persistence.removedKeys == [OpenAIUsageStore.defaultStorageKey])
    }

    @Test func legacyBareArrayLoadsAndResavesTheSameSevenKeys() throws {
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let identifier = try #require(
            UUID(uuidString: "71111111-1111-1111-1111-111111111111")
        )
        let persistence = FakeOpenAIUsagePersistence(
            savedData: try legacyData(rows: [[
                "id": identifier.uuidString,
                "timestamp": now.timeIntervalSinceReferenceDate,
                "model": "gpt-4o-transcribe",
                "durationSeconds": 60,
                "priceUSDPerMinute": 0.006,
                "estimatedCostUSD": 0.006,
                "pricingSource": "OpenAI pricing reviewed 2026-06-22",
            ]])
        )
        let store = OpenAIUsageStore(
            persistence: persistence,
            calendar: makeCalendar(),
            now: { now }
        )

        #expect(try store.load().map(\.id) == [identifier])
        try store.append(
            OpenAIUsagePricing.current.makeEvent(
                timestamp: now.addingTimeInterval(1),
                model: "custom-model",
                durationSeconds: 30
            )
        )

        let data = try #require(persistence.savedData)
        let rows = try #require(
            JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )
        let expectedKeys: Set<String> = [
            "id", "timestamp", "model", "durationSeconds",
            "priceUSDPerMinute", "estimatedCostUSD", "pricingSource",
        ]
        #expect(Set(try #require(rows.first).keys) == [
            "id", "timestamp", "model", "durationSeconds",
        ])
        #expect(Set(try #require(rows.last).keys) == expectedKeys)
    }

    @Test func legacyUnknownPriceMayOmitItsThreeOptionalKeys() throws {
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let identifier = try #require(
            UUID(uuidString: "72222222-2222-2222-2222-222222222222")
        )
        let persistence = FakeOpenAIUsagePersistence(
            savedData: try legacyData(rows: [[
                "id": identifier.uuidString,
                "timestamp": now.timeIntervalSinceReferenceDate,
                "model": "custom-model",
                "durationSeconds": 60,
            ]])
        )
        let store = OpenAIUsageStore(
            persistence: persistence,
            calendar: makeCalendar(),
            now: { now }
        )

        let event = try #require(try store.load().first)
        #expect(event.id == identifier)
        #expect(event.priceUSDPerMinute == nil)
        #expect(event.estimatedCostUSD == nil)
        #expect(event.pricingSource == nil)
    }

    @Test func invalidOrDuplicateLegacyRowsMapOnlyToUnreadableUsage() throws {
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let identifier = try #require(
            UUID(uuidString: "73333333-3333-3333-3333-333333333333")
        )
        let canonical: [String: Any] = [
            "id": identifier.uuidString,
            "timestamp": now.timeIntervalSinceReferenceDate,
            "model": "gpt-4o-transcribe",
            "durationSeconds": 60,
            "priceUSDPerMinute": 0.006,
            "estimatedCostUSD": 0.006,
            "pricingSource": "OpenAI pricing reviewed 2026-06-22",
        ]
        var invalidTimestamp = canonical
        invalidTimestamp["timestamp"] = "not-a-date"
        var invalidDuration = canonical
        invalidDuration["durationSeconds"] = 0
        var noncanonicalModel = canonical
        noncanonicalModel["model"] = " GPT-4O-Transcribe "
        var noncanonicalSource = canonical
        noncanonicalSource["pricingSource"] = " source "
        var incompleteSnapshot = canonical
        incompleteSnapshot.removeValue(forKey: "estimatedCostUSD")
        var inconsistentSnapshot = canonical
        inconsistentSnapshot["estimatedCostUSD"] = 1
        let fixtures = [
            [invalidTimestamp],
            [invalidDuration],
            [noncanonicalModel],
            [noncanonicalSource],
            [incompleteSnapshot],
            [inconsistentSnapshot],
            [canonical, canonical],
        ]

        for rows in fixtures {
            let source = try legacyData(rows: rows)
            let persistence = FakeOpenAIUsagePersistence(savedData: source)
            let store = OpenAIUsageStore(
                persistence: persistence,
                calendar: makeCalendar(),
                now: { now }
            )

            #expect(throws: OpenAIUsageStoreError.unreadableUsage) {
                _ = try store.load()
            }
            #expect(persistence.savedData == source)
        }
    }

    @Test func injectedLoadAndSaveFailuresKeepTheirExistingErrorMapping() throws {
        let persistence = FakeOpenAIUsagePersistence()
        persistence.loadError = OpenAIUsagePersistenceTestError.loadFailed
        let store = OpenAIUsageStore(persistence: persistence)
        #expect(throws: OpenAIUsageStoreError.loadFailed) {
            _ = try store.load()
        }

        persistence.loadError = nil
        persistence.saveError = OpenAIUsagePersistenceTestError.saveFailed
        let event = try OpenAIUsagePricing.current.makeEvent(
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        #expect(throws: OpenAIUsageStoreError.saveFailed) {
            _ = try store.append(event)
        }
    }

    private func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.calendar = makeCalendar()
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return components.date!
    }

    private func isClose(_ value: Double?, _ expected: Double, tolerance: Double = 0.000_001) -> Bool {
        guard let value else {
            return false
        }

        return abs(value - expected) <= tolerance
    }

    private func legacyData(rows: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: rows, options: [.sortedKeys])
    }
}

private final class FakeOpenAIUsagePersistence: OpenAIUsagePersistence {
    var savedData: Data?
    var removedKeys: [String] = []
    var saveCount = 0
    var loadError: (any Error)?
    var saveError: (any Error)?

    init(savedData: Data? = nil) {
        self.savedData = savedData
    }

    func loadData(forKey key: String) throws -> Data? {
        if let loadError {
            throw loadError
        }
        return savedData
    }

    func saveData(_ data: Data, forKey key: String) throws {
        saveCount += 1
        if let saveError {
            throw saveError
        }
        savedData = data
    }

    func removeData(forKey key: String) throws {
        removedKeys.append(key)
        savedData = nil
    }
}

private enum OpenAIUsagePersistenceTestError: Error {
    case loadFailed
    case saveFailed
}
