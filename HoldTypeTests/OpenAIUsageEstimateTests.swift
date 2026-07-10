//
//  OpenAIUsageEstimateTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/22/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct OpenAIUsageEstimateTests {

    @Test func pricingCalculatesKnownTranscriptionModelCosts() throws {
        let pricing = OpenAIUsagePricing.current
        let event = try pricing.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 22, hour: 10),
            model: " gpt-4o-transcribe ",
            durationSeconds: 120
        )

        #expect(event.model == "gpt-4o-transcribe")
        #expect(event.priceUSDPerMinute == 0.006)
        #expect(isClose(event.estimatedCostUSD, 0.012))
        #expect(event.pricingSource == "OpenAI pricing reviewed 2026-06-22")
    }

    @Test func pricingLeavesUnknownModelCostUnavailable() throws {
        let event = try OpenAIUsagePricing.current.makeEvent(
            timestamp: makeDate(year: 2026, month: 6, day: 22, hour: 10),
            model: "custom-model",
            durationSeconds: 180
        )

        #expect(event.priceUSDPerMinute == nil)
        #expect(event.estimatedCostUSD == nil)
        #expect(event.pricingSource == nil)
    }

    @Test func summaryGroupsRecentUsageAndProjectsKnownCost() throws {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let pricing = OpenAIUsagePricing.current
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

        let summary = OpenAIUsageSummary.make(
            events: events,
            now: now,
            calendar: calendar,
            windowDays: 30
        )

        #expect(summary.dailyBuckets.count == 30)
        #expect(summary.todayDurationSeconds == 720)
        #expect(summary.totalDurationSeconds == 1_020)
        #expect(summary.unpricedDurationSeconds == 120)
        #expect(summary.hasUnpricedUsage)
        #expect(isClose(summary.totalEstimatedCostUSD, 0.075))
        #expect(isClose(summary.averageDailyCostUSD, 0.0375))
        #expect(isClose(summary.projected30DayCostUSD, 1.125))
        #expect(summary.averageDailyDurationSeconds == 510)
    }

    @Test func summaryMarksUnknownOnlyCostAsUnavailable() throws {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)
        let event = try OpenAIUsagePricing.current.makeEvent(
            timestamp: now,
            model: "custom-model",
            durationSeconds: 300
        )

        let summary = OpenAIUsageSummary.make(events: [event], now: now, calendar: calendar)

        #expect(summary.totalDurationSeconds == 300)
        #expect(summary.todayEstimatedCostUSD == nil)
        #expect(summary.totalEstimatedCostUSD == nil)
        #expect(summary.averageDailyCostUSD == nil)
        #expect(summary.projected30DayCostUSD == nil)
        #expect(summary.hasUnpricedUsage)
    }

    @Test func emptySummaryStillProvidesThirtyChartBuckets() {
        let calendar = makeCalendar()
        let now = makeDate(year: 2026, month: 6, day: 22, hour: 12)

        let summary = OpenAIUsageSummary.empty(now: now, calendar: calendar)

        #expect(summary.isEmpty)
        #expect(summary.dailyBuckets.count == 30)
        #expect(summary.totalEstimatedCostUSD == 0)
        #expect(summary.projected30DayCostUSD == 0)
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
