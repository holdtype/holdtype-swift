import Foundation
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct OpenAITextUsageStoreTests {
    @Test func measuredTextUsageFreezesProviderCountsAndKnownPrice() throws {
        let persistence = TextUsagePersistence()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let store = OpenAIUsageStore(persistence: persistence, now: { now })
        let usage = try OpenAITextResponseUsage(
            model: "GPT-5.4-MINI",
            inputTokens: 1_000,
            cachedInputTokens: 200,
            outputTokens: 100,
            reasoningTokens: 40
        )

        store.recordTextUsage(.measured(usage), category: .fixes)

        let event = try #require(store.entries.first)
        #expect(event.category == .fixes)
        #expect(event.model == "gpt-5.4-mini")
        #expect(event.inputTokens == 1_000)
        #expect(event.cachedInputTokens == 200)
        #expect(event.outputTokens == 100)
        #expect(event.reasoningTokens == 40)
        #expect(isClose(event.estimatedCostUSD, 0.001_065))

        let summary = OpenAIUsageSummary.make(events: store.entries, now: now)
        #expect(summary.categories[.fixes]?.requestCount == 1)
        #expect(summary.categories[.fixes]?.pricedRequestCount == 1)
        #expect(summary.categories[.fixes]?.textTokens == 1_100)
        #expect(isClose(summary.totalEstimatedCostUSD, 0.001_065))
        #expect(summary.hasTextUsage)
        #expect(!summary.hasUnpricedUsage)
    }

    @Test func unknownModelKeepsMeasurementsAndMakesCostUnavailable() throws {
        let persistence = TextUsagePersistence()
        let now = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let store = OpenAIUsageStore(persistence: persistence, now: { now })
        let usage = try OpenAITextResponseUsage(
            model: "future-model",
            inputTokens: 30,
            cachedInputTokens: 0,
            outputTokens: 20,
            reasoningTokens: 0
        )

        store.recordTextUsage(.measured(usage), category: .translation)

        let event = try #require(store.entries.first)
        #expect(event.estimatedCostUSD == nil)
        #expect(event.textTokenCount == 50)
        let summary = OpenAIUsageSummary.make(events: store.entries, now: now)
        #expect(summary.totalEstimatedCostUSD == nil)
        #expect(summary.todayEstimatedCostUSD == nil)
        #expect(summary.categories[.translation]?.pricedRequestCount == 0)
        #expect(summary.hasUnpricedUsage)
    }

    @Test func reviewedSnapshotIdentifiersUseTheSameFrozenPriceAsTheirAliases() throws {
        let usage = try OpenAITextResponseUsage(
            model: "gpt-5.4-mini-2026-03-17",
            inputTokens: 1_000,
            cachedInputTokens: 200,
            outputTokens: 100,
            reasoningTokens: 40
        )
        let event = OpenAIUsageEvent(
            timestamp: Date(),
            category: .fixes,
            usage: usage
        )

        #expect(isClose(event.estimatedCostUSD, 0.001_065))
    }

    @Test func gpt56FixModelsUseReviewedFrozenPricesInOneCategory() throws {
        let timestamp = Date(timeIntervalSinceReferenceDate: 800_000_000)
        let usages = try [
            OpenAITextResponseUsage(
                model: "gpt-5.6-terra",
                inputTokens: 1_000,
                cachedInputTokens: 200,
                outputTokens: 100,
                reasoningTokens: 40
            ),
            OpenAITextResponseUsage(
                model: "gpt-5.6-sol",
                inputTokens: 1_000,
                cachedInputTokens: 200,
                outputTokens: 100,
                reasoningTokens: 40
            ),
            OpenAITextResponseUsage(
                model: "gpt-5.6",
                inputTokens: 1_000,
                cachedInputTokens: 200,
                outputTokens: 100,
                reasoningTokens: 40
            ),
        ]
        let events = usages.map {
            OpenAIUsageEvent(timestamp: timestamp, category: .fixes, usage: $0)
        }

        #expect(isClose(events[0].estimatedCostUSD, 0.002_84))
        #expect(isClose(events[1].estimatedCostUSD, 0.007_1))
        #expect(isClose(events[2].estimatedCostUSD, 0.007_1))

        let summary = OpenAIUsageSummary.make(events: events, now: timestamp)
        let fixes = try #require(summary.categories[.fixes])
        #expect(fixes.requestCount == 3)
        #expect(fixes.pricedRequestCount == 3)
        #expect(isClose(fixes.estimatedCostUSD, 0.017_04))
        #expect(!summary.hasUnpricedUsage)
    }

    @Test func missingProviderUsageShowsNoticeWithoutInventingEvent() throws {
        let persistence = TextUsagePersistence()
        let store = OpenAIUsageStore(persistence: persistence)

        store.recordTextUsage(.unavailable, category: .textCorrection)

        #expect(store.entries.isEmpty)
        #expect(store.estimateNoticeMessage?.contains("incomplete") == true)
        #expect(persistence.saveCount == 0)

        try store.clear()
        #expect(store.estimateNoticeMessage == nil)
    }

    @Test func v2RejectsInconsistentFrozenTextCost() throws {
        let id = try #require(UUID(uuidString: "74444444-4444-4444-4444-444444444444"))
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 2,
            "events": [[
                "id": id.uuidString,
                "timestamp": Date(timeIntervalSinceReferenceDate: 800_000_000).timeIntervalSinceReferenceDate,
                "category": "fixes",
                "model": "gpt-5.4-mini",
                "inputTokens": 1_000,
                "cachedInputTokens": 0,
                "outputTokens": 100,
                "reasoningTokens": 0,
                "textPricing": [
                    "inputUSDPerMillionTokens": 0.75,
                    "cachedInputUSDPerMillionTokens": 0.075,
                    "outputUSDPerMillionTokens": 4.5,
                    "source": "OpenAI model pricing reviewed 2026-08-12",
                ],
                "estimatedCostUSD": 1,
                "pricingSource": "OpenAI model pricing reviewed 2026-08-12",
            ]],
        ])
        let persistence = TextUsagePersistence(savedData: data)
        let store = OpenAIUsageStore(persistence: persistence)

        #expect(throws: OpenAIUsageStoreError.unreadableUsage) {
            _ = try store.load()
        }
        #expect(persistence.savedData == data)
    }

    private func isClose(_ value: Double?, _ expected: Double) -> Bool {
        guard let value else { return false }
        return abs(value - expected) <= 0.000_000_001
    }
}

private final class TextUsagePersistence: OpenAIUsagePersistence {
    var savedData: Data?
    var saveCount = 0

    init(savedData: Data? = nil) {
        self.savedData = savedData
    }

    func loadData(forKey key: String) throws -> Data? { savedData }

    func saveData(_ data: Data, forKey key: String) throws {
        saveCount += 1
        savedData = data
    }

    func removeData(forKey key: String) throws { savedData = nil }
}
