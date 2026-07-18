import Foundation
import HoldTypeDomain
import Testing

struct TranscriptionUsageSummaryTests {
    @Test func groupsRecentUsageAndProjectsKnownCostAcrossElapsedCalendarDays() throws {
        let calendar = makeCalendar(secondsFromGMT: 0)
        let now = try makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let pricing = TranscriptionUsagePricing.current
        let events = [
            try pricing.makeEvent(
                timestamp: makeDate(year: 2026, month: 6, day: 22, hour: 9),
                model: "gpt-4o-transcribe",
                durationSeconds: 600
            ),
            try pricing.makeEvent(
                timestamp: makeDate(year: 2026, month: 6, day: 21, hour: 9),
                model: "gpt-4o-mini-transcribe",
                durationSeconds: 300
            ),
            try pricing.makeEvent(
                timestamp: makeDate(year: 2026, month: 6, day: 22, hour: 10),
                model: "custom-model",
                durationSeconds: 120
            ),
        ]

        let summary = TranscriptionUsageSummary.make(
            events: events,
            now: now,
            calendar: calendar,
            windowDays: 30
        )

        #expect(summary.generatedAt == now)
        #expect(summary.dailyBuckets.count == 30)
        #expect(summary.todayDurationSeconds == 720)
        #expect(summary.totalDurationSeconds == 1_020)
        #expect(summary.unpricedDurationSeconds == 120)
        #expect(summary.hasUnpricedUsage)
        #expect(isClose(summary.totalEstimatedCostUSD, 0.075))
        #expect(isClose(summary.todayEstimatedCostUSD, 0.06))
        #expect(isClose(summary.averageDailyCostUSD, 0.0375))
        #expect(isClose(summary.projected30DayCostUSD, 1.125))
        #expect(summary.averageDailyDurationSeconds == 510)

        let todayBucket = try #require(summary.dailyBuckets.last)
        let expectedToday = try makeDate(year: 2026, month: 6, day: 22)
        #expect(todayBucket.id == expectedToday)
        #expect(todayBucket.durationSeconds == 720)
        #expect(todayBucket.minutes == 12)
        #expect(isClose(todayBucket.estimatedCostUSD, 0.06))
        #expect(todayBucket.unpricedDurationSeconds == 120)
        #expect(todayBucket.hasUnpricedUsage)

        let previousBucket = summary.dailyBuckets[summary.dailyBuckets.count - 2]
        let expectedPreviousDay = try makeDate(year: 2026, month: 6, day: 21)
        #expect(previousBucket.day == expectedPreviousDay)
        #expect(previousBucket.durationSeconds == 300)
        #expect(isClose(previousBucket.estimatedCostUSD, 0.015))
        #expect(previousBucket.unpricedDurationSeconds == 0)
        #expect(!previousBucket.hasUnpricedUsage)
    }

    @Test func leavesUnknownOnlyCostsUnavailableWhilePreservingMinutes() throws {
        let calendar = makeCalendar(secondsFromGMT: 0)
        let now = try makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let event = try TranscriptionUsagePricing.current.makeEvent(
            timestamp: now,
            model: "custom-model",
            durationSeconds: 300
        )

        let summary = TranscriptionUsageSummary.make(
            events: [event],
            now: now,
            calendar: calendar
        )

        #expect(summary.totalDurationSeconds == 300)
        #expect(summary.todayDurationSeconds == 300)
        #expect(summary.todayEstimatedCostUSD == nil)
        #expect(summary.totalEstimatedCostUSD == nil)
        #expect(summary.averageDailyCostUSD == nil)
        #expect(summary.projected30DayCostUSD == nil)
        #expect(summary.hasUnpricedUsage)
    }

