import Foundation
import HoldTypeDomain

enum IOSV1VoiceCaptureError: Error, Equatable, Sendable {
    case captureAlreadyExists
    case namespaceUnavailable
    case sourceConflict
    case sourceChanged
    case invalidLeaseState
    case dataProtectionUnavailable
    case mediaValidationFailed
    case mediaValidationTimedOut
    case cleanupUncertain
}

enum IOSV1VoiceCaptureInvalidReason: Equatable, Sendable {
    case empty
    case tooShort
    case maximumDurationReached
    case invalidMedia
}

enum IOSV1VoiceCaptureFinalizationResult: Sendable {
    case completed(IOSV1VoiceCompletedCapture)
    case discarded(IOSV1VoiceCaptureInvalidReason)
}

struct IOSV1VoiceCaptureFileIdentity: Equatable, Sendable {
    let device: UInt64
    let inode: UInt64
}

struct IOSV1VoiceCaptureFileFacts: Equatable, Sendable {
    let identity: IOSV1VoiceCaptureFileIdentity
    let byteCount: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
}

struct IOSV1VoiceCaptureFileHandle: Sendable {
    let attemptID: UUID
    let directoryDescriptor: Int32
    let fileDescriptor: Int32
    let directoryURL: URL
    let fileName: String
    let directoryIdentity: IOSV1VoiceCaptureFileIdentity
    let identity: IOSV1VoiceCaptureFileIdentity

    var fileURL: URL {
        directoryURL.appendingPathComponent(fileName, isDirectory: false)
    }
}

protocol IOSV1VoiceCaptureFileSystem: Sendable {
    func create(
        attemptID: UUID,
        directoryURL: URL,
        fileName: String
    ) throws -> IOSV1VoiceCaptureFileHandle
    func validate(
        _ handle: IOSV1VoiceCaptureFileHandle
    ) throws -> IOSV1VoiceCaptureFileFacts
    func synchronize(_ handle: IOSV1VoiceCaptureFileHandle) throws
    func remove(_ handle: IOSV1VoiceCaptureFileHandle) throws
    func close(_ handle: IOSV1VoiceCaptureFileHandle)
}

actor IOSV1VoiceCaptureOwner {
    static let mediaValidationTimeoutNanoseconds: UInt64 = 2_000_000_000
    static let maximumAudioByteCount: Int64 = 25_000_000

    private let repository: IOSVoiceStateRepository
    private let directoryURL: URL
    private let fileSystem: any IOSV1VoiceCaptureFileSystem
    private let mediaValidator: any IOSV1VoiceCaptureMediaValidating
    private weak var liveLease: IOSV1VoiceCaptureLease?

    init(
        repository: IOSVoiceStateRepository,
        directoryURL: URL,
        fileSystem: any IOSV1VoiceCaptureFileSystem,
        mediaValidator: any IOSV1VoiceCaptureMediaValidating
    ) {
        self.repository = repository
        self.directoryURL = directoryURL
        self.fileSystem = fileSystem
        self.mediaValidator = mediaValidator
    }

    func createCapture(
        attemptID: UUID,
        outputIntent: DictationOutputIntent,
        draftInsertionMode: IOSVoiceDraftInsertionMode = .replace,
        forcesTextCorrection: Bool = false,
        recordingDurationLimit: RecordingDurationLimit = .default,
        createdAt: Date = Date()
    ) async throws -> IOSV1VoiceCaptureLease {
        if let liveLease, liveLease.isOpen {
            throw IOSV1VoiceCaptureError.captureAlreadyExists
        }
        let relativeIdentifier = IOSVoiceStateStorageLocation
            .relativeAudioIdentifier(for: attemptID)
        let fileName = IOSVoiceStateStorageLocation.audioFileURL(
            for: attemptID,
            in: directoryURL.deletingLastPathComponent()
                .deletingLastPathComponent()
        ).lastPathComponent
        let handle = try fileSystem.create(
            attemptID: attemptID,
            directoryURL: directoryURL,
            fileName: fileName
        )
        do {
            let record = try IOSVoiceStateCapture(
                attemptID: attemptID,
                audioRelativeIdentifier: relativeIdentifier,
                createdAt: createdAt,
                outputIntent: outputIntent,
                draftInsertionMode: draftInsertionMode,
                forcesTextCorrection: forcesTextCorrection,
                recordingDurationLimit: recordingDurationLimit,
                phase: .recording
            )
            _ = try await repository.installCapture(record)
        } catch {
            do {
                try fileSystem.remove(handle)
            } catch {
                fileSystem.close(handle)
                throw IOSV1VoiceCaptureError.cleanupUncertain
            }
            fileSystem.close(handle)
            throw error
        }
        let lease = IOSV1VoiceCaptureLease(
            repository: repository,
            handle: handle,
            fileSystem: fileSystem,
            mediaValidator: mediaValidator,
            recordingDurationLimit: recordingDurationLimit
        )
        liveLease = lease
        return lease
    }
}

