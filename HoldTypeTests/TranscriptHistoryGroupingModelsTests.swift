import Foundation
import Testing
@testable import HoldType

struct TranscriptHistoryGroupingModelsTests {
    @Test func retryUpdateDoesNotMoveSavedRecordingAheadOfNewerEntry() throws {
        let olderRecordingDate = Date(timeIntervalSince1970: 1_000)
        let newerRecordingDate = Date(timeIntervalSince1970: 2_000)
        let retryUpdateDate = Date(timeIntervalSince1970: 3_000)
        let savedRecording = FailedTranscriptionAttempt(
            createdAt: olderRecordingDate,
            updatedAt: retryUpdateDate,
            audioFileURL: URL(fileURLWithPath: "/tmp/holdtype-ordering-test.m4a"),
            audioDuration: 12,
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: nil,
            state: .processing,
            reason: .other
        )
        let newerTranscript = try TranscriptHistoryEntry(
            createdAt: newerRecordingDate,
            transcriptText: "Newer recording",
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: nil
        )

        let rows = [
            TranscriptHistoryRow.failed(savedRecording),
            TranscriptHistoryRow.transcript(newerTranscript)
        ].sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }

        #expect(rows.map(\.id) == [
            "transcript-\(newerTranscript.id.uuidString)",
            "failed-\(savedRecording.id.uuidString)"
        ])
        #expect(rows.last?.createdAt == olderRecordingDate)
    }
}
