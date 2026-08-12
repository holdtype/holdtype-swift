import Combine
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

protocol OpenAIUsagePersistence {
    func loadData(forKey key: String) throws -> Data?
    func saveData(_ data: Data, forKey key: String) throws
    func removeData(forKey key: String) throws
}

extension UserDefaults: OpenAIUsagePersistence {
    func loadData(forKey key: String) throws -> Data? { data(forKey: key) }
    func saveData(_ data: Data, forKey key: String) throws { set(data, forKey: key) }
    func removeData(forKey key: String) throws { removeObject(forKey: key) }
}

enum OpenAIUsageStoreError: Error, Equatable, LocalizedError {
    case loadFailed
    case unreadableUsage
    case saveFailed
    case clearFailed

    var errorDescription: String? {
        switch self {
        case .loadFailed: return "OpenAI usage estimate could not be loaded."
        case .unreadableUsage: return "Saved OpenAI usage estimate could not be read."
        case .saveFailed: return "OpenAI usage estimate could not be saved."
        case .clearFailed: return "OpenAI usage estimate could not be cleared."
        }
    }
}

@MainActor
final class OpenAIUsageStore: ObservableObject, TranscriptionUsageRecording {
    static let shared = OpenAIUsageStore()
    nonisolated static let defaultStorageKey = "holdtype.openAIUsageEstimate.events"
    nonisolated static let defaultRetentionDays = 365

    @Published private(set) var entries: [OpenAIUsageEvent]
    @Published private(set) var storageErrorMessage: String?
    @Published private(set) var estimateNoticeMessage: String?

    private let persistence: any OpenAIUsagePersistence
    private let storageKey: String
    private let retentionDays: Int
    private let transcriptionPricing: OpenAIUsagePricing
    private let textPricing: OpenAITextUsagePricing
    private let calendar: Calendar
    private let now: () -> Date
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    convenience init(
        userDefaults: UserDefaults = .standard,
        storageKey: String = OpenAIUsageStore.defaultStorageKey,
        retentionDays: Int = OpenAIUsageStore.defaultRetentionDays,
        transcriptionPricing: OpenAIUsagePricing = .current,
        textPricing: OpenAITextUsagePricing = .current,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.init(
            persistence: userDefaults,
            storageKey: storageKey,
            retentionDays: retentionDays,
            transcriptionPricing: transcriptionPricing,
            textPricing: textPricing,
            calendar: calendar,
            now: now,
            encoder: encoder,
            decoder: decoder
        )
    }

    init(
        persistence: any OpenAIUsagePersistence,
        storageKey: String = OpenAIUsageStore.defaultStorageKey,
        retentionDays: Int = OpenAIUsageStore.defaultRetentionDays,
        transcriptionPricing: OpenAIUsagePricing = .current,
        textPricing: OpenAITextUsagePricing = .current,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.persistence = persistence
        self.storageKey = storageKey
        self.retentionDays = max(1, retentionDays)
        self.transcriptionPricing = transcriptionPricing
        self.textPricing = textPricing
        self.calendar = calendar
        self.now = now
        self.encoder = encoder
        self.decoder = decoder
        entries = []
        storageErrorMessage = nil
        estimateNoticeMessage = nil
        reload()
    }

    nonisolated static func reporter(
        for category: OpenAIUsageCategory
    ) -> OpenAITextUsageReporter {
        { observation in
            await MainActor.run {
                OpenAIUsageStore.shared.recordTextUsage(
                    observation,
                    category: category
                )
            }
        }
    }

    func reload() {
        do {
            entries = try load()
            storageErrorMessage = nil
        } catch {
            entries = []
            storageErrorMessage = Self.userFacingMessage(for: error)
        }
    }

    func recordSuccessfulTranscriptionUsage(_ usage: SuccessfulTranscriptionUsage) {
        do {
            let event = try transcriptionPricing.makeEvent(timestamp: now(), for: usage)
            _ = try append(event)
        } catch {
            storageErrorMessage = Self.userFacingMessage(for: OpenAIUsageStoreError.saveFailed)
        }
    }

    func recordTextUsage(
        _ observation: OpenAITextUsageObservation,
        category: OpenAIUsageCategory
    ) {
        switch observation {
        case .unavailable:
            estimateNoticeMessage = "Some OpenAI usage could not be measured, so this estimate may be incomplete."
        case .measured(let usage):
            do {
                let event = OpenAIUsageEvent(
                    timestamp: now(),
                    category: category,
                    usage: usage,
                    pricing: textPricing
                )
                _ = try append(event)
            } catch {
                storageErrorMessage = Self.userFacingMessage(for: error)
            }
        }
    }

