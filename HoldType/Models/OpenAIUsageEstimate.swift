import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

typealias OpenAIUsagePricing = TranscriptionUsagePricing

enum OpenAIUsageCategory: String, Codable, CaseIterable, Identifiable, Sendable {
    case transcription
    case fixes
    case textCorrection
    case translation

    var id: Self { self }

    var title: String {
        switch self {
        case .transcription: return "Transcription"
        case .fixes: return "Fixes"
        case .textCorrection: return "Text Correction"
        case .translation: return "Translation"
        }
    }
}

struct OpenAITextPricingSnapshot: Codable, Equatable, Sendable {
    let inputUSDPerMillionTokens: Double
    let cachedInputUSDPerMillionTokens: Double
    let outputUSDPerMillionTokens: Double
    let source: String

    func estimatedCost(for usage: OpenAITextResponseUsage) -> Double {
        let uncachedInput = usage.inputTokens - usage.cachedInputTokens
        return Double(uncachedInput) / 1_000_000 * inputUSDPerMillionTokens
            + Double(usage.cachedInputTokens) / 1_000_000 * cachedInputUSDPerMillionTokens
            + Double(usage.outputTokens) / 1_000_000 * outputUSDPerMillionTokens
    }
}

struct OpenAITextUsagePricing: Sendable {
    nonisolated static let current: OpenAITextUsagePricing = {
        let source = "OpenAI model pricing reviewed 2026-08-12"
        let gpt55 = OpenAITextPricingSnapshot(
            inputUSDPerMillionTokens: 5,
            cachedInputUSDPerMillionTokens: 0.5,
            outputUSDPerMillionTokens: 30,
            source: source
        )
        let gpt54 = OpenAITextPricingSnapshot(
            inputUSDPerMillionTokens: 2.5,
            cachedInputUSDPerMillionTokens: 0.25,
            outputUSDPerMillionTokens: 15,
            source: source
        )
        let gpt54Mini = OpenAITextPricingSnapshot(
            inputUSDPerMillionTokens: 0.75,
            cachedInputUSDPerMillionTokens: 0.075,
            outputUSDPerMillionTokens: 4.5,
            source: source
        )
        return OpenAITextUsagePricing(
            rates: [
                "gpt-5.5": gpt55,
                "gpt-5.5-2026-04-23": gpt55,
                "gpt-5.4": gpt54,
                "gpt-5.4-2026-03-05": gpt54,
                "gpt-5.4-mini": gpt54Mini,
                "gpt-5.4-mini-2026-03-17": gpt54Mini,
            ]
        )
    }()

    private let rates: [String: OpenAITextPricingSnapshot]

    nonisolated func snapshot(for model: String) -> OpenAITextPricingSnapshot? {
        rates[model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()]
    }
}

struct OpenAIUsageEvent: Equatable, Identifiable, Sendable {
    let id: UUID
    let timestamp: Date
    let category: OpenAIUsageCategory
    let model: String
    let audioDurationSeconds: TimeInterval?
    let inputTokens: Int?
    let cachedInputTokens: Int?
    let outputTokens: Int?
    let reasoningTokens: Int?
    let priceUSDPerMinute: Double?
    let textPricing: OpenAITextPricingSnapshot?
    let estimatedCostUSD: Double?
    let pricingSource: String?

    var durationSeconds: TimeInterval { audioDurationSeconds ?? 0 }
    var textTokenCount: Int { (inputTokens ?? 0) + (outputTokens ?? 0) }

    init(transcription event: TranscriptionUsageEvent) {
        id = event.id
        timestamp = event.timestamp
        category = .transcription
        model = event.model
        audioDurationSeconds = event.durationSeconds
        inputTokens = nil
        cachedInputTokens = nil
        outputTokens = nil
        reasoningTokens = nil
        priceUSDPerMinute = event.priceUSDPerMinute
        textPricing = nil
        estimatedCostUSD = event.estimatedCostUSD
        pricingSource = event.pricingSource
    }

    init(
        id: UUID = UUID(),
        timestamp: Date,
        category: OpenAIUsageCategory,
        usage: OpenAITextResponseUsage,
        pricing: OpenAITextUsagePricing = .current
    ) {
        let snapshot = pricing.snapshot(for: usage.model)
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.model = usage.model
        audioDurationSeconds = nil
        inputTokens = usage.inputTokens
        cachedInputTokens = usage.cachedInputTokens
        outputTokens = usage.outputTokens
        reasoningTokens = usage.reasoningTokens
        priceUSDPerMinute = nil
        textPricing = snapshot
        estimatedCostUSD = snapshot?.estimatedCost(for: usage)
        pricingSource = snapshot?.source
    }

