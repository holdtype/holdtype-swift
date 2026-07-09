//
//  TranscriptRecoveryHistoryStoreTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/22/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct TranscriptRecoveryHistoryStoreTests {

    @Test func recordsAcceptedTranscriptsNewestFirstInMemory() throws {
        let store = TranscriptRecoveryHistoryStore()
        var settings = AppSettings.defaults
        settings.transcriptionModel = "gpt-4o-mini-transcribe"
        settings.language = .english

        try store.recordAcceptedTranscript(
            "  First transcript  ",
            settings: settings,
            audioDuration: 1.5
        )
        try store.recordAcceptedTranscript(
            "Second transcript",
            settings: settings,
            audioDuration: 2.5
        )

        #expect(store.entries.map(\.transcriptText) == ["Second transcript", "First transcript"])
        #expect(store.entries.first?.transcriptionModel == "gpt-4o-mini-transcribe")
        #expect(store.entries.first?.languageCode == "en")
        #expect(store.entries.first?.audioDuration == 2.5)
    }

    @Test func disabledSettingDoesNotRecordTranscript() throws {
        let store = TranscriptRecoveryHistoryStore()
        var settings = AppSettings.defaults
        settings.saveTranscriptHistory = false

        try store.recordAcceptedTranscript(
            "Private transcript",
            settings: settings,
            audioDuration: nil
        )

        #expect(store.entries.isEmpty)
    }

    @Test func recordsCachedAudioFileURLWhenRecordingCacheKeepsRecordings() throws {
        let store = TranscriptRecoveryHistoryStore()
        let cachedAudioFileURL = URL(fileURLWithPath: "/tmp/HoldType-cache-enabled.m4a")
        var settings = AppSettings.defaults
        settings.recordingCachePolicy = .keepLast(10)

        try store.recordAcceptedTranscript(
            "Cached transcript",
            settings: settings,
            audioDuration: 3.5,
            cachedAudioFileURL: cachedAudioFileURL
        )

        #expect(store.entries.first?.cachedAudioFileURL == cachedAudioFileURL)
    }

    @Test func dropsCachedAudioFileURLWhenRecordingCacheDeletesImmediately() throws {
        let store = TranscriptRecoveryHistoryStore()
        let cachedAudioFileURL = URL(fileURLWithPath: "/tmp/HoldType-cache-disabled.m4a")
        var settings = AppSettings.defaults
        settings.recordingCachePolicy = .deleteImmediately

        try store.recordAcceptedTranscript(
            "Uncached transcript",
            settings: settings,
            audioDuration: 3.5,
            cachedAudioFileURL: cachedAudioFileURL
        )

        #expect(store.entries.first?.cachedAudioFileURL == nil)
    }

    @Test func retainsOnlyMostRecentTwentyEntries() throws {
        let store = TranscriptRecoveryHistoryStore()

        for offset in 0..<21 {
            try store.recordAcceptedTranscript(
                "Transcript \(offset)",
                settings: .defaults,
                audioDuration: nil
            )
        }

        #expect(store.entries.count == TranscriptRecoveryHistoryStore.defaultRetentionLimit)
        #expect(store.entries.first?.transcriptText == "Transcript 20")
        #expect(store.entries.last?.transcriptText == "Transcript 1")
        #expect(store.entries.contains { $0.transcriptText == "Transcript 0" } == false)
    }

    @Test func clearRemovesOnlyCurrentRecoveryEntries() throws {
        let store = TranscriptRecoveryHistoryStore()

        try store.recordAcceptedTranscript(
            "Recoverable transcript",
            settings: .defaults,
            audioDuration: nil
        )

        store.clear()

        #expect(store.entries.isEmpty)
    }

    @Test func deleteEntryRemovesOnlyMatchingRecoveryEntry() throws {
        let store = TranscriptRecoveryHistoryStore()

        try store.recordAcceptedTranscript(
            "Keep this transcript",
            settings: .defaults,
            audioDuration: nil
        )
        try store.recordAcceptedTranscript(
            "Delete this transcript",
            settings: .defaults,
            audioDuration: nil
        )

        let entryToDelete = try #require(store.entries.first)

        #expect(store.deleteEntry(id: entryToDelete.id))
        #expect(store.entries.map(\.transcriptText) == ["Keep this transcript"])
        #expect(store.deleteEntry(id: UUID()) == false)
    }

    @Test func rejectsWhitespaceOnlyTranscript() {
        let store = TranscriptRecoveryHistoryStore()

        #expect(throws: TranscriptRecoveryHistoryError.emptyTranscript) {
            try store.recordAcceptedTranscript(
                " \n\t ",
                settings: .defaults,
                audioDuration: nil
            )
        }
        #expect(store.entries.isEmpty)
    }
}
