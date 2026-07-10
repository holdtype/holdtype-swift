//
//  TranscriptionFailureRecoveryStoreTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/7/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct TranscriptionFailureRecoveryStoreTests {
    @Test func oversizedMultipartMetadataUsesBadRequestRecoveryReason() {
        #expect(
            FailedTranscriptionReason(error: OpenAITranscriptionServiceError.multipartMetadataTooLarge)
                == .badRequest
        )
    }

    @Test func recordsFailedAttemptByMovingAudioIntoSessionRecovery() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "source.m4a")
        var settings = AppSettings.defaults
        settings.transcriptionModel = "gpt-4o-mini-transcribe"
        settings.language = .english
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            now: { Date(timeIntervalSince1970: 1_781_983_983) },
            uuidProvider: {
                UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!
            }
        )

        let attempt = try #require(
            try store.recordFailedAttempt(
                audioFileURL: sourceURL,
                settings: settings,
                audioDuration: 7.5,
                reason: .invalidAPIKey
            )
        )

        #expect(store.failedAttempts == [attempt])
        #expect(attempt.reason == .invalidAPIKey)
        #expect(attempt.transcriptionModel == "gpt-4o-mini-transcribe")
        #expect(attempt.languageCode == "en")
        #expect(attempt.audioDuration == 7.5)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: attempt.audioFileURL.path))
        #expect(attempt.audioFileURL.path.hasPrefix(fixture.recoveryURL.path))
    }

    @Test func disabledHistoryDoesNotRecordOrMoveFailedAttemptAudio() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "private.m4a")
        var settings = AppSettings.defaults
        settings.saveTranscriptHistory = false
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)

        let attempt = try store.recordFailedAttempt(
            audioFileURL: sourceURL,
            settings: settings,
            audioDuration: 3,
            reason: .networkUnavailable
        )

        #expect(attempt == nil)
        #expect(store.failedAttempts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @Test func clearRemovesFailedAttemptAudio() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "failed.m4a")
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let attempt = try #require(
            try store.recordFailedAttempt(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: nil,
                reason: .timedOut
            )
        )

        store.clear()

        #expect(store.failedAttempts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: attempt.audioFileURL.path) == false)
    }

    private func makeFixture() throws -> (rootURL: URL, recoveryURL: URL) {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-failed-recovery-tests-\(UUID().uuidString)", isDirectory: true)
        let recoveryURL = rootURL.appendingPathComponent("Recovery", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        return (rootURL, recoveryURL)
    }

    private func makeAudioFile(in directoryURL: URL, named fileName: String) throws -> URL {
        let fileURL = directoryURL.appendingPathComponent(fileName)
        try Data("audio".utf8).write(to: fileURL)
        return fileURL
    }
}
