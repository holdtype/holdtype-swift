import Foundation
import HoldTypeDomain

@MainActor
struct AudioRecordingArtifactFinalizer {
    nonisolated static let defaultDurationTimeout: TimeInterval = 2

    private let fileManager: FileManager
    private let minimumRecordingDuration: TimeInterval
    private let finalizedMediaDurationProvider:
        @Sendable (URL) async throws -> TimeInterval
    private let finalizedMediaDurationTimeout: TimeInterval
    private let finalizedMediaDurationTimeoutSleeper:
        @Sendable (TimeInterval) async throws -> Void

    init(
        fileManager: FileManager,
        minimumRecordingDuration: TimeInterval,
        finalizedMediaDurationProvider:
            @escaping @Sendable (URL) async throws -> TimeInterval,
        finalizedMediaDurationTimeout: TimeInterval,
        finalizedMediaDurationTimeoutSleeper:
            @escaping @Sendable (TimeInterval) async throws -> Void
    ) {
        self.fileManager = fileManager
        self.minimumRecordingDuration = minimumRecordingDuration.isFinite
            && minimumRecordingDuration >= 0
            ? minimumRecordingDuration
            : 0.3
        self.finalizedMediaDurationProvider = finalizedMediaDurationProvider
        let hasValidFinalizedMediaDurationTimeout =
            finalizedMediaDurationTimeout.isFinite
            && finalizedMediaDurationTimeout > 0
        self.finalizedMediaDurationTimeout =
            hasValidFinalizedMediaDurationTimeout
            ? finalizedMediaDurationTimeout
            : Self.defaultDurationTimeout
        self.finalizedMediaDurationTimeoutSleeper =
            finalizedMediaDurationTimeoutSleeper
    }

    func makeFinalizationTask(
        outputFileURL: URL,
        fallbackDuration: TimeInterval
    ) -> Task<AudioRecordingArtifact, Error> {
        let finalizedMediaDurationProvider = finalizedMediaDurationProvider
        let finalizedMediaDurationTimeout = finalizedMediaDurationTimeout
        let finalizedMediaDurationTimeoutSleeper =
            finalizedMediaDurationTimeoutSleeper
        let fileManager = fileManager
        let minimumRecordingDuration = minimumRecordingDuration

        return Task {
            let mediaDuration = await Self.boundedFinalizedMediaDuration(
                at: outputFileURL,
                provider: finalizedMediaDurationProvider,
                timeout: finalizedMediaDurationTimeout,
                timeoutSleeper: finalizedMediaDurationTimeoutSleeper
            )

            let duration = mediaDuration ?? fallbackDuration
            return try Self.recordingArtifact(
                at: outputFileURL,
                duration: duration,
                minimumDuration: minimumRecordingDuration,
                fileManager: fileManager
            )
        }
    }

    func shouldDeleteRecorderOutput(
        after error: AudioRecorderServiceError
    ) -> Bool {
        switch error {
        case .missingRecordingFile, .emptyRecording:
            return true
        default:
            return false
        }
    }

    nonisolated static func normalizedDuration(
        _ duration: TimeInterval
    ) -> TimeInterval? {
        guard duration.isFinite, duration > 0 else {
            return nil
        }

        return duration
    }

    private static func boundedFinalizedMediaDuration(
        at outputFileURL: URL,
        provider: @escaping @Sendable (URL) async throws -> TimeInterval,
        timeout: TimeInterval,
        timeoutSleeper:
            @escaping @Sendable (TimeInterval) async throws -> Void
    ) async -> TimeInterval? {
        let resolution = FinalizedMediaDurationResolution()
        let candidate = await withTaskCancellationHandler {
            await resolution.resolve(
                provider: {
                    try await provider(outputFileURL)
                },
                deadline: {
                    try await timeoutSleeper(timeout)
                }
            )
        } onCancel: {
            resolution.cancel()
        }
        return normalizedDuration(candidate ?? 0)
    }

    private static func recordingArtifact(
        at outputFileURL: URL,
        duration: TimeInterval,
        minimumDuration: TimeInterval,
        fileManager: FileManager
    ) throws -> AudioRecordingArtifact {
        let path = outputFileURL.path
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(
            atPath: path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw AudioRecorderServiceError.missingRecordingFile
        }

        let attributes = try fileManager.attributesOfItem(atPath: path)
        guard let fileSize = attributes[.size] as? NSNumber else {
            throw AudioRecorderServiceError.stopFailed
        }

        let byteCount = fileSize.int64Value
        guard byteCount > 0 else {
            throw AudioRecorderServiceError.emptyRecording
        }

        guard duration <= 0 || duration >= minimumDuration else {
            throw AudioRecorderServiceError.recordingTooShort(
                duration: duration,
                minimumDuration: minimumDuration
            )
        }

        // A finalized, nonempty file is the recoverable user artifact. Media
        // duration is diagnostic metadata and must never make that artifact
        // disappear because a recorder clock reset or encoder post-roll was
        // reported at finalization.
        return AudioRecordingArtifact(
            fileURL: outputFileURL,
            duration: duration,
            byteCount: byteCount
        )
    }
}

nonisolated private final class FinalizedMediaDurationResolution:
    @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<TimeInterval?, Never>?
    private var providerTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var isFinished = false

    func resolve(
        provider: @escaping @Sendable () async throws -> TimeInterval,
        deadline: @escaping @Sendable () async throws -> Void
    ) async -> TimeInterval? {
        await withCheckedContinuation { continuation in
            start(
                continuation: continuation,
                provider: provider,
                deadline: deadline
            )
        }
    }

    func cancel() {
        finish(with: nil)
    }

    private func start(
        continuation: CheckedContinuation<TimeInterval?, Never>,
        provider: @escaping @Sendable () async throws -> TimeInterval,
        deadline: @escaping @Sendable () async throws -> Void
    ) {
        lock.lock()
        guard !isFinished else {
            lock.unlock()
            continuation.resume(returning: nil)
            return
        }

        self.continuation = continuation
        let providerTask = Task { [self] in
            do {
                finish(with: try await provider())
            } catch {
                finish(with: nil)
            }
        }
        let deadlineTask = Task { [self] in
            do {
                try await deadline()
                finish(with: nil)
            } catch is CancellationError {
                // The provider won the race.
            } catch {
                finish(with: nil)
            }
        }
        self.providerTask = providerTask
        self.deadlineTask = deadlineTask
        lock.unlock()
    }

    private func finish(with duration: TimeInterval?) {
        let completion: (
            continuation: CheckedContinuation<TimeInterval?, Never>?,
            providerTask: Task<Void, Never>?,
            deadlineTask: Task<Void, Never>?
        )? = lock.withLock {
            guard !isFinished else {
                return nil
            }

            isFinished = true
            let completion = (
                continuation: continuation,
                providerTask: providerTask,
                deadlineTask: deadlineTask
            )
            continuation = nil
            providerTask = nil
            deadlineTask = nil
            return completion
        }

        guard let completion else {
            return
        }

        completion.providerTask?.cancel()
        completion.deadlineTask?.cancel()
        completion.continuation?.resume(returning: duration)
    }
}
