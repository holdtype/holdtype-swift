import Darwin
import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

@Suite(.serialized)
struct IOSV1VoiceCaptureTests {
    @Test func validCapturePromotesTheSameAudioWithoutCopyOrRemoval()
        async throws {
        let fixture = CaptureFixture(durationMilliseconds: 1_250)
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .standard,
            createdAt: CaptureDates.created
        )
        var exposedURL: URL?
        try lease.withTransientRecordingURL { exposedURL = $0 }
        try lease.revalidateRecorderCheckpoint()
        #expect(exposedURL?.lastPathComponent == fixture.fileSystem.fileName)
        #expect(try await fixture.repository.load().capture?.phase == .recording)

        try await lease.beginFinalizing()
        #expect(try await fixture.repository.load().capture?.phase == .finalizing)
        guard case .completed(let completed) =
            try await lease.completeAfterRecorderClose() else {
            Issue.record("Expected completed capture")
            return
        }
        #expect(try await fixture.repository.load().capture?.phase == .completed)

        let pending = try await completed.promote(
            transcriptionConfiguration: TranscriptionConfiguration()
        )
        let snapshot = try await fixture.repository.load()
        #expect(snapshot.capture == nil)
        #expect(snapshot.pending == pending)
        #expect(
            pending.audioRelativeIdentifier
                == IOSVoiceStateStorageLocation.relativeAudioIdentifier(
                    for: CaptureIDs.attempt
                )
        )
        #expect(fixture.fileSystem.createCount == 1)
        #expect(fixture.fileSystem.removeCount == 0)
    }

    @Test func fiveMinuteFinalizationToleranceKeepsCanonicalDuration()
        async throws {
        for duration in [Int64(300_000), 302_000] {
            let fixture = CaptureFixture(durationMilliseconds: duration)
            let lease = try await fixture.owner.createCapture(
                attemptID: CaptureIDs.attempt,
                outputIntent: .standard,
                createdAt: CaptureDates.created
            )
            try await lease.beginFinalizing()
            guard case .completed(let completed) =
                try await lease.completeAfterRecorderClose() else {
                Issue.record("Expected tolerated five-minute capture")
                continue
            }

            #expect(completed.durationMilliseconds == duration)
            let pending = try await completed.promote(
                transcriptionConfiguration: .defaults
            )
            #expect(pending.durationMilliseconds == duration)
            #expect(fixture.fileSystem.removeCount == 0)
        }
    }

    @Test func selectedLimitControlsCanonicalFinalizationAndSurvivesRelaunch()
        async throws {
        for minutes in [1, 15] {
            let limit = RecordingDurationLimit(minutes: minutes)
            let duration = limit.maximumFinalizedMediaDurationMilliseconds
            let fixture = CaptureFixture(durationMilliseconds: duration)
            let lease = try await fixture.owner.createCapture(
                attemptID: CaptureIDs.attempt,
                outputIntent: .standard,
                recordingDurationLimit: limit,
                createdAt: CaptureDates.created
            )
            try await lease.beginFinalizing()

            guard case .completed(let completed) = try await lease
                .completeAfterRecorderClose() else {
                Issue.record("Expected configured-limit capture")
                continue
            }

            #expect(completed.recordingDurationLimit == limit)
            #expect(completed.durationMilliseconds == duration)
            let persisted = try await fixture.repository.load().capture
            #expect(persisted?.recordingDurationLimit == limit)
            #expect(persisted?.durationMilliseconds == duration)
            completed.release()
        }
    }

    @Test func mediaBeyondSelectedLimitUsesTheAttemptSpecificFallback()
        async throws {
        let limit = RecordingDurationLimit(minutes: 1)
        let fixture = CaptureFixture(durationMilliseconds: 62_001)
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .standard,
            recordingDurationLimit: limit,
            createdAt: CaptureDates.created
        )
        try await lease.beginFinalizing()

        guard case .completed(let completed) = try await lease
            .completeAfterRecorderClose(
                fallbackDurationMilliseconds: 80_000
            ) else {
            Issue.record("Expected recoverable configured-limit capture")
            return
        }

        #expect(
            completed.durationMilliseconds
                == limit.maximumFinalizedMediaDurationMilliseconds
        )
        #expect(fixture.fileSystem.removeCount == 0)
        completed.release()
    }

    @Test func abnormalPositiveDurationBecomesUnknownInsteadOfBlocked()
        async throws {
        let duration: Int64 = 302_001
        let fixture = CaptureFixture(durationMilliseconds: duration)
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .standard,
            createdAt: CaptureDates.created
        )
        try await lease.beginFinalizing()
        guard case .completed(let completed) =
            try await lease.completeAfterRecorderClose() else {
            Issue.record("Expected overrun capture to remain recoverable")
            return
        }

        #expect(completed.durationMilliseconds == 0)
        let pending = try await completed.promote(
            transcriptionConfiguration: .defaults,
            initialStatus: .failed
        )
        #expect(pending.durationMilliseconds == 0)
        #expect(try await fixture.repository.load().pending?.status == .failed)
        #expect(fixture.fileSystem.removeCount == 0)
    }

    @Test func explicitDiscardIsDurableBeforeExactUnlink() async throws {
        let fixture = CaptureFixture(durationMilliseconds: 1_250)
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .translate,
            createdAt: CaptureDates.created
        )

        try await lease.beginDiscardingBeforeRecorderStop()
        let beforeUnlink = try await fixture.repository.load()
        #expect(beforeUnlink.capture?.phase == .discarding)
        #expect(fixture.fileSystem.removeCount == 0)

        try await lease.finishDiscardAfterRecorderStop()
        #expect(try await fixture.repository.load().capture == nil)
        #expect(fixture.fileSystem.removedAttemptIDs == [CaptureIDs.attempt])
        #expect(fixture.fileSystem.closeCount == 1)
    }

    @Test func shortNonEmptyMediaBecomesRecoverableWithSuspectDuration()
        async throws {
        let fixture = CaptureFixture(durationMilliseconds: 299)
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .standard,
            createdAt: CaptureDates.created
        )
        try await lease.beginFinalizing()

        guard case .completed(let completed) =
            try await lease.completeAfterRecorderClose() else {
            Issue.record("Expected non-empty short probe to remain recoverable")
            return
        }
        let snapshot = try await fixture.repository.load()
        #expect(completed.durationMilliseconds == 0)
        #expect(snapshot.capture?.phase == .completed)
        #expect(snapshot.capture?.durationMilliseconds == 0)
        #expect(snapshot.pending == nil)
        #expect(fixture.fileSystem.removeCount == 0)
        completed.release()
    }

    @Test func invalidMetadataOnNonEmptyMediaBecomesRecoverableUnknown()
        async throws {
        let fixture = CaptureFixture(mediaMode: .invalidMedia)
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .standard,
            createdAt: CaptureDates.created
        )
        try await lease.beginFinalizing()

        guard case .completed(let completed) =
            try await lease.completeAfterRecorderClose() else {
            Issue.record("Expected invalid metadata to preserve non-empty audio")
            return
        }
        #expect(completed.durationMilliseconds == 0)
        #expect(try await fixture.repository.load().capture?.phase == .completed)
        #expect(fixture.fileSystem.removeCount == 0)
        completed.release()
    }

    @Test func longMonotonicElapsedRecoversShortOrInvalidMediaProbe()
        async throws {
        let cases: [(CaptureMediaValidator.Mode, Int64, Int64)] = [
            (.duration(299), 30_000, 30_000),
            (.invalidMedia, 30_000, 30_000),
            (.invalidMedia, 329_000, 302_000),
            (.duration(302_001), 329_000, 302_000),
        ]
        for (mediaMode, fallback, expectedDuration) in cases {
            let fixture = CaptureFixture(mediaMode: mediaMode)
            let lease = try await fixture.owner.createCapture(
                attemptID: CaptureIDs.attempt,
                outputIntent: .standard,
                createdAt: CaptureDates.created
            )
            try await lease.beginFinalizing()

            guard case .completed(let completed) = try await lease
                .completeAfterRecorderClose(
                    fallbackDurationMilliseconds: fallback
                ) else {
                Issue.record("Expected monotonic duration fallback")
                continue
            }
            #expect(completed.durationMilliseconds == expectedDuration)
            let pending = try await completed.promote(
                transcriptionConfiguration: .defaults
            )
            #expect(pending.durationMilliseconds == expectedDuration)
            #expect(fixture.fileSystem.removeCount == 0)
        }
    }

    @Test func exactEmptyMediaIsTheOnlyAutomaticFinalizationDiscard()
        async throws {
        let fixture = CaptureFixture(durationMilliseconds: 1_250)
        fixture.fileSystem.facts = IOSV1VoiceCaptureFileFacts(
            identity: fixture.fileSystem.facts.identity,
            byteCount: 0,
            modificationSeconds: fixture.fileSystem.facts.modificationSeconds,
            modificationNanoseconds:
                fixture.fileSystem.facts.modificationNanoseconds
        )
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .standard,
            createdAt: CaptureDates.created
        )
        try await lease.beginFinalizing()

        guard case .discarded(.empty) =
            try await lease.completeAfterRecorderClose() else {
            Issue.record("Expected exact empty capture discard")
            return
        }
        #expect(try await fixture.repository.load().capture == nil)
        #expect(fixture.fileSystem.removeCount == 1)
    }

    @Test func validationTimeoutPreservesNonEmptyAudioAsUnknownCompleted()
        async throws {
        let fixture = CaptureFixture(mediaMode: .timedOut)
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .standard,
            createdAt: CaptureDates.created
        )
        try await lease.beginFinalizing()

        guard case .completed(let completed) = try await lease
            .completeAfterRecorderClose() else {
            Issue.record("Expected timeout to preserve completed audio")
            return
        }
        #expect(completed.durationMilliseconds == 0)
        #expect(try await fixture.repository.load().capture?.phase == .completed)
        #expect(fixture.fileSystem.removeCount == 0)
        completed.release()
    }

    @Test func sourceReplacementBlocksURLAndPreservesDurableOwner()
        async throws {
        let fixture = CaptureFixture(durationMilliseconds: 1_250)
        let lease = try await fixture.owner.createCapture(
            attemptID: CaptureIDs.attempt,
            outputIntent: .standard,
            createdAt: CaptureDates.created
        )
        fixture.fileSystem.failValidation = true

        #expect(throws: IOSV1VoiceCaptureError.sourceChanged) {
            try lease.withTransientRecordingURL { _ in }
        }
        #expect(try await fixture.repository.load().capture?.phase == .recording)
        #expect(fixture.fileSystem.removeCount == 0)
        lease.release()
    }

    @Test func metadataFailureRemovesAndClosesTheCreatedFile() async throws {
        let fixture = CaptureFixture(durationMilliseconds: 1_250)
        fixture.metadata.failNextWrite = true

        await #expect(throws: IOSVoiceStateRepositoryError.writeFailed) {
            _ = try await fixture.owner.createCapture(
                attemptID: CaptureIDs.attempt,
                outputIntent: .standard,
                createdAt: CaptureDates.created
            )
        }
        #expect(try await fixture.repository.load().capture == nil)
        #expect(fixture.fileSystem.createCount == 1)
        #expect(fixture.fileSystem.removeCount == 1)
        #expect(fixture.fileSystem.closeCount == 1)
    }

    @Test func darwinBoundaryIsExclusiveModeSixHundredAndIdentityPinned()
        throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ios-v1-capture-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let fileSystem = IOSV1VoiceCaptureDarwinFileSystem()
        let fileName = "pending-v1-\(CaptureIDs.attempt.uuidString.lowercased()).m4a"
        let handle = try fileSystem.create(
            attemptID: CaptureIDs.attempt,
            directoryURL: root,
            fileName: fileName
        )
        defer { fileSystem.close(handle) }

        let permissions = try FileManager.default.attributesOfItem(
            atPath: handle.fileURL.path
        )[.posixPermissions] as? NSNumber
        #expect(permissions?.intValue == 0o600)
        #expect(
            try handle.fileURL.resourceValues(
                forKeys: [.isExcludedFromBackupKey]
            ).isExcludedFromBackup == true
        )
        #expect(throws: IOSV1VoiceCaptureError.sourceConflict) {
            _ = try fileSystem.create(
                attemptID: CaptureIDs.attempt,
                directoryURL: root,
                fileName: fileName
            )
        }

        try FileManager.default.removeItem(at: handle.fileURL)
        try Data("replacement".utf8).write(to: handle.fileURL)
        #expect(throws: IOSV1VoiceCaptureError.sourceChanged) {
            _ = try fileSystem.validate(handle)
        }
    }
}

