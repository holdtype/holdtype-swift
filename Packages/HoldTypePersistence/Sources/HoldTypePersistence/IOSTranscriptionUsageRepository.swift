import CoreFoundation
import Foundation
import HoldTypeDomain

public enum IOSTranscriptionUsageRepositoryError: Error, Equatable, Sendable {
    case readFailed
    case sourceTooLarge
    case malformedData
    case topLevelNotObject
    case missingSchemaVersion
    case unsupportedSchemaVersion
    case invalidRootFields
    case invalidEventFields
    case invalidFieldType
    case invalidIdentifier
    case invalidTimestamp
    case invalidEvent
    case duplicateIdentifier
    case invalidEventOrder
    case calendarCalculationFailed
    case encodingFailed
    case encodedDataTooLarge
    case writeFailed
    case compactionFailed
    case resetFailed
}

public enum IOSTranscriptionUsageRecordResult: Equatable, Sendable {
    case inserted
    case duplicate
}

/// Serializes all containing-app access to the canonical local usage estimate.
public actor IOSTranscriptionUsageRepository {
    public static let maximumByteCount = 4 * 1_024 * 1_024
    public static let retentionDayCount = 365

    private let fileURL: URL
    private let fileSystem: any ProtectedAtomicMetadataFileSystem
    private let filePolicy: ProtectedAtomicMetadataFilePolicy
    private let pricing: TranscriptionUsagePricing
    private let calendar: Calendar
    private let retentionDayCount: Int
    private let now: @Sendable () -> Date

    /// The containing-app composition root must create and retain exactly one
    /// repository actor for its Application Support directory.
    public init(applicationSupportDirectoryURL: URL) {
        fileURL = IOSTranscriptionUsageStorageLocation.fileURL(
            in: applicationSupportDirectoryURL
        )
        fileSystem = FoundationProtectedAtomicMetadataFileSystem()
        filePolicy = ProtectedAtomicMetadataFilePolicy(
            maximumByteCount: Self.maximumByteCount,
            fileProtection: .complete,
            excludesFromBackup: true
        )
        pricing = .current
        calendar = .autoupdatingCurrent
        retentionDayCount = Self.retentionDayCount
        now = { Date() }
    }

    init(
        fileURL: URL,
        fileSystem: any ProtectedAtomicMetadataFileSystem = FoundationProtectedAtomicMetadataFileSystem(),
        maximumByteCount: Int = IOSTranscriptionUsageRepository.maximumByteCount,
        pricing: TranscriptionUsagePricing = .current,
        calendar: Calendar = .autoupdatingCurrent,
        retentionDayCount: Int = IOSTranscriptionUsageRepository.retentionDayCount,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileURL = fileURL
        self.fileSystem = fileSystem
        self.filePolicy = ProtectedAtomicMetadataFilePolicy(
            maximumByteCount: maximumByteCount,
            fileProtection: .complete,
            excludesFromBackup: true
        )
        self.pricing = pricing
        self.calendar = calendar
        self.retentionDayCount = retentionDayCount
        self.now = now
    }

    public func load() throws -> [TranscriptionUsageEvent] {
        let referenceDate = now()
        guard referenceDate.timeIntervalSinceReferenceDate.isFinite else {
            throw IOSTranscriptionUsageRepositoryError.invalidTimestamp
        }
        return try loadAndCompact(referenceDate: referenceDate)
    }

    public func record(
        _ usage: SuccessfulTranscriptionUsage
    ) throws -> IOSTranscriptionUsageRecordResult {
        let timestamp = try IOSTranscriptionUsageTimestampCodec.canonicalDate(from: now())
        let storedEvents = try readStoredEvents() ?? []
        let retainedEvents = try retainedEvents(
            from: storedEvents,
            referenceDate: timestamp
        )

        if retainedEvents.contains(where: { $0.id == usage.transcriptionID }) {
            if retainedEvents.count != storedEvents.count {
                try persist(retainedEvents, failure: .compactionFailed)
            }
            return .duplicate
        }

        let event: TranscriptionUsageEvent
        do {
            event = try pricing.makeEvent(timestamp: timestamp, for: usage)
        } catch {
            throw IOSTranscriptionUsageRepositoryError.invalidEvent
        }

        let updatedEvents = Self.sortedNewestFirst([event] + retainedEvents)
        try persist(updatedEvents, failure: .writeFailed)
        return .inserted
    }

    public func reset() throws {
        do {
            try fileSystem.removeFileIfPresent(at: fileURL)
        } catch {
            throw IOSTranscriptionUsageRepositoryError.resetFailed
        }
    }

    private func loadAndCompact(referenceDate: Date) throws -> [TranscriptionUsageEvent] {
        guard let storedEvents = try readStoredEvents() else {
            return []
        }

        let retainedEvents = try retainedEvents(
            from: storedEvents,
            referenceDate: referenceDate
        )
        if storedEvents.isEmpty {
            try removeForCompaction()
            return []
        }
        guard retainedEvents.count != storedEvents.count else {
            return storedEvents
        }

        if retainedEvents.isEmpty {
            try removeForCompaction()
        } else {
            try persist(retainedEvents, failure: .compactionFailed)
        }

        return retainedEvents
    }

    private func removeForCompaction() throws {
        do {
            try fileSystem.removeFileIfPresent(at: fileURL)
        } catch {
            throw IOSTranscriptionUsageRepositoryError.compactionFailed
        }
    }

    private func retainedEvents(
        from events: [TranscriptionUsageEvent],
        referenceDate: Date
    ) throws -> [TranscriptionUsageEvent] {
        let cutoff = try retentionCutoff(referenceDate: referenceDate)
        return events.filter { $0.timestamp >= cutoff }
    }

    private func readStoredEvents() throws -> [TranscriptionUsageEvent]? {
        let data: Data?
        do {
            data = try fileSystem.readFileIfPresent(
                at: fileURL,
                policy: filePolicy
            )
        } catch ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded {
            throw IOSTranscriptionUsageRepositoryError.sourceTooLarge
        } catch {
            throw IOSTranscriptionUsageRepositoryError.readFailed
        }

        guard let data else {
            return nil
        }
        return try IOSTranscriptionUsageWireCodec.decode(data)
    }

    private func persist(
        _ events: [TranscriptionUsageEvent],
        failure: IOSTranscriptionUsageRepositoryError
    ) throws {
        let data: Data
        do {
            data = try IOSTranscriptionUsageWireCodec.encode(events)
        } catch let error as IOSTranscriptionUsageRepositoryError {
            if error == .encodingFailed {
                throw failure
            }
            throw error
        } catch {
            throw failure
        }

        guard data.count <= filePolicy.maximumByteCount else {
            if failure == .compactionFailed {
                throw IOSTranscriptionUsageRepositoryError.compactionFailed
            }
            throw IOSTranscriptionUsageRepositoryError.encodedDataTooLarge
        }

        do {
            try fileSystem.replaceFileAtomically(
                at: fileURL,
                with: data,
                policy: filePolicy
            )
        } catch ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded {
            if failure == .compactionFailed {
                throw IOSTranscriptionUsageRepositoryError.compactionFailed
            }
            throw IOSTranscriptionUsageRepositoryError.encodedDataTooLarge
        } catch {
            throw failure
        }
    }

    private func retentionCutoff(referenceDate: Date) throws -> Date {
        guard retentionDayCount > 0 else {
            throw IOSTranscriptionUsageRepositoryError.calendarCalculationFailed
        }
        let today = calendar.startOfDay(for: referenceDate)
        guard let cutoff = calendar.date(
            byAdding: .day,
            value: 1 - retentionDayCount,
            to: today
        ) else {
            throw IOSTranscriptionUsageRepositoryError.calendarCalculationFailed
        }
        return cutoff
    }

    private static func sortedNewestFirst(
        _ events: [TranscriptionUsageEvent]
    ) -> [TranscriptionUsageEvent] {
        events.sorted(by: isOrderedBefore)
    }

    fileprivate static func isOrderedBefore(
        _ lhs: TranscriptionUsageEvent,
        _ rhs: TranscriptionUsageEvent
    ) -> Bool {
        if lhs.timestamp != rhs.timestamp {
            return lhs.timestamp > rhs.timestamp
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private enum IOSTranscriptionUsageWireCodec {
    private static let supportedSchemaVersion = 1
    private static let rootFields: Set<String> = ["schemaVersion", "events"]
    private static let eventFields: Set<String> = [
        "id",
        "timestamp",
        "model",
        "durationSeconds",
        "priceUSDPerMinute",
        "estimatedCostUSD",
        "pricingSource",
    ]

    static func encode(_ events: [TranscriptionUsageEvent]) throws -> Data {
        let rows: [IOSTranscriptionUsageWireEventV1]
        do {
            rows = try events.map(IOSTranscriptionUsageWireEventV1.init(event:))
        } catch {
            throw IOSTranscriptionUsageRepositoryError.encodingFailed
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(
                IOSTranscriptionUsageWireRootV1(
                    schemaVersion: supportedSchemaVersion,
                    events: rows
                )
            )
        } catch {
            throw IOSTranscriptionUsageRepositoryError.encodingFailed
        }
    }

    static func decode(_ data: Data) throws -> [TranscriptionUsageEvent] {
        let rootValue: Any
        do {
            rootValue = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
        } catch {
            throw IOSTranscriptionUsageRepositoryError.malformedData
        }

        guard let root = rootValue as? [String: Any] else {
            throw IOSTranscriptionUsageRepositoryError.topLevelNotObject
        }
        guard root.keys.contains("schemaVersion") else {
            throw IOSTranscriptionUsageRepositoryError.missingSchemaVersion
        }
        guard Set(root.keys) == rootFields else {
            throw IOSTranscriptionUsageRepositoryError.invalidRootFields
        }
        guard let schemaVersion = integer(root["schemaVersion"]),
              schemaVersion == supportedSchemaVersion else {
            if integer(root["schemaVersion"]) == nil {
                throw IOSTranscriptionUsageRepositoryError.invalidFieldType
            }
            throw IOSTranscriptionUsageRepositoryError.unsupportedSchemaVersion
        }
        guard let eventObjects = root["events"] as? [Any] else {
            throw IOSTranscriptionUsageRepositoryError.invalidFieldType
        }

        var events: [TranscriptionUsageEvent] = []
        events.reserveCapacity(eventObjects.count)
        var identifiers: Set<UUID> = []

        for eventValue in eventObjects {
            guard let object = eventValue as? [String: Any] else {
                throw IOSTranscriptionUsageRepositoryError.invalidFieldType
            }
            guard Set(object.keys) == eventFields else {
                throw IOSTranscriptionUsageRepositoryError.invalidEventFields
            }

            let event = try decodeEvent(object)
            guard identifiers.insert(event.id).inserted else {
                throw IOSTranscriptionUsageRepositoryError.duplicateIdentifier
            }
            if let previous = events.last,
               !IOSTranscriptionUsageRepository.isOrderedBefore(previous, event) {
                throw IOSTranscriptionUsageRepositoryError.invalidEventOrder
            }
            events.append(event)
        }

        return events
    }

    private static func decodeEvent(
        _ object: [String: Any]
    ) throws -> TranscriptionUsageEvent {
        guard let identifierString = object["id"] as? String,
              let identifier = UUID(uuidString: identifierString),
              identifier.uuidString == identifierString else {
            throw IOSTranscriptionUsageRepositoryError.invalidIdentifier
        }
        guard let timestampString = object["timestamp"] as? String else {
            throw IOSTranscriptionUsageRepositoryError.invalidFieldType
        }
        let timestamp = try IOSTranscriptionUsageTimestampCodec.date(
            fromCanonicalString: timestampString
        )
        guard let model = object["model"] as? String,
              let duration = number(object["durationSeconds"]) else {
            throw IOSTranscriptionUsageRepositoryError.invalidFieldType
        }
        let price = try optionalNumber(object["priceUSDPerMinute"])
        let cost = try optionalNumber(object["estimatedCostUSD"])
        let source = try optionalString(object["pricingSource"])

        let event: TranscriptionUsageEvent
        do {
            event = try TranscriptionUsageEvent(
                id: identifier,
                timestamp: timestamp,
                model: model,
                durationSeconds: duration,
                priceUSDPerMinute: price,
                estimatedCostUSD: cost,
                pricingSource: source
            )
        } catch {
            throw IOSTranscriptionUsageRepositoryError.invalidEvent
        }
        guard event.model == model,
              event.pricingSource == source else {
            throw IOSTranscriptionUsageRepositoryError.invalidEvent
        }
        return event
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        let objectiveCType = String(cString: number.objCType)
        guard objectiveCType != "f", objectiveCType != "d" else {
            return nil
        }
        let string = number.stringValue
        guard let integer = Int(string), String(integer) == string else {
            return nil
        }
        return integer
    }

    private static func number(_ value: Any?) -> Double? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return nil
        }
        return number.doubleValue
    }

    private static func optionalNumber(_ value: Any?) throws -> Double? {
        guard let value else {
            throw IOSTranscriptionUsageRepositoryError.invalidEventFields
        }
        if value is NSNull {
            return nil
        }
        guard let number = number(value) else {
            throw IOSTranscriptionUsageRepositoryError.invalidFieldType
        }
        return number
    }

    private static func optionalString(_ value: Any?) throws -> String? {
        guard let value else {
            throw IOSTranscriptionUsageRepositoryError.invalidEventFields
        }
        if value is NSNull {
            return nil
        }
        guard let string = value as? String else {
            throw IOSTranscriptionUsageRepositoryError.invalidFieldType
        }
        return string
    }
}

private struct IOSTranscriptionUsageWireRootV1: Encodable {
    let schemaVersion: Int
    let events: [IOSTranscriptionUsageWireEventV1]
}

private struct IOSTranscriptionUsageWireEventV1: Encodable {
    private enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case model
        case durationSeconds
        case priceUSDPerMinute
        case estimatedCostUSD
        case pricingSource
    }

    let id: String
    let timestamp: String
    let model: String
    let durationSeconds: TimeInterval
    let priceUSDPerMinute: Double?
    let estimatedCostUSD: Double?
    let pricingSource: String?

    init(event: TranscriptionUsageEvent) throws {
        id = event.id.uuidString
        timestamp = try IOSTranscriptionUsageTimestampCodec.canonicalString(
            from: event.timestamp
        )
        model = event.model
        durationSeconds = event.durationSeconds
        priceUSDPerMinute = event.priceUSDPerMinute
        estimatedCostUSD = event.estimatedCostUSD
        pricingSource = event.pricingSource
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(model, forKey: .model)
        try container.encode(durationSeconds, forKey: .durationSeconds)
        if let priceUSDPerMinute {
            try container.encode(priceUSDPerMinute, forKey: .priceUSDPerMinute)
        } else {
            try container.encodeNil(forKey: .priceUSDPerMinute)
        }
        if let estimatedCostUSD {
            try container.encode(estimatedCostUSD, forKey: .estimatedCostUSD)
        } else {
            try container.encodeNil(forKey: .estimatedCostUSD)
        }
        if let pricingSource {
            try container.encode(pricingSource, forKey: .pricingSource)
        } else {
            try container.encodeNil(forKey: .pricingSource)
        }
    }
}

