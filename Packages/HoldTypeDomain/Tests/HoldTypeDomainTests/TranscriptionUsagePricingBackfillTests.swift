import Foundation
import HoldTypeDomain
import Testing

struct TranscriptionUsagePricingBackfillTests {
    @Test func currentPricingUsesReviewedGptTranscribeRate() throws {
        let event = try TranscriptionUsagePricing.current.makeEvent(
            model: "gpt-transcribe",
            durationSeconds: 120
        )

        #expect(event.priceUSDPerMinute == 0.0045)
        #expect(event.estimatedCostUSD == 0.009)
    }

    @Test func backfillOnlyChangesCanonicalGptTranscribeWithNoSnapshot() throws {
        let pricing = TranscriptionUsagePricing.current
        let legacyEvent = try makeEvent(model: "gpt-transcribe")
        let otherModel = try makeEvent(model: "custom-model")
        let knownEvent = try pricing.makeEvent(
            timestamp: legacyEvent.timestamp,
            model: "gpt-transcribe",
            durationSeconds: legacyEvent.durationSeconds,
            id: legacyEvent.id
        )

        let maybeBackfilled = try pricing.backfilledEventIfEligible(legacyEvent)
        let backfilled = try #require(maybeBackfilled)
        let repeatedBackfill = try pricing.backfilledEventIfEligible(backfilled)
        let otherModelBackfill = try pricing.backfilledEventIfEligible(otherModel)
        let knownEventBackfill = try pricing.backfilledEventIfEligible(knownEvent)

        #expect(backfilled.id == legacyEvent.id)
        #expect(backfilled.timestamp == legacyEvent.timestamp)
        #expect(backfilled.durationSeconds == legacyEvent.durationSeconds)
        #expect(backfilled.priceUSDPerMinute == 0.0045)
        #expect(backfilled.estimatedCostUSD == 0.0045)
        #expect(repeatedBackfill == nil)
        #expect(otherModelBackfill == nil)
        #expect(knownEventBackfill == nil)
    }

    @Test func backfillDoesNothingWhenTheInjectedTableDoesNotKnowGptTranscribe() throws {
        let pricing = try TranscriptionUsagePricing(
            ratesUSDPerMinute: ["custom-model": 0.01],
            sourceLabel: "test pricing"
        )
        let legacyEvent = try makeEvent(model: "gpt-transcribe")

        let backfilled = try pricing.backfilledEventIfEligible(legacyEvent)

        #expect(backfilled == nil)
    }

    private func makeEvent(model: String) throws -> TranscriptionUsageEvent {
        try TranscriptionUsageEvent(
            id: try #require(UUID(uuidString: "DDA5B2A4-BA0B-4DDB-9924-29E5EB30D0B7")),
            timestamp: Date(timeIntervalSince1970: 1_752_148_496),
            model: model,
            durationSeconds: 60,
            priceUSDPerMinute: nil,
            estimatedCostUSD: nil,
            pricingSource: nil
        )
    }
}