private final class CaptureFixture: @unchecked Sendable {
    let metadata = CaptureMetadataFileSystem()
    let fileSystem = CaptureFileSystem()
    let repository: IOSVoiceStateRepository
    let owner: IOSV1VoiceCaptureOwner

    convenience init(durationMilliseconds: Int64) {
        self.init(mediaMode: .duration(durationMilliseconds))
    }

    init(mediaMode: CaptureMediaValidator.Mode) {
        let root = URL(fileURLWithPath: "/tmp/ios-v1-capture-tests")
        repository = IOSVoiceStateRepository(
            fileURL: root.appendingPathComponent("voice-state.json"),
            fileSystem: metadata,
            now: { CaptureDates.updated }
        )
        owner = IOSV1VoiceCaptureOwner(
            repository: repository,
            directoryURL: root,
            fileSystem: fileSystem,
            mediaValidator: CaptureMediaValidator(mode: mediaMode)
        )
    }
}

private final class CaptureFileSystem:
    IOSV1VoiceCaptureFileSystem,
    @unchecked Sendable {
    private let lock = NSLock()
    private(set) var fileName: String?
    private(set) var createCount = 0
    private(set) var removeCount = 0
    private(set) var closeCount = 0
    private(set) var removedAttemptIDs: [UUID] = []
    var failValidation = false
    var facts = IOSV1VoiceCaptureFileFacts(
        identity: IOSV1VoiceCaptureFileIdentity(device: 7, inode: 11),
        byteCount: 4_096,
        modificationSeconds: 1_700_000_000,
        modificationNanoseconds: 0
    )

    func create(
        attemptID: UUID,
        directoryURL: URL,
        fileName: String
    ) throws -> IOSV1VoiceCaptureFileHandle {
        lock.withLock {
            self.fileName = fileName
            createCount += 1
        }
        return IOSV1VoiceCaptureFileHandle(
            attemptID: attemptID,
            directoryDescriptor: 40,
            fileDescriptor: 41,
            directoryURL: directoryURL,
            fileName: fileName,
            directoryIdentity: IOSV1VoiceCaptureFileIdentity(
                device: 3,
                inode: 5
            ),
            identity: facts.identity
        )
    }

    func validate(
        _ handle: IOSV1VoiceCaptureFileHandle
    ) throws -> IOSV1VoiceCaptureFileFacts {
        try lock.withLock {
            guard !failValidation, handle.identity == facts.identity else {
                throw IOSV1VoiceCaptureError.sourceChanged
            }
            return facts
        }
    }

    func synchronize(_: IOSV1VoiceCaptureFileHandle) throws {}

    func remove(_ handle: IOSV1VoiceCaptureFileHandle) throws {
        _ = try validate(handle)
        lock.withLock {
            removeCount += 1
            removedAttemptIDs.append(handle.attemptID)
        }
    }

    func close(_: IOSV1VoiceCaptureFileHandle) {
        lock.withLock { closeCount += 1 }
    }
}