private enum IOSTranscriptionUsageTimestampCodec {
    private static let dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"

    static func canonicalDate(from date: Date) throws -> Date {
        let string = try canonicalString(from: date)
        return try self.date(fromCanonicalString: string)
    }

    static func canonicalString(from date: Date) throws -> String {
        guard date.timeIntervalSinceReferenceDate.isFinite else {
            throw IOSTranscriptionUsageRepositoryError.invalidTimestamp
        }
        let string = formatter().string(from: date)
        guard hasCanonicalShape(string),
              let decoded = formatter().date(from: string),
              decoded.timeIntervalSinceReferenceDate.isFinite,
              formatter().string(from: decoded) == string else {
            throw IOSTranscriptionUsageRepositoryError.invalidTimestamp
        }
        return string
    }

    static func date(fromCanonicalString string: String) throws -> Date {
        let dateFormatter = formatter()
        guard hasCanonicalShape(string),
              let date = dateFormatter.date(from: string),
              date.timeIntervalSinceReferenceDate.isFinite,
              dateFormatter.string(from: date) == string else {
            throw IOSTranscriptionUsageRepositoryError.invalidTimestamp
        }
        return date
    }

    private static func hasCanonicalShape(_ string: String) -> Bool {
        let bytes = Array(string.utf8)
        guard bytes.count == 24,
              bytes[4] == 45,
              bytes[7] == 45,
              bytes[10] == 84,
              bytes[13] == 58,
              bytes[16] == 58,
              bytes[19] == 46,
              bytes[23] == 90 else {
            return false
        }

        let digitPositions = Array(0...3) + [5, 6, 8, 9, 11, 12, 14, 15, 17, 18, 20, 21, 22]
        guard digitPositions.allSatisfy({ (48...57).contains(bytes[$0]) }),
              let year = Int(String(decoding: bytes[0...3], as: UTF8.self)),
              (1...9_999).contains(year) else {
            return false
        }
        return true
    }

    private static func formatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = dateFormat
        formatter.isLenient = false
        return formatter
    }
}
