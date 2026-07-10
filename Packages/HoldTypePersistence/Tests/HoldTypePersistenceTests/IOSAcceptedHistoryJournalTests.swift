import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSAcceptedHistoryJournalTests {
    @Test func canonicalV1HasExactRootAndRowFieldsAndExplicitNulls() throws {
        let entry = try historyWireEntry()
        let envelope = try IOSAcceptedHistoryEnvelope(
            revision: 7,
            entries: [entry]
        )
        let data = try IOSAcceptedHistoryWireCodec.encode(envelope)
        let root = try #require(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        #expect(Set(root.keys) == ["schemaVersion", "revision", "entries"])
        #expect(root["schemaVersion"] as? Int == 1)
        #expect(root["revision"] as? Int == 7)
        let entries = try #require(root["entries"] as? [[String: Any]])
        let row = try #require(entries.first)
        #expect(Set(row.keys) == [
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
        ])
        #expect(row["deliveryID"] as? String == entry.deliveryID.uuidString.lowercased())
        #expect(row["transcriptionLanguageCode"] is NSNull)
        #expect(row["durationMilliseconds"] is NSNull)
        #expect(row["cachedAudioRelativeIdentifier"] is NSNull)
        #expect(try IOSAcceptedHistoryWireCodec.decode(data) == envelope)
    }

    @Test func nonnullCacheIdentifierAndMaximumTextRoundTripExactly() throws {
        let text = "a" + String(repeating: "\t", count: 131_070) + "b"
        #expect(text.utf8.count == 131_072)
        let entry = try historyWireEntry(
            acceptedText: text,
            transcriptionLanguageCode: "eng",
            durationMilliseconds: 299_999,
            cachedAudioRelativeIdentifier: "cache/2026/audio.m4a"
        )
        let envelope = try IOSAcceptedHistoryEnvelope(
            revision: 1,
            entries: [entry]
        )

        let decoded = try IOSAcceptedHistoryWireCodec.decode(
            IOSAcceptedHistoryWireCodec.encode(envelope)
        )
        #expect(
            decoded.entries[0].acceptedText.utf8.elementsEqual(text.utf8)
        )
        #expect(
            decoded.entries[0].cachedAudioRelativeIdentifier
                == "cache/2026/audio.m4a"
        )
    }

    @Test func schemaDispatchPrecedesV1Allowlists() throws {
        let future = Data(
            """
            {"schemaVersion":2,"revision":1,"entries":[],"future":"value"}
            """.utf8
        )
        #expect(throws: IOSAcceptedHistoryError.unsupportedSchemaVersion) {
            _ = try IOSAcceptedHistoryWireCodec.decode(future)
        }
        #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
            _ = try IOSAcceptedHistoryWireCodec.decode(
                Data(
                    """
                    {"schemaVersion":1,"revision":1,"entries":[],"future":"value"}
                    """.utf8
                )
            )
        }
    }

    @Test func duplicateUnknownMissingAndNumericAliasesAreRejected() {
        let sources = [
            #"""
            {"schemaVersion":1,"schema\u0056ersion":1,"revision":1,"entries":[]}
            """#,
            """
            {"schemaVersion":1,"revision":1.0,"entries":[]}
            """,
            """
            {"schemaVersion":1,"revision":1e0,"entries":[]}
            """,
            """
            {"schemaVersion":true,"revision":1,"entries":[]}
            """,
            """
            {"schemaVersion":1,"entries":[]}
            """,
            """
            {"schemaVersion":1,"revision":1,"entries":[null]}
            """,
        ]
        for source in sources {
            #expect(throws: (any Error).self) {
                _ = try IOSAcceptedHistoryWireCodec.decode(Data(source.utf8))
            }
        }
    }

    @Test func rowShapeCanonicalUUIDDateEnumsAndNullsAreStrict() throws {
        let canonical = String(
            decoding: try IOSAcceptedHistoryWireCodec.encode(
                IOSAcceptedHistoryEnvelope(
                    revision: 1,
                    entries: [try historyWireEntry()]
                )
            ),
            as: UTF8.self
        )
        let mutations = [
            canonical.replacingOccurrences(
                of: "00000000-0000-4000-8000-000000000001",
                with: "00000000-0000-4000-8000-00000000000A"
            ),
            canonical.replacingOccurrences(
                of: "2030-01-19T07:00:00.000Z",
                with: "2030-01-19T07:00:00Z"
            ),
            canonical.replacingOccurrences(
                of: "\"standard\"",
                with: "\"unknown\""
            ),
            canonical.replacingOccurrences(
                of: "\"transcriptionLanguageCode\":null",
                with: "\"transcriptionLanguageCode\":\"EN\""
            ),
            canonical.replacingOccurrences(
                of: "\"durationMilliseconds\":null",
                with: "\"durationMilliseconds\":0"
            ),
            canonical.replacingOccurrences(
                of: "\"cachedAudioRelativeIdentifier\":null",
                with: "\"cachedAudioRelativeIdentifier\":\"../audio\""
            ),
            canonical.replacingOccurrences(
                of: "\"durationMilliseconds\":null,",
                with: ""
            ),
        ]
        for source in mutations {
            #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
                _ = try IOSAcceptedHistoryWireCodec.decode(Data(source.utf8))
            }
        }
    }

    @Test func unsortedAndCollidingSourceRowsAreRejected() throws {
        let older = try historyWireEntry(
            deliveryID: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            transcriptID: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!,
            createdAt: historyWireDate().addingTimeInterval(-1)
        )
        let newer = try historyWireEntry()
        let unsortedData = try encodeUncheckedHistoryEnvelope(
            revision: 1,
            entries: [older, newer]
        )
        #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
            _ = try IOSAcceptedHistoryWireCodec.decode(unsortedData)
        }

        let duplicateDelivery = try historyWireEntry(
            transcriptID: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!
        )
        let duplicateDeliveryData = try encodeUncheckedHistoryEnvelope(
            revision: 1,
            entries: [newer, duplicateDelivery]
        )
        #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
            _ = try IOSAcceptedHistoryWireCodec.decode(duplicateDeliveryData)
        }
    }

    @Test func malformedDepthAndSourceLimitsFailBeforeMaterialization() {
        #expect(throws: IOSAcceptedHistoryError.malformedData) {
            _ = try IOSAcceptedHistoryWireCodec.decode(Data([0x7B, 0xFF, 0x7D]))
        }
        #expect(throws: IOSAcceptedHistoryError.malformedData) {
            _ = try IOSAcceptedHistoryWireCodec.decode(
                Data([0xEF, 0xBB, 0xBF] + Array("{}".utf8))
            )
        }
        #expect(throws: IOSAcceptedHistoryError.malformedData) {
            _ = try IOSAcceptedHistoryWireCodec.decode(
                Data(
                    """
                    {"schemaVersion":1,"revision":1,"entries":[{"nested":[[]]}]}
                    """.utf8
                )
            )
        }
        #expect(throws: IOSAcceptedHistoryError.sourceTooLarge) {
            _ = try IOSAcceptedHistoryWireCodec.decode(
                Data(
                    repeating: 0x20,
                    count: IOSAcceptedHistoryJournal.maximumByteCount + 1
                )
            )
        }
    }

    @Test func exactSourceLimitAndSemanticEntryLimitAreIndependent() throws {
        let envelope = try IOSAcceptedHistoryEnvelope(revision: 1, entries: [])
        let canonical = try IOSAcceptedHistoryWireCodec.encode(envelope)
        var exactLimit = canonical
        exactLimit.append(
            Data(
                repeating: 0x20,
                count: IOSAcceptedHistoryJournal.maximumByteCount
                    - canonical.count
            )
        )
        #expect(try IOSAcceptedHistoryWireCodec.decode(exactLimit) == envelope)
        exactLimit.append(0x20)
        #expect(throws: IOSAcceptedHistoryError.sourceTooLarge) {
            _ = try IOSAcceptedHistoryWireCodec.decode(exactLimit)
        }

        let rows = Array(repeating: "{}", count: 21).joined(separator: ",")
        let source = Data(
            """
            {"schemaVersion":1,"revision":1,"entries":[\(rows)]}
            """.utf8
        )
        #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
            _ = try IOSAcceptedHistoryWireCodec.decode(source)
        }
    }

    @Test func repositoryPreservesCorruptFutureAndProtectedSlots() throws {
        let fileSystem = AcceptedHistoryFakeFileSystem()
        let repository = FoundationIOSAcceptedHistoryJournalRepository(
            fileSystem: fileSystem
        )
        fileSystem.install(Data("corrupt".utf8))
        #expect(throws: IOSAcceptedHistoryError.malformedData) {
            _ = try repository.load()
        }
        let preserved = fileSystem.file?.data

        fileSystem.install(
            Data(
                """
                {"schemaVersion":2,"revision":1,"entries":[]}
                """.utf8
            )
        )
        #expect(throws: IOSAcceptedHistoryError.unsupportedSchemaVersion) {
            _ = try repository.load()
        }

        fileSystem.readError = .protectedDataUnavailable
        #expect(throws: IOSAcceptedHistoryError.dataProtectionUnavailable) {
            _ = try repository.load()
        }
        #expect(preserved != nil)
    }

    @Test func maintenanceMappingIsContentFree() throws {
        let expected = IOSStrictProtectedRecordMaintenanceReport(
            inspectedEntryCount: 4,
            inspectedByteCount: 80,
            removedFileCount: 1,
            removedByteCount: 20,
            reachedLimit: false
        )
        let repository = FoundationIOSAcceptedHistoryJournalRepository(
            fileSystem: AcceptedHistoryFakeFileSystem(),
            stagingMaintenance: { _ in expected }
        )
        #expect(
            try repository.performStagingMaintenance(
                now: Date(timeIntervalSince1970: 1_800_000_000)
            ) == expected
        )
    }
}

private func historyWireEntry(
    deliveryID: UUID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
    transcriptID: UUID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
    acceptedText: String = "Accepted text",
    createdAt: Date = historyWireDate(),
    transcriptionLanguageCode: String? = nil,
    durationMilliseconds: Int64? = nil,
    cachedAudioRelativeIdentifier: String? = nil
) throws -> IOSAcceptedHistoryEntry {
    try IOSAcceptedHistoryEntry(
        deliveryID: deliveryID,
        transcriptID: transcriptID,
        acceptedText: acceptedText,
        outputIntent: .standard,
        createdAt: createdAt,
        policyGeneration: 1,
        transcriptionModel: "gpt-4o-mini-transcribe",
        transcriptionLanguageCode: transcriptionLanguageCode,
        durationMilliseconds: durationMilliseconds,
        cachedAudioRelativeIdentifier: cachedAudioRelativeIdentifier
    )
}

private func historyWireDate() -> Date {
    Date(timeIntervalSince1970: 1_895_036_400)
}

private func encodeUncheckedHistoryEnvelope(
    revision: Int64,
    entries: [IOSAcceptedHistoryEntry]
) throws -> Data {
    let rows: [[String: Any]] = try entries.map { entry in
        [
            "deliveryID": entry.deliveryID.uuidString.lowercased(),
            "transcriptID": entry.transcriptID.uuidString.lowercased(),
            "acceptedText": entry.acceptedText,
            "outputIntent": entry.outputIntent.rawValue,
            "createdAt": try IOSAcceptedOutputDeliveryTimestampCodec.string(
                from: entry.createdAt
            ),
            "policyGeneration": entry.policyGeneration,
            "transcriptionModel": entry.transcriptionModel,
            "transcriptionLanguageCode":
                entry.transcriptionLanguageCode ?? NSNull(),
            "durationMilliseconds": entry.durationMilliseconds ?? NSNull(),
            "cachedAudioRelativeIdentifier":
                entry.cachedAudioRelativeIdentifier ?? NSNull(),
        ]
    }
    return try JSONSerialization.data(
        withJSONObject: [
            "schemaVersion": 1,
            "revision": revision,
            "entries": rows,
        ],
        options: [.sortedKeys]
    )
}

private final class AcceptedHistoryFakeFileSystem:
    IOSStrictProtectedRecordFileSystem,
    @unchecked Sendable {
    var file: IOSStrictProtectedRecordFile?
    var readError: IOSStrictProtectedRecordFileSystemError?
    private var nextToken: UInt64 = 1

    func install(_ data: Data) {
        file = IOSStrictProtectedRecordFile(
            data: data,
            revision: makeRevision()
        )
    }

    func readFileIfPresent() throws -> IOSStrictProtectedRecordFile? {
        if let readError { throw readError }
        return file
    }

    func createFile(
        with data: Data
    ) throws -> IOSStrictProtectedRecordFileRevision {
        guard file == nil else {
            throw IOSStrictProtectedRecordFileSystemError.destinationConflict
        }
        install(data)
        return file!.revision
    }

    func replaceFile(
        with data: Data,
        expected: IOSStrictProtectedRecordFileRevision
    ) throws -> IOSStrictProtectedRecordFileRevision {
        guard file?.revision == expected else {
            throw IOSStrictProtectedRecordFileSystemError.staleRevision
        }
        install(data)
        return file!.revision
    }

    func removeFile(
        expected: IOSStrictProtectedRecordFileRevision
    ) throws {
        throw IOSStrictProtectedRecordFileSystemError.removeFailed
    }

    func removeAbandonedTemporaryFiles(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport {
        .empty
    }

    private func makeRevision() -> IOSStrictProtectedRecordFileRevision {
        defer { nextToken += 1 }
        return IOSStrictProtectedRecordFileRevision(testingToken: nextToken)
    }
}
