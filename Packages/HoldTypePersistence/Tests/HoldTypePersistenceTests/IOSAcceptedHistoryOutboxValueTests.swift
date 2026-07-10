import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSAcceptedHistoryOutboxValueTests {
    @Test func validEntryHasExactTemporalBoundariesAndRedaction() throws {
        let entry = try outboxValueEntry()
        #expect(
            entry.temporalState(
                at: entry.createdAt.addingTimeInterval(-0.001)
            ) == .clockRollbackAmbiguous
        )
        #expect(entry.temporalState(at: entry.createdAt) == .live)
        #expect(
            entry.temporalState(
                at: entry.expiresAt.addingTimeInterval(-0.001)
            ) == .live
        )
        #expect(entry.temporalState(at: entry.expiresAt) == .expired)
        #expect(
            String(describing: entry)
                == "IOSAcceptedHistoryOutboxEntry(redacted)"
        )
        #expect(entry.customMirror.children.isEmpty)
        #expect(
            String(describing: IOSAcceptedHistoryOutboxError.capacityExceeded)
                == "IOSAcceptedHistoryOutboxError(redacted)"
        )
        #expect(
            IOSAcceptedHistoryOutboxError.capacityExceeded
                .customMirror.children.isEmpty
        )

        requireOutboxSendable(IOSAcceptedHistoryOutboxEntry.self)
        requireOutboxSendable(IOSAcceptedHistoryOutboxEnvelope.self)
        requireOutboxSendable(IOSAcceptedHistoryOutboxReceipt.self)
        requireOutboxSendable(IOSAcceptedHistoryOutboxError.self)
    }

    @Test func entryRequiresExactExpiryAndDeliveryMetadata() throws {
        let createdAt = outboxValueDate()
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidEntry) {
            _ = try outboxValueEntry(
                expiresAt: createdAt.addingTimeInterval(86_399.999)
            )
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidEntry) {
            _ = try outboxValueEntry(acceptedText: " text")
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidEntry) {
            _ = try outboxValueEntry(transcriptionModel: " model")
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidEntry) {
            _ = try outboxValueEntry(
                transcriptionLanguageCode: "EN"
            )
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidEntry) {
            _ = try outboxValueEntry(durationMilliseconds: 300_000)
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidEntry) {
            _ = try outboxValueEntry(policyGeneration: 0)
        }
    }

    @Test func immutableIdentityUsesUTF8Bytes() throws {
        let lhs = try outboxValueEntry(
            acceptedText: "é",
            transcriptionModel: "modèle"
        )
        let rhs = try outboxValueEntry(
            acceptedText: "e\u{301}",
            transcriptionModel: "mode\u{300}le"
        )
        #expect(lhs.acceptedText == rhs.acceptedText)
        #expect(!lhs.hasSameImmutableBytes(as: rhs))
        #expect(lhs != rhs)
    }

    @Test func envelopeRequiresOldestFirstOrderRevisionAndUniqueIDs() throws {
        let date = outboxValueDate()
        let lower = try outboxValueEntry(
            deliveryID: UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
            transcriptID: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
            createdAt: date
        )
        let higher = try outboxValueEntry(
            deliveryID: UUID(uuidString: "00000000-0000-4000-8000-000000000002")!,
            transcriptID: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!,
            createdAt: date
        )
        let envelope = try IOSAcceptedHistoryOutboxEnvelope(
            revision: 1,
            entries: [lower, higher]
        )
        #expect(
            String(reflecting: envelope)
                == "IOSAcceptedHistoryOutboxEnvelope(redacted)"
        )
        #expect(envelope.customMirror.children.isEmpty)

        #expect(throws: IOSAcceptedHistoryOutboxError.invalidRecord) {
            _ = try IOSAcceptedHistoryOutboxEnvelope(
                revision: 1,
                entries: [higher, lower]
            )
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidRecord) {
            _ = try IOSAcceptedHistoryOutboxEnvelope(
                revision: 0,
                entries: []
            )
        }
        #expect(throws: IOSAcceptedHistoryOutboxError.invalidRecord) {
            _ = try IOSAcceptedHistoryOutboxEnvelope(
                revision: 1,
                entries: [lower, lower]
            )
        }
    }

    @Test func storageLocationAndConfigurationAreExact() {
        let base = URL(fileURLWithPath: "/private/app-support", isDirectory: true)
        #expect(
            IOSAcceptedHistoryOutboxStorageLocation.fileURL(in: base).path
                == "/private/app-support/HoldType/ios-accepted-history-outbox.json"
        )
        let configuration =
            IOSStrictProtectedRecordConfiguration.acceptedHistoryOutbox
        #expect(configuration.rootDirectoryName == "HoldType")
        #expect(configuration.fileName == "ios-accepted-history-outbox.json")
        #expect(configuration.maximumByteCount == 4_194_304)
        #expect(
            configuration.marker?.name
                == "com.holdtype.ios.accepted-history-outbox"
        )
        #expect(configuration.marker?.value == Array("v1".utf8))
    }
}

private func outboxValueEntry(
    deliveryID: UUID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
    transcriptID: UUID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
    acceptedText: String = "Accepted text",
    createdAt: Date = outboxValueDate(),
    expiresAt: Date? = nil,
    policyGeneration: Int64 = 1,
    transcriptionModel: String = "gpt-4o-mini-transcribe",
    transcriptionLanguageCode: String? = "en",
    durationMilliseconds: Int64? = 1_250
) throws -> IOSAcceptedHistoryOutboxEntry {
    try IOSAcceptedHistoryOutboxEntry(
        deliveryID: deliveryID,
        transcriptID: transcriptID,
        acceptedText: acceptedText,
        outputIntent: .standard,
        createdAt: createdAt,
        expiresAt: expiresAt ?? createdAt.addingTimeInterval(86_400),
        policyGeneration: policyGeneration,
        transcriptionModel: transcriptionModel,
        transcriptionLanguageCode: transcriptionLanguageCode,
        durationMilliseconds: durationMilliseconds
    )
}

private func outboxValueDate() -> Date {
    Date(timeIntervalSince1970: 1_800_000_000)
}

private func requireOutboxSendable<Value: Sendable>(_ type: Value.Type) {}
