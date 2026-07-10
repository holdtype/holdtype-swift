import Foundation

/// One runtime-only, device-local estimate for an accepted audio transcription.
public struct TranscriptionUsageEvent: Equatable, Identifiable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case invalidTimestamp
        case emptyModel
        case invalidDuration
        case incompletePriceSnapshot
        case invalidPriceRate
        case invalidEstimatedCost
        case emptyPricingSource
        case inconsistentEstimatedCost
    }

    public let id: UUID
    public let timestamp: Date
    public let model: String
    public let durationSeconds: TimeInterval
    public let priceUSDPerMinute: Double?
    public let estimatedCostUSD: Double?
    public let pricingSource: String?

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        model: String,
        durationSeconds: TimeInterval,
        priceUSDPerMinute: Double?,
        estimatedCostUSD: Double?,
        pricingSource: String?
    ) throws {
        guard timestamp.timeIntervalSinceReferenceDate.isFinite else {
            throw ValidationError.invalidTimestamp
        }

        let normalizedModel = Self.normalizedModel(model)
        guard !normalizedModel.isEmpty else {
            throw ValidationError.emptyModel
        }
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw ValidationError.invalidDuration
        }

        let normalizedPricingSource: String?
        switch (priceUSDPerMinute, estimatedCostUSD, pricingSource) {
        case (nil, nil, nil):
            normalizedPricingSource = nil

        case let (rate?, cost?, source?):
            guard rate.isFinite, rate >= 0 else {
                throw ValidationError.invalidPriceRate
            }
            guard cost.isFinite, cost >= 0 else {
                throw ValidationError.invalidEstimatedCost
            }

            let normalizedSource = Self.normalizedPricingSource(source)
            guard !normalizedSource.isEmpty else {
                throw ValidationError.emptyPricingSource
            }

            let expectedCost = durationSeconds / 60 * rate
            guard expectedCost.isFinite else {
                throw ValidationError.invalidEstimatedCost
            }
            if expectedCost == 0 {
                guard cost == 0 else {
                    throw ValidationError.inconsistentEstimatedCost
                }
            } else {
                let tolerance = max(1e-12, abs(expectedCost) * 1e-9)
                let difference = abs(cost - expectedCost)
                guard difference.isFinite, difference <= tolerance else {
                    throw ValidationError.inconsistentEstimatedCost
                }
            }
            normalizedPricingSource = normalizedSource

        default:
            throw ValidationError.incompletePriceSnapshot
        }

        self.id = id
        self.timestamp = timestamp
        self.model = normalizedModel
        self.durationSeconds = durationSeconds
        self.priceUSDPerMinute = priceUSDPerMinute
        self.estimatedCostUSD = estimatedCostUSD
        self.pricingSource = normalizedPricingSource
    }

    static func normalizedModel(_ model: String) -> String {
        model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func normalizedPricingSource(_ source: String) -> String {
        source.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
