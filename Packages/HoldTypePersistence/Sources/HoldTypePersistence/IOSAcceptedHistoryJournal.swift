import CoreFoundation
import Foundation
import HoldTypeDomain

struct IOSAcceptedHistoryJournalSnapshot: Equatable, Sendable {
    let envelope: IOSAcceptedHistoryEnvelope
    let fileRevision: IOSStrictProtectedRecordFileRevision
}

protocol IOSAcceptedHistoryJournalStoring: Sendable {
    func load() throws -> IOSAcceptedHistoryJournalSnapshot?
    func create(
        _ envelope: IOSAcceptedHistoryEnvelope,
        authorization: IOSAcceptedHistoryJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryJournalSnapshot
    func replace(
        _ envelope: IOSAcceptedHistoryEnvelope,
        expected: IOSAcceptedHistoryJournalSnapshot,
        authorization: IOSAcceptedHistoryJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryJournalSnapshot
    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport
}

enum IOSAcceptedHistoryJournal {
    static let maximumByteCount = 4_194_304
}

struct FoundationIOSAcceptedHistoryJournalRepository:
    IOSAcceptedHistoryJournalStoring,
    Sendable {
    private let fileSystem: any IOSStrictProtectedRecordFileSystem
    private let stagingMaintenance: @Sendable (Date) throws
        -> IOSStrictProtectedRecordMaintenanceReport

    init(
        applicationSupportDirectoryURL: URL,
        repositoryGuard:
            IOSAcceptedHistoryCoordinatorRepositoryGuard? = nil
    ) {
        let fileSystem = FoundationIOSStrictProtectedRecordFileSystem(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            configuration: .acceptedHistory,
            expectedRepositoryRoot:
                repositoryGuard?.expectedPhysicalRootIdentity,
            onRepositoryIdentityMismatch: {
                repositoryGuard?.invalidate()
            }
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

    func load() throws -> IOSAcceptedHistoryJournalSnapshot? {
        guard let file = try readFile() else { return nil }
        return IOSAcceptedHistoryJournalSnapshot(
            envelope: try IOSAcceptedHistoryWireCodec.decode(file.data),
            fileRevision: file.revision
        )
    }

    func create(
        _ envelope: IOSAcceptedHistoryEnvelope,
        authorization: IOSAcceptedHistoryJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryJournalSnapshot {
        _ = authorization
        let data = try IOSAcceptedHistoryWireCodec.encode(envelope)
        do {
            let revision = try fileSystem.createFile(with: data)
            return IOSAcceptedHistoryJournalSnapshot(
                envelope: envelope,
                fileRevision: revision
            )
        } catch IOSStrictProtectedRecordFileSystemError.destinationConflict {
            throw IOSAcceptedHistoryError.slotOccupied
        } catch IOSStrictProtectedRecordFileSystemError.protectedDataUnavailable {
            throw IOSAcceptedHistoryError.dataProtectionUnavailable
        } catch IOSStrictProtectedRecordFileSystemError.commitUncertain {
            throw IOSAcceptedHistoryError.commitUncertain
        } catch {
            throw IOSAcceptedHistoryError.writeFailed
        }
    }

    func replace(
        _ envelope: IOSAcceptedHistoryEnvelope,
        expected: IOSAcceptedHistoryJournalSnapshot,
        authorization: IOSAcceptedHistoryJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryJournalSnapshot {
        _ = authorization
        let data = try IOSAcceptedHistoryWireCodec.encode(envelope)
        do {
            let revision = try fileSystem.replaceFile(
                with: data,
                expected: expected.fileRevision
            )
            return IOSAcceptedHistoryJournalSnapshot(
                envelope: envelope,
                fileRevision: revision
            )
        } catch IOSStrictProtectedRecordFileSystemError.staleRevision,
                IOSStrictProtectedRecordFileSystemError.missing {
            throw IOSAcceptedHistoryError.compareAndSwapFailed
        } catch IOSStrictProtectedRecordFileSystemError.protectedDataUnavailable {
            throw IOSAcceptedHistoryError.dataProtectionUnavailable
        } catch IOSStrictProtectedRecordFileSystemError.commitUncertain {
            throw IOSAcceptedHistoryError.commitUncertain
        } catch {
            throw IOSAcceptedHistoryError.writeFailed
        }
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport {
        do {
            return try stagingMaintenance(now)
        } catch IOSStrictProtectedRecordFileSystemError.protectedDataUnavailable {
            throw IOSAcceptedHistoryError.dataProtectionUnavailable
        } catch {
            throw IOSAcceptedHistoryError.maintenanceFailed
        }
    }

    private func readFile() throws -> IOSStrictProtectedRecordFile? {
        do {
            return try fileSystem.readFileIfPresent()
        } catch IOSStrictProtectedRecordFileSystemError.sourceTooLarge {
            throw IOSAcceptedHistoryError.sourceTooLarge
        } catch IOSStrictProtectedRecordFileSystemError.protectedDataUnavailable {
            throw IOSAcceptedHistoryError.dataProtectionUnavailable
        } catch {
            throw IOSAcceptedHistoryError.readFailed
        }
    }
}

enum IOSAcceptedHistoryWireCodec {
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
        "policyGeneration",
        "transcriptionModel",
        "transcriptionLanguageCode",
        "durationMilliseconds",
        "cachedAudioRelativeIdentifier",
    ]

    static func encode(_ envelope: IOSAcceptedHistoryEnvelope) throws -> Data {
        let data = try encodedData(envelope)
        guard data.count <= IOSAcceptedHistoryJournal.maximumByteCount else {
            throw IOSAcceptedHistoryError.writeFailed
        }
        return data
    }

    static func isWithinEncodedLimit(
        _ envelope: IOSAcceptedHistoryEnvelope
    ) throws -> Bool {
        try encodedData(envelope).count
            <= IOSAcceptedHistoryJournal.maximumByteCount
    }

    static func decode(_ data: Data) throws -> IOSAcceptedHistoryEnvelope {
        do {
            try BoundedJSONMemberValidator.validate(
                data,
                limits: BoundedJSONMemberValidationLimits(
                    maximumInputByteCount:
                        IOSAcceptedHistoryJournal.maximumByteCount,
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
            throw IOSAcceptedHistoryError.sourceTooLarge
        } catch {
            throw IOSAcceptedHistoryError.malformedData
        }

        let root: Any
        do {
            root = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            )
        } catch {
            throw IOSAcceptedHistoryError.malformedData
        }
        guard let object = root as? [String: Any] else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        let reader = IOSAcceptedHistoryObjectReader(object: object)
        guard try reader.integer64("schemaVersion") == supportedSchemaVersion else {
            throw IOSAcceptedHistoryError.unsupportedSchemaVersion
        }
        guard Set(object.keys) == rootFields else {
            throw IOSAcceptedHistoryError.invalidRecord
        }

        let rawEntries = try reader.objectArray("entries")
        guard rawEntries.count <= IOSAcceptedHistoryValidation.maximumEntryCount
        else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        let entries = try rawEntries.map(decodeEntry)
        do {
            return try IOSAcceptedHistoryEnvelope(
                revision: reader.integer64("revision"),
                entries: entries
            )
        } catch {
            throw IOSAcceptedHistoryError.invalidRecord
        }
    }

    private static func encodedData(
        _ envelope: IOSAcceptedHistoryEnvelope
    ) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(
                IOSAcceptedHistoryWireV1(envelope: envelope)
            )
        } catch {
            throw IOSAcceptedHistoryError.writeFailed
        }
    }

    private static func decodeEntry(
        _ object: [String: Any]
    ) throws -> IOSAcceptedHistoryEntry {
        guard Set(object.keys) == entryFields else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        let reader = IOSAcceptedHistoryObjectReader(object: object)
        do {
            return try IOSAcceptedHistoryEntry(
                deliveryID: canonicalUUID(reader.string("deliveryID")),
                transcriptID: canonicalUUID(reader.string("transcriptID")),
                acceptedText: reader.string("acceptedText"),
                outputIntent: decodeOutputIntent(reader.string("outputIntent")),
                createdAt: IOSAcceptedOutputDeliveryTimestampCodec.date(
                    from: reader.string("createdAt")
                ),
                policyGeneration: reader.integer64("policyGeneration"),
                transcriptionModel: reader.string("transcriptionModel"),
                transcriptionLanguageCode: reader.nullableString(
                    "transcriptionLanguageCode"
                ),
                durationMilliseconds: reader.nullableInteger64(
                    "durationMilliseconds"
                ),
                cachedAudioRelativeIdentifier: reader.nullableString(
                    "cachedAudioRelativeIdentifier"
                )
            )
        } catch {
            throw IOSAcceptedHistoryError.invalidRecord
        }
    }

    private static func canonicalUUID(_ value: String) throws -> UUID {
        guard let identifier = UUID(uuidString: value),
              value == identifier.uuidString.lowercased() else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        return identifier
    }

    private static func decodeOutputIntent(
        _ value: String
    ) throws -> DictationOutputIntent {
        guard let intent = DictationOutputIntent(rawValue: value) else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        return intent
    }
}

private struct IOSAcceptedHistoryObjectReader {
    let object: [String: Any]

    func string(_ key: String) throws -> String {
        guard let value = object[key] as? String else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        return value
    }

    func nullableString(_ key: String) throws -> String? {
        guard let value = object[key] else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        if value is NSNull { return nil }
        guard let value = value as? String else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        return value
    }

    func integer64(_ key: String) throws -> Int64 {
        guard let value = object[key] as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID(),
              !Self.isFloatingPoint(value),
              let integer = Int64(value.stringValue) else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        return integer
    }

    func nullableInteger64(_ key: String) throws -> Int64? {
        guard let value = object[key] else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        if value is NSNull { return nil }
        return try integer64(key)
    }

    func objectArray(_ key: String) throws -> [[String: Any]] {
        guard let value = object[key] as? [Any] else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        return try value.map { entry in
            guard let object = entry as? [String: Any] else {
                throw IOSAcceptedHistoryError.invalidRecord
            }
            return object
        }
    }

    private static func isFloatingPoint(_ number: NSNumber) -> Bool {
        let type = String(cString: number.objCType)
        return type == "f" || type == "d"
    }
}

private struct IOSAcceptedHistoryWireV1: Encodable {
    let schemaVersion = 1
    let revision: Int64
    let entries: [Entry]

    init(envelope: IOSAcceptedHistoryEnvelope) throws {
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
        let policyGeneration: Int64
        let transcriptionModel: String
        let transcriptionLanguageCode: String?
        let durationMilliseconds: Int64?
        let cachedAudioRelativeIdentifier: String?

        init(_ entry: IOSAcceptedHistoryEntry) throws {
            deliveryID = IOSAcceptedHistoryValidation.canonicalIdentifier(
                entry.deliveryID
            )
            transcriptID = IOSAcceptedHistoryValidation.canonicalIdentifier(
                entry.transcriptID
            )
            acceptedText = entry.acceptedText
            outputIntent = entry.outputIntent.rawValue
            createdAt = try IOSAcceptedOutputDeliveryTimestampCodec.string(
                from: entry.createdAt
            )
            policyGeneration = entry.policyGeneration
            transcriptionModel = entry.transcriptionModel
            transcriptionLanguageCode = entry.transcriptionLanguageCode
            durationMilliseconds = entry.durationMilliseconds
            cachedAudioRelativeIdentifier =
                entry.cachedAudioRelativeIdentifier
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(deliveryID, forKey: .deliveryID)
            try container.encode(transcriptID, forKey: .transcriptID)
            try container.encode(acceptedText, forKey: .acceptedText)
            try container.encode(outputIntent, forKey: .outputIntent)
            try container.encode(createdAt, forKey: .createdAt)
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
            if let cachedAudioRelativeIdentifier {
                try container.encode(
                    cachedAudioRelativeIdentifier,
                    forKey: .cachedAudioRelativeIdentifier
                )
            } else {
                try container.encodeNil(
                    forKey: .cachedAudioRelativeIdentifier
                )
            }
        }

        private enum CodingKeys: String, CodingKey {
            case deliveryID
            case transcriptID
            case acceptedText
            case outputIntent
            case createdAt
            case policyGeneration
            case transcriptionModel
            case transcriptionLanguageCode
            case durationMilliseconds
            case cachedAudioRelativeIdentifier
        }
    }
}
