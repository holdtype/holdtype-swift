import Foundation
import Testing
@testable import HoldType

@MainActor
struct RecoveryAudioValidationTests {
    @Test func rejectsUnfinishedCheckpointWithoutDeletingSource() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("unfinished.m4a")
        try Data("unfinished M4A".utf8).write(to: audio)
        let recovery = root.appendingPathComponent("Recovery")
        let store = TranscriptionFailureRecoveryStore(directoryURL: recovery)
        #expect(throws: TranscriptionFailureRecoveryError.audioUnavailable) {
            try store.recordProcessingCheckpoint(audioFileURL: audio, settings: .defaults,
                                                audioDuration: 3, completionKind: .standard)
        }
        #expect(store.failedAttempts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: audio.path))
    }

    @Test func corruptRecoveryIsHiddenOnRelaunchButAudioAndSealSurvive() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("completed.wav")
        try TranscriptionTestAudio.wav.write(to: audio)
        let recovery = root.appendingPathComponent("Recovery")
        let store = TranscriptionFailureRecoveryStore(directoryURL: recovery)
        let attempt = try store.recordProcessingCheckpoint(audioFileURL: audio, settings: .defaults,
                                                          audioDuration: 4, completionKind: .standard)
        try Data("truncated".utf8).write(to: attempt.audioFileURL)
        let seal = recovery.appendingPathComponent("ProviderDispatch-\(attempt.id.uuidString.lowercased()).json")
        try Data("protected seal".utf8).write(to: seal)
        #expect(TranscriptionFailureRecoveryStore(directoryURL: recovery).failedAttempts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: attempt.audioFileURL.path))
        #expect(try Data(contentsOf: seal) == Data("protected seal".utf8))
    }
}
