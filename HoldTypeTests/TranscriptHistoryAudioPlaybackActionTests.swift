//
//  TranscriptHistoryAudioPlaybackActionTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/7/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct TranscriptHistoryAudioPlaybackActionTests {

    @Test func playsCachedAudioWhenCacheIsEnabledAndFileExists() throws {
        let cachedAudioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: cachedAudioFileURL.deletingLastPathComponent()) }

        let player = FakeTranscriptHistoryAudioPlayer()
        let action = TranscriptHistoryAudioPlaybackAction(audioPlayer: player)
        var settings = AppSettings.defaults
        settings.recordingCachePolicy = .keepLast(10)
        let entry = try TranscriptHistoryEntry(
            transcriptText: "Accepted transcript",
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: "en",
            cachedAudioFileURL: cachedAudioFileURL
        )

        let result = action.play(entry, settings: settings)

        #expect(result == .playing)
        #expect(result.statusText == "Playing cached recording.")
        #expect(player.playedURLs == [cachedAudioFileURL])
    }

    @Test func doesNotPlayWhenRecordingCacheIsOff() throws {
        let cachedAudioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: cachedAudioFileURL.deletingLastPathComponent()) }

        let player = FakeTranscriptHistoryAudioPlayer()
        let action = TranscriptHistoryAudioPlaybackAction(audioPlayer: player)
        var settings = AppSettings.defaults
        settings.recordingCachePolicy = .deleteImmediately
        let entry = try TranscriptHistoryEntry(
            transcriptText: "Accepted transcript",
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: "en",
            cachedAudioFileURL: cachedAudioFileURL
        )

        let result = action.play(entry, settings: settings)

        #expect(action.canPlay(entry, settings: settings) == false)
        #expect(result == .unavailable)
        #expect(result.statusText == "Cached recording is no longer available.")
        #expect(player.playedURLs.isEmpty)
    }

    @Test func doesNotPlayWhenCachedAudioFileIsMissing() throws {
        let player = FakeTranscriptHistoryAudioPlayer()
        let action = TranscriptHistoryAudioPlaybackAction(audioPlayer: player)
        var settings = AppSettings.defaults
        settings.recordingCachePolicy = .keepLast(10)
        let entry = try TranscriptHistoryEntry(
            transcriptText: "Accepted transcript",
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: "en",
            cachedAudioFileURL: URL(fileURLWithPath: "/tmp/holdtype-missing-cached-audio.m4a")
        )

        let result = action.play(entry, settings: settings)

        #expect(action.canPlay(entry, settings: settings) == false)
        #expect(result == .unavailable)
        #expect(player.playedURLs.isEmpty)
    }

    @Test func reportsFailureWhenAudioPlayerFails() throws {
        let cachedAudioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: cachedAudioFileURL.deletingLastPathComponent()) }

        let player = FakeTranscriptHistoryAudioPlayer(error: TranscriptHistoryAudioPlaybackError.playbackFailed)
        let action = TranscriptHistoryAudioPlaybackAction(audioPlayer: player)
        var settings = AppSettings.defaults
        settings.recordingCachePolicy = .keepLast(10)
        let entry = try TranscriptHistoryEntry(
            transcriptText: "Accepted transcript",
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: "en",
            cachedAudioFileURL: cachedAudioFileURL
        )

        let result = action.play(entry, settings: settings)

        #expect(result == .failed)
        #expect(result.statusText == "Could not play cached recording.")
        #expect(player.playedURLs == [cachedAudioFileURL])
    }

    @Test func playsSavedRecoveryAudioRegardlessOfAcceptedRecordingCachePolicy() throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let player = FakeTranscriptHistoryAudioPlayer()
        let action = TranscriptHistoryAudioPlaybackAction(audioPlayer: player)
        let attempt = FailedTranscriptionAttempt(
            audioFileURL: audioFileURL,
            audioDuration: 30,
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: "en",
            state: .processing,
            reason: .other
        )

        #expect(action.canPlay(attempt))
        #expect(action.play(attempt) == .playing)
        #expect(player.playedURLs == [audioFileURL])
    }

    @Test func savedTranscribedRowOffersPlaybackAndDeleteButNeverRetry() throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let attempt = FailedTranscriptionAttempt(
            audioFileURL: audioFileURL,
            audioDuration: 300,
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: nil,
            completionKind: .maximumDuration,
            state: .saved,
            reason: .other,
            acceptedTranscriptText: "Five-minute accepted transcript"
        )
        let presentation = TranscriptionRecoveryHistoryRowPresentation(attempt: attempt)
        let action = TranscriptHistoryAudioPlaybackAction(
            audioPlayer: FakeTranscriptHistoryAudioPlayer()
        )

        #expect(presentation.title == "Saved and transcribed")
        #expect(presentation.message == "Five-minute accepted transcript")
        #expect(presentation.showsProgress == false)
        #expect(presentation.showsSettings == false)
        #expect(presentation.showsRetry == false)
        #expect(presentation.showsSaveRetry == false)
        #expect(attempt.canRetry == false)
        #expect(attempt.canDelete)
        #expect(action.canPlay(attempt))
    }

    @Test func incompleteSavedStateOffersOnlyLocalSaveRetry() {
        let attempt = FailedTranscriptionAttempt(
            audioFileURL: URL(fileURLWithPath: "/tmp/holdtype-incomplete-saved-state.m4a"),
            audioDuration: 300,
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: nil,
            completionKind: .maximumDuration,
            state: .failed,
            reason: .savedStatePersistenceFailed,
            acceptedTranscriptText: "Already accepted text"
        )
        let presentation = TranscriptionRecoveryHistoryRowPresentation(attempt: attempt)

        #expect(presentation.title == "Transcribed — save incomplete")
        #expect(presentation.message == "Already accepted text")
        #expect(presentation.showsRetry == false)
        #expect(presentation.showsSaveRetry)
        #expect(attempt.canRetry == false)
        #expect(attempt.canDelete)
    }

    @Test func doesNotPlayEmptySavedRecoveryAudio() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-history-empty-playback-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let audioFileURL = directoryURL.appendingPathComponent("empty.m4a")
        try Data().write(to: audioFileURL)

        let player = FakeTranscriptHistoryAudioPlayer()
        let action = TranscriptHistoryAudioPlaybackAction(audioPlayer: player)
        let attempt = FailedTranscriptionAttempt(
            audioFileURL: audioFileURL,
            audioDuration: 0,
            transcriptionModel: "gpt-4o-transcribe",
            languageCode: nil,
            state: .failed,
            reason: .invalidRecording
        )

        #expect(action.canPlay(attempt) == false)
        #expect(action.play(attempt) == .unavailable)
        #expect(player.playedURLs.isEmpty)
    }

    private func makeTemporaryAudioFile() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-history-playback-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = directoryURL.appendingPathComponent("cached.m4a")
        try Data("audio".utf8).write(to: fileURL)
        return fileURL
    }
}

private final class FakeTranscriptHistoryAudioPlayer: TranscriptHistoryAudioPlaying {
    private(set) var playedURLs: [URL] = []
    private let error: Error?

    init(error: Error? = nil) {
        self.error = error
    }

    func playCachedAudio(at fileURL: URL) throws {
        playedURLs.append(fileURL)
        if let error {
            throw error
        }
    }
}
