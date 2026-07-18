//
//  RecordingCaptureJournal.swift
//  HoldType
//

import Foundation
import HoldTypeDomain

struct RecordingCaptureLease: Equatable {
    let id: UUID
    let createdAt: Date
    let audioFileURL: URL
    let transcriptionModel: String
    let languageCode: String?
    let maximumDuration: TimeInterval
}

enum RecordingCaptureInspection: Equatable {
    case nonempty(AudioRecordingArtifact)
    case empty
    case missing
    case unavailable
}

enum RecordingCaptureJournalError: Error, Equatable, LocalizedError {
    case directoryUnavailable
    case journalWriteFailed
    case unsupportedCapture
    case releaseFailed
    case discardFailed

    var errorDescription: String? {
        switch self {
        case .directoryUnavailable:
            return "Recording recovery storage could not be prepared."
        case .journalWriteFailed:
            return "Recording recovery could not be prepared before capture."
        case .unsupportedCapture:
            return "The active recording could not be verified."
        case .releaseFailed:
            return "The completed recording remains protected in History."
        case .discardFailed:
            return "The discarded recording could not be removed completely."
        }
    }
}

@MainActor
protocol RecordingCaptureJournaling: AnyObject {
    func prepareCapture(
        settings: AppSettings,
        maximumDuration: TimeInterval
    ) throws -> RecordingCaptureLease
    func releaseCapture(
        _ lease: RecordingCaptureLease,
        artifact: AudioRecordingArtifact,
        recoveryAttemptID: FailedTranscriptionAttempt.ID
    ) throws -> AudioRecordingArtifact
    func retireCaptureAfterRecovery(
        _ lease: RecordingCaptureLease,
        recoveryAttemptID: FailedTranscriptionAttempt.ID
    ) throws
    func discardCapture(_ lease: RecordingCaptureLease) throws
    func inspectCapture(
        _ lease: RecordingCaptureLease,
        fallbackDuration: TimeInterval
    ) -> RecordingCaptureInspection
    func repairInterruptedCaptures(
        into recoveryStore: any TranscriptionFailureRecoveryRecording,
        onRepair: (UUID, RecordingDurabilityOutcome) -> Void
    ) -> Int
}

@MainActor
final class RecordingCaptureJournal: RecordingCaptureJournaling {
    static let shared = RecordingCaptureJournal()

    private nonisolated static let captureAudioPrefix = "HoldType-Capture-"
    private nonisolated static let captureMarkerPrefix = ".HoldType-Capture-"
    private nonisolated static let markerExtension = "json"

    private let directoryURL: URL
    private let releasedDirectoryURL: URL
    private let fileManager: FileManager
    private let now: () -> Date
    private let uuidProvider: () -> UUID

    init(
        directoryURL: URL? = nil,
        releasedDirectoryURL: URL? = nil,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        uuidProvider: @escaping () -> UUID = UUID.init
    ) {
        let activeDirectoryURL = directoryURL
            ?? Self.defaultActiveRecordingDirectoryURL(fileManager: fileManager)
        self.directoryURL = activeDirectoryURL
        self.releasedDirectoryURL = releasedDirectoryURL
            ?? (directoryURL == nil
                ? RecordingCacheService.shared.directoryURL
                : activeDirectoryURL)
        self.fileManager = fileManager
        self.now = now
        self.uuidProvider = uuidProvider
    }

    func prepareCapture(
        settings: AppSettings,
        maximumDuration: TimeInterval
    ) throws -> RecordingCaptureLease {
        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw RecordingCaptureJournalError.directoryUnavailable
        }
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        var activeDirectoryURL = directoryURL
        try? activeDirectoryURL.setResourceValues(resourceValues)

        let id = uuidProvider()
        let createdAt = now()
        let fileName = Self.captureAudioFileName(id: id, createdAt: createdAt)
        let lease = RecordingCaptureLease(
            id: id,
            createdAt: createdAt,
            audioFileURL: directoryURL.appendingPathComponent(fileName, isDirectory: false),
            transcriptionModel: settings.resolvedTranscriptionModel,
            languageCode: settings.resolvedLanguageCode,
            maximumDuration: maximumDuration
        )

