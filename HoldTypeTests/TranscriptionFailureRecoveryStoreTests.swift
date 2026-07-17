//
//  TranscriptionFailureRecoveryStoreTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/7/26.
//

import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
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

    @Test func recordsFailedAttemptByCopyingAudioIntoSessionRecovery() throws {
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
        #expect(attempt.state == .failed)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(FileManager.default.fileExists(atPath: attempt.audioFileURL.path))
        #expect(attempt.audioFileURL.path.hasPrefix(fixture.recoveryURL.path))
    }

    @Test func processingCheckpointCopiesNonemptyAudioEvenWhenAcceptedHistoryIsOff() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "processing.m4a")
        var settings = AppSettings.defaults
        settings.saveTranscriptHistory = false
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)

        let attempt = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: settings,
            audioDuration: 30
        )

        #expect(attempt.state == .processing)
        #expect(store.failedAttempts == [attempt])
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(FileManager.default.fileExists(atPath: attempt.audioFileURL.path))
    }

    @Test func processingCheckpointRejectsEmptyAudio() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = fixture.rootURL.appendingPathComponent("empty.m4a")
        try Data().write(to: sourceURL)
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)

        #expect(throws: TranscriptionFailureRecoveryError.audioUnavailable) {
            try store.recordProcessingCheckpoint(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: 0
            )
        }
        #expect(store.failedAttempts.isEmpty)
    }

    @Test func checkpointAndMarkerFailureReconstructsMaximumPlayableOrphan() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        try FileManager.default.createDirectory(
            at: fixture.recoveryURL,
            withIntermediateDirectories: true
        )
        let metadataURL = fixture.recoveryURL.appendingPathComponent("Recovery.json")
        try FileManager.default.createDirectory(
            at: metadataURL,
            withIntermediateDirectories: false
        )
        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "metadata-blocked.m4a")
        let attemptID = UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!
        try FileManager.default.createDirectory(
            at: fixture.recoveryURL.appendingPathComponent(
                "ProcessingCheckpoint-\(attemptID.uuidString.lowercased()).json"
            ),
            withIntermediateDirectories: false
        )
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            uuidProvider: { attemptID }
        )

        #expect(throws: TranscriptionFailureRecoveryError.saveFailed) {
            try store.recordProcessingCheckpoint(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: 300,
                completionKind: .maximumDuration
            )
        }
        let orphanAudioURLs = try FileManager.default.contentsOfDirectory(
            at: fixture.recoveryURL,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "m4a" }
        let orphanAudioURL = try #require(orphanAudioURLs.first)
        #expect(orphanAudioURLs.count == 1)
        #expect(FileManager.default.fileExists(atPath: orphanAudioURL.path))
        let checkpointMarkerNames = try FileManager.default.contentsOfDirectory(
            atPath: fixture.recoveryURL.path
        ).filter { $0.hasPrefix("ProcessingCheckpoint-") }
        #expect(checkpointMarkerNames.count == 1)

        let blockedRestoredStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let blockedRestored = try #require(blockedRestoredStore.failedAttempts.first)
        #expect(blockedRestored.id == attemptID)
        #expect(blockedRestored.state == .failed)
        #expect(blockedRestored.reason == .processingInterrupted)
        #expect(blockedRestored.completionKind == .maximumDuration)
        #expect(blockedRestored.canRetry)
        #expect(blockedRestored.audioFileURL == orphanAudioURL)

        try FileManager.default.removeItem(at: metadataURL)
        let restoredStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let restored = try #require(restoredStore.failedAttempts.first)
        #expect(restored.id == attemptID)
        #expect(restored.state == .failed)
        #expect(restored.reason == .processingInterrupted)
        #expect(restored.completionKind == .maximumDuration)
        #expect(restored.canRetry)
        #expect(restored.audioFileURL == orphanAudioURL)
        #expect(TranscriptHistoryAudioPlaybackAction().canPlay(restored))
    }

    @Test func failedUpdateTransitionsProcessingCheckpointWithoutCountingInitialFailureAsRetry() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "transition.m4a")
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 8
        )

        try store.updateFailedAttempt(id: checkpoint.id, reason: .networkUnavailable)
        let failedAttempt = try #require(store.failedAttempts.first)
        #expect(failedAttempt.state == .failed)
        #expect(failedAttempt.reason == .networkUnavailable)
        #expect(failedAttempt.retryCount == 0)

        try store.updateFailedAttempt(id: checkpoint.id, reason: .timedOut)
        #expect(store.failedAttempts.first?.reason == .timedOut)
        #expect(store.failedAttempts.first?.retryCount == 1)
    }

    @Test func restoresInterruptedProcessingCheckpointAsRetryableFailureAfterRelaunch() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "durable.m4a")
        let id = UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!
        let firstStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            now: { Date(timeIntervalSince1970: 1_781_983_983) },
            uuidProvider: { id }
        )
        let checkpoint = try firstStore.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 42
        )

        let restoredStore = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let restored = try #require(restoredStore.failedAttempts.first)

        #expect(restored.id == checkpoint.id)
        #expect(restored.createdAt == checkpoint.createdAt)
        #expect(restored.state == .failed)
        #expect(restored.reason == .processingInterrupted)
        #expect(restored.reason.canRetry)
        #expect(restored.audioDuration == 42)
        #expect(canonicalFileURL(restored.audioFileURL) == canonicalFileURL(checkpoint.audioFileURL))
        #expect(FileManager.default.fileExists(atPath: restored.audioFileURL.path))
    }

    @Test func corruptMetadataReconstructsOwnedAudioAndPersistsStableRetryRow() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let id = UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!
        let audioFileURL = try makeRecoveryAudioFile(
            in: fixture.recoveryURL,
            timestamp: "20260716-231751",
            id: id
        )
        try Data("not-json".utf8).write(
            to: fixture.recoveryURL.appendingPathComponent("Recovery.json")
        )

        let firstStore = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let reconstructed = try #require(firstStore.failedAttempts.first)

        #expect(firstStore.failedAttempts.count == 1)
        #expect(reconstructed.id == id)
        #expect(canonicalFileURL(reconstructed.audioFileURL) == canonicalFileURL(audioFileURL))
        #expect(reconstructed.state == .failed)
        #expect(reconstructed.reason == .processingInterrupted)
        #expect(reconstructed.reason.canRetry)
        #expect(reconstructed.transcriptionModel == AppSettings.defaults.resolvedTranscriptionModel)
        #expect(reconstructed.languageCode == AppSettings.defaults.resolvedLanguageCode)

        let restoredStore = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        #expect(restoredStore.failedAttempts.map(\.id) == [id])
        #expect(
            canonicalFileURL(restoredStore.failedAttempts.first?.audioFileURL)
                == canonicalFileURL(audioFileURL)
        )
    }

    @Test func orphanReconstructionIgnoresSymlinksNonregularFilesAndUnmanagedNames() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let retainedID = UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!
        let directoryID = UUID(uuidString: "42502885-F88B-42C6-84AC-E0C5550843EF")!
        let symlinkID = UUID(uuidString: "145E0EB0-D53F-4425-8B76-BF4E830DBB18")!
        let retainedURL = try makeRecoveryAudioFile(
            in: fixture.recoveryURL,
            timestamp: "20260716-231751",
            id: retainedID
        )
        let directoryURL = recoveryAudioURL(
            in: fixture.recoveryURL,
            timestamp: "20260716-231752",
            id: directoryID
        )
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
        let outsideURL = try makeAudioFile(in: fixture.rootURL, named: "outside.m4a")
        let symlinkURL = recoveryAudioURL(
            in: fixture.recoveryURL,
            timestamp: "20260716-231753",
            id: symlinkID
        )
        try FileManager.default.createSymbolicLink(at: symlinkURL, withDestinationURL: outsideURL)
        try Data("audio".utf8).write(
            to: fixture.recoveryURL.appendingPathComponent("Recording-manual.m4a")
        )
        try Data("audio".utf8).write(
            to: fixture.recoveryURL.appendingPathComponent("notes.m4a")
        )

        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)

        #expect(store.failedAttempts.map(\.id) == [retainedID])
        #expect(
            canonicalFileURL(store.failedAttempts.first?.audioFileURL)
                == canonicalFileURL(retainedURL)
        )
        #expect(FileManager.default.fileExists(atPath: symlinkURL.path))
        #expect(FileManager.default.fileExists(atPath: outsideURL.path))
        #expect(FileManager.default.fileExists(atPath: directoryURL.path))
    }

    @Test func orphanReconstructionNeverEvictsUnresolvedAudioByCount() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let ids = [
            UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!,
            UUID(uuidString: "42502885-F88B-42C6-84AC-E0C5550843EF")!,
            UUID(uuidString: "145E0EB0-D53F-4425-8B76-BF4E830DBB18")!,
        ]
        let fileURLs = try ids.enumerated().map { index, id in
            let fileURL = try makeRecoveryAudioFile(
                in: fixture.recoveryURL,
                timestamp: "20260716-23175\(index + 1)",
                id: id
            )
            try FileManager.default.setAttributes(
                [.modificationDate: Date(timeIntervalSince1970: TimeInterval(index + 1))],
                ofItemAtPath: fileURL.path
            )
            return fileURL
        }

        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            retentionLimit: 2
        )

        #expect(Set(store.failedAttempts.map(\.id)) == Set(ids))
        #expect(FileManager.default.fileExists(atPath: fileURLs[0].path))
        #expect(FileManager.default.fileExists(atPath: fileURLs[1].path))
        #expect(FileManager.default.fileExists(atPath: fileURLs[2].path))
    }

    @Test func newCheckpointNeverEvictsAnOlderUnresolvedAttempt() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let firstSourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "first-unresolved.m4a"
        )
        let secondSourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "second-unresolved.m4a"
        )
        var identifiers = [
            UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!,
            UUID(uuidString: "42502885-F88B-42C6-84AC-E0C5550843EF")!,
        ]
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            retentionLimit: 1,
            uuidProvider: { identifiers.removeFirst() }
        )

        let first = try store.recordProcessingCheckpoint(
            audioFileURL: firstSourceURL,
            settings: .defaults,
            audioDuration: 10
        )
        try store.updateFailedAttempt(id: first.id, reason: .networkFailure)
        let second = try store.recordProcessingCheckpoint(
            audioFileURL: secondSourceURL,
            settings: .defaults,
            audioDuration: 20
        )

        #expect(Set(store.failedAttempts.map(\.id)) == [first.id, second.id])
        #expect(FileManager.default.fileExists(atPath: first.audioFileURL.path))
        #expect(FileManager.default.fileExists(atPath: second.audioFileURL.path))

        let relaunched = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            retentionLimit: 1
        )
        #expect(Set(relaunched.failedAttempts.map(\.id)) == [first.id, second.id])
    }

    @Test func emergencyFallbackNeverHidesAnotherUnresolvedAttempt() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sources = try ["first.m4a", "second.m4a"].map {
            try makeAudioFile(in: fixture.rootURL, named: $0)
        }
        var identifiers = [
            UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!,
            UUID(uuidString: "42502885-F88B-42C6-84AC-E0C5550843EF")!,
        ]
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            retentionLimit: 1,
            uuidProvider: { identifiers.removeFirst() }
        )

        let attempts = sources.compactMap {
            store.retainEmergencyFallback(
                audioFileURL: $0,
                settings: .defaults,
                audioDuration: 10,
                reason: .other
            )
        }

        #expect(attempts.count == 2)
        #expect(Set(store.failedAttempts.map(\.id)) == Set(attempts.map(\.id)))
        #expect(sources.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
    }

    @Test func removingOneCheckpointDeletesOnlyItsRecoveryCopy() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let firstSourceURL = try makeAudioFile(in: fixture.rootURL, named: "first.m4a")
        let secondSourceURL = try makeAudioFile(in: fixture.rootURL, named: "second.m4a")
        var ids = [
            UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!,
            UUID(uuidString: "42502885-F88B-42C6-84AC-E0C5550843EF")!,
        ]
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            uuidProvider: { ids.removeFirst() }
        )
        let first = try store.recordProcessingCheckpoint(
            audioFileURL: firstSourceURL,
            settings: .defaults,
            audioDuration: 1
        )
        let second = try store.recordProcessingCheckpoint(
            audioFileURL: secondSourceURL,
            settings: .defaults,
            audioDuration: 2
        )

        try store.removeFailedAttempt(id: first.id)

        #expect(store.failedAttempts.map(\.id) == [second.id])
        #expect(FileManager.default.fileExists(atPath: first.audioFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: second.audioFileURL.path))
        #expect(FileManager.default.fileExists(atPath: firstSourceURL.path))
        #expect(FileManager.default.fileExists(atPath: secondSourceURL.path))
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

    @Test func emergencyFallbackKeepsOriginalUntilExplicitDiscard() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "emergency-original.m4a"
        )
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )

        let attempt = try #require(
            store.retainEmergencyFallback(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: 30,
                reason: .other
            )
        )

        #expect(attempt.audioFileURL == sourceURL)
        #expect(attempt.reason == .recoveryOwnershipPersistenceFailed)
        #expect(attempt.canRetry == false)
        #expect(TranscriptHistoryAudioPlaybackAction().canPlay(attempt))
        #expect(store.failedAttempts == [attempt])
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))

        try store.removeFailedAttempt(id: attempt.id)

        #expect(store.failedAttempts.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sourceURL.path))
    }

    @Test func ownershipRepairUsesDurableMainIndexWhenCheckpointMarkerFails() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        try FileManager.default.createDirectory(
            at: fixture.recoveryURL,
            withIntermediateDirectories: true
        )
        let id = UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!
        let sourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "main-index-repair.m4a"
        )
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            uuidProvider: { id }
        )
        let emergency = try #require(
            store.retainEmergencyFallback(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: 300,
                reason: .other,
                completionKind: .maximumDuration
            )
        )
        let markerURL = fixture.recoveryURL.appendingPathComponent(
            "ProcessingCheckpoint-\(id.uuidString.lowercased()).json"
        )
        try FileManager.default.createDirectory(
            at: markerURL,
            withIntermediateDirectories: false
        )

        try store.repairLocalRecovery(id: emergency.id)

        let repaired = try #require(store.failedAttempts.first)
        #expect(repaired.reason == .processingInterrupted)
        #expect(repaired.canRetry)
        #expect(repaired.audioFileURL != sourceURL)
        #expect(FileManager.default.fileExists(atPath: repaired.audioFileURL.path))
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))

        let relaunched = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let restored = try #require(relaunched.failedAttempts.first)
        #expect(restored.id == id)
        #expect(restored.reason == .processingInterrupted)
        #expect(restored.canRetry)
    }

    @Test func ownershipRepairUsesDurableCheckpointMarkerWhenMainIndexFails() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        try FileManager.default.createDirectory(
            at: fixture.recoveryURL,
            withIntermediateDirectories: true
        )
        let metadataURL = fixture.recoveryURL.appendingPathComponent("Recovery.json")
        try FileManager.default.createDirectory(
            at: metadataURL,
            withIntermediateDirectories: false
        )
        let id = UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!
        let sourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "checkpoint-marker-repair.m4a"
        )
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            uuidProvider: { id }
        )
        let emergency = try #require(
            store.retainEmergencyFallback(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: 300,
                reason: .other,
                completionKind: .maximumDuration
            )
        )

        try store.repairLocalRecovery(id: emergency.id)

        let repaired = try #require(store.failedAttempts.first)
        #expect(repaired.reason == .processingInterrupted)
        #expect(repaired.canRetry)
        let markerURL = fixture.recoveryURL.appendingPathComponent(
            "ProcessingCheckpoint-\(id.uuidString.lowercased()).json"
        )
        #expect(FileManager.default.fileExists(atPath: markerURL.path))
        #expect(FileManager.default.fileExists(atPath: repaired.audioFileURL.path))
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))

        let relaunched = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let restored = try #require(relaunched.failedAttempts.first)
        #expect(restored.id == id)
        #expect(restored.reason == .processingInterrupted)
        #expect(restored.canRetry)
    }

    @Test func deleteReportsMetadataFailureWithoutRemovingAudioOrHidingRow() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "metadata-failure.m4a")
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let attempt = try #require(
            try store.recordFailedAttempt(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: 5,
                reason: .timedOut
            )
        )
        let metadataURL = fixture.recoveryURL.appendingPathComponent("Recovery.json")
        try FileManager.default.removeItem(at: metadataURL)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: false)

        #expect(throws: TranscriptionFailureRecoveryError.deleteFailed) {
            _ = try store.removeFailedAttempt(id: attempt.id)
        }
        #expect(store.failedAttempts == [attempt])
        #expect(FileManager.default.fileExists(atPath: attempt.audioFileURL.path))
    }

    @Test func deleteRollsMetadataBackAndRetainsRowWhenAudioUnlinkFails() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let fileManager = ControlledRemovalFileManager()
        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "unlink-failure.m4a")
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            fileManager: fileManager
        )
        let attempt = try #require(
            try store.recordFailedAttempt(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: 5,
                reason: .networkUnavailable
            )
        )
        fileManager.blockedRemovalURL = attempt.audioFileURL

        #expect(throws: TranscriptionFailureRecoveryError.deleteFailed) {
            _ = try store.removeFailedAttempt(id: attempt.id)
        }
        #expect(store.failedAttempts == [attempt])
        #expect(FileManager.default.fileExists(atPath: attempt.audioFileURL.path))

        let restoredStore = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        #expect(restoredStore.failedAttempts.map(\.id) == [attempt.id])
        #expect(restoredStore.failedAttempts.first?.reason == .networkUnavailable)

        fileManager.blockedRemovalURL = nil
        #expect(try store.removeFailedAttempt(id: attempt.id))
        #expect(store.failedAttempts.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: attempt.audioFileURL.path))
        #expect(try store.removeFailedAttempt(id: attempt.id) == false)
    }

    @Test func acceptedStandardCleanupFailureKeepsDispatchSealWhenRollbackFails() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let fileManager = ControlledRemovalFileManager()
        let sourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "accepted-standard-cleanup.m4a"
        )
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            fileManager: fileManager
        )
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 23,
            completionKind: .standard
        )
        try store.sealProviderDispatch(id: checkpoint.id)
        store.recordProviderAccepted(
            id: checkpoint.id,
            acceptedTranscriptText: "Accepted standard transcript"
        )
        let ownedAudioURL = try #require(store.failedAttempts.first?.audioFileURL)
        let metadataURL = fixture.recoveryURL.appendingPathComponent("Recovery.json")
        let dispatchMarkerURL = fixture.recoveryURL.appendingPathComponent(
            "ProviderDispatch-\(checkpoint.id.uuidString.lowercased()).json"
        )
        let repairMarkerURL = fixture.recoveryURL.appendingPathComponent(
            "SavedStateRepair-\(checkpoint.id.uuidString.lowercased()).json"
        )
        fileManager.blockedRemovalURL = ownedAudioURL
        fileManager.onBlockedRemoval = { _ in
            try? FileManager.default.removeItem(at: metadataURL)
            try? FileManager.default.createDirectory(
                at: metadataURL,
                withIntermediateDirectories: false
            )
        }

        #expect(throws: TranscriptionFailureRecoveryError.deleteFailed) {
            _ = try store.removeFailedAttempt(id: checkpoint.id)
        }

        #expect(FileManager.default.fileExists(atPath: ownedAudioURL.path))
        #expect(FileManager.default.fileExists(atPath: dispatchMarkerURL.path))
        #expect(FileManager.default.fileExists(atPath: repairMarkerURL.path))
        let relaunched = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let restored = try #require(relaunched.failedAttempts.first)
        #expect(restored.id == checkpoint.id)
        #expect(restored.completionKind == .standard)
        #expect(restored.reason == .savedStatePersistenceFailed)
        #expect(restored.acceptedTranscriptText == "Accepted standard transcript")
        #expect(restored.canRetry == false)
        #expect(TranscriptHistoryAudioPlaybackAction().canPlay(restored))
        let presentation = TranscriptionRecoveryHistoryRowPresentation(
            attempt: restored
        )
        #expect(presentation.showsRetry == false)
    }

    @Test func savedAcceptedDeleteDoubleFaultKeepsLifetimeDispatchSeal() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let fileManager = ControlledRemovalFileManager()
        let sourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "saved-accepted-double-fault.m4a"
        )
        let firstStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            fileManager: fileManager
        )
        let checkpoint = try firstStore.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )
        try firstStore.sealProviderDispatch(id: checkpoint.id)
        firstStore.recordProviderAccepted(
            id: checkpoint.id,
            acceptedTranscriptText: "Accepted maximum transcript"
        )
        try firstStore.markSaved(
            id: checkpoint.id,
            acceptedTranscriptText: "Accepted maximum transcript"
        )
        let dispatchMarkerURL = fixture.recoveryURL.appendingPathComponent(
            "ProviderDispatch-\(checkpoint.id.uuidString.lowercased()).json"
        )
        #expect(FileManager.default.fileExists(atPath: dispatchMarkerURL.path))

        let restoredStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            fileManager: fileManager
        )
        let savedAttempt = try #require(restoredStore.failedAttempts.first)
        #expect(savedAttempt.state == .saved)
        #expect(savedAttempt.acceptedTranscriptText == "Accepted maximum transcript")
        #expect(FileManager.default.fileExists(atPath: dispatchMarkerURL.path))

        let metadataURL = fixture.recoveryURL.appendingPathComponent("Recovery.json")
        fileManager.blockedRemovalURL = savedAttempt.audioFileURL
        fileManager.onBlockedRemoval = { _ in
            try? FileManager.default.removeItem(at: metadataURL)
            try? FileManager.default.createDirectory(
                at: metadataURL,
                withIntermediateDirectories: false
            )
        }

        #expect(throws: TranscriptionFailureRecoveryError.deleteFailed) {
            _ = try restoredStore.removeFailedAttempt(id: savedAttempt.id)
        }

        #expect(
            FileManager.default.fileExists(
                atPath: savedAttempt.audioFileURL.path
            )
        )
        #expect(FileManager.default.fileExists(atPath: dispatchMarkerURL.path))
        let doubleFaultRelaunch = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let uncertain = try #require(doubleFaultRelaunch.failedAttempts.first)
        #expect(uncertain.id == savedAttempt.id)
        #expect(uncertain.completionKind == .maximumDuration)
        #expect(uncertain.reason == .providerOutcomeUncertain)
        #expect(uncertain.canRetry == false)
        #expect(TranscriptHistoryAudioPlaybackAction().canPlay(uncertain))
        let presentation = TranscriptionRecoveryHistoryRowPresentation(
            attempt: uncertain
        )
        #expect(presentation.showsRetry == false)
    }

    @Test func pruningDuplicateIDAudioDoesNotConsumeRetainedDispatchSeal() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sharedID = UUID(
            uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2"
        )!
        var timestamp: TimeInterval = 1_784_160_000
        let firstStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            retentionLimit: 2,
            now: {
                defer { timestamp += 1 }
                return Date(timeIntervalSince1970: timestamp)
            },
            uuidProvider: { sharedID }
        )
        let olderSourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "duplicate-older.m4a"
        )
        let newerSourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "duplicate-newer.m4a"
        )
        let olderCheckpoint = try firstStore.recordProcessingCheckpoint(
            audioFileURL: olderSourceURL,
            settings: .defaults,
            audioDuration: 12,
            completionKind: .standard
        )
        let newerCheckpoint = try firstStore.recordProcessingCheckpoint(
            audioFileURL: newerSourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )
        try firstStore.sealProviderDispatch(id: newerCheckpoint.id)
        firstStore.recordProviderAccepted(
            id: newerCheckpoint.id,
            acceptedTranscriptText: "Retained duplicate transcript"
        )
        try firstStore.markSaved(
            id: newerCheckpoint.id,
            acceptedTranscriptText: "Retained duplicate transcript"
        )
        let savedNewer = try #require(
            firstStore.failedAttempts.first { $0.state == .saved }
        )
        #expect(savedNewer.audioFileURL != olderCheckpoint.audioFileURL)
        let dispatchMarkerURL = fixture.recoveryURL.appendingPathComponent(
            "ProviderDispatch-\(sharedID.uuidString.lowercased()).json"
        )
        let markerObject = try #require(
            try JSONSerialization.jsonObject(
                with: Data(contentsOf: dispatchMarkerURL)
            ) as? [String: Any]
        )
        #expect(markerObject["audioFileName"] as? String == savedNewer.audioFileURL.lastPathComponent)

        let prunedStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            retentionLimit: 1
        )
        let retained = try #require(prunedStore.failedAttempts.first)
        #expect(retained.id == sharedID)
        #expect(retained.state == .saved)
        #expect(retained.audioFileURL.lastPathComponent == savedNewer.audioFileURL.lastPathComponent)
        #expect(!FileManager.default.fileExists(atPath: olderCheckpoint.audioFileURL.path))
        #expect(FileManager.default.fileExists(atPath: retained.audioFileURL.path))
        #expect(FileManager.default.fileExists(atPath: dispatchMarkerURL.path))

        let metadataURL = fixture.recoveryURL.appendingPathComponent("Recovery.json")
        try Data("corrupt index".utf8).write(to: metadataURL, options: .atomic)
        let corruptIndexRelaunch = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            retentionLimit: 1
        )
        let uncertain = try #require(corruptIndexRelaunch.failedAttempts.first)
        #expect(uncertain.id == sharedID)
        #expect(uncertain.completionKind == .maximumDuration)
        #expect(uncertain.reason == .providerOutcomeUncertain)
        #expect(uncertain.canRetry == false)
        #expect(TranscriptHistoryAudioPlaybackAction().canPlay(uncertain))
    }

    @Test func savedAttemptRoundTripsAcceptedTextAndAudioAcrossRelaunch() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "maximum.m4a")
        let attemptID = UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!
        let firstStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            now: { Date(timeIntervalSince1970: 1_784_160_000) },
            uuidProvider: { attemptID }
        )
        let checkpoint = try firstStore.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )

        try firstStore.markSaved(
            id: checkpoint.id,
            acceptedTranscriptText: "  Durable accepted transcript\n"
        )

        let saved = try #require(firstStore.failedAttempts.first)
        #expect(saved.state == .saved)
        #expect(saved.acceptedTranscriptText == "Durable accepted transcript")
        #expect(saved.canRetry == false)
        #expect(saved.canDelete)
        #expect(FileManager.default.fileExists(atPath: saved.audioFileURL.path))

        let restoredStore = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let restored = try #require(restoredStore.failedAttempts.first)
        #expect(restored.id == attemptID)
        #expect(restored.state == .saved)
        #expect(restored.completionKind == .maximumDuration)
        #expect(restored.acceptedTranscriptText == "Durable accepted transcript")
        #expect(canonicalFileURL(restored.audioFileURL) == canonicalFileURL(saved.audioFileURL))
        #expect(FileManager.default.fileExists(atPath: restored.audioFileURL.path))
    }

    @Test func markSavedFailureSurvivesRelaunchAsLocalOnlyRepair() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "atomic.m4a")
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )
        let metadataURL = fixture.recoveryURL.appendingPathComponent("Recovery.json")
        try FileManager.default.removeItem(at: metadataURL)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: false)

        #expect(throws: TranscriptionFailureRecoveryError.saveFailed) {
            try store.markSaved(
                id: checkpoint.id,
                acceptedTranscriptText: "Must not publish"
            )
        }

        let retained = try #require(store.failedAttempts.first)
        #expect(retained.state == .failed)
        #expect(retained.reason == .savedStatePersistenceFailed)
        #expect(retained.canRetry == false)
        #expect(retained.acceptedTranscriptText == "Must not publish")
        #expect(FileManager.default.fileExists(atPath: retained.audioFileURL.path))

        let repairMarkerNames = try FileManager.default.contentsOfDirectory(
            atPath: fixture.recoveryURL.path
        ).filter { $0.hasPrefix("SavedStateRepair-") }
        #expect(repairMarkerNames.count == 1)

        let relaunchedStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let restored = try #require(relaunchedStore.failedAttempts.first)
        #expect(restored.id == checkpoint.id)
        #expect(restored.state == .failed)
        #expect(restored.reason == .savedStatePersistenceFailed)
        #expect(restored.completionKind == .maximumDuration)
        #expect(restored.canRetry == false)
        #expect(restored.acceptedTranscriptText == "Must not publish")
        #expect(canonicalFileURL(restored.audioFileURL) == canonicalFileURL(retained.audioFileURL))
        #expect(FileManager.default.fileExists(atPath: restored.audioFileURL.path))
        let presentation = TranscriptionRecoveryHistoryRowPresentation(
            attempt: restored
        )
        #expect(presentation.showsRetry == false)
        #expect(presentation.showsSaveRetry)

        try FileManager.default.removeItem(at: metadataURL)
        try relaunchedStore.markSaved(
            id: checkpoint.id,
            acceptedTranscriptText: "Must not publish"
        )
        #expect(relaunchedStore.failedAttempts.first?.state == .saved)
        #expect(relaunchedStore.failedAttempts.first?.acceptedTranscriptText == "Must not publish")
        let remainingMarkerNames = try FileManager.default.contentsOfDirectory(
            atPath: fixture.recoveryURL.path
        ).filter { $0.hasPrefix("SavedStateRepair-") }
        #expect(remainingMarkerNames.isEmpty)
    }

    @Test func retrySuccessPromotesFailedMaximumAttemptToSaved() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "retry-max.m4a")
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )
        try store.updateFailedAttempt(id: checkpoint.id, reason: .networkUnavailable)

        try store.markSaved(
            id: checkpoint.id,
            acceptedTranscriptText: "Recovered maximum transcript"
        )

        let saved = try #require(store.failedAttempts.first)
        #expect(saved.state == .saved)
        #expect(saved.completionKind == .maximumDuration)
        #expect(saved.acceptedTranscriptText == "Recovered maximum transcript")
        #expect(saved.canRetry == false)
        #expect(FileManager.default.fileExists(atPath: saved.audioFileURL.path))
    }

    @Test func newerPostProcessingFailureWinsOverStaleAcceptedRepairMarker() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "stale-marker.m4a")
        var timestamp: TimeInterval = 1_784_160_000
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            now: {
                defer { timestamp += 1 }
                return Date(timeIntervalSince1970: timestamp)
            }
        )
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )

        store.recordProviderAccepted(
            id: checkpoint.id,
            acceptedTranscriptText: "Raw provider transcript"
        )
        let markerURL = fixture.recoveryURL.appendingPathComponent(
            "SavedStateRepair-\(checkpoint.id.uuidString.lowercased()).json"
        )
        let staleAcceptedMarker = try Data(contentsOf: markerURL)

        try store.updateFailedAttempt(
            id: checkpoint.id,
            reason: .networkFailure
        )
        let failedAfterAcceptance = try #require(store.failedAttempts.first)
        #expect(
            failedAfterAcceptance.reason
                == .postProcessingFailedAfterProviderAcceptance
        )

        // Recreate the selective-write failure state: Recovery.json contains
        // the newer downstream failure while the marker still contains the
        // earlier accepted-provider checkpoint.
        try staleAcceptedMarker.write(to: markerURL, options: .atomic)

        let relaunchedStore = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let restored = try #require(relaunchedStore.failedAttempts.first)
        #expect(restored.state == .failed)
        #expect(restored.reason == .postProcessingFailedAfterProviderAcceptance)
        #expect(restored.acceptedTranscriptText == "Raw provider transcript")
        #expect(restored.canRetry == false)
        let failedPresentation = TranscriptionRecoveryHistoryRowPresentation(
            attempt: restored
        )
        #expect(failedPresentation.saveRetryTitle == "Save Raw Transcription")

        try relaunchedStore.markSaved(
            id: checkpoint.id,
            acceptedTranscriptText: "Raw provider transcript"
        )
        let saved = try #require(relaunchedStore.failedAttempts.first)
        #expect(saved.state == .saved)
        #expect(saved.reason == .postProcessingFailedAfterProviderAcceptance)
        let savedPresentation = TranscriptionRecoveryHistoryRowPresentation(
            attempt: saved
        )
        #expect(
            savedPresentation.title
                == "Raw transcription saved — post-processing failed"
        )
    }

    @Test func standardDispatchSealRelaunchesAsOutcomeUncertain() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "standard-dispatch.m4a"
        )
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 18,
            completionKind: .standard
        )

        try store.sealProviderDispatch(id: checkpoint.id)

        let relaunched = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let restored = try #require(relaunched.failedAttempts.first)
        #expect(restored.id == checkpoint.id)
        #expect(restored.completionKind == .standard)
        #expect(restored.reason == .providerOutcomeUncertain)
        #expect(restored.canRetry == false)
        #expect(TranscriptHistoryAudioPlaybackAction().canPlay(restored))
    }

    @Test func standardAcceptedCheckpointSurvivesPostProcessingFailureAndLocalSave() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(
            in: fixture.rootURL,
            named: "standard-accepted.m4a"
        )
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 21,
            completionKind: .standard
        )
        try store.sealProviderDispatch(id: checkpoint.id)
        store.recordProviderAccepted(
            id: checkpoint.id,
            acceptedTranscriptText: "  Standard raw transcript \n"
        )
        try store.updateFailedAttempt(
            id: checkpoint.id,
            reason: .timedOut
        )

        let relaunched = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL
        )
        let restored = try #require(relaunched.failedAttempts.first)
        #expect(restored.id == checkpoint.id)
        #expect(restored.completionKind == .standard)
        #expect(restored.reason == .postProcessingFailedAfterProviderAcceptance)
        #expect(restored.acceptedTranscriptText == "Standard raw transcript")
        #expect(restored.canRetry == false)

        try relaunched.markSaved(
            id: restored.id,
            acceptedTranscriptText: "Standard raw transcript"
        )
        let saved = try #require(relaunched.failedAttempts.first)
        #expect(saved.state == .saved)
        #expect(saved.completionKind == .standard)
        #expect(saved.reason == .postProcessingFailedAfterProviderAcceptance)
        let presentation = TranscriptionRecoveryHistoryRowPresentation(
            attempt: saved
        )
        #expect(
            presentation.title
                == "Raw transcription saved — post-processing failed"
        )
    }

    @Test func legacyMetadataWithoutNewSavedFieldsStillRestoresFailedAttempt() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "legacy.m4a")
        let firstStore = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let attempt = try #require(
            try firstStore.recordFailedAttempt(
                audioFileURL: sourceURL,
                settings: .defaults,
                audioDuration: 12,
                reason: .networkUnavailable
            )
        )
        let metadataURL = fixture.recoveryURL.appendingPathComponent("Recovery.json")
        var legacyRecords = try #require(
            try JSONSerialization.jsonObject(with: Data(contentsOf: metadataURL))
                as? [[String: Any]]
        )
        legacyRecords[0].removeValue(forKey: "completionKind")
        legacyRecords[0].removeValue(forKey: "acceptedTranscriptText")
        try JSONSerialization.data(withJSONObject: legacyRecords)
            .write(to: metadataURL, options: .atomic)
        let metadataText = try String(contentsOf: metadataURL, encoding: .utf8)
        #expect(metadataText.contains("acceptedTranscriptText") == false)
        #expect(metadataText.contains("completionKind") == false)

        let restoredStore = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let restored = try #require(restoredStore.failedAttempts.first)
        #expect(restored.id == attempt.id)
        #expect(restored.state == .failed)
        #expect(restored.reason == .networkUnavailable)
        #expect(restored.acceptedTranscriptText == nil)
        #expect(restored.completionKind == .standard)
    }

    @Test func savedAndFailedRowsShareTheExistingBoundedRetention() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        var timestamp: TimeInterval = 1_784_160_000
        var ids = [
            UUID(uuidString: "D9C6D531-C23C-4D7C-A0C0-976A9E289ED2")!,
            UUID(uuidString: "42502885-F88B-42C6-84AC-E0C5550843EF")!,
            UUID(uuidString: "145E0EB0-D53F-4425-8B76-BF4E830DBB18")!,
        ]
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.recoveryURL,
            retentionLimit: 2,
            now: {
                defer { timestamp += 1 }
                return Date(timeIntervalSince1970: timestamp)
            },
            uuidProvider: { ids.removeFirst() }
        )

        let firstSourceURL = try makeAudioFile(in: fixture.rootURL, named: "first-max.m4a")
        let first = try store.recordProcessingCheckpoint(
            audioFileURL: firstSourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )
        try store.markSaved(id: first.id, acceptedTranscriptText: "First")
        let firstRecoveryURL = first.audioFileURL

        let secondSourceURL = try makeAudioFile(in: fixture.rootURL, named: "failed.m4a")
        _ = try store.recordFailedAttempt(
            audioFileURL: secondSourceURL,
            settings: .defaults,
            audioDuration: 20,
            reason: .networkUnavailable
        )

        let thirdSourceURL = try makeAudioFile(in: fixture.rootURL, named: "third-max.m4a")
        let third = try store.recordProcessingCheckpoint(
            audioFileURL: thirdSourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )
        try store.markSaved(id: third.id, acceptedTranscriptText: "Third")

        #expect(store.failedAttempts.count == 2)
        #expect(
            store.failedAttempts.map(\.state.rawValue).sorted()
                == [
                    TranscriptionRecoveryState.failed.rawValue,
                    TranscriptionRecoveryState.saved.rawValue,
                ].sorted()
        )
        #expect(store.failedAttempts.contains { $0.acceptedTranscriptText == "Third" })
        #expect(store.failedAttempts.contains { $0.reason == .networkUnavailable })
        #expect(FileManager.default.fileExists(atPath: firstRecoveryURL.path) == false)
    }

    @Test func deletingSavedAttemptRemovesOnlyItsDurableAudio() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.rootURL) }

        let sourceURL = try makeAudioFile(in: fixture.rootURL, named: "saved-delete.m4a")
        let store = TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: sourceURL,
            settings: .defaults,
            audioDuration: 300,
            completionKind: .maximumDuration
        )
        try store.markSaved(id: checkpoint.id, acceptedTranscriptText: "Delete me")
        let recoveryURL = try #require(store.failedAttempts.first?.audioFileURL)

        #expect(try store.removeFailedAttempt(id: checkpoint.id))

        #expect(store.failedAttempts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: recoveryURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(
            TranscriptionFailureRecoveryStore(directoryURL: fixture.recoveryURL)
                .failedAttempts.isEmpty
        )
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

    private func makeRecoveryAudioFile(
        in directoryURL: URL,
        timestamp: String,
        id: UUID
    ) throws -> URL {
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let fileURL = recoveryAudioURL(in: directoryURL, timestamp: timestamp, id: id)
        try Data("audio".utf8).write(to: fileURL)
        return fileURL
    }

    private func recoveryAudioURL(in directoryURL: URL, timestamp: String, id: UUID) -> URL {
        directoryURL.appendingPathComponent(
            "Recording-\(timestamp)-\(id.uuidString.lowercased()).m4a"
        )
    }

    private func canonicalFileURL(_ url: URL?) -> URL? {
        url?.standardizedFileURL.resolvingSymlinksInPath()
    }
}

private final class ControlledRemovalFileManager: FileManager {
    var blockedRemovalURL: URL?
    var onBlockedRemoval: ((URL) -> Void)?

    override func removeItem(at URL: URL) throws {
        if URL.standardizedFileURL == blockedRemovalURL?.standardizedFileURL {
            onBlockedRemoval?(URL)
            throw CocoaError(.fileWriteNoPermission)
        }
        try super.removeItem(at: URL)
    }
}
