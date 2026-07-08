//
//  TranscriptHistoryAudioPlaybackActionTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/7/26.
//

import Foundation
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
