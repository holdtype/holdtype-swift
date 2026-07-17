//
//  RecordingCaptureJournalTests.swift
//  HoldTypeTests
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct RecordingCaptureJournalTests {
    private let captureID = UUID(
        uuidString: "00000000-0000-0000-0000-00000000CAFE"
    )!
    private let captureDate = Date(timeIntervalSince1970: 1_783_333_503)

    @Test func productionActiveDirectoryUsesApplicationSupportInsteadOfCache() {
        let activeURL = RecordingCaptureJournal.defaultActiveRecordingDirectoryURL(
            fileManager: .default
        )

        #expect(activeURL.lastPathComponent == "ActiveRecordings")
        #expect(activeURL.deletingLastPathComponent().lastPathComponent == "HoldType")
        #expect(activeURL.path.contains("/Library/Application Support/"))
        #expect(activeURL != RecordingCacheService.shared.directoryURL)
    }

    @Test func preparesDurableMarkerBeforeTheRecorderCreatesAudio() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cacheURL = rootURL.appendingPathComponent("Cache", isDirectory: true)
        let journal = makeJournal(directoryURL: cacheURL)

        let lease = try journal.prepareCapture(
            settings: .defaults,
            maximumDuration: 300
        )

        #expect(FileManager.default.fileExists(atPath: markerURL(in: cacheURL).path))
        #expect(FileManager.default.fileExists(atPath: lease.audioFileURL.path) == false)
        #expect(RecordingCaptureJournal.isProtectedCaptureFileURL(lease.audioFileURL))
        #expect(
            try cacheURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
                .isExcludedFromBackup == true
        )
    }

    @Test func releasingCompletedCaptureMovesItOutOfProtectedNamespace() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let activeURL = rootURL.appendingPathComponent("Active", isDirectory: true)
        let cacheURL = rootURL.appendingPathComponent("Cache", isDirectory: true)
        let journal = makeJournal(
            directoryURL: activeURL,
            releasedDirectoryURL: cacheURL
        )
        let lease = try journal.prepareCapture(
            settings: .defaults,
            maximumDuration: 300
        )
        let contents = Data("playable recording".utf8)
        try contents.write(to: lease.audioFileURL)

        let released = try journal.releaseCapture(
            lease,
            artifact: AudioRecordingArtifact(
                fileURL: lease.audioFileURL,
                duration: 12.5,
                byteCount: Int64(contents.count)
            ),
            recoveryAttemptID: UUID()
        )

        #expect(released.fileURL != lease.audioFileURL)
        #expect(released.fileURL.deletingLastPathComponent() == cacheURL)
        #expect(RecordingCaptureJournal.isProtectedCaptureFileURL(released.fileURL) == false)
        #expect(try Data(contentsOf: released.fileURL) == contents)
        #expect(FileManager.default.fileExists(atPath: lease.audioFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: markerURL(in: activeURL).path) == false)
    }

    @Test func launchRepairCopiesPositiveCaptureIntoPlayableRecoveryHistory() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cacheURL = rootURL.appendingPathComponent("Cache", isDirectory: true)
        let recoveryURL = rootURL.appendingPathComponent("Recovery", isDirectory: true)
        let journal = makeJournal(directoryURL: cacheURL)
        var settings = AppSettings.defaults
        settings.transcriptionModel = "gpt-4o-mini-transcribe"
        settings.language = .custom
        settings.customLanguageCode = "uk"
        let lease = try journal.prepareCapture(
            settings: settings,
            maximumDuration: 900
        )
        let contents = Data("interrupted but playable".utf8)
        try contents.write(to: lease.audioFileURL)
        let recoveryStore = TranscriptionFailureRecoveryStore(directoryURL: recoveryURL)

        let recoveredCount = journal.repairInterruptedCaptures(into: recoveryStore)

        #expect(recoveredCount == 1)
        let attempt = try #require(recoveryStore.failedAttempts.first)
        #expect(attempt.state == .failed)
        #expect(attempt.reason == .processingInterrupted)
        #expect(attempt.transcriptionModel == settings.resolvedTranscriptionModel)
        #expect(attempt.languageCode == "uk")
        #expect(attempt.audioFileURL != lease.audioFileURL)
        #expect(try Data(contentsOf: attempt.audioFileURL) == contents)
        #expect(FileManager.default.fileExists(atPath: lease.audioFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: markerURL(in: cacheURL).path) == false)
    }

    @Test func launchRepairDiscardsOnlyAnEmptyCapture() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cacheURL = rootURL.appendingPathComponent("Cache", isDirectory: true)
        let recoveryURL = rootURL.appendingPathComponent("Recovery", isDirectory: true)
        let journal = makeJournal(directoryURL: cacheURL)
        let lease = try journal.prepareCapture(
            settings: .defaults,
            maximumDuration: 300
        )
        try Data().write(to: lease.audioFileURL)
        let recoveryStore = TranscriptionFailureRecoveryStore(directoryURL: recoveryURL)

        let recoveredCount = journal.repairInterruptedCaptures(into: recoveryStore)

        #expect(recoveredCount == 0)
        #expect(recoveryStore.failedAttempts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: lease.audioFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: markerURL(in: cacheURL).path) == false)
    }

    @Test func launchRepairRecoversMarkerlessCaptureLeftByPartialCleanup() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cacheURL = rootURL.appendingPathComponent("Cache", isDirectory: true)
        let recoveryURL = rootURL.appendingPathComponent("Recovery", isDirectory: true)
        try FileManager.default.createDirectory(
            at: cacheURL,
            withIntermediateDirectories: true
        )
        let orphanURL = cacheURL.appendingPathComponent(
            "HoldType-Capture-20260717-120000-\(captureID.uuidString.lowercased()).m4a"
        )
        let contents = Data("orphaned capture".utf8)
        try contents.write(to: orphanURL)
        let journal = makeJournal(directoryURL: cacheURL)
        let recoveryStore = TranscriptionFailureRecoveryStore(directoryURL: recoveryURL)

        let recoveredCount = journal.repairInterruptedCaptures(into: recoveryStore)

        #expect(recoveredCount == 1)
        let attempt = try #require(recoveryStore.failedAttempts.first)
        #expect(try Data(contentsOf: attempt.audioFileURL) == contents)
        #expect(FileManager.default.fileExists(atPath: orphanURL.path) == false)
    }

    @Test func transferredMarkerMakesCleanupFailureIdempotentAcrossLaunches() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let activeURL = rootURL.appendingPathComponent("Active", isDirectory: true)
        let recoveryURL = rootURL.appendingPathComponent("Recovery", isDirectory: true)
        let fileManager = CaptureRemovalFailingFileManager()
        let journal = RecordingCaptureJournal(
            directoryURL: activeURL,
            fileManager: fileManager,
            now: { captureDate },
            uuidProvider: { captureID }
        )
        let lease = try journal.prepareCapture(
            settings: .defaults,
            maximumDuration: 300
        )
        try Data("one durable owner only".utf8).write(to: lease.audioFileURL)
        let recoveryStore = TranscriptionFailureRecoveryStore(directoryURL: recoveryURL)
        fileManager.failsAudioRemoval = true

        #expect(journal.repairInterruptedCaptures(into: recoveryStore) == 1)
        #expect(recoveryStore.failedAttempts.count == 1)
        #expect(FileManager.default.fileExists(atPath: lease.audioFileURL.path))
        let markerData = try Data(contentsOf: markerURL(in: activeURL))
        #expect(
            String(decoding: markerData, as: UTF8.self)
                .contains("transferredRecoveryAttemptID")
        )

        fileManager.failsAudioRemoval = false
        let relaunchedJournal = RecordingCaptureJournal(
            directoryURL: activeURL,
            fileManager: fileManager
        )
        #expect(
            relaunchedJournal.repairInterruptedCaptures(into: recoveryStore) == 0
        )
        #expect(recoveryStore.failedAttempts.count == 1)
        #expect(FileManager.default.fileExists(atPath: lease.audioFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: markerURL(in: activeURL).path) == false)
    }

    @Test func transferMarkerWriteFailureFallsBackToDirectCleanup() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let activeURL = rootURL.appendingPathComponent("Active", isDirectory: true)
        let journal = makeJournal(directoryURL: activeURL)
        let lease = try journal.prepareCapture(
            settings: .defaults,
            maximumDuration: 300
        )
        try Data("separately owned audio".utf8).write(to: lease.audioFileURL)
        let markerURL = markerURL(in: activeURL)
        try FileManager.default.removeItem(at: markerURL)
        try FileManager.default.createDirectory(
            at: markerURL,
            withIntermediateDirectories: false
        )

        try journal.retireCaptureAfterRecovery(
            lease,
            recoveryAttemptID: UUID()
        )

        #expect(FileManager.default.fileExists(atPath: lease.audioFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: markerURL.path) == false)
    }

    @Test func symlinkCaptureFailsClosedWithoutTouchingItsTarget() throws {
        let rootURL = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let cacheURL = rootURL.appendingPathComponent("Cache", isDirectory: true)
        let recoveryURL = rootURL.appendingPathComponent("Recovery", isDirectory: true)
        let journal = makeJournal(directoryURL: cacheURL)
        let lease = try journal.prepareCapture(
            settings: .defaults,
            maximumDuration: 300
        )
        let targetURL = rootURL.appendingPathComponent("outside-target.m4a")
        let targetContents = Data("must not be moved or removed".utf8)
        try targetContents.write(to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: lease.audioFileURL,
            withDestinationURL: targetURL
        )
        let recoveryStore = TranscriptionFailureRecoveryStore(directoryURL: recoveryURL)

        #expect(journal.inspectCapture(lease, fallbackDuration: 10) == .unavailable)
        #expect(journal.repairInterruptedCaptures(into: recoveryStore) == 0)
        #expect(recoveryStore.failedAttempts.isEmpty)
        #expect(try Data(contentsOf: targetURL) == targetContents)
        #expect(FileManager.default.fileExists(atPath: markerURL(in: cacheURL).path))
    }

    private func makeJournal(
        directoryURL: URL,
        releasedDirectoryURL: URL? = nil
    ) -> RecordingCaptureJournal {
        RecordingCaptureJournal(
            directoryURL: directoryURL,
            releasedDirectoryURL: releasedDirectoryURL,
            now: { captureDate },
            uuidProvider: { captureID }
        )
    }

    private func markerURL(in directoryURL: URL) -> URL {
        directoryURL.appendingPathComponent(
            ".HoldType-Capture-\(captureID.uuidString.lowercased()).json"
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "holdtype-capture-journal-tests-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        return directoryURL
    }
}

private final class CaptureRemovalFailingFileManager:
    FileManager,
    @unchecked Sendable {
    var failsAudioRemoval = false

    override func removeItem(at URL: URL) throws {
        if failsAudioRemoval, URL.pathExtension.lowercased() == "m4a" {
            throw CocoaError(.fileWriteUnknown)
        }
        try super.removeItem(at: URL)
    }
}