private struct CaptureMediaValidator: IOSV1VoiceCaptureMediaValidating {
    enum Mode: Sendable {
        case duration(Int64)
        case invalidMedia
        case timedOut
    }

    let mode: Mode

    func durationMilliseconds(
        fileDescriptor _: Int32,
        byteCount _: Int64,
        timeoutNanoseconds: UInt64
    ) throws -> Int64 {
        #expect(timeoutNanoseconds <= 2_000_000_000)
        switch mode {
        case .duration(let value): return value
        case .invalidMedia:
            throw IOSV1VoiceCaptureError.mediaValidationFailed
        case .timedOut: throw IOSV1VoiceCaptureError.mediaValidationTimedOut
        }
    }
}

private final class CaptureMetadataFileSystem:
    ProtectedAtomicMetadataFileSystem,
    @unchecked Sendable {
    private let lock = NSLock()
    private var bytes: Data?
    var failNextWrite = false

    func readFileIfPresent(
        at _: URL,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws -> Data? {
        try lock.withLock {
            if let bytes, bytes.count > policy.maximumByteCount {
                throw ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded
            }
            return bytes
        }
    }

    func replaceFileAtomically(
        at _: URL,
        with data: Data,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws {
        if failNextWrite {
            failNextWrite = false
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }
        guard data.count <= policy.maximumByteCount else {
            throw ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded
        }
        lock.withLock { bytes = data }
    }

    func removeFileIfPresent(at _: URL) throws {
        lock.withLock { bytes = nil }
    }
}

private enum CaptureIDs {
    static let attempt = UUID(
        uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA"
    )!
}

private enum CaptureDates {
    static let created = Date(timeIntervalSince1970: 1_700_000_000)
    static let updated = Date(timeIntervalSince1970: 1_700_000_001)
}