    init(
        id: UUID,
        timestamp: Date,
        category: OpenAIUsageCategory,
        model: String,
        audioDurationSeconds: TimeInterval?,
        inputTokens: Int?,
        cachedInputTokens: Int?,
        outputTokens: Int?,
        reasoningTokens: Int?,
        priceUSDPerMinute: Double?,
        textPricing: OpenAITextPricingSnapshot?,
        estimatedCostUSD: Double?,
        pricingSource: String?
    ) throws {
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedModel.isEmpty, timestamp.timeIntervalSinceReferenceDate.isFinite else {
            throw OpenAIUsageStoreError.unreadableUsage
        }

        switch category {
        case .transcription:
            guard let audioDurationSeconds,
                  audioDurationSeconds.isFinite,
                  audioDurationSeconds > 0,
                  inputTokens == nil,
                  cachedInputTokens == nil,
                  outputTokens == nil,
                  reasoningTokens == nil,
                  textPricing == nil else {
                throw OpenAIUsageStoreError.unreadableUsage
            }
            _ = try TranscriptionUsageEvent(
                id: id,
                timestamp: timestamp,
                model: model,
                durationSeconds: audioDurationSeconds,
                priceUSDPerMinute: priceUSDPerMinute,
                estimatedCostUSD: estimatedCostUSD,
                pricingSource: pricingSource
            )
        case .fixes, .textCorrection, .translation:
            guard audioDurationSeconds == nil,
                  priceUSDPerMinute == nil,
                  let inputTokens,
                  let cachedInputTokens,
                  let outputTokens,
                  let reasoningTokens,
                  inputTokens >= 0,
                  cachedInputTokens >= 0,
                  cachedInputTokens <= inputTokens,
                  outputTokens >= 0,
                  reasoningTokens >= 0,
                  reasoningTokens <= outputTokens else {
                throw OpenAIUsageStoreError.unreadableUsage
            }
            let usage = try OpenAITextResponseUsage(
                model: model,
                inputTokens: inputTokens,
                cachedInputTokens: cachedInputTokens,
                outputTokens: outputTokens,
                reasoningTokens: reasoningTokens
            )
            switch (textPricing, estimatedCostUSD, pricingSource) {
            case (nil, nil, nil):
                break
            case let (snapshot?, cost?, source?):
                let normalizedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
                guard snapshot.inputUSDPerMillionTokens.isFinite,
                      snapshot.inputUSDPerMillionTokens >= 0,
                      snapshot.cachedInputUSDPerMillionTokens.isFinite,
                      snapshot.cachedInputUSDPerMillionTokens >= 0,
                      snapshot.outputUSDPerMillionTokens.isFinite,
                      snapshot.outputUSDPerMillionTokens >= 0,
                      snapshot.source == normalizedSource,
                      !normalizedSource.isEmpty,
                      cost.isFinite,
                      cost >= 0 else {
                    throw OpenAIUsageStoreError.unreadableUsage
                }
                let expectedCost = snapshot.estimatedCost(for: usage)
                let tolerance = max(1e-12, abs(expectedCost) * 1e-9)
                guard abs(cost - expectedCost) <= tolerance else {
                    throw OpenAIUsageStoreError.unreadableUsage
                }
            default:
                throw OpenAIUsageStoreError.unreadableUsage
            }
        }

        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.model = normalizedModel
        self.audioDurationSeconds = audioDurationSeconds
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
        self.priceUSDPerMinute = priceUSDPerMinute
        self.textPricing = textPricing
        self.estimatedCostUSD = estimatedCostUSD
        self.pricingSource = pricingSource
    }
}

struct OpenAIUsageCategoryMetrics: Equatable, Sendable {
    var requestCount = 0
    var pricedRequestCount = 0
    var audioDurationSeconds: TimeInterval = 0
    var inputTokens = 0
    var cachedInputTokens = 0
    var outputTokens = 0
    var reasoningTokens = 0
    var estimatedCostUSD: Double = 0
    var hasUnpricedUsage = false

