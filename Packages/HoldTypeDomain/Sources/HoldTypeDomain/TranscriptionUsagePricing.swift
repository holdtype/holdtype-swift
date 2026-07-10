import Foundation

/// A validated local pricing table used only to freeze new usage estimates.
public struct TranscriptionUsagePricing: Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case emptyModel
        case duplicateNormalizedModel
        case invalidRate
        case emptySource
    }

    public static let current = TranscriptionUsagePricing(
        validatedRatesUSDPerMinute: [
            "gpt-4o-transcribe": 0.006,
            "gpt-4o-mini-transcribe": 0.003,
        ],
        validatedSourceLabel: "OpenAI pricing reviewed 2026-06-22"
    )

    public let ratesUSDPerMinute: [String: Double]
    public let sourceLabel: String

    public init(
        ratesUSDPerMinute: [String: Double],
        sourceLabel: String
    ) throws {
        var normalizedRates: [String: Double] = [:]
        normalizedRates.reserveCapacity(ratesUSDPerMinute.count)

        for (model, rate) in ratesUSDPerMinute {
            let normalizedModel = TranscriptionUsageEvent.normalizedModel(model)
            guard !normalizedModel.isEmpty else {
                throw ValidationError.emptyModel
            }
            guard normalizedRates[normalizedModel] == nil else {
                throw ValidationError.duplicateNormalizedModel
            }
            guard rate.isFinite, rate >= 0 else {
                throw ValidationError.invalidRate
            }
            normalizedRates[normalizedModel] = rate
        }

        let normalizedSource = TranscriptionUsageEvent.normalizedPricingSource(sourceLabel)
        guard !normalizedSource.isEmpty else {
            throw ValidationError.emptySource
        }

        self.init(
            validatedRatesUSDPerMinute: normalizedRates,
            validatedSourceLabel: normalizedSource
        )
    }

    public func rateUSDPerMinute(for model: String) -> Double? {
        ratesUSDPerMinute[TranscriptionUsageEvent.normalizedModel(model)]
    }

    public func makeEvent(
        timestamp: Date = Date(),
        model: String,
        durationSeconds: TimeInterval,
        id: UUID = UUID()
    ) throws -> TranscriptionUsageEvent {
        let normalizedModel = TranscriptionUsageEvent.normalizedModel(model)
        let rate = rateUSDPerMinute(for: normalizedModel)
        let cost = rate.map { durationSeconds / 60 * $0 }

        return try TranscriptionUsageEvent(
            id: id,
            timestamp: timestamp,
            model: normalizedModel,
            durationSeconds: durationSeconds,
            priceUSDPerMinute: rate,
            estimatedCostUSD: cost,
            pricingSource: rate == nil ? nil : sourceLabel
        )
    }

    public func makeEvent(
        timestamp: Date = Date(),
        for usage: SuccessfulTranscriptionUsage
    ) throws -> TranscriptionUsageEvent {
        try makeEvent(
            timestamp: timestamp,
            model: usage.model,
            durationSeconds: usage.audioDuration,
            id: usage.transcriptionID
        )
    }

    private init(
        validatedRatesUSDPerMinute: [String: Double],
        validatedSourceLabel: String
    ) {
        ratesUSDPerMinute = validatedRatesUSDPerMinute
        sourceLabel = validatedSourceLabel
    }
}