        do {
            try persist(PersistedRecordingCapture(lease))
        } catch {
            throw RecordingCaptureJournalError.journalWriteFailed
        }
        return lease
    }

    func releaseCapture(
        _ lease: RecordingCaptureLease,
        artifact: AudioRecordingArtifact,
        recoveryAttemptID: FailedTranscriptionAttempt.ID
    ) throws -> AudioRecordingArtifact {
        guard isExactCapture(lease),
              artifact.fileURL.standardizedFileURL == lease.audioFileURL.standardizedFileURL,
              artifact.byteCount > 0,
              case .nonempty = inspectCapture(
                  lease,
                  fallbackDuration: artifact.duration
              ) else {
            throw RecordingCaptureJournalError.unsupportedCapture
        }

        do {
            // The recovery checkpoint is now the durable owner. Commit that
            // transfer before moving the original so a crash at any later
            // instruction is cleanup-only on the next launch.
            try persist(
                PersistedRecordingCapture(
                    lease,
                    transferredRecoveryAttemptID: recoveryAttemptID
                )
            )
        } catch {
            // A separate recovery checkpoint is already committed. If the
            // transfer marker itself cannot be advanced, deleting the source
            // and old marker is still safer than leaving a replayable capture.
            try? finishTransferredCaptureCleanup(lease)
            throw RecordingCaptureJournalError.releaseFailed
        }

        do {
            try fileManager.createDirectory(
                at: releasedDirectoryURL,
                withIntermediateDirectories: true
            )
        } catch {
            throw RecordingCaptureJournalError.releaseFailed
        }
        let releasedURL = releasedDirectoryURL.appendingPathComponent(
            Self.releasedAudioFileName(id: lease.id, createdAt: lease.createdAt),
            isDirectory: false
        )
        do {
            try fileManager.moveItem(at: lease.audioFileURL, to: releasedURL)
        } catch {
            throw RecordingCaptureJournalError.releaseFailed
        }

        // A stale marker is explicitly cleanup-only because the transfer was
        // persisted before the move.
        try? removeMarker(for: lease.id)
        return AudioRecordingArtifact(
            fileURL: releasedURL,
            duration: artifact.duration,
            byteCount: artifact.byteCount
        )
    }

    func retireCaptureAfterRecovery(
        _ lease: RecordingCaptureLease,
        recoveryAttemptID: FailedTranscriptionAttempt.ID
    ) throws {
        guard isExactCapture(lease) else {
            throw RecordingCaptureJournalError.unsupportedCapture
        }

        do {
            // Commit the ownership transfer before attempting cleanup. If
            // unlinking later fails, launch repair sees this marker and only
            // retries cleanup; it must never import the source a second time.
            try persist(
                PersistedRecordingCapture(
                    lease,
                    transferredRecoveryAttemptID: recoveryAttemptID
                )
            )
        } catch {
            // The separate recovery owner is already confirmed. If marker
            // advancement fails, remove the replayable source directly.
            do {
                try finishTransferredCaptureCleanup(lease)
                return
            } catch {
                throw RecordingCaptureJournalError.releaseFailed
            }
        }

        do {
            try finishTransferredCaptureCleanup(lease)
        } catch {
            // The transferred marker keeps this capture out of both cache
            // mutation and launch re-import until cleanup can finish.
            throw RecordingCaptureJournalError.releaseFailed
        }
    }

    func discardCapture(_ lease: RecordingCaptureLease) throws {
        guard isExactCapture(lease) else {
            throw RecordingCaptureJournalError.unsupportedCapture
        }

        do {
            try removeRegularFileIfPresent(at: lease.audioFileURL)
            try removeMarker(for: lease.id)
        } catch {
            throw RecordingCaptureJournalError.discardFailed
        }
    }

    func inspectCapture(
        _ lease: RecordingCaptureLease,
        fallbackDuration: TimeInterval = 0
    ) -> RecordingCaptureInspection {
        guard isExactCapture(lease) else {
            return .unavailable
        }

        guard fileManager.fileExists(atPath: lease.audioFileURL.path) else {
            return .missing
        }

        do {
            let values = try lease.audioFileURL.resourceValues(forKeys: [
                .isRegularFileKey,
                .isSymbolicLinkKey,
                .fileSizeKey,
            ])
            guard values.isRegularFile == true,
                  values.isSymbolicLink != true,
                  let fileSize = values.fileSize else {
                return .unavailable
            }
            let byteCount = Int64(fileSize)
            guard byteCount > 0 else {
                return .empty
            }
            let duration = fallbackDuration.isFinite && fallbackDuration > 0
                ? fallbackDuration
                : 0
            return .nonempty(
                AudioRecordingArtifact(
                    fileURL: lease.audioFileURL,
                    duration: duration,
                    byteCount: byteCount
                )
            )
        } catch {
            return .unavailable
        }
    }

    func repairInterruptedCaptures(
        into recoveryStore: any TranscriptionFailureRecoveryRecording,
        onRepair: (UUID, RecordingDurabilityOutcome) -> Void
    ) -> Int {
        var recoveredCount = 0
        for candidate in persistedAndOrphanedCaptures() {
            let lease = candidate.lease
            if candidate.transferredRecoveryAttemptID != nil {
                try? finishTransferredCaptureCleanup(lease)
                continue
            }
            switch inspectCapture(lease, fallbackDuration: 0) {
            case .nonempty(let artifact):
                let checkpoint: FailedTranscriptionAttempt
                do {
                    checkpoint = try recoveryStore.recordProcessingCheckpoint(
                        audioFileURL: artifact.fileURL,
                        settings: settings(for: lease),
                        audioDuration: nil,
                        completionKind: .standard
                    )
                } catch {
                    let fallback = recoveryStore.retainEmergencyFallback(
                        audioFileURL: artifact.fileURL,
                        settings: settings(for: lease),
                        audioDuration: nil,
                        reason: .recoveryOwnershipPersistenceFailed,
                        completionKind: .standard
                    )
                    if let fallback,
                       fallback.audioFileURL.standardizedFileURL
                        != artifact.fileURL.standardizedFileURL {
                        try? retireCaptureAfterRecovery(
                            lease,
                            recoveryAttemptID: fallback.id
                        )
                    }
                    if fallback != nil {
                        onRepair(fallback?.id ?? lease.id, .emergencyFallback)
                        recoveredCount += 1
                    }
                    continue
                }

                try? recoveryStore.updateFailedAttempt(
                    id: checkpoint.id,
                    reason: .processingInterrupted
                )
                do {
                    try retireCaptureAfterRecovery(
                        lease,
                        recoveryAttemptID: checkpoint.id
                    )
                } catch {
                    // The recovery checkpoint already owns a separate durable copy.
                }
                onRepair(checkpoint.id, .historyCheckpoint)
                recoveredCount += 1
            case .empty, .missing:
                try? discardCapture(lease)
                onRepair(lease.id, .emptyOrMissingDiscarded)
            case .unavailable:
                onRepair(lease.id, .protectedCapture)
                continue
            }
        }
        return recoveredCount
    }

    nonisolated static func isProtectedCaptureFileURL(_ fileURL: URL) -> Bool {
        captureIdentity(fileName: fileURL.lastPathComponent) != nil
    }

    private func settings(for lease: RecordingCaptureLease) -> AppSettings {
        var settings = AppSettings.defaults
        settings.transcriptionModel = lease.transcriptionModel
        if let languageCode = lease.languageCode {
            settings.language = .custom
            settings.customLanguageCode = languageCode
        } else {
            settings.language = .automatic
            settings.customLanguageCode = ""
        }
        return settings
    }

    private func persistedAndOrphanedCaptures() -> [RecordingCaptureCandidate] {
        guard let fileURLs = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: []
        ) else {
            return []
        }

        let persistedByID = Dictionary(
            uniqueKeysWithValues: fileURLs.compactMap {
                markerURL -> (UUID, RecordingCaptureCandidate)? in
                guard let id = Self.markerIdentity(fileName: markerURL.lastPathComponent),
                      let data = try? Data(contentsOf: markerURL),
                      let persisted = try? JSONDecoder.captureJournalDecoder.decode(
                          PersistedRecordingCapture.self,
                          from: data
                      ),
                      persisted.id == id,
                      let lease = persisted.lease(in: directoryURL),
                      isExactCapture(lease) else {
                    return nil
                }
                return (
                    id,
                    RecordingCaptureCandidate(
                        lease: lease,
                        transferredRecoveryAttemptID:
                            persisted.transferredRecoveryAttemptID
                    )
                )
            }
        )

        var captures = Array(persistedByID.values)
        let knownIDs = Set(persistedByID.keys)
        for audioURL in fileURLs {
            guard let id = Self.captureIdentity(fileName: audioURL.lastPathComponent),
                  !knownIDs.contains(id) else {
                continue
            }
            captures.append(
                RecordingCaptureCandidate(
                    lease: RecordingCaptureLease(
                        id: id,
                        createdAt: (try? audioURL.resourceValues(forKeys: [.creationDateKey]))?.creationDate
                            ?? .distantPast,
                        audioFileURL: audioURL,
                        transcriptionModel: AppSettings.defaults.resolvedTranscriptionModel,
                        languageCode: nil,
                        maximumDuration: RecordingDurationLimit.default.duration
                    ),
                    transferredRecoveryAttemptID: nil
                )
            )
        }
        return captures.sorted { $0.lease.createdAt < $1.lease.createdAt }
    }

    private func persist(_ capture: PersistedRecordingCapture) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        let data = try encoder.encode(capture)
        try data.write(to: markerURL(id: capture.id), options: .atomic)
    }

    private func removeMarker(for id: UUID) throws {
        let markerURL = markerURL(id: id)
        guard fileManager.fileExists(atPath: markerURL.path) else {
            return
        }
        try fileManager.removeItem(at: markerURL)
    }

    private func removeRegularFileIfPresent(at fileURL: URL) throws {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDirectory) else {
            return
        }
        guard !isDirectory.boolValue else {
            throw RecordingCaptureJournalError.unsupportedCapture
        }
        try fileManager.removeItem(at: fileURL)
    }

    private func finishTransferredCaptureCleanup(
        _ lease: RecordingCaptureLease
    ) throws {
        try removeRegularFileIfPresent(at: lease.audioFileURL)
        try removeMarker(for: lease.id)
    }

    private func isExactCapture(_ lease: RecordingCaptureLease) -> Bool {
        lease.audioFileURL.standardizedFileURL.deletingLastPathComponent()
            == directoryURL.standardizedFileURL
            && Self.captureIdentity(fileName: lease.audioFileURL.lastPathComponent) == lease.id
    }

    private func markerURL(id: UUID) -> URL {
        directoryURL.appendingPathComponent(
            "\(Self.captureMarkerPrefix)\(id.uuidString.lowercased()).\(Self.markerExtension)",
            isDirectory: false
        )
    }

    private static func captureAudioFileName(id: UUID, createdAt: Date) -> String {
        "\(captureAudioPrefix)\(fileTimestamp(from: createdAt))-\(id.uuidString.lowercased()).m4a"
    }

    private static func releasedAudioFileName(id: UUID, createdAt: Date) -> String {
        "HoldType-\(fileTimestamp(from: createdAt))-\(String(id.uuidString.prefix(8)).lowercased()).m4a"
    }

    private nonisolated static func captureIdentity(fileName: String) -> UUID? {
        guard fileName.hasPrefix(captureAudioPrefix),
              fileName.hasSuffix(".m4a") else {
            return nil
        }
        let stem = String(fileName.dropLast(4))
        // UUIDs contain hyphens, so use the fixed 36-character UUID suffix.
        guard stem.count > 36 else {
            return nil
        }
        let uuidStart = stem.index(stem.endIndex, offsetBy: -36)
        guard uuidStart > stem.startIndex,
              stem[stem.index(before: uuidStart)] == "-",
              let id = UUID(uuidString: String(stem[uuidStart...])) else {
            return nil
        }
        return id
    }

    private nonisolated static func markerIdentity(fileName: String) -> UUID? {
        guard fileName.hasPrefix(captureMarkerPrefix),
              fileName.hasSuffix(".\(markerExtension)") else {
            return nil
        }
        let rawID = fileName
            .dropFirst(captureMarkerPrefix.count)
            .dropLast(markerExtension.count + 1)
        return UUID(uuidString: String(rawID))
    }

    private static func fileTimestamp(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }

    static func defaultActiveRecordingDirectoryURL(
        fileManager: FileManager
    ) -> URL {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support", isDirectory: true)
        return applicationSupportURL
            .appendingPathComponent("HoldType", isDirectory: true)
            .appendingPathComponent("ActiveRecordings", isDirectory: true)
    }
}