final class IOSV1VoiceCaptureLease: @unchecked Sendable {
    private enum Phase { case recording, finalizing, completed, discarding }
    private struct State {
        var phase = Phase.recording
        var operationInFlight = false
        var releaseRequested = false
        var closed = false
    }

    private let lock = NSLock()
    private let repository: IOSVoiceStateRepository
    private let handle: IOSV1VoiceCaptureFileHandle
    private let fileSystem: any IOSV1VoiceCaptureFileSystem
    private let mediaValidator: any IOSV1VoiceCaptureMediaValidating
    private let recordingDurationLimit: RecordingDurationLimit
    private var state = State()

    init(
        repository: IOSVoiceStateRepository,
        handle: IOSV1VoiceCaptureFileHandle,
        fileSystem: any IOSV1VoiceCaptureFileSystem,
        mediaValidator: any IOSV1VoiceCaptureMediaValidating,
        recordingDurationLimit: RecordingDurationLimit = .default
    ) {
        self.repository = repository
        self.handle = handle
        self.fileSystem = fileSystem
        self.mediaValidator = mediaValidator
        self.recordingDurationLimit = recordingDurationLimit
    }

    var isOpen: Bool {
        lock.withLock { !state.closed && !state.releaseRequested }
    }

    func withTransientRecordingURL(_ body: (URL) throws -> Void) throws {
        try begin(allowed: [.recording])
        defer { finish() }
        _ = try fileSystem.validate(handle)
        try body(handle.fileURL)
    }

    func revalidateRecorderCheckpoint() throws {
        try begin(allowed: [.recording])
        defer { finish() }
        _ = try fileSystem.validate(handle)
    }

    func beginFinalizing() async throws {
        try begin(allowed: [.recording])
        do {
            _ = try await repository.transitionCapture(
                attemptID: handle.attemptID,
                to: .finalizing
            )
            finish(phase: .finalizing)
        } catch {
            finish()
            throw error
        }
    }

    func completeAfterRecorderClose(
        fallbackDurationMilliseconds: Int64? = nil
    ) async throws
        -> IOSV1VoiceCaptureFinalizationResult {
        try begin(allowed: [.finalizing])
        do {
            try fileSystem.synchronize(handle)
            let before = try fileSystem.validate(handle)
            guard before.byteCount > 0 else {
                return try await discardInvalid(.empty)
            }
            guard before.byteCount
                    < IOSV1VoiceCaptureOwner.maximumAudioByteCount else {
                // A bounded reader cannot safely admit this source, but byte
                // count alone is never authority to destroy the only capture.
                // Leave finalizing ownership intact for explicit Discard.
                finish()
                throw IOSV1VoiceCaptureError.mediaValidationFailed
            }
            let maximumDuration = recordingDurationLimit
                .maximumFinalizedMediaDurationMilliseconds
            let monotonicFallback = fallbackDurationMilliseconds
                .flatMap { $0 >= 300 ? min($0, maximumDuration) : nil } ?? 0
            let duration: Int64
            do {
                let measured = try mediaValidator.durationMilliseconds(
                    fileDescriptor: handle.fileDescriptor,
                    byteCount: before.byteCount,
                    timeoutNanoseconds:
                        IOSV1VoiceCaptureOwner.mediaValidationTimeoutNanoseconds
                )
                // Zero is the durable unknown/suspect marker. A bogus short
                // probe must not destroy a non-empty finalized recording.
                duration = measured >= 300 && measured <= maximumDuration
                    ? measured : monotonicFallback
            } catch IOSV1VoiceCaptureError.mediaValidationFailed {
                duration = monotonicFallback
            } catch IOSV1VoiceCaptureError.mediaValidationTimedOut {
                duration = monotonicFallback
            } catch {
                finish()
                throw error
            }
            let after = try fileSystem.validate(handle)
            guard before == after else {
                finish()
                throw IOSV1VoiceCaptureError.sourceChanged
            }
            // The recorder requests its stop at the configured limit, but a
            // delayed callback can make the monotonic fallback larger. Clamp that
            // fallback to the finalized-media tolerance. An abnormal media
            // probe without a trustworthy fallback becomes duration 0, so the
            // source remains recoverable instead of being deleted here.
            _ = try await repository.completeCapture(
                attemptID: handle.attemptID,
                durationMilliseconds: duration,
                byteCount: after.byteCount
            )
            finish(phase: .completed)
            return .completed(
                IOSV1VoiceCompletedCapture(
                    repository: repository,
                    lease: self,
                    attemptID: handle.attemptID,
                    recordingDurationLimit: recordingDurationLimit,
                    durationMilliseconds: duration,
                    byteCount: after.byteCount
                )
            )
        } catch {
            if lock.withLock({ state.operationInFlight }) { finish() }
            throw error
        }
    }

