import Foundation
import Testing
@testable import HoldType

@MainActor
struct ConfirmedDuplicateRetryTests {
    @Test func confirmedRetryReopensOnlyAnUncertainAttempt() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-confirmed-duplicate-retry-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let audioURL = rootURL.appendingPathComponent("recording.m4a")
        try Data("audio".utf8).write(to: audioURL)
        let recoveryURL = rootURL.appendingPathComponent("Recovery", isDirectory: true)
        let store = TranscriptionFailureRecoveryStore(directoryURL: recoveryURL)
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: audioURL,
            settings: .defaults,
            audioDuration: 12
        )
        try store.sealProviderDispatch(id: checkpoint.id)
        store.markProviderOutcomeUncertain(id: checkpoint.id)

        let uncertainAttempt = try #require(store.failedAttempts.first)
        #expect(uncertainAttempt.requiresDuplicateRetryConfirmation)
        #expect(uncertainAttempt.canRetry == false)

        try store.beginConfirmedDuplicateRetry(id: uncertainAttempt.id)

        let reopenedAttempt = try #require(store.failedAttempts.first)
        #expect(reopenedAttempt.state == .processing)
        #expect(reopenedAttempt.retryCount == 1)
        #expect(FileManager.default.fileExists(atPath: reopenedAttempt.audioFileURL.path))
    }
}
