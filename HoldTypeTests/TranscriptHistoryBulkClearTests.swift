import Foundation
import Testing
@testable import HoldType

@MainActor
struct TranscriptHistoryBulkClearTests {
    @Test func summaryEnablesClearForSavedRecordingsAndProtectsProcessing() {
        let failed = makeAttempt(state: .failed)
        let processing = makeAttempt(state: .processing)

        let summary = TranscriptHistoryBulkClearSummary(
            acceptedTranscriptCount: 0,
            savedRecordings: [failed, processing]
        )

        #expect(summary.canClear)
        #expect(summary.deletableSavedRecordingCount == 1)
        #expect(summary.processingSavedRecordingCount == 1)
        #expect(summary.confirmationMessage.contains("including their recovery audio"))
        #expect(summary.confirmationMessage.contains("will be kept"))
    }

    @Test func bulkDeletionRemovesTerminalRecordingsAndKeepsProcessing() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let processing = try store.recordProcessingCheckpoint(
            audioFileURL: try makeAudioFile(in: fixture.rootURL, named: "processing.m4a"),
            settings: .defaults,
            audioDuration: 1,
            completionKind: .standard
        )
        let failed = try #require(
            try store.recordFailedAttempt(
                audioFileURL: try makeAudioFile(in: fixture.rootURL, named: "failed.m4a"),
                settings: .defaults,
                audioDuration: 1,
                reason: .networkFailure
            )
        )

        let result = store.removeAllDeletableAttempts()

        #expect(result == SavedRecordingBulkDeletionResult(deletedCount: 1, keptCount: 0))
        #expect(store.failedAttempts.map(\.id) == [processing.id])
        #expect(FileManager.default.fileExists(atPath: failed.audioFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: processing.audioFileURL.path))
    }

    @Test func bulkDeletionReportsRecordingsKeptAfterDeletionFailure() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let fileManager = BlockingRemovalFileManager()
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            fileManager: fileManager
        )
        let failed = try #require(
            try store.recordFailedAttempt(
                audioFileURL: try makeAudioFile(in: fixture.rootURL, named: "blocked.m4a"),
                settings: .defaults,
                audioDuration: 1,
                reason: .networkFailure
            )
        )
        fileManager.blockedURL = failed.audioFileURL

        let result = store.removeAllDeletableAttempts()

        #expect(result == SavedRecordingBulkDeletionResult(deletedCount: 0, keptCount: 1))
        #expect(store.failedAttempts.map(\.id) == [failed.id])
        #expect(FileManager.default.fileExists(atPath: failed.audioFileURL.path))
    }

    private func makeAttempt(state: TranscriptionRecoveryState) -> FailedTranscriptionAttempt {
        FailedTranscriptionAttempt(
            audioFileURL: URL(fileURLWithPath: "/tmp/holdtype-bulk-clear-test.m4a"),
            audioDuration: 1,
            transcriptionModel: "gpt-4o-mini-transcribe",
            languageCode: nil,
            state: state,
            reason: .networkFailure
        )
    }

    private func makeFixture() throws -> (rootURL: URL, recoveryURL: URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("HoldTypeBulkClear-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return (rootURL, rootURL.appendingPathComponent("Recovery"))
    }

    private func makeAudioFile(in directoryURL: URL, named name: String) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent(name)
        try Data([0x01]).write(to: fileURL)
        return fileURL
    }
}

private final class BlockingRemovalFileManager: FileManager, @unchecked Sendable {
    var blockedURL: URL?

    override func removeItem(at URL: URL) throws {
        if URL.standardizedFileURL == blockedURL?.standardizedFileURL {
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.removeItem(at: URL)
    }
}
