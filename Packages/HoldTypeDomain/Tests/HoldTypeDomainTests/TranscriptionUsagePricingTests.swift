import Foundation
import Testing
@testable import HoldTypeDomain

struct TranscriptionUsagePricingTests {
    @Test func currentPricingPreservesTheExistingRatesAndSource() throws {
        let pricing = TranscriptionUsagePricing.current

        #expect(pricing.rateUSDPerMinute(for: " gpt-4o-transcribe ") == 0.006)
        #expect(pricing.rateUSDPerMinute(for: "GPT-4O-MINI-TRANSCRIBE") == 0.003)
        #expect(pricing.rateUSDPerMinute(for: "unknown") == nil)
        #expect(pricing.sourceLabel == "OpenAI pricing reviewed 2026-06-22")
        requireSendable(TranscriptionUsagePricing.self)
        #expect(((pricing as Any) is any Encodable) == false)
        #expect(((pricing as Any) is any Decodable) == false)
    }

    @Test func initializerNormalizesKeysAndSource() throws {
        let pricing = try TranscriptionUsagePricing(
            ratesUSDPerMinute: [" Custom-Model \n": 0],
            sourceLabel: " Price table v1 \n"
        )

        #expect(pricing.ratesUSDPerMinute == ["custom-model": 0])
        #expect(pricing.sourceLabel == "Price table v1")
    }

    @Test func initializerRejectsEmptyCollidingAndInvalidEntries() {
        #expect(throws: TranscriptionUsagePricing.ValidationError.emptyModel) {
            _ = try TranscriptionUsagePricing(
                ratesUSDPerMinute: [" \n": 0.01],
                sourceLabel: "source"
            )
        }
        #expect(throws: TranscriptionUsagePricing.ValidationError.duplicateNormalizedModel) {
            _ = try TranscriptionUsagePricing(
                ratesUSDPerMinute: ["MODEL": 0.01, " model ": 0.02],
                sourceLabel: "source"
            )
        }
        for rate in [-1, Double.nan, .infinity, -.infinity] {
            #expect(throws: TranscriptionUsagePricing.ValidationError.invalidRate) {
                _ = try TranscriptionUsagePricing(
                    ratesUSDPerMinute: ["model": rate],
                    sourceLabel: "source"
                )
            }
        }
        #expect(throws: TranscriptionUsagePricing.ValidationError.emptySource) {
            _ = try TranscriptionUsagePricing(
                ratesUSDPerMinute: [:],
                sourceLabel: " \n "
            )
        }
    }

    @Test func makeEventFreezesKnownAndUnknownPriceSnapshots() throws {
        let timestamp = Date(timeIntervalSince1970: 1_752_148_496)
        let identifier = try #require(
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        )
        let known = try TranscriptionUsagePricing.current.makeEvent(
            timestamp: timestamp,
            model: " GPT-4O-Transcribe ",
            durationSeconds: 120,
            id: identifier
        )
        let unknown = try TranscriptionUsagePricing.current.makeEvent(
            timestamp: timestamp,
            model: " Custom-Model ",
            durationSeconds: 180
        )

        #expect(known.model == "gpt-4o-transcribe")
        #expect(known.priceUSDPerMinute == 0.006)
        #expect(known.estimatedCostUSD == 0.012)
        #expect(known.pricingSource == "OpenAI pricing reviewed 2026-06-22")
        #expect(unknown.model == "custom-model")
        #expect(unknown.priceUSDPerMinute == nil)
        #expect(unknown.estimatedCostUSD == nil)
        #expect(unknown.pricingSource == nil)
    }

    @Test func successfulUsageOverloadPreservesTheIdempotencyIdentity() throws {
        let id = try #require(
            UUID(uuidString: "22222222-2222-2222-2222-222222222222")
        )
        let usage = try SuccessfulTranscriptionUsage(
            transcriptionID: id,
            model: "gpt-4o-mini-transcribe",
            audioDuration: 180
        )
        let timestamp = Date(timeIntervalSince1970: 1_752_148_496)

        let event = try TranscriptionUsagePricing.current.makeEvent(
            timestamp: timestamp,
            for: usage
        )

        #expect(event.id == id)
        #expect(event.timestamp == timestamp)
        #expect(event.model == "gpt-4o-mini-transcribe")
        #expect(event.durationSeconds == 180)
        #expect(
            event.estimatedCostUSD.map { abs($0 - 0.009) <= 1e-12 } == true
        )
    }

    @Test func makeEventRejectsInvalidDurationInsteadOfClampingIt() {
        for duration in [0, -1, Double.nan, .infinity, -.infinity] {
            #expect(throws: TranscriptionUsageEvent.ValidationError.invalidDuration) {
                _ = try TranscriptionUsagePricing.current.makeEvent(
                    model: "gpt-4o-transcribe",
                    durationSeconds: duration
                )
            }
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
