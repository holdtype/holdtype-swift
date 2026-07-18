import Foundation
import HoldTypeDomain

@_spi(HoldTypeIOSCore)
public enum IOSV1ForegroundVoicePersistenceError:
    Error,
    Equatable,
    Sendable {
    case stalePending
    case invalidTransition
    case invalidAcceptedOutput
    case audioMissing
    case audioTemporarilyUnavailable
    case audioInvalid
    case cleanupUncertain
    case dispatchAlreadyExecuted
    case invalidAudioRead
    case localPersistence
}

@_spi(HoldTypeIOSCore)
public struct IOSV1ForegroundVoiceAcceptedOutputPreparation:
    Equatable,
    Sendable {
    public let deliveryID: UUID
    public let attemptID: UUID
    public let transcriptID: UUID
    public let acceptedText: String
    public let outputIntent: DictationOutputIntent

    public init(
        deliveryID: UUID,
        attemptID: UUID,
        transcriptID: UUID,
        rawAcceptedText: String,
        outputIntent: DictationOutputIntent
    ) throws {
        guard !rawAcceptedText.isEmpty,
              rawAcceptedText.utf8.count <= 1_000_000,
              rawAcceptedText == rawAcceptedText.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ) else {
            throw IOSV1ForegroundVoicePersistenceError.invalidAcceptedOutput
        }
        self.deliveryID = deliveryID
        self.attemptID = attemptID
        self.transcriptID = transcriptID
        acceptedText = rawAcceptedText
        self.outputIntent = outputIntent
    }
}

@_spi(HoldTypeIOSCore)
public struct IOSV1AcceptedOutputDeliveryRecord: Equatable, Sendable {
    public let resultID: UUID
    public let sourceAttemptID: UUID
    public let acceptedText: String
    public let createdAt: Date

    public init(
        resultID: UUID,
        sourceAttemptID: UUID,
        acceptedText: String,
        createdAt: Date
    ) throws {
        guard !acceptedText.isEmpty,
              acceptedText.utf8.count <= 1_000_000,
              acceptedText == acceptedText.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ) else {
            throw IOSV1ForegroundVoicePersistenceError.invalidAcceptedOutput
        }
        self.resultID = resultID
        self.sourceAttemptID = sourceAttemptID
        self.acceptedText = acceptedText
        self.createdAt = createdAt
    }

    init(_ latest: IOSVoiceStateLatest) {
        resultID = latest.resultID
        sourceAttemptID = latest.sourceAttemptID
        acceptedText = latest.text
        createdAt = latest.createdAt
    }

    init(_ accepted: IOSVoiceStateAcceptedResult) {
        resultID = accepted.resultID
        sourceAttemptID = accepted.sourceAttemptID
        acceptedText = accepted.text
        createdAt = accepted.createdAt
    }
}

@_spi(HoldTypeIOSCore)
public enum IOSV1ForegroundVoiceAcceptanceNotice: Equatable, Sendable {
    case historyWriteFailed
    case localCleanupPending
    case historyWriteFailedAndLocalCleanupPending
}

@_spi(HoldTypeIOSCore)
public enum IOSV1ForegroundVoiceAcceptanceResult: Equatable, Sendable {
    case resultReady(
        IOSV1AcceptedOutputDeliveryRecord,
        notice: IOSV1ForegroundVoiceAcceptanceNotice? = nil
    )
}

@_spi(HoldTypeIOSCore)
public enum IOSV1ForegroundVoiceLatestResultObservation: Equatable, Sendable {
    case absent
    case resultReady(IOSV1AcceptedOutputDeliveryRecord)
}

@_spi(HoldTypeIOSCore)
public enum IOSV1ContainingAppRecoveryOpportunity: Equatable, Sendable {
    case processLaunch
    case foregroundOpportunity
}

@_spi(HoldTypeIOSCore)
public enum IOSV1ContainingAppRecoveryDisposition: Equatable, Sendable {
    case complete
    case pendingLocalRecovery
}

@_spi(HoldTypeIOSCore)
public enum IOSV1ForegroundVoiceCaptureInvalidReason: Equatable, Sendable {
    case tooShort
    case empty
    case maximumDurationReached
    case invalidMedia
}

@_spi(HoldTypeIOSCore)
public enum IOSV1ForegroundVoiceCaptureFinalizationResult: Sendable {
    case completed(IOSV1ForegroundVoiceCompletedCapture)
    case discarded(IOSV1ForegroundVoiceCaptureInvalidReason)
}

