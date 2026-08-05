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

    @Test func recordsAcceptedTranscriptsNewestFirstAndRestoresThemAfterRelaunch() throws {
        let persistence = InMemoryTranscriptHistoryPersistence()
        let store = TranscriptRecoveryHistoryStore(persistence: persistence)

        try store.recordAcceptedTranscript(
            try makeRequest(
                "  First transcript  ",
                transcriptionModel: "gpt-4o-mini-transcribe",
                language: .english,
                audioDuration: 1.5
            )
        )
        try store.recordAcceptedTranscript(
            try makeRequest(
                "Second transcript",
                transcriptionModel: "gpt-4o-mini-transcribe",
                language: .english,
                audioDuration: 2.5
            )
        )

        #expect(store.entries.map(\.transcriptText) == ["Second transcript", "First transcript"])
        #expect(store.entries.first?.transcriptionModel == "gpt-4o-mini-transcribe")
        #expect(store.entries.first?.languageCode == "en")
        #expect(store.entries.first?.audioDuration == 2.5)

        let relaunchedStore = TranscriptRecoveryHistoryStore(persistence: persistence)
        #expect(
            relaunchedStore.entries.map(\.transcriptText)
                == ["Second transcript", "First transcript"]
        )
    }

    @Test func userDefaultsHistorySurvivesAStoreRelaunch() throws {
        let suiteName = "holdtype.TranscriptRecoveryHistoryStoreTests.\(UUID().uuidString)"
        let userDefaults = try #require(UserDefaults(suiteName: suiteName))
        defer { userDefaults.removePersistentDomain(forName: suiteName) }
        let storageKey = "history-relaunch"

        let firstStore = TranscriptRecoveryHistoryStore(
            userDefaults: userDefaults,
            storageKey: storageKey
        )
        try firstStore.recordAcceptedTranscript(try makeRequest("Persisted transcript"))

        let relaunchedStore = TranscriptRecoveryHistoryStore(
            userDefaults: userDefaults,
            storageKey: storageKey
        )

        #expect(relaunchedStore.entries.map(\.transcriptText) == ["Persisted transcript"])
    }

    @Test func disabledSettingDoesNotRecordTranscript() throws {
        let store = TranscriptRecoveryHistoryStore(
            persistence: InMemoryTranscriptHistoryPersistence()
        )

        try store.recordAcceptedTranscript(
            try makeRequest(
                "Private transcript",
                historyEnabled: false
            )
        )

        #expect(store.entries.isEmpty)
    }

    @Test func recordsCachedAudioFileURLWhenRecordingCacheKeepsRecordings() throws {
        let persistence = InMemoryTranscriptHistoryPersistence()
        let store = TranscriptRecoveryHistoryStore(persistence: persistence)
        let cachedAudioFileURL = URL(fileURLWithPath: "/tmp/HoldType-cache-enabled.m4a")

        try store.recordAcceptedTranscript(
            try makeRequest(
                "Cached transcript",
                recordingCachePolicy: .keepLast(10),
                audioDuration: 3.5,
                cachedAudioFileURL: cachedAudioFileURL
            )
        )

        #expect(store.entries.first?.cachedAudioFileURL == cachedAudioFileURL)
        #expect(
            TranscriptRecoveryHistoryStore(persistence: persistence)
                .entries.first?.cachedAudioFileURL == nil
        )
    }

    @Test func dropsCachedAudioFileURLWhenRecordingCacheDeletesImmediately() throws {
        let store = TranscriptRecoveryHistoryStore(
            persistence: InMemoryTranscriptHistoryPersistence()
        )
        let cachedAudioFileURL = URL(fileURLWithPath: "/tmp/HoldType-cache-disabled.m4a")

        try store.recordAcceptedTranscript(
            try makeRequest(
                "Uncached transcript",
                recordingCachePolicy: .deleteImmediately,
                audioDuration: 3.5,
                cachedAudioFileURL: cachedAudioFileURL
            )
        )

        #expect(store.entries.first?.cachedAudioFileURL == nil)
    }

    @Test func retainsOnlyMostRecentTwentyEntries() throws {
        let persistence = InMemoryTranscriptHistoryPersistence()
        let store = TranscriptRecoveryHistoryStore(persistence: persistence)

        for offset in 0..<21 {
            try store.recordAcceptedTranscript(
                try makeRequest("Transcript \(offset)")
            )
        }

        #expect(store.entries.count == TranscriptRecoveryHistoryStore.defaultRetentionLimit)
        #expect(store.entries.first?.transcriptText == "Transcript 20")
        #expect(store.entries.last?.transcriptText == "Transcript 1")
        #expect(store.entries.contains { $0.transcriptText == "Transcript 0" } == false)
        #expect(
            TranscriptRecoveryHistoryStore(persistence: persistence).entries.count
                == TranscriptRecoveryHistoryStore.defaultRetentionLimit
        )
    }

    @Test func clearRemovesPersistedRecoveryEntries() throws {
        let persistence = InMemoryTranscriptHistoryPersistence()
        let store = TranscriptRecoveryHistoryStore(persistence: persistence)

        try store.recordAcceptedTranscript(
            try makeRequest("Recoverable transcript")
        )

        try store.clear()

        #expect(store.entries.isEmpty)
        #expect(TranscriptRecoveryHistoryStore(persistence: persistence).entries.isEmpty)
    }

    @Test func deleteEntryRemovesOnlyMatchingPersistedEntry() throws {
        let persistence = InMemoryTranscriptHistoryPersistence()
        let store = TranscriptRecoveryHistoryStore(persistence: persistence)

        try store.recordAcceptedTranscript(
            try makeRequest("Keep this transcript")
        )
        try store.recordAcceptedTranscript(
            try makeRequest("Delete this transcript")
        )

        let entryToDelete = try #require(store.entries.first)

        #expect(try store.deleteEntry(id: entryToDelete.id))
        #expect(store.entries.map(\.transcriptText) == ["Keep this transcript"])
        #expect(try store.deleteEntry(id: UUID()) == false)
        #expect(
            TranscriptRecoveryHistoryStore(persistence: persistence)
                .entries.map(\.transcriptText) == ["Keep this transcript"]
        )
    }

    @Test func persistenceFailuresDoNotPublishUncommittedChanges() throws {
        let persistence = InMemoryTranscriptHistoryPersistence(saveError: TestPersistenceError.failed)
        let store = TranscriptRecoveryHistoryStore(persistence: persistence)

        #expect(throws: TranscriptRecoveryHistoryError.saveFailed) {
            try store.recordAcceptedTranscript(try makeRequest("Unsaved transcript"))
        }
        #expect(store.entries.isEmpty)
        #expect(store.storageErrorMessage == "Transcript history could not be saved.")
    }

    @Test func unreadablePersistedHistoryIsReportedWithoutCrashingLaunch() {
        let persistence = InMemoryTranscriptHistoryPersistence(
            storedData: Data("not-json".utf8)
        )

        let store = TranscriptRecoveryHistoryStore(persistence: persistence)

        #expect(store.entries.isEmpty)
        #expect(store.storageErrorMessage == "Saved transcript history could not be read.")
    }

    private func makeRequest(
        _ rawText: String,
        transcriptionModel: String = TranscriptionConfiguration.defaultModel,
        language: TranscriptionLanguage = .automatic,
        customLanguageCode: String = "",
        historyEnabled: Bool = true,
        recordingCachePolicy: RecordingCachePolicy = .deleteImmediately,
        audioDuration: TimeInterval? = nil,
        cachedAudioFileURL: URL? = nil
    ) throws -> AcceptedTranscriptHistoryRequest {
        try AcceptedTranscriptHistoryRequest(
            acceptedTranscript: AcceptedTranscript(rawText: rawText),
            transcriptionConfiguration: TranscriptionConfiguration(
                model: transcriptionModel,
                language: language,
                customLanguageCode: customLanguageCode
            ),
            retentionConfiguration: RetentionConfiguration(
                historyEnabled: historyEnabled,
                recordingCachePolicy: recordingCachePolicy
            ),
            audioDuration: audioDuration,
            cachedAudioFileURL: cachedAudioFileURL
        )
    }
}

private enum TestPersistenceError: Error {
    case failed
}

private final class InMemoryTranscriptHistoryPersistence: TranscriptHistoryPersistence {
    private var storedData: Data?
    private let loadError: Error?
    private let saveError: Error?
    private let removeError: Error?

    init(
        storedData: Data? = nil,
        loadError: Error? = nil,
        saveError: Error? = nil,
        removeError: Error? = nil
    ) {
        self.storedData = storedData
        self.loadError = loadError
        self.saveError = saveError
        self.removeError = removeError
    }

    func loadTranscriptHistoryData(forKey key: String) throws -> Data? {
        if let loadError {
            throw loadError
        }
        return storedData
    }

    func saveTranscriptHistoryData(_ data: Data, forKey key: String) throws {
        if let saveError {
            throw saveError
        }
        storedData = data
    }

    func removeTranscriptHistoryData(forKey key: String) throws {
        if let removeError {
            throw removeError
        }
        storedData = nil
    }
}
