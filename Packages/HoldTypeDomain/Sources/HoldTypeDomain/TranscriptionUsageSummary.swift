import Foundation

/// One local-calendar day in a transcription usage estimate window.
public struct TranscriptionUsageDailyBucket: Equatable, Identifiable, Sendable {
    public let day: Date
    public let durationSeconds: TimeInterval
    public let estimatedCostUSD: Double
    public let unpricedDurationSeconds: TimeInterval

    public var id: Date {
        day
    }

    public var minutes: Double {
        durationSeconds / 60
    }

    public var hasUnpricedUsage: Bool {
        unpricedDurationSeconds > 0
    }
}

/// A portable local-calendar summary of accepted audio transcription usage.
public struct TranscriptionUsageSummary: Equatable, Sendable {
    public static let defaultWindowDays = 30

    public let generatedAt: Date
    public let windowDays: Int
    public let dailyBuckets: [TranscriptionUsageDailyBucket]
    public let totalDurationSeconds: TimeInterval
    public let totalEstimatedCostUSD: Double?
    public let todayDurationSeconds: TimeInterval
    public let todayEstimatedCostUSD: Double?
    public let averageDailyDurationSeconds: TimeInterval
    public let averageDailyCostUSD: Double?
    public let projected30DayCostUSD: Double?
    public let unpricedDurationSeconds: TimeInterval

    public var isEmpty: Bool {
        totalDurationSeconds == 0
    }

    public var hasUnpricedUsage: Bool {
        unpricedDurationSeconds > 0
    }

    public static func empty(
        now: Date = Date(),
        calendar: Calendar = .current,
        windowDays: Int = defaultWindowDays
    ) -> TranscriptionUsageSummary {
        make(events: [], now: now, calendar: calendar, windowDays: windowDays)
    }

    public static func make(
        events: [TranscriptionUsageEvent],
        now: Date = Date(),
        calendar: Calendar = .current,
        windowDays: Int = defaultWindowDays
    ) -> TranscriptionUsageSummary {
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
        let projectionDayCount = projectionDayCount(
            for: buckets,
            today: today,
            calendar: calendar
        )
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

        return TranscriptionUsageSummary(
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
        events: [TranscriptionUsageEvent],
        startDay: Date,
        windowDays: Int,
        calendar: Calendar
    ) -> [TranscriptionUsageDailyBucket] {
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

            return TranscriptionUsageDailyBucket(
                day: day,
                durationSeconds: durationByDay[day, default: 0],
                estimatedCostUSD: costByDay[day, default: 0],
                unpricedDurationSeconds: unpricedDurationByDay[day, default: 0]
            )
        }
    }

    private static func projectionDayCount(
        for buckets: [TranscriptionUsageDailyBucket],
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