    var textTokens: Int { inputTokens + outputTokens }
}

struct OpenAIUsageDailyBucket: Equatable, Identifiable, Sendable {
    let day: Date
    let categories: [OpenAIUsageCategory: OpenAIUsageCategoryMetrics]
    var id: Date { day }
}

struct OpenAIUsageSummary: Equatable, Sendable {
    static let defaultWindowDays = 30

    let generatedAt: Date
    let dailyBuckets: [OpenAIUsageDailyBucket]
    let categories: [OpenAIUsageCategory: OpenAIUsageCategoryMetrics]
    let todayEstimatedCostUSD: Double?
    let totalEstimatedCostUSD: Double?
    let averageDailyCostUSD: Double?
    let projected30DayCostUSD: Double?
    let hasUnpricedUsage: Bool

    var isEmpty: Bool { categories.values.allSatisfy { $0.requestCount == 0 } }
    var hasTextUsage: Bool { categories.values.contains { $0.textTokens > 0 } }

    static func empty() -> OpenAIUsageSummary { make(events: []) }

    static func make(
        events: [OpenAIUsageEvent],
        now: Date = Date(),
        calendar: Calendar = .current,
        windowDays: Int = defaultWindowDays
    ) -> OpenAIUsageSummary {
        let safeWindow = max(1, windowDays)
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -(safeWindow - 1), to: today) ?? today
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let retained = events.filter { $0.timestamp >= start && $0.timestamp < end }
        var totals: [OpenAIUsageCategory: OpenAIUsageCategoryMetrics] = [:]
        var daily: [Date: [OpenAIUsageCategory: OpenAIUsageCategoryMetrics]] = [:]

        for event in retained {
            let day = calendar.startOfDay(for: event.timestamp)
            accumulate(event, into: &totals[event.category, default: .init()])
            accumulate(event, into: &daily[day, default: [:]][event.category, default: .init()])
        }

        let buckets = (0..<safeWindow).compactMap { offset -> OpenAIUsageDailyBucket? in
            guard let day = calendar.date(byAdding: .day, value: offset, to: start) else { return nil }
            return OpenAIUsageDailyBucket(day: day, categories: daily[day] ?? [:])
        }
        let hasUnpriced = totals.values.contains { $0.hasUnpricedUsage }
        let totalKnownCost = totals.values.reduce(0) { $0 + $1.estimatedCostUSD }
        let pricedRequestCount = totals.values.reduce(0) { $0 + $1.pricedRequestCount }
        let firstEventDay = retained.map { calendar.startOfDay(for: $0.timestamp) }.min() ?? today
        let elapsedDays = max(1, (calendar.dateComponents([.day], from: firstEventDay, to: today).day ?? 0) + 1)
        let todayCost = daily[today]?.values.reduce(0) { $0 + $1.estimatedCostUSD } ?? 0
        let todayPricedRequestCount = daily[today]?.values.reduce(0) { $0 + $1.pricedRequestCount } ?? 0
        let totalCost: Double? = pricedRequestCount == 0 ? nil : totalKnownCost
        let average = totalCost.map { $0 / Double(elapsedDays) }

        return OpenAIUsageSummary(
            generatedAt: now,
            dailyBuckets: buckets,
            categories: totals,
            todayEstimatedCostUSD: todayPricedRequestCount == 0 ? nil : todayCost,
            totalEstimatedCostUSD: totalCost,
            averageDailyCostUSD: average,
            projected30DayCostUSD: average.map { $0 * 30 },
            hasUnpricedUsage: hasUnpriced
        )
    }

    private static func accumulate(
        _ event: OpenAIUsageEvent,
        into metrics: inout OpenAIUsageCategoryMetrics
    ) {
        metrics.requestCount += 1
        metrics.pricedRequestCount += event.estimatedCostUSD == nil ? 0 : 1
        metrics.audioDurationSeconds += event.audioDurationSeconds ?? 0
        metrics.inputTokens += event.inputTokens ?? 0
        metrics.cachedInputTokens += event.cachedInputTokens ?? 0
        metrics.outputTokens += event.outputTokens ?? 0
        metrics.reasoningTokens += event.reasoningTokens ?? 0
        metrics.estimatedCostUSD += event.estimatedCostUSD ?? 0
        metrics.hasUnpricedUsage = metrics.hasUnpricedUsage || event.estimatedCostUSD == nil
    }
}
