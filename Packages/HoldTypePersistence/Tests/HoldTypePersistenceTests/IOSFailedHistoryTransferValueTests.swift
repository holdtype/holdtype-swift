import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryTransferValueTests {
    @Test func pendingAndFailedRowShareOnlyTheFrozenMatchIdentity()
        async throws {
        let attemptID = failedHistoryTestUUID(namespace: 0x71, index: 1)
        let createdAt = try failedHistoryTestDate(offsetMilliseconds: 40)
        let pending = try pendingRecording(
            attemptID: attemptID,
            createdAt: createdAt
        )
        let row = try failedHistoryTestEntry(
            attemptID: attemptID,
            createdAt: createdAt,
            updatedAt: try failedHistoryTestDate(offsetMilliseconds: 90),
            outputIntent: pending.outputIntent,
            transcriptionModel: pending.transcriptionModel,
            transcriptionLanguageCode: pending.transcriptionLanguageCode,
            durationMilliseconds: pending.durationMilliseconds,
            byteCount: pending.byteCount,
            audioRelativeIdentifier: pending.audioRelativeIdentifier,
            ownershipState: .pendingJournalRetirement
        )

        #expect(
            IOSFailedHistoryPendingMatchIdentity(pending: pending)
                == IOSFailedHistoryPendingMatchIdentity(failedRow: row)
        )

        let state = IOSFailedHistoryTransferOperationState()
        await state.store(.committingRow(row))
        #expect(await state.current() == .committingRow(row))
        await state.clear()
        #expect(await state.current() == nil)
    }

    @Test func matchIdentityRejectsNonRecoveryPendingAndNonTransferRow()
        throws {
        let attemptID = failedHistoryTestUUID(namespace: 0x71, index: 2)
        let createdAt = try failedHistoryTestDate(offsetMilliseconds: 50)
        let transcribing = try pendingRecording(
            attemptID: attemptID,
            createdAt: createdAt,
            phase: .transcribing,
            transcriptionID:
                failedHistoryTestUUID(namespace: 0x72, index: 2)
        )
        let ready = try failedHistoryTestEntry(
            attemptID: attemptID,
            createdAt: createdAt,
            updatedAt: try failedHistoryTestDate(offsetMilliseconds: 90),
            audioRelativeIdentifier: transcribing.audioRelativeIdentifier,
            ownershipState: .ready
        )

        #expect(
            IOSFailedHistoryPendingMatchIdentity(pending: transcribing) == nil
        )
        #expect(IOSFailedHistoryPendingMatchIdentity(failedRow: ready) == nil)
    }

    @Test func matchIdentityUsesExactUTF8ModelBytesAndIsRedacted() throws {
        let attemptID = failedHistoryTestUUID(namespace: 0x71, index: 3)
        let createdAt = try failedHistoryTestDate(offsetMilliseconds: 60)
        let composed = "mod\u{00e9}l"
        let decomposed = "mode\u{0301}l"
        #expect(composed == decomposed)
        #expect(!composed.utf8.elementsEqual(decomposed.utf8))

        let pending = try pendingRecording(
            attemptID: attemptID,
            createdAt: createdAt,
            transcriptionModel: composed
        )
        let row = try failedHistoryTestEntry(
            attemptID: attemptID,
            createdAt: createdAt,
            updatedAt: try failedHistoryTestDate(offsetMilliseconds: 90),
            outputIntent: pending.outputIntent,
            transcriptionModel: decomposed,
            transcriptionLanguageCode: pending.transcriptionLanguageCode,
            durationMilliseconds: pending.durationMilliseconds,
            byteCount: pending.byteCount,
            audioRelativeIdentifier: pending.audioRelativeIdentifier,
            ownershipState: .pendingJournalRetirement
        )
        let identity = try #require(
            IOSFailedHistoryPendingMatchIdentity(pending: pending)
        )

        #expect(
            identity
                != IOSFailedHistoryPendingMatchIdentity(failedRow: row)
        )
        #expect(String(describing: identity).contains("redacted"))
        #expect(identity.customMirror.children.isEmpty)
        #expect(
            String(describing: IOSFailedHistoryTransferResult.transferred)
                == "IOSFailedHistoryTransferResult(redacted)"
        )
    }

    private func pendingRecording(
        attemptID: UUID,
        createdAt: Date,
        phase: IOSPendingRecordingPhase = .awaitingRecovery,
        transcriptionID: UUID? = nil,
        transcriptionModel: String = "gpt-4o-mini-transcribe"
    ) throws -> IOSPendingRecording {
        try IOSPendingRecording(
            attemptID: attemptID,
            audioRelativeIdentifier: IOSPendingRecordingStorageLocation
                .relativeAudioIdentifier(for: attemptID, format: .m4a),
            createdAt: createdAt,
            updatedAt: try failedHistoryTestDate(
                offsetMilliseconds: 80
            ),
            phase: phase,
            outputIntent: .standard,
            transcriptionID: transcriptionID,
            transcriptionModel: transcriptionModel,
            transcriptionLanguageCode: "en",
            durationMilliseconds: 1_250,
            byteCount: 4_096
        )
    }
}
