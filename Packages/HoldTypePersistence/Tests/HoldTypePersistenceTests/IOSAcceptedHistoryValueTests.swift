import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSAcceptedHistoryValueTests {
    @Test func validEntryEnvelopeAndDiagnosticsAreExactAndRedacted() throws {
        let entry = try acceptedHistoryEntry()
        let envelope = try IOSAcceptedHistoryEnvelope(
            revision: 1,
            entries: [entry]
        )

        #expect(envelope.entries == [entry])
        #expect(String(describing: entry) == "IOSAcceptedHistoryEntry(redacted)")
        #expect(
            String(reflecting: envelope)
                == "IOSAcceptedHistoryEnvelope(redacted)"
        )
        #expect(
            String(describing: IOSAcceptedHistoryError.collision)
                == "IOSAcceptedHistoryError(redacted)"
        )
        #expect(entry.customMirror.children.isEmpty)
        #expect(envelope.customMirror.children.isEmpty)
        #expect(IOSAcceptedHistoryError.collision.customMirror.children.isEmpty)

        requireAcceptedHistorySendable(IOSAcceptedHistoryEntry.self)
        requireAcceptedHistorySendable(IOSAcceptedHistoryEnvelope.self)
        requireAcceptedHistorySendable(IOSAcceptedHistoryError.self)
        requireAcceptedHistorySendable(IOSAcceptedHistoryRowReceipt.self)
    }

    @Test func entryRejectsNoncanonicalDeliveryMetadata() throws {
        let base = try acceptedHistoryEntry()
        let noncanonicalDate = base.createdAt.addingTimeInterval(0.0005)

        for acceptedText in [" leading", "trailing ", "\u{0000}bad"] {
            #expect(throws: IOSAcceptedHistoryError.invalidEntry) {
                _ = try acceptedHistoryEntry(acceptedText: acceptedText)
            }
        }
        for model in ["", " model", "model ", String(repeating: "m", count: 257)] {
            #expect(throws: IOSAcceptedHistoryError.invalidEntry) {
                _ = try acceptedHistoryEntry(transcriptionModel: model)
            }
        }
        for language in ["E", "EN", "engl", "e1"] {
            #expect(throws: IOSAcceptedHistoryError.invalidEntry) {
                _ = try acceptedHistoryEntry(
                    transcriptionLanguageCode: language
                )
            }
        }
        for duration in [0, 300_000, -1] as [Int64] {
            #expect(throws: IOSAcceptedHistoryError.invalidEntry) {
                _ = try acceptedHistoryEntry(durationMilliseconds: duration)
            }
        }
        #expect(throws: IOSAcceptedHistoryError.invalidEntry) {
            _ = try acceptedHistoryEntry(policyGeneration: 0)
        }
        #expect(throws: IOSAcceptedHistoryError.invalidEntry) {
            _ = try acceptedHistoryEntry(createdAt: noncanonicalDate)
        }
    }

    @Test func cacheIdentifierGrammarIsStrictAndOpaque() throws {
        for valid in [
            "audio.wav",
            "cache/2026/audio.wav",
            "é/片段.m4a",
            String(repeating: "a", count: 512),
        ] {
            #expect(
                try acceptedHistoryEntry(
                    cachedAudioRelativeIdentifier: valid
                ).cachedAudioRelativeIdentifier == valid
            )
        }

        for invalid in [
            "",
            "/audio.wav",
            "audio.wav/",
            "cache//audio.wav",
            ".",
            "..",
            "cache/./audio.wav",
            "cache/../audio.wav",
            "cache\\audio.wav",
            "cache/\u{0000}/audio.wav",
            String(repeating: "a", count: 513),
        ] {
            #expect(throws: IOSAcceptedHistoryError.invalidEntry) {
                _ = try acceptedHistoryEntry(
                    cachedAudioRelativeIdentifier: invalid
                )
            }
        }
    }

    @Test func immutableTextAndModelIdentityUseUTF8Bytes() throws {
        let composed = "é"
        let decomposed = "e\u{301}"
        #expect(composed == decomposed)

        let lhs = try acceptedHistoryEntry(
            acceptedText: composed,
            transcriptionModel: "modèle"
        )
        let rhs = try acceptedHistoryEntry(
            acceptedText: decomposed,
            transcriptionModel: "mode\u{300}le"
        )

        #expect(!lhs.hasSameImmutableBytes(as: rhs))
        #expect(lhs != rhs)
    }

    @Test func envelopeRequiresCanonicalOrderRevisionAndUniqueIdentities() throws {
        let date = acceptedHistoryDate()
        let lowerID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let higherID = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let lower = try acceptedHistoryEntry(
            deliveryID: lowerID,
            transcriptID: UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
            createdAt: date
        )
        let higher = try acceptedHistoryEntry(
            deliveryID: higherID,
            transcriptID: UUID(uuidString: "10000000-0000-4000-8000-000000000002")!,
            createdAt: date
        )

        _ = try IOSAcceptedHistoryEnvelope(
            revision: 1,
            entries: [lower, higher]
        )
        #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
            _ = try IOSAcceptedHistoryEnvelope(
                revision: 1,
                entries: [higher, lower]
            )
        }
        #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
            _ = try IOSAcceptedHistoryEnvelope(revision: 0, entries: [])
        }
        #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
            _ = try IOSAcceptedHistoryEnvelope(
                revision: 1,
                entries: [lower, lower]
            )
        }
        let duplicateTranscript = try acceptedHistoryEntry(
            deliveryID: higherID,
            transcriptID: lower.transcriptID,
            createdAt: date
        )
        #expect(throws: IOSAcceptedHistoryError.invalidRecord) {
            _ = try IOSAcceptedHistoryEnvelope(
                revision: 1,
                entries: [lower, duplicateTranscript]
            )
        }
    }

    @Test func storageLocationAndStrictConfigurationAreExact() {
        let base = URL(fileURLWithPath: "/private/app-support", isDirectory: true)
        #expect(
            IOSAcceptedHistoryStorageLocation.fileURL(in: base).path
                == "/private/app-support/HoldType/ios-accepted-history.json"
        )
        let configuration = IOSStrictProtectedRecordConfiguration.acceptedHistory
        #expect(configuration.rootDirectoryName == "HoldType")
        #expect(configuration.fileName == "ios-accepted-history.json")
        #expect(configuration.maximumByteCount == 4_194_304)
        #expect(
            configuration.marker?.name
                == "com.holdtype.ios.accepted-history"
        )
        #expect(configuration.marker?.value == Array("v1".utf8))
    }
}

