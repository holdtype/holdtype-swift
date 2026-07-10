import Foundation
import Testing
@testable import HoldTypeDomain

struct TranscriptionUsageEventTests {
    @Test func runtimeValueNormalizesApprovedTextEdgesAndIsNotAWireDTO() throws {
        let id = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let timestamp = Date(timeIntervalSince1970: 1_752_148_496.125)
        let event = try TranscriptionUsageEvent(
            id: id,
            timestamp: timestamp,
            model: "  GPT-4O-Transcribe \n",
            durationSeconds: 120,
            priceUSDPerMinute: 0.006,
            estimatedCostUSD: 0.012,
            pricingSource: " OpenAI pricing reviewed 2026-06-22 \n"
        )

        #expect(event.id == id)
        #expect(event.timestamp == timestamp)
        #expect(event.model == "gpt-4o-transcribe")
        #expect(event.durationSeconds == 120)
        #expect(event.priceUSDPerMinute == 0.006)
        #expect(event.estimatedCostUSD == 0.012)
        #expect(event.pricingSource == "OpenAI pricing reviewed 2026-06-22")
        requireSendable(TranscriptionUsageEvent.self)
        #expect(((event as Any) is any Encodable) == false)
        #expect(((event as Any) is any Decodable) == false)
    }

    @Test func unknownPriceRequiresAnEntirelyNilSnapshot() throws {
        let event = try makeEvent(
            priceUSDPerMinute: nil,
            estimatedCostUSD: nil,
            pricingSource: nil
        )

        #expect(event.priceUSDPerMinute == nil)
        #expect(event.estimatedCostUSD == nil)
        #expect(event.pricingSource == nil)

        let incompleteSnapshots: [(Double?, Double?, String?)] = [
            (0.006, nil, nil),
            (nil, 0.006, nil),
            (nil, nil, "source"),
            (0.006, 0.006, nil),
            (0.006, nil, "source"),
            (nil, 0.006, "source"),
        ]
        for (rate, cost, source) in incompleteSnapshots {
            #expect(throws: TranscriptionUsageEvent.ValidationError.incompletePriceSnapshot) {
                _ = try makeEvent(
                    priceUSDPerMinute: rate,
                    estimatedCostUSD: cost,
                    pricingSource: source
                )
            }
        }
    }

    @Test func rejectsInvalidTimestampModelAndDurationWithoutClamping() {
        for timestamp in [
            Date(timeIntervalSinceReferenceDate: .nan),
            Date(timeIntervalSinceReferenceDate: .infinity),
            Date(timeIntervalSinceReferenceDate: -.infinity),
        ] {
            #expect(throws: TranscriptionUsageEvent.ValidationError.invalidTimestamp) {
                _ = try makeEvent(timestamp: timestamp)
            }
        }

        for model in ["", " \n\t "] {
            #expect(throws: TranscriptionUsageEvent.ValidationError.emptyModel) {
                _ = try makeEvent(model: model)
            }
        }

        for duration in [0, -1, Double.nan, .infinity, -.infinity] {
            #expect(throws: TranscriptionUsageEvent.ValidationError.invalidDuration) {
                _ = try makeEvent(durationSeconds: duration)
            }
        }
    }

    @Test func validatesNonnegativeFinitePriceComponentsAndSource() {
        for rate in [-1, Double.nan, .infinity, -.infinity] {
            #expect(throws: TranscriptionUsageEvent.ValidationError.invalidPriceRate) {
                _ = try makeEvent(
                    priceUSDPerMinute: rate,
                    estimatedCostUSD: 0,
                    pricingSource: "source"
                )
            }
        }

        for cost in [-1, Double.nan, .infinity, -.infinity] {
            #expect(throws: TranscriptionUsageEvent.ValidationError.invalidEstimatedCost) {
                _ = try makeEvent(
                    priceUSDPerMinute: 0,
                    estimatedCostUSD: cost,
                    pricingSource: "source"
                )
            }
        }

        #expect(throws: TranscriptionUsageEvent.ValidationError.emptyPricingSource) {
            _ = try makeEvent(
                priceUSDPerMinute: 0,
                estimatedCostUSD: 0,
                pricingSource: " \n "
            )
        }
    }

    @Test func costConsistencyUsesTheApprovedToleranceAndExactZeroRule() throws {
        let expectedCost = 120.0 / 60 * 0.006
        let tolerance = max(1e-12, abs(expectedCost) * 1e-9)

        _ = try makeEvent(
            durationSeconds: 120,
            priceUSDPerMinute: 0.006,
            estimatedCostUSD: expectedCost + tolerance * 0.5,
            pricingSource: "source"
        )
        #expect(throws: TranscriptionUsageEvent.ValidationError.inconsistentEstimatedCost) {
            _ = try makeEvent(
                durationSeconds: 120,
                priceUSDPerMinute: 0.006,
                estimatedCostUSD: expectedCost + tolerance * 2,
                pricingSource: "source"
            )
        }

        _ = try makeEvent(
            priceUSDPerMinute: 0,
            estimatedCostUSD: 0,
            pricingSource: "free pricing"
        )
        #expect(throws: TranscriptionUsageEvent.ValidationError.inconsistentEstimatedCost) {
            _ = try makeEvent(
                priceUSDPerMinute: 0,
                estimatedCostUSD: Double.leastNonzeroMagnitude,
                pricingSource: "free pricing"
            )
        }
    }

    @Test func rejectsAnOverflowingExpectedCostBeforeToleranceComparison() {
        #expect(throws: TranscriptionUsageEvent.ValidationError.invalidEstimatedCost) {
            _ = try makeEvent(
                durationSeconds: .greatestFiniteMagnitude,
                priceUSDPerMinute: .greatestFiniteMagnitude,
                estimatedCostUSD: .greatestFiniteMagnitude,
                pricingSource: "source"
            )
        }
    }

    private func makeEvent(
        timestamp: Date = Date(timeIntervalSince1970: 1_752_148_496),
        model: String = "gpt-4o-transcribe",
        durationSeconds: TimeInterval = 60,
        priceUSDPerMinute: Double? = nil,
        estimatedCostUSD: Double? = nil,
        pricingSource: String? = nil
    ) throws -> TranscriptionUsageEvent {
        let id = try #require(
            UUID(uuidString: "11111111-1111-1111-1111-111111111111")
        )
        return try TranscriptionUsageEvent(
            id: id,
            timestamp: timestamp,
            model: model,
            durationSeconds: durationSeconds,
            priceUSDPerMinute: priceUSDPerMinute,
            estimatedCostUSD: estimatedCostUSD,
            pricingSource: pricingSource
        )
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