    func load() throws -> [OpenAIUsageEvent] {
        let data: Data?
        do {
            data = try persistence.loadData(forKey: storageKey)
        } catch {
            throw OpenAIUsageStoreError.loadFailed
        }
        guard let data else { return [] }

        if let root = try? decoder.decode(OpenAIUsageRootWire.self, from: data) {
            guard root.schemaVersion == 2 else { throw OpenAIUsageStoreError.unreadableUsage }
            return try retainedEntries(validatedEvents(from: root.events))
        }

        do {
            let legacyRows = try decoder.decode([LegacyOpenAIUsageEventWire].self, from: data)
            var identifiers: Set<UUID> = []
            let migrated = try legacyRows.map { row -> OpenAIUsageEvent in
                var transcription = try row.runtimeEvent()
                if let backfilled = try transcriptionPricing.backfilledEventIfEligible(transcription) {
                    transcription = backfilled
                }
                guard identifiers.insert(transcription.id).inserted else {
                    throw OpenAIUsageStoreError.unreadableUsage
                }
                return OpenAIUsageEvent(transcription: transcription)
            }
            let retained = retainedEntries(migrated)
            try save(retained)
            return retained
        } catch let error as OpenAIUsageStoreError {
            throw error
        } catch {
            throw OpenAIUsageStoreError.unreadableUsage
        }
    }

    @discardableResult
    func append(_ transcriptionEvent: TranscriptionUsageEvent) throws -> [OpenAIUsageEvent] {
        try append(OpenAIUsageEvent(transcription: transcriptionEvent))
    }

    @discardableResult
    func append(_ event: OpenAIUsageEvent) throws -> [OpenAIUsageEvent] {
        let existingEntries = try load()
        guard !existingEntries.contains(where: { $0.id == event.id }) else {
            entries = existingEntries
            return existingEntries
        }

        let updated = retainedEntries([event] + existingEntries)
        try save(updated)
        entries = updated
        storageErrorMessage = nil
        return updated
    }

    func clear() throws {
        do {
            try persistence.removeData(forKey: storageKey)
            entries = []
            storageErrorMessage = nil
            estimateNoticeMessage = nil
        } catch {
            throw OpenAIUsageStoreError.clearFailed
        }
    }

    func clearUsageEstimate() {
        do { try clear() } catch { storageErrorMessage = Self.userFacingMessage(for: error) }
    }

    private func save(_ events: [OpenAIUsageEvent]) throws {
        do {
            let root = OpenAIUsageRootWire(
                schemaVersion: 2,
                events: events.map(OpenAIUsageEventWire.init(event:))
            )
            try persistence.saveData(try encoder.encode(root), forKey: storageKey)
        } catch {
            throw OpenAIUsageStoreError.saveFailed
        }
    }

    private func validatedEvents(from rows: [OpenAIUsageEventWire]) throws -> [OpenAIUsageEvent] {
        var identifiers: Set<UUID> = []
        return try rows.map { row in
            let event = try row.runtimeEvent()
            guard identifiers.insert(event.id).inserted else {
                throw OpenAIUsageStoreError.unreadableUsage
            }
            return event
        }
    }

    private func retainedEntries(_ source: [OpenAIUsageEvent]) -> [OpenAIUsageEvent] {
        let cutoff = calendar.date(
            byAdding: .day,
            value: -(retentionDays - 1),
            to: calendar.startOfDay(for: now())
        ) ?? now()
        return source.filter { $0.timestamp >= cutoff }.sorted {
            $0.timestamp == $1.timestamp
                ? $0.id.uuidString < $1.id.uuidString
                : $0.timestamp > $1.timestamp
        }
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        return error.localizedDescription
    }
}

private struct OpenAIUsageRootWire: Codable {
    let schemaVersion: Int
    let events: [OpenAIUsageEventWire]
}

private struct OpenAIUsageEventWire: Codable {
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

    init(event: OpenAIUsageEvent) {
        id = event.id
        timestamp = event.timestamp
        category = event.category
        model = event.model
        audioDurationSeconds = event.audioDurationSeconds
        inputTokens = event.inputTokens
        cachedInputTokens = event.cachedInputTokens
        outputTokens = event.outputTokens
        reasoningTokens = event.reasoningTokens
        priceUSDPerMinute = event.priceUSDPerMinute
        textPricing = event.textPricing
        estimatedCostUSD = event.estimatedCostUSD
        pricingSource = event.pricingSource
    }

    func runtimeEvent() throws -> OpenAIUsageEvent {
        try OpenAIUsageEvent(
            id: id,
            timestamp: timestamp,
            category: category,
            model: model,
            audioDurationSeconds: audioDurationSeconds,
            inputTokens: inputTokens,
            cachedInputTokens: cachedInputTokens,
            outputTokens: outputTokens,
            reasoningTokens: reasoningTokens,
            priceUSDPerMinute: priceUSDPerMinute,
            textPricing: textPricing,
            estimatedCostUSD: estimatedCostUSD,
            pricingSource: pricingSource
        )
    }
}

private struct LegacyOpenAIUsageEventWire: Codable {
    let id: UUID
    let timestamp: Date
    let model: String
    let durationSeconds: TimeInterval
    let priceUSDPerMinute: Double?
    let estimatedCostUSD: Double?
    let pricingSource: String?

    func runtimeEvent() throws -> TranscriptionUsageEvent {
        let event = try TranscriptionUsageEvent(
            id: id,
            timestamp: timestamp,
            model: model,
            durationSeconds: durationSeconds,
            priceUSDPerMinute: priceUSDPerMinute,
            estimatedCostUSD: estimatedCostUSD,
            pricingSource: pricingSource
        )
        guard event.model == model, event.pricingSource == pricingSource else {
            throw OpenAIUsageStoreError.unreadableUsage
        }
        return event
    }
}