private struct RecordingCaptureCandidate {
    let lease: RecordingCaptureLease
    let transferredRecoveryAttemptID: FailedTranscriptionAttempt.ID?
}

private struct PersistedRecordingCapture: Codable {
    let schemaVersion: Int
    let id: UUID
    let createdAt: Date
    let audioFileName: String
    let transcriptionModel: String
    let languageCode: String?
    let maximumDuration: TimeInterval
    let transferredRecoveryAttemptID: UUID?

    init(
        _ lease: RecordingCaptureLease,
        transferredRecoveryAttemptID: UUID? = nil
    ) {
        schemaVersion = 1
        id = lease.id
        createdAt = lease.createdAt
        audioFileName = lease.audioFileURL.lastPathComponent
        transcriptionModel = lease.transcriptionModel
        languageCode = lease.languageCode
        maximumDuration = lease.maximumDuration
        self.transferredRecoveryAttemptID = transferredRecoveryAttemptID
    }

    func lease(in directoryURL: URL) -> RecordingCaptureLease? {
        guard schemaVersion == 1,
              audioFileName == URL(fileURLWithPath: audioFileName).lastPathComponent,
              maximumDuration.isFinite,
              maximumDuration > 0 else {
            return nil
        }
        return RecordingCaptureLease(
            id: id,
            createdAt: createdAt,
            audioFileURL: directoryURL.appendingPathComponent(audioFileName, isDirectory: false),
            transcriptionModel: transcriptionModel,
            languageCode: languageCode,
            maximumDuration: maximumDuration
        )
    }
}

private extension JSONDecoder {
    static var captureJournalDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