private func acceptedHistoryEntry(
    deliveryID: UUID = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!,
    transcriptID: UUID = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!,
    acceptedText: String = "Accepted text",
    outputIntent: DictationOutputIntent = .standard,
    createdAt: Date = acceptedHistoryDate(),
    policyGeneration: Int64 = 1,
    transcriptionModel: String = "gpt-4o-mini-transcribe",
    transcriptionLanguageCode: String? = "en",
    durationMilliseconds: Int64? = 1_250,
    cachedAudioRelativeIdentifier: String? = nil
) throws -> IOSAcceptedHistoryEntry {
    try IOSAcceptedHistoryEntry(
        deliveryID: deliveryID,
        transcriptID: transcriptID,
        acceptedText: acceptedText,
        outputIntent: outputIntent,
        createdAt: createdAt,
        policyGeneration: policyGeneration,
        transcriptionModel: transcriptionModel,
        transcriptionLanguageCode: transcriptionLanguageCode,
        durationMilliseconds: durationMilliseconds,
        cachedAudioRelativeIdentifier: cachedAudioRelativeIdentifier
    )
}

private func acceptedHistoryDate() -> Date {
    Date(timeIntervalSince1970: 1_800_000_000)
}

private func requireAcceptedHistorySendable<Value: Sendable>(
    _ type: Value.Type
) {}