@_spi(HoldTypeIOSCore)
public enum IOSV1ForegroundVoiceCaptureRecoveryObservation:
    Equatable,
    Sendable {
    case empty
    case recoverable(attemptID: UUID)
    case discardOnly(attemptID: UUID)
    case blocked
}

@_spi(HoldTypeIOSCore)
public final class IOSV1PendingTranscriptionAudio: @unchecked Sendable {
    public static let maximumReadByteCount = 64 * 1_024

    public let format: IOSV1PendingRecordingAudioFormat
    public let durationMilliseconds: Int64
    public let byteCount: Int64

    private let lock = NSLock()
    private let fileSystem: any IOSV1ForegroundVoiceAudioFileSystem
    private var handle: IOSV1ForegroundVoiceAudioHandle?
    private var activeReadCount = 0
    private var invalidated = false

    init(
        recording: IOSV1PendingRecording,
        handle: IOSV1ForegroundVoiceAudioHandle,
        fileSystem: any IOSV1ForegroundVoiceAudioFileSystem
    ) {
        format = recording.audioRelativeIdentifier.hasSuffix(".wav")
            ? .wav : .m4a
        durationMilliseconds = recording.durationMilliseconds
        byteCount = recording.byteCount
        self.handle = handle
        self.fileSystem = fileSystem
    }

    public func read(
        atOffset offset: Int64,
        maximumByteCount: Int = IOSV1PendingTranscriptionAudio
            .maximumReadByteCount
    ) async throws -> Data {
        guard offset >= 0, offset <= byteCount,
              maximumByteCount > 0,
              maximumByteCount <= Self.maximumReadByteCount else {
            throw IOSV1ForegroundVoicePersistenceError.invalidAudioRead
        }
        try Task.checkCancellation()
        let active = try lock.withLock {
            guard !invalidated, let handle else {
                throw IOSV1ForegroundVoicePersistenceError
                    .dispatchAlreadyExecuted
            }
            activeReadCount += 1
            return handle
        }
        defer { finishRead() }
        let data = try fileSystem.read(
            active,
            atOffset: offset,
            maximumByteCount: maximumByteCount
        )
        try Task.checkCancellation()
        return data
    }

    fileprivate func invalidate() {
        let closing = lock.withLock {
            invalidated = true
            return takeClosableHandle()
        }
        if let closing { fileSystem.close(closing) }
    }

    private func finishRead() {
        let closing = lock.withLock {
            activeReadCount -= 1
            return takeClosableHandle()
        }
        if let closing { fileSystem.close(closing) }
    }

    private func takeClosableHandle() -> IOSV1ForegroundVoiceAudioHandle? {
        guard invalidated, activeReadCount == 0 else { return nil }
        defer { handle = nil }
        return handle
    }

    deinit {
        if let handle { fileSystem.close(handle) }
    }
}

@_spi(HoldTypeIOSCore)
public protocol IOSV1PendingTranscriptionExecutor: Sendable {
    func transcribe(
        recording: IOSV1PendingRecording,
        audio: IOSV1PendingTranscriptionAudio
    ) async throws -> String
}

private final class IOSV1ForegroundVoiceDispatchAdmission:
    @unchecked Sendable {
    private let lock = NSLock()
    private var admitted = false

    func admit() -> Bool {
        lock.withLock {
            guard !admitted else { return false }
            admitted = true
            return true
        }
    }
}

@_spi(HoldTypeIOSCore)
public struct IOSV1ForegroundVoiceTranscriptionDispatch: Sendable {
    public let recording: IOSV1PendingRecording

    private let audio: IOSV1PendingTranscriptionAudio
    private let admission = IOSV1ForegroundVoiceDispatchAdmission()

    init(
        recording: IOSV1PendingRecording,
        audio: IOSV1PendingTranscriptionAudio
    ) {
        self.recording = recording
        self.audio = audio
    }

    public func execute(
        using executor: any IOSV1PendingTranscriptionExecutor
    ) async throws -> String {
        guard admission.admit() else {
            throw IOSV1ForegroundVoicePersistenceError
                .dispatchAlreadyExecuted
        }
        defer { audio.invalidate() }
        try Task.checkCancellation()
        return try await executor.transcribe(
            recording: recording,
            audio: audio
        )
    }
}

extension IOSV1AcceptedOutputDeliveryRecord: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "IOSV1AcceptedOutputDeliveryRecord(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
