import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSAcceptedHistoryOutboxJournalTests {
    @Test func canonicalWireHasExactRootRowAndExplicitNulls() throws {
        let entry = try outboxWireEntry()
        let envelope = try IOSAcceptedHistoryOutboxEnvelope(
            revision: 7,
            entries: [entry]
        )
        let data = try IOSAcceptedHistoryOutboxWireCodec.encode(envelope)
        let object = try JSONSerialization.jsonObject(with: data)
        let root = try #require(object as? [String: Any])
        #expect(Set(root.keys) == ["schemaVersion", "revision", "entries"])
        let entries = try #require(root["entries"] as? [[String: Any]])
        let row = try #require(entries.first)
        #expect(Set(row.keys) == [
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
        ])
        #expect(row["transcriptionLanguageCode"] is NSNull)
        #expect(row["durationMilliseconds"] is NSNull)
        #expect(try IOSAcceptedHistoryOutboxWireCodec.decode(data) == envelope)
    }

    @Test func futureSchemaDispatchPrecedesV1Allowlists() {
        let future = Data(
            """
            {"schemaVersion":2,"revision":1,"entries":[],"future":"value"}
            """.utf8
        )
        #expect(throws: IOSAcceptedHistoryOutboxError.unsupportedSchemaVersion) {
            _ = try IOSAcceptedHistoryOutboxWireCodec.decode(future)
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidRecord) {
            _ = try IOSAcceptedHistoryOutboxWireCodec.decode(
                Data(
                    """
                    {"schemaVersion":1,"revision":1,"entries":[],"future":"value"}
                    """.utf8
                )
            )
        }
    }

    @Test func duplicateMembersNumericAliasesAndMissingNullsFail() throws {
        let canonical = String(
            decoding: try IOSAcceptedHistoryOutboxWireCodec.encode(
                IOSAcceptedHistoryOutboxEnvelope(
                    revision: 1,
                    entries: [try outboxWireEntry()]
                )
            ),
            as: UTF8.self
        )
        let sources = [
            #"{"schemaVersion":1,"schema\u0056ersion":1,"revision":1,"entries":[]}"#,
            #"{"schemaVersion":1,"revision":1.0,"entries":[]}"#,
            #"{"schemaVersion":1,"revision":1e0,"entries":[]}"#,
            #"{"schemaVersion":true,"revision":1,"entries":[]}"#,
            canonical.replacingOccurrences(
                of: "\"durationMilliseconds\":null,",
                with: ""
            ),
            canonical.replacingOccurrences(
                of: "\"transcriptionLanguageCode\":null",
                with: "\"transcriptionLanguageCode\":\"EN\""
            ),
        ]
        for source in sources {
            #expect(throws: (any Error).self) {
                _ = try IOSAcceptedHistoryOutboxWireCodec.decode(
                    Data(source.utf8)
                )
            }
        }
    }

    @Test func canonicalUUIDDateExpiryIntentAndOrderAreStrict() throws {
        let canonical = String(
            decoding: try IOSAcceptedHistoryOutboxWireCodec.encode(
                IOSAcceptedHistoryOutboxEnvelope(
                    revision: 1,
                    entries: [try outboxWireEntry()]
                )
            ),
            as: UTF8.self
        )
        let sources = [
            canonical.replacingOccurrences(
                of: "00000000-0000-4000-8000-000000000001",
                with: "00000000-0000-4000-8000-00000000000A"
            ),
            canonical.replacingOccurrences(
                of: "\"standard\"",
                with: "\"unknown\""
            ),
            canonical.replacingOccurrences(
                of: "2030-01-19T07:00:00.000Z",
                with: "2030-01-19T07:00:00Z"
            ),
            canonical.replacingOccurrences(
                of: "2030-01-20T07:00:00.000Z",
                with: "2030-01-20T06:59:59.999Z"
            ),
        ]
        for source in sources {
            #expect(throws: IOSAcceptedHistoryOutboxError.invalidRecord) {
                _ = try IOSAcceptedHistoryOutboxWireCodec.decode(
                    Data(source.utf8)
                )
            }
        }

        let newer = try outboxWireEntry()
        let older = try outboxWireEntry(
            deliveryID: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            transcriptID: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!,
            createdAt: outboxWireDate().addingTimeInterval(-1)
        )
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidRecord) {
            _ = try IOSAcceptedHistoryOutboxWireCodec.decode(
                encodeUncheckedOutbox(revision: 1, entries: [newer, older])
            )
        }
    }

    @Test func structuralAndExactSourceLimitsAreIndependent() throws {
        #expect(throws: IOSAcceptedHistoryOutboxError.malformedData) {
            _ = try IOSAcceptedHistoryOutboxWireCodec.decode(
                Data([0x7B, 0xFF, 0x7D])
            )
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.malformedData) {
            _ = try IOSAcceptedHistoryOutboxWireCodec.decode(
                Data([0xEF, 0xBB, 0xBF] + Array("{}".utf8))
            )
        }

        let empty = try IOSAcceptedHistoryOutboxEnvelope(
            revision: 1,
            entries: []
        )
        let canonical = try IOSAcceptedHistoryOutboxWireCodec.encode(empty)
        var exact = canonical
        exact.append(
            Data(
                repeating: 0x20,
                count: IOSAcceptedHistoryOutboxJournal.maximumByteCount
                    - canonical.count
            )
        )
        #expect(try IOSAcceptedHistoryOutboxWireCodec.decode(exact) == empty)
        exact.append(0x20)
        #expect(throws: IOSAcceptedHistoryOutboxError.sourceTooLarge) {
            _ = try IOSAcceptedHistoryOutboxWireCodec.decode(exact)
        }

        let rows = Array(repeating: "{}", count: 21).joined(separator: ",")
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidRecord) {
            _ = try IOSAcceptedHistoryOutboxWireCodec.decode(
                Data(
                    """
                    {"schemaVersion":1,"revision":1,"entries":[\(rows)]}
                    """.utf8
                )
            )
        }
    }

    @Test func repositoryPreservesCorruptFutureAndProtectedSlots() throws {
        let fileSystem = OutboxWireFakeFileSystem()
        let repository = FoundationIOSAcceptedHistoryOutboxJournalRepository(
            fileSystem: fileSystem
        )
        fileSystem.install(Data("corrupt".utf8))
        #expect(throws: IOSAcceptedHistoryOutboxError.malformedData) {
            _ = try repository.load()
        }
        fileSystem.install(
            Data(
                """
                {"schemaVersion":2,"revision":1,"entries":[]}
                """.utf8
            )
        )
        #expect(throws: IOSAcceptedHistoryOutboxError.unsupportedSchemaVersion) {
            _ = try repository.load()
        }
        fileSystem.readError = .protectedDataUnavailable
        #expect(throws: IOSAcceptedHistoryOutboxError.dataProtectionUnavailable) {
            _ = try repository.load()
        }
    }
}

