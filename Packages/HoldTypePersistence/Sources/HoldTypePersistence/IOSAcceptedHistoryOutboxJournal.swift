import CoreFoundation
import Foundation
import HoldTypeDomain

struct IOSAcceptedHistoryOutboxJournalSnapshot: Equatable, Sendable {
    let envelope: IOSAcceptedHistoryOutboxEnvelope
    let fileRevision: IOSStrictProtectedRecordFileRevision
}

protocol IOSAcceptedHistoryOutboxJournalStoring: Sendable {
    func load() throws -> IOSAcceptedHistoryOutboxJournalSnapshot?
    func create(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope,
        authorization: IOSAcceptedHistoryOutboxJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryOutboxJournalSnapshot
    func replace(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope,
        expected: IOSAcceptedHistoryOutboxJournalSnapshot,
        authorization: IOSAcceptedHistoryOutboxJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryOutboxJournalSnapshot
    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport
}

enum IOSAcceptedHistoryOutboxJournal {
    static let maximumByteCount = 4_194_304
}

struct FoundationIOSAcceptedHistoryOutboxJournalRepository:
    IOSAcceptedHistoryOutboxJournalStoring,
    Sendable {
    private let fileSystem: any IOSStrictProtectedRecordFileSystem
    private let stagingMaintenance: @Sendable (Date) throws
        -> IOSStrictProtectedRecordMaintenanceReport

    init(applicationSupportDirectoryURL: URL) {
        let fileSystem = FoundationIOSStrictProtectedRecordFileSystem(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            configuration: .acceptedHistoryOutbox
        )
        self.fileSystem = fileSystem
        stagingMaintenance = { now in
            try fileSystem.removeAbandonedTemporaryFiles(now: now)
        }
    }

    init(
        fileSystem: any IOSStrictProtectedRecordFileSystem,
        stagingMaintenance: @escaping @Sendable (Date) throws
            -> IOSStrictProtectedRecordMaintenanceReport = { _ in .empty }
    ) {
        self.fileSystem = fileSystem
        self.stagingMaintenance = stagingMaintenance
    }

    func load() throws -> IOSAcceptedHistoryOutboxJournalSnapshot? {
        guard let file = try readFile() else { return nil }
        return IOSAcceptedHistoryOutboxJournalSnapshot(
            envelope: try IOSAcceptedHistoryOutboxWireCodec.decode(file.data),
            fileRevision: file.revision
        )
    }

    func create(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope,
        authorization: IOSAcceptedHistoryOutboxJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryOutboxJournalSnapshot {
        _ = authorization
        let data = try IOSAcceptedHistoryOutboxWireCodec.encode(envelope)
        do {
            let revision = try fileSystem.createFile(with: data)
            return IOSAcceptedHistoryOutboxJournalSnapshot(
                envelope: envelope,
                fileRevision: revision
            )
        } catch IOSStrictProtectedRecordFileSystemError.destinationConflict {
            throw IOSAcceptedHistoryOutboxError.slotOccupied
        } catch IOSStrictProtectedRecordFileSystemError.protectedDataUnavailable {
            throw IOSAcceptedHistoryOutboxError.dataProtectionUnavailable
        } catch IOSStrictProtectedRecordFileSystemError.commitUncertain {
            throw IOSAcceptedHistoryOutboxError.commitUncertain
        } catch {
            throw IOSAcceptedHistoryOutboxError.writeFailed
        }
    }

    func replace(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope,
        expected: IOSAcceptedHistoryOutboxJournalSnapshot,
        authorization: IOSAcceptedHistoryOutboxJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryOutboxJournalSnapshot {
        _ = authorization
        let data = try IOSAcceptedHistoryOutboxWireCodec.encode(envelope)
        do {
            let revision = try fileSystem.replaceFile(
                with: data,
                expected: expected.fileRevision
            )
            return IOSAcceptedHistoryOutboxJournalSnapshot(
                envelope: envelope,
                fileRevision: revision
            )
        } catch IOSStrictProtectedRecordFileSystemError.staleRevision,
                IOSStrictProtectedRecordFileSystemError.missing {
            throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
        } catch IOSStrictProtectedRecordFileSystemError.protectedDataUnavailable {
            throw IOSAcceptedHistoryOutboxError.dataProtectionUnavailable
        } catch IOSStrictProtectedRecordFileSystemError.commitUncertain {
            throw IOSAcceptedHistoryOutboxError.commitUncertain
        } catch {
            throw IOSAcceptedHistoryOutboxError.writeFailed
        }
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport {
        do {
            return try stagingMaintenance(now)
        } catch IOSStrictProtectedRecordFileSystemError.protectedDataUnavailable {
            throw IOSAcceptedHistoryOutboxError.dataProtectionUnavailable
        } catch {
            throw IOSAcceptedHistoryOutboxError.maintenanceFailed
        }
    }

    private func readFile() throws -> IOSStrictProtectedRecordFile? {
        do {
            return try fileSystem.readFileIfPresent()
        } catch IOSStrictProtectedRecordFileSystemError.sourceTooLarge {
            throw IOSAcceptedHistoryOutboxError.sourceTooLarge
        } catch IOSStrictProtectedRecordFileSystemError.protectedDataUnavailable {
            throw IOSAcceptedHistoryOutboxError.dataProtectionUnavailable
        } catch {
            throw IOSAcceptedHistoryOutboxError.readFailed
        }
    }
}

enum IOSAcceptedHistoryOutboxWireCodec {
    private static let supportedSchemaVersion: Int64 = 1
    private static let rootFields: Set<String> = [
        "schemaVersion", "revision", "entries",
    ]
    private static let entryFields: Set<String> = [
        "deliveryID",
        "transcriptID",
        "acceptedText",
        "outputIntent",
        "createdAt",
        "expiresAt",
        "policyGeneration",
        "transcriptionModel",
        "transcriptionLanguageCode",
        "durationMilliseconds",
    ]

    static func encode(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope
    ) throws -> Data {
        let data = try encodedData(envelope)
        guard data.count <= IOSAcceptedHistoryOutboxJournal.maximumByteCount else {
            throw IOSAcceptedHistoryOutboxError.writeFailed
        }
        return data
    }

    static func isWithinEncodedLimit(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope
    ) throws -> Bool {
        try encodedData(envelope).count
            <= IOSAcceptedHistoryOutboxJournal.maximumByteCount
    }

    static func decode(
        _ data: Data
    ) throws -> IOSAcceptedHistoryOutboxEnvelope {
        do {
            try BoundedJSONMemberValidator.validate(
                data,
                limits: BoundedJSONMemberValidationLimits(
                    maximumInputByteCount:
                        IOSAcceptedHistoryOutboxJournal.maximumByteCount,
                    maximumNestingDepth: 3,
                    maximumMembersPerObject: 32,
                    maximumTotalObjectMembers: 512,
                    maximumElementsPerArray: 32,
                    maximumTotalValues: 600,
                    maximumDecodedKeyByteCount: 64,
                    maximumDecodedValueStringByteCount:
                        IOSAcceptedOutputDeliveryValidation
                            .maximumAcceptedTextByteCount,
                    maximumNumberTokenByteCount: 20
                )
            )
        } catch BoundedJSONMemberValidationError.inputTooLarge {
            throw IOSAcceptedHistoryOutboxError.sourceTooLarge
        } catch {
            throw IOSAcceptedHistoryOutboxError.malformedData
        }

        let root: Any
        do {
            root = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
        } catch {
            throw IOSAcceptedHistoryOutboxError.malformedData
        }
        guard let object = root as? [String: Any] else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        let reader = IOSAcceptedHistoryOutboxObjectReader(object: object)
        guard try reader.integer64("schemaVersion") == supportedSchemaVersion else {
            throw IOSAcceptedHistoryOutboxError.unsupportedSchemaVersion
        }
        guard Set(object.keys) == rootFields else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        let rawEntries = try reader.objectArray("entries")
        guard rawEntries.count
                <= IOSAcceptedHistoryOutboxValidation.maximumEntryCount else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        let entries = try rawEntries.map(decodeEntry)
        do {
            return try IOSAcceptedHistoryOutboxEnvelope(
                revision: reader.integer64("revision"),
                entries: entries
            )
        } catch {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
    }

    private static func encodedData(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(
                IOSAcceptedHistoryOutboxWireV1(envelope: envelope)
            )
        } catch {
            throw IOSAcceptedHistoryOutboxError.writeFailed
        }
    }

    private static func decodeEntry(
        _ object: [String: Any]
    ) throws -> IOSAcceptedHistoryOutboxEntry {
        guard Set(object.keys) == entryFields else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        let reader = IOSAcceptedHistoryOutboxObjectReader(object: object)
        do {
            return try IOSAcceptedHistoryOutboxEntry(
                deliveryID: canonicalUUID(reader.string("deliveryID")),
                transcriptID: canonicalUUID(reader.string("transcriptID")),
                acceptedText: reader.string("acceptedText"),
                outputIntent: decodeOutputIntent(reader.string("outputIntent")),
                createdAt: IOSAcceptedOutputDeliveryTimestampCodec.date(
                    from: reader.string("createdAt")
                ),
                expiresAt: IOSAcceptedOutputDeliveryTimestampCodec.date(
                    from: reader.string("expiresAt")
                ),
                policyGeneration: reader.integer64("policyGeneration"),
                transcriptionModel: reader.string("transcriptionModel"),
                transcriptionLanguageCode: reader.nullableString(
                    "transcriptionLanguageCode"
                ),
                durationMilliseconds: reader.nullableInteger64(
                    "durationMilliseconds"
                )
            )
        } catch {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
    }

    private static func canonicalUUID(_ value: String) throws -> UUID {
        guard let identifier = UUID(uuidString: value),
              value == identifier.uuidString.lowercased() else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        return identifier
    }

    private static func decodeOutputIntent(
        _ value: String
    ) throws -> DictationOutputIntent {
        guard let intent = DictationOutputIntent(rawValue: value) else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        return intent
    }
}

private struct IOSAcceptedHistoryOutboxObjectReader {
    let object: [String: Any]

    func string(_ key: String) throws -> String {
        guard let value = object[key] as? String else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        return value
    }

    func nullableString(_ key: String) throws -> String? {
        guard let value = object[key] else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        if value is NSNull { return nil }
        guard let value = value as? String else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        return value
    }

    func integer64(_ key: String) throws -> Int64 {
        guard let value = object[key] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              !Self.isFloatingPoint(value),
              let integer = Int64(value.stringValue) else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        return integer
    }

    func nullableInteger64(_ key: String) throws -> Int64? {
        guard let value = object[key] else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        if value is NSNull { return nil }
        return try integer64(key)
    }

    func objectArray(_ key: String) throws -> [[String: Any]] {
        guard let value = object[key] as? [Any] else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        return try value.map { element in
            guard let object = element as? [String: Any] else {
                throw IOSAcceptedHistoryOutboxError.invalidRecord
            }
            return object
        }
    }

    private static func isFloatingPoint(_ number: NSNumber) -> Bool {
        let type = String(cString: number.objCType)
        return type == "f" || type == "d"
    }
}

private struct IOSAcceptedHistoryOutboxWireV1: Encodable {
    let schemaVersion = 1
    let revision: Int64
    let entries: [Entry]

    init(envelope: IOSAcceptedHistoryOutboxEnvelope) throws {
        revision = envelope.revision
        entries = try envelope.entries.map(Entry.init)
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case revision
        case entries
    }

    struct Entry: Encodable {
        let deliveryID: String
        let transcriptID: String
        let acceptedText: String
        let outputIntent: String
        let createdAt: String
        let expiresAt: String
        let policyGeneration: Int64
        let transcriptionModel: String
        let transcriptionLanguageCode: String?
        let durationMilliseconds: Int64?

        init(_ entry: IOSAcceptedHistoryOutboxEntry) throws {
            deliveryID = IOSAcceptedHistoryOutboxValidation
                .canonicalIdentifier(entry.deliveryID)
            transcriptID = IOSAcceptedHistoryOutboxValidation
                .canonicalIdentifier(entry.transcriptID)
            acceptedText = entry.acceptedText
            outputIntent = entry.outputIntent.rawValue
            createdAt = try IOSAcceptedOutputDeliveryTimestampCodec.string(
                from: entry.createdAt
            )
            expiresAt = try IOSAcceptedOutputDeliveryTimestampCodec.string(
                from: entry.expiresAt
            )
            policyGeneration = entry.policyGeneration
            transcriptionModel = entry.transcriptionModel
            transcriptionLanguageCode = entry.transcriptionLanguageCode
            durationMilliseconds = entry.durationMilliseconds
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(deliveryID, forKey: .deliveryID)
            try container.encode(transcriptID, forKey: .transcriptID)
            try container.encode(acceptedText, forKey: .acceptedText)
            try container.encode(outputIntent, forKey: .outputIntent)
            try container.encode(createdAt, forKey: .createdAt)
            try container.encode(expiresAt, forKey: .expiresAt)
            try container.encode(
                policyGeneration,
                forKey: .policyGeneration
            )
            try container.encode(
                transcriptionModel,
                forKey: .transcriptionModel
            )
            if let transcriptionLanguageCode {
                try container.encode(
                    transcriptionLanguageCode,
                    forKey: .transcriptionLanguageCode
                )
            } else {
                try container.encodeNil(forKey: .transcriptionLanguageCode)
            }
            if let durationMilliseconds {
                try container.encode(
                    durationMilliseconds,
                    forKey: .durationMilliseconds
                )
            } else {
                try container.encodeNil(forKey: .durationMilliseconds)
            }
        }

        private enum CodingKeys: String, CodingKey {
            case deliveryID
            case transcriptID
            case acceptedText
            case outputIntent
            case createdAt
            case expiresAt
            case policyGeneration
            case transcriptionModel
            case transcriptionLanguageCode
            case durationMilliseconds
        }
    }
}
