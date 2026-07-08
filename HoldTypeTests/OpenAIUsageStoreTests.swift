//
//  OpenAIUsageStoreTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/22/26.
//

import Foundation
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
        let olderEvent = OpenAIUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 21, hour: 10),
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        let newerEvent = OpenAIUsagePricing.current.makeEvent(
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
        let retainedEvent = OpenAIUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 21, hour: 10),
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        let prunedEvent = OpenAIUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 19, hour: 10),
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )

        try store.append(retainedEvent)
        try store.append(prunedEvent)

        #expect(store.entries.map(\.id) == [retainedEvent.id])
    }

    @Test func recordCompletedTranscriptionUsesResolvedModelAndCurrentPricing() {
        let persistence = FakeOpenAIUsagePersistence()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let store = OpenAIUsageStore(
            persistence: persistence,
            calendar: makeCalendar(),
            now: { now }
        )
        var settings = AppSettings.defaults
        settings.transcriptionModel = "gpt-4o-mini-transcribe"

        store.recordCompletedTranscription(settings: settings, audioDuration: 180)

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.model == "gpt-4o-mini-transcribe")
        #expect(store.entries.first?.durationSeconds == 180)
        #expect(isClose(store.entries.first?.estimatedCostUSD, 0.009))
    }

    @Test func clearRemovesUsageEstimateOnlyFromLocalStore() throws {
        let persistence = FakeOpenAIUsagePersistence()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let store = OpenAIUsageStore(
            persistence: persistence,
            calendar: makeCalendar(),
            now: { now }
        )
        let event = OpenAIUsagePricing.current.makeEvent(
            timestamp: now,
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        try store.append(event)

        try store.clear()

        #expect(store.entries.isEmpty)
        #expect(persistence.removedKeys == [OpenAIUsageStore.defaultStorageKey])
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
}

private final class FakeOpenAIUsagePersistence: OpenAIUsagePersistence {
    var savedData: Data?
    var removedKeys: [String] = []

    func loadData(forKey key: String) throws -> Data? {
        savedData
    }

    func saveData(_ data: Data, forKey key: String) throws {
        savedData = data
    }

    func removeData(forKey key: String) throws {
        removedKeys.append(key)
        savedData = nil
    }
}