    func beginDiscardingBeforeRecorderStop() async throws {
        try begin(allowed: [.recording, .finalizing, .completed])
        do {
            _ = try await repository.transitionCapture(
                attemptID: handle.attemptID,
                to: .discarding
            )
            finish(phase: .discarding)
        } catch {
            finish()
            throw error
        }
    }

    func finishDiscardAfterRecorderStop() async throws {
        try begin(allowed: [.discarding])
        do {
            try fileSystem.remove(handle)
            try await repository.clearCapture(attemptID: handle.attemptID)
            finish(release: true)
        } catch {
            finish()
            throw error
        }
    }

    func release() {
        let shouldClose = lock.withLock {
            state.releaseRequested = true
            guard !state.operationInFlight, !state.closed else { return false }
            state.closed = true
            return true
        }
        if shouldClose { fileSystem.close(handle) }
    }

    private func discardInvalid(
        _ reason: IOSV1VoiceCaptureInvalidReason
    ) async throws -> IOSV1VoiceCaptureFinalizationResult {
        _ = try await repository.transitionCapture(
            attemptID: handle.attemptID,
            to: .discarding
        )
        try fileSystem.remove(handle)
        try await repository.clearCapture(attemptID: handle.attemptID)
        finish(phase: .discarding, release: true)
        return .discarded(reason)
    }

    private func begin(allowed: Set<Phase>) throws {
        try lock.withLock {
            guard !state.closed, !state.releaseRequested,
                  !state.operationInFlight, allowed.contains(state.phase) else {
                throw IOSV1VoiceCaptureError.invalidLeaseState
            }
            state.operationInFlight = true
        }
    }

    private func finish(
        phase: Phase? = nil,
        release: Bool = false
    ) {
        let shouldClose = lock.withLock {
            if let phase { state.phase = phase }
            state.operationInFlight = false
            state.releaseRequested = state.releaseRequested || release
            guard state.releaseRequested, !state.closed else { return false }
            state.closed = true
            return true
        }
        if shouldClose { fileSystem.close(handle) }
    }

    deinit { release() }
}

final class IOSV1VoiceCompletedCapture: @unchecked Sendable {
    let attemptID: UUID
    let recordingDurationLimit: RecordingDurationLimit
    let durationMilliseconds: Int64
    let byteCount: Int64
    private let repository: IOSVoiceStateRepository
    private let lease: IOSV1VoiceCaptureLease

    fileprivate init(
        repository: IOSVoiceStateRepository,
        lease: IOSV1VoiceCaptureLease,
        attemptID: UUID,
        recordingDurationLimit: RecordingDurationLimit,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) {
        self.repository = repository
        self.lease = lease
        self.attemptID = attemptID
        self.recordingDurationLimit = recordingDurationLimit
        self.durationMilliseconds = durationMilliseconds
        self.byteCount = byteCount
    }

    func promote(
        transcriptionConfiguration: TranscriptionConfiguration,
        acceptedAudioRetention: IOSAcceptedAudioRetention =
            .recordingCachePolicy,
        initialStatus: IOSVoiceStatePendingStatus = .ready
    ) async throws -> IOSVoiceStatePending {
        let pending = try await repository.promoteCapture(
            attemptID: attemptID,
            transcriptionConfiguration: transcriptionConfiguration,
            acceptedAudioRetention: acceptedAudioRetention,
            initialStatus: initialStatus
        )
        lease.release()
        return pending
    }

    func release() { lease.release() }
    deinit { release() }
}

extension IOSV1VoiceCaptureError: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    var description: String { "IOSV1VoiceCaptureError(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
