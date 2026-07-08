//
//  OpenAIUsageEstimate.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import Foundation

struct OpenAIUsageEvent: Codable, Equatable, Identifiable {
    let id: UUID
    let timestamp: Date
    let model: String
    let durationSeconds: TimeInterval
    let priceUSDPerMinute: Double?
    let estimatedCostUSD: Double?
    let pricingSource: String?

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        model: String,
        durationSeconds: TimeInterval,
        priceUSDPerMinute: Double?,
        estimatedCostUSD: Double?,
        pricingSource: String?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.durationSeconds = max(0, durationSeconds)
        self.priceUSDPerMinute = priceUSDPerMinute
        self.estimatedCostUSD = estimatedCostUSD
        self.pricingSource = pricingSource
    }
}

struct OpenAIUsagePricing: Equatable {
    static let current = OpenAIUsagePricing(
        ratesUSDPerMinute: [
            "gpt-4o-transcribe": 0.006,
            "gpt-4o-mini-transcribe": 0.003,
        ],
        sourceLabel: "OpenAI pricing reviewed 2026-06-22"
    )

    let ratesUSDPerMinute: [String: Double]
    let sourceLabel: String

    func rateUSDPerMinute(for model: String) -> Double? {
        ratesUSDPerMinute[Self.normalizedModel(model)]
    }

    func makeEvent(
        timestamp: Date = Date(),
        model: String,
        durationSeconds: TimeInterval,
        id: UUID = UUID()
    ) -> OpenAIUsageEvent {
        let normalizedModel = Self.normalizedModel(model)
        let durationSeconds = max(0, durationSeconds)
        let rate = rateUSDPerMinute(for: normalizedModel)
        let cost = rate.map { durationSeconds / 60 * $0 }

        return OpenAIUsageEvent(
            id: id,
            timestamp: timestamp,
            model: normalizedModel,
            durationSeconds: durationSeconds,
            priceUSDPerMinute: rate,
            estimatedCostUSD: cost,
            pricingSource: rate == nil ? nil : sourceLabel
        )
    }