    @Test func emptySummaryProvidesTheCompleteWindowAndClampsInvalidWindowLength() throws {
        let calendar = makeCalendar(secondsFromGMT: 0)
        let now = try makeDate(year: 2026, month: 6, day: 22, hour: 12)

        let defaultSummary = TranscriptionUsageSummary.empty(now: now, calendar: calendar)
        let clampedSummary = TranscriptionUsageSummary.empty(
            now: now,
            calendar: calendar,
            windowDays: 0
        )

        #expect(defaultSummary.isEmpty)
        #expect(defaultSummary.dailyBuckets.count == 30)
        #expect(defaultSummary.totalEstimatedCostUSD == 0)
        #expect(defaultSummary.projected30DayCostUSD == 0)
        #expect(defaultSummary.averageDailyDurationSeconds == 0)
        #expect(!defaultSummary.hasUnpricedUsage)
        #expect(clampedSummary.dailyBuckets.count == 1)
        let expectedToday = try makeDate(year: 2026, month: 6, day: 22)
        #expect(clampedSummary.dailyBuckets[0].day == expectedToday)
    }

    @Test func usesTheInjectedLocalCalendarForWindowAndDailyBuckets() throws {
        let calendar = makeCalendar(secondsFromGMT: 2 * 60 * 60)
        let now = try makeDate(year: 2026, month: 6, day: 22, hour: 0, minute: 30)
        let sameLocalDay = try TranscriptionUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 21, hour: 23, minute: 45),
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        let previousLocalDay = try TranscriptionUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 21, hour: 20),
            model: "gpt-4o-transcribe",
            durationSeconds: 120
        )

        let summary = TranscriptionUsageSummary.make(
            events: [sameLocalDay, previousLocalDay],
            now: now,
            calendar: calendar,
            windowDays: 2
        )

        #expect(summary.dailyBuckets.map(\.durationSeconds) == [120, 60])
        #expect(summary.todayDurationSeconds == 60)
        #expect(summary.totalDurationSeconds == 180)
        #expect(summary.averageDailyDurationSeconds == 90)
    }

    @Test func excludesEventsOutsideTheCalendarWindowWithoutMutatingInputValues() throws {
        let calendar = makeCalendar(secondsFromGMT: 0)
        let now = try makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let pricing = TranscriptionUsagePricing.current
        let oldestIncluded = try pricing.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 20),
            model: "gpt-4o-transcribe",
            durationSeconds: 60
        )
        let expired = try pricing.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 19, hour: 23),
            model: "gpt-4o-transcribe",
            durationSeconds: 120
        )
        let nextDay = try pricing.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 23),
            model: "gpt-4o-transcribe",
            durationSeconds: 180
        )
        let events = [nextDay, expired, oldestIncluded]

        let summary = TranscriptionUsageSummary.make(
            events: events,
            now: now,
            calendar: calendar,
            windowDays: 3
        )

        #expect(summary.dailyBuckets.map(\.durationSeconds) == [60, 0, 0])
        #expect(summary.totalDurationSeconds == 60)
        #expect(events == [nextDay, expired, oldestIncluded])
    }

    @Test func summaryAndBucketsArePortableRuntimeValuesRatherThanWireDTOs() throws {
        let calendar = makeCalendar(secondsFromGMT: 0)
        let summary = TranscriptionUsageSummary.empty(
            now: try makeDate(year: 2026, month: 6, day: 22),
            calendar: calendar
        )
        let bucket = try #require(summary.dailyBuckets.last)

        requireSendable(TranscriptionUsageSummary.self)
        requireSendable(TranscriptionUsageDailyBucket.self)
        #expect(summary == summary)
        #expect(bucket == bucket)
        #expect(((summary as Any) is any Encodable) == false)
        #expect(((summary as Any) is any Decodable) == false)
        #expect(((bucket as Any) is any Encodable) == false)
        #expect(((bucket as Any) is any Decodable) == false)
    }

    private func makeCalendar(secondsFromGMT: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: secondsFromGMT) ?? .gmt
        return calendar
    }

    private func makeDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0
    ) throws -> Date {
        var components = DateComponents()
        components.calendar = makeCalendar(secondsFromGMT: 0)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return try #require(components.date)
    }

    private func isClose(
        _ value: Double?,
        _ expected: Double,
        tolerance: Double = 0.000_001
    ) -> Bool {
        guard let value else {
            return false
        }

        return abs(value - expected) <= tolerance
    }

    private func isClose(
        _ value: Double,
        _ expected: Double,
        tolerance: Double = 0.000_001
    ) -> Bool {
        abs(value - expected) <= tolerance
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