private func outboxWireEntry(
    deliveryID: UUID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
    transcriptID: UUID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
    acceptedText: String = "Accepted text",
    createdAt: Date = outboxWireDate()
) throws -> IOSAcceptedHistoryOutboxEntry {
    try IOSAcceptedHistoryOutboxEntry(
        deliveryID: deliveryID,
        transcriptID: transcriptID,
        acceptedText: acceptedText,
        outputIntent: .standard,
        createdAt: createdAt,
        expiresAt: createdAt.addingTimeInterval(86_400),
        policyGeneration: 1,
        transcriptionModel: "gpt-4o-mini-transcribe",
        transcriptionLanguageCode: nil,
        durationMilliseconds: nil
    )
}

private func outboxWireDate() -> Date {
    Date(timeIntervalSince1970: 1_895_036_400)
}

private func encodeUncheckedOutbox(
    revision: Int64,
    entries: [IOSAcceptedHistoryOutboxEntry]
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
            "expiresAt": try IOSAcceptedOutputDeliveryTimestampCodec.string(
                from: entry.expiresAt
            ),
            "policyGeneration": entry.policyGeneration,
            "transcriptionModel": entry.transcriptionModel,
            "transcriptionLanguageCode":
                entry.transcriptionLanguageCode ?? NSNull(),
            "durationMilliseconds": entry.durationMilliseconds ?? NSNull(),
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

private final class OutboxWireFakeFileSystem:
    IOSStrictProtectedRecordFileSystem,
    @unchecked Sendable {
    var file: IOSStrictProtectedRecordFile?
    var readError: IOSStrictProtectedRecordFileSystemError?
    private var nextToken: UInt64 = 1

    func install(_ data: Data) {
        defer { nextToken += 1 }
        file = IOSStrictProtectedRecordFile(
            data: data,
            revision: IOSStrictProtectedRecordFileRevision(
                testingToken: nextToken
            )
        )
    }

    func readFileIfPresent() throws -> IOSStrictProtectedRecordFile? {
        if let readError { throw readError }
        return file
    }

    func createFile(
        with data: Data
    ) throws -> IOSStrictProtectedRecordFileRevision {
        throw IOSStrictProtectedRecordFileSystemError.destinationConflict
    }

    func replaceFile(
        with data: Data,
        expected: IOSStrictProtectedRecordFileRevision
    ) throws -> IOSStrictProtectedRecordFileRevision {
        throw IOSStrictProtectedRecordFileSystemError.staleRevision
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
}