    private static func normalizedModel(_ model: String) -> String {
        model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct OpenAIUsageDailyBucket: Equatable, Identifiable {
    let day: Date
    let durationSeconds: TimeInterval
    let estimatedCostUSD: Double
    let unpricedDurationSeconds: TimeInterval

    var id: Date {
        day
    }

    var minutes: Double {
        durationSeconds / 60
    }

    var hasUnpricedUsage: Bool {
        unpricedDurationSeconds > 0
    }
}

struct OpenAIUsageSummary: Equatable {
    static let defaultWindowDays = 30

    let generatedAt: Date
    let windowDays: Int
    let dailyBuckets: [OpenAIUsageDailyBucket]
    let totalDurationSeconds: TimeInterval
    let totalEstimatedCostUSD: Double?
    let todayDurationSeconds: TimeInterval
    let todayEstimatedCostUSD: Double?
    let averageDailyDurationSeconds: TimeInterval
    let averageDailyCostUSD: Double?
    let projected30DayCostUSD: Double?
    let unpricedDurationSeconds: TimeInterval

    var isEmpty: Bool {
        totalDurationSeconds == 0
    }

    var hasUnpricedUsage: Bool {
        unpricedDurationSeconds > 0
    }

    static func empty(
        now: Date = Date(),
        calendar: Calendar = .current,
        windowDays: Int = defaultWindowDays
    ) -> OpenAIUsageSummary {
        make(events: [], now: now, calendar: calendar, windowDays: windowDays)
    }

    static func make(
        events: [OpenAIUsageEvent],
        now: Date = Date(),
        calendar: Calendar = .current,
        windowDays: Int = defaultWindowDays
    ) -> OpenAIUsageSummary {
        let safeWindowDays = max(1, windowDays)
        let today = calendar.startOfDay(for: now)
        let startDay = calendar.date(
            byAdding: .day,
            value: -(safeWindowDays - 1),
            to: today
        ) ?? today
        let endDate = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let windowEvents = events.filter { event in
            event.timestamp >= startDay && event.timestamp < endDate
        }

        let buckets = makeDailyBuckets(
            events: windowEvents,
            startDay: startDay,
            windowDays: safeWindowDays,
            calendar: calendar
        )

        let totalDuration = buckets.reduce(0) { $0 + $1.durationSeconds }
        let totalKnownCost = buckets.reduce(0) { $0 + $1.estimatedCostUSD }
        let unpricedDuration = buckets.reduce(0) { $0 + $1.unpricedDurationSeconds }
        let todayBucket = buckets.last
        let projectionDayCount = projectionDayCount(for: buckets, today: today, calendar: calendar)
        let hasKnownCostUsage = windowEvents.contains { $0.estimatedCostUSD != nil }
        let totalCost = totalDuration == 0 || hasKnownCostUsage ? totalKnownCost : nil
        let todayCost = todayBucket.map { bucket in
            costValue(
                durationSeconds: bucket.durationSeconds,
                knownCostUSD: bucket.estimatedCostUSD,
                unpricedDurationSeconds: bucket.unpricedDurationSeconds
            )
        } ?? 0
        let averageCost = totalCost.map { $0 / Double(projectionDayCount) }

        return OpenAIUsageSummary(
            generatedAt: now,
            windowDays: safeWindowDays,
            dailyBuckets: buckets,
            totalDurationSeconds: totalDuration,
            totalEstimatedCostUSD: totalCost,
            todayDurationSeconds: todayBucket?.durationSeconds ?? 0,
            todayEstimatedCostUSD: todayCost,
            averageDailyDurationSeconds: totalDuration / Double(projectionDayCount),
            averageDailyCostUSD: averageCost,
            projected30DayCostUSD: averageCost.map { $0 * 30 },
            unpricedDurationSeconds: unpricedDuration
        )
    }

    private static func costValue(
        durationSeconds: TimeInterval,
        knownCostUSD: Double,
        unpricedDurationSeconds: TimeInterval
    ) -> Double? {
        if durationSeconds == 0 {
            return 0
        }

        if knownCostUSD > 0 {
            return knownCostUSD
        }

        if unpricedDurationSeconds > 0 {
            return nil
        }

        return 0
    }

    private static func makeDailyBuckets(
        events: [OpenAIUsageEvent],
        startDay: Date,
        windowDays: Int,
        calendar: Calendar
    ) -> [OpenAIUsageDailyBucket] {
        var durationByDay: [Date: TimeInterval] = [:]
        var costByDay: [Date: Double] = [:]
        var unpricedDurationByDay: [Date: TimeInterval] = [:]

        for event in events {
            let day = calendar.startOfDay(for: event.timestamp)
            durationByDay[day, default: 0] += event.durationSeconds

            if let estimatedCostUSD = event.estimatedCostUSD {
                costByDay[day, default: 0] += estimatedCostUSD
            } else {
                unpricedDurationByDay[day, default: 0] += event.durationSeconds
            }
        }

        return (0..<windowDays).map { offset in
            let day = calendar.date(byAdding: .day, value: offset, to: startDay) ?? startDay

            return OpenAIUsageDailyBucket(
                day: day,
                durationSeconds: durationByDay[day, default: 0],
                estimatedCostUSD: costByDay[day, default: 0],
                unpricedDurationSeconds: unpricedDurationByDay[day, default: 0]
            )
        }
    }

    private static func projectionDayCount(
        for buckets: [OpenAIUsageDailyBucket],
        today: Date,
        calendar: Calendar
    ) -> Int {
        guard let firstUsageDay = buckets.first(where: { $0.durationSeconds > 0 })?.day else {
            return max(1, buckets.count)
        }

        let elapsedDays = calendar.dateComponents([.day], from: firstUsageDay, to: today).day ?? 0
        return max(1, elapsedDays + 1)
    }
}
