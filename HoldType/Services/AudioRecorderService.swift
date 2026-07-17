//
//  AudioRecorderService.swift
//  HoldType
//
//  Created by Codex on 6/20/26.
//

import AVFoundation
import Foundation
import HoldTypeDomain

enum AudioRecorderStatus: Equatable {
    case idle
    case recording
    case finished(artifact: AudioRecordingArtifact)
    case cancelled
    case failed(message: String)

    var isRecording: Bool {
        self == .recording
    }
}

protocol AudioRecorderService {
    var currentStatus: AudioRecorderStatus { get }
    var lastFinalizationReachedMaximumDuration: Bool { get }

    func startRecording() async throws
    func stopRecording() async throws -> AudioRecordingArtifact
    func cancelRecording()
    func setAutomaticStopHandler(_ handler: AudioRecorderAutomaticStopHandler?)
}

enum AudioRecorderAutomaticCompletionReason: Equatable {
    case maximumDuration
    case unexpected(recorderReportedSuccess: Bool)
}

struct AudioRecorderAutomaticCompletion: Equatable {
    let artifact: AudioRecordingArtifact
    let reason: AudioRecorderAutomaticCompletionReason
    let recorderReportedSuccess: Bool?

    init(
        artifact: AudioRecordingArtifact,
        reason: AudioRecorderAutomaticCompletionReason,
        recorderReportedSuccess: Bool? = nil
    ) {
        self.artifact = artifact
        self.reason = reason
        self.recorderReportedSuccess = recorderReportedSuccess
    }
}

typealias AudioRecorderAutomaticStopHandler = @MainActor (
    Result<AudioRecorderAutomaticCompletion, AudioRecorderServiceError>
) -> Void

extension AudioRecorderService {
    var lastFinalizationReachedMaximumDuration: Bool { false }

    func setAutomaticStopHandler(_ handler: AudioRecorderAutomaticStopHandler?) {}
}

enum AudioRecorderServiceError: Error, Equatable, LocalizedError {
    case alreadyRecording
    case notRecording
    case microphonePermissionDenied
    case recordingUnavailable
    case temporaryFileUnavailable
    case startFailed
    case stopFailed
    case cancelCleanupFailed
    case missingRecordingFile
    case emptyRecording
    case recordingTooShort(duration: TimeInterval, minimumDuration: TimeInterval)
    case recordingTimedOut(duration: TimeInterval, maximumDuration: TimeInterval)

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress."
        case .notRecording:
            return "There is no active recording to stop."
        case .microphonePermissionDenied:
            return "Microphone access is required before recording can start."
        case .recordingUnavailable:
            return "Recording is unavailable on this Mac."
        case .temporaryFileUnavailable:
            return "Could not prepare a temporary recording file."
        case .startFailed:
            return "Could not start microphone recording."
        case .stopFailed:
            return "Could not finish the current recording."
        case .cancelCleanupFailed:
            return "Could not remove the canceled recording."
        case .missingRecordingFile:
            return "The completed recording file is missing."
        case .emptyRecording:
            return "No audio was captured. Try recording again."
        case .recordingTooShort:
            return "Recording was too short. Try speaking for a little longer."
        case .recordingTimedOut:
            return "Recording reached the maximum length. Try again with a shorter dictation."
        }
    }
}

protocol AudioRecorderEngine: AnyObject {
    var isRecording: Bool { get }
    var currentTime: TimeInterval { get }

    func record() -> Bool
    func record(forDuration duration: TimeInterval) -> Bool
    func stop()
    @discardableResult func deleteRecording() -> Bool
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?)
}

extension AudioRecorderEngine {
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) {}
}

private final class AVFoundationAudioRecorderEngine: NSObject, AudioRecorderEngine, AVAudioRecorderDelegate {
    private let recorder: AVAudioRecorder
    private var recordingFinishedHandler: ((Bool) -> Void)?

    init(recorder: AVAudioRecorder) {
        self.recorder = recorder
        super.init()
        recorder.delegate = self
    }

    var isRecording: Bool {
        recorder.isRecording
    }

    var currentTime: TimeInterval {
        recorder.currentTime
    }

    func record() -> Bool {
        recorder.record()
    }

    func record(forDuration duration: TimeInterval) -> Bool {
        recorder.record(forDuration: duration)
    }

    func stop() {
        recorder.stop()
    }

    func deleteRecording() -> Bool {
        recorder.deleteRecording()
    }

    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) {
        recordingFinishedHandler = handler
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        recordingFinishedHandler?(flag)
    }
}

protocol AudioRecorderEngineFactory {
    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any]
    ) throws -> any AudioRecorderEngine
}

struct AVFoundationAudioRecorderEngineFactory: AudioRecorderEngineFactory {
    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any]
    ) throws -> any AudioRecorderEngine {
        let recorder = try AVAudioRecorder(url: outputFileURL, settings: settings)

        guard recorder.prepareToRecord() else {
            throw AudioRecorderServiceError.temporaryFileUnavailable
        }

        return AVFoundationAudioRecorderEngine(recorder: recorder)
    }
}

nonisolated private final class FinalizedMediaDurationResolution: @unchecked Sendable {
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

final class AVFoundationAudioRecorderService: AudioRecorderService {
    static let defaultMaximumRecordingDuration =
        VoiceSessionPreferences.maximumUtteranceDuration
    static let defaultFinalizedMediaDurationTimeout: TimeInterval = 2

    private static let automaticLimitClassificationTolerance: TimeInterval = 0.5

    private let permissionStatusProvider: () -> MicrophonePermissionStatus
    private let recorderFactory: any AudioRecorderEngineFactory
    private let makeRecordingFileURL: () throws -> URL
    private let fileManager: FileManager
    private let maximumRecordingDuration: TimeInterval
    private let finalizedMediaDurationProvider: @Sendable (URL) async throws -> TimeInterval
    private let finalizedMediaDurationTimeout: TimeInterval
    private let finalizedMediaDurationTimeoutSleeper:
        @Sendable (TimeInterval) async throws -> Void
    private let monotonicClock: () -> TimeInterval

    private var activeRecorder: (any AudioRecorderEngine)?
    private var activeFileURL: URL?
    private var activeAttemptID: UUID?
    private var activeRecordingStartTime: TimeInterval?
    private var finalizationTask: Task<AudioRecordingArtifact, Error>?
    private var finalizationAttemptID: UUID?
    private var finalizingRecorder: (any AudioRecorderEngine)?
    private var automaticStopHandler: AudioRecorderAutomaticStopHandler?

    private(set) var currentStatus: AudioRecorderStatus = .idle
    private(set) var lastFinalizationReachedMaximumDuration = false

    init(
        permissionStatusProvider: @escaping () -> MicrophonePermissionStatus = {
            MicrophonePermissionService().currentStatus()
        },
        recorderFactory: any AudioRecorderEngineFactory = AVFoundationAudioRecorderEngineFactory(),
        fileManager: FileManager = .default,
        minimumRecordingDuration: TimeInterval = 0.3,
        maximumRecordingDuration: TimeInterval = AVFoundationAudioRecorderService.defaultMaximumRecordingDuration,
        finalizedMediaDurationProvider: @escaping @Sendable (URL) async throws -> TimeInterval = { fileURL in
            let duration = try await AVURLAsset(url: fileURL).load(.duration)
            return duration.seconds
        },
        finalizedMediaDurationTimeout: TimeInterval =
            AVFoundationAudioRecorderService.defaultFinalizedMediaDurationTimeout,
        finalizedMediaDurationTimeoutSleeper:
            @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
                let nanoseconds = UInt64(seconds * 1_000_000_000)
                try await Task.sleep(nanoseconds: nanoseconds)
            },
        monotonicClock: @escaping () -> TimeInterval = {
            ProcessInfo.processInfo.systemUptime
        },
        makeRecordingFileURL: @escaping () throws -> URL = {
            try RecordingCacheService.shared.makeRecordingFileURL()
        }
    ) {
        self.permissionStatusProvider = permissionStatusProvider
        self.recorderFactory = recorderFactory
        self.fileManager = fileManager
        self.maximumRecordingDuration = maximumRecordingDuration > 0
            ? maximumRecordingDuration
            : Self.defaultMaximumRecordingDuration
        self.finalizedMediaDurationProvider = finalizedMediaDurationProvider
        let hasValidFinalizedMediaDurationTimeout =
            finalizedMediaDurationTimeout.isFinite && finalizedMediaDurationTimeout > 0
        self.finalizedMediaDurationTimeout = hasValidFinalizedMediaDurationTimeout
            ? finalizedMediaDurationTimeout
            : Self.defaultFinalizedMediaDurationTimeout
        self.finalizedMediaDurationTimeoutSleeper = finalizedMediaDurationTimeoutSleeper
        self.monotonicClock = monotonicClock
        self.makeRecordingFileURL = makeRecordingFileURL
    }

    func setAutomaticStopHandler(_ handler: AudioRecorderAutomaticStopHandler?) {
        automaticStopHandler = handler
    }

    func startRecording() async throws {
        lastFinalizationReachedMaximumDuration = false
        let permissionStatus = permissionStatusProvider()
        guard permissionStatus.canRecord else {
            let error = startError(for: permissionStatus)
            fail(with: error)
            throw error
        }

        guard activeRecorder == nil, finalizationTask == nil else {
            throw AudioRecorderServiceError.alreadyRecording
        }

        do {
            let outputFileURL = try makeRecordingFileURL()
            let recorder = try recorderFactory.makeRecorder(
                outputFileURL: outputFileURL,
                settings: Self.recordingSettings
            )
            let attemptID = UUID()

            activeRecorder = recorder
            activeFileURL = outputFileURL
            activeAttemptID = attemptID
            activeRecordingStartTime = monotonicClock()
            recorder.setRecordingFinishedHandler { [weak self] recorderReportedSuccess in
                Task { @MainActor [weak self] in
                    await self?.finishAutomatically(
                        attemptID: attemptID,
                        recorderReportedSuccess: recorderReportedSuccess
                    )
                }
            }

            guard recorder.record(forDuration: maximumRecordingDuration) else {
                clearActiveRecording(ifAttemptID: attemptID)
                recorder.setRecordingFinishedHandler(nil)
                recorder.deleteRecording()
                let error = AudioRecorderServiceError.startFailed
                fail(with: error)
                throw error
            }

            currentStatus = .recording
        } catch let error as AudioRecorderServiceError {
            fail(with: error)
            throw error
        } catch {
            let serviceError = AudioRecorderServiceError.recordingUnavailable
            fail(with: serviceError)
            throw serviceError
        }
    }

    func stopRecording() async throws -> AudioRecordingArtifact {
        // A key-up may already be waiting in the configured stop tail when the
        // recorder reaches its hard limit. The automatic callback can finish
        // first; the manual consumer must still join that exact artifact.
        if case .finished(let artifact) = currentStatus {
            return artifact
        }

        if let finalizationTask, let finalizationAttemptID {
            return try await awaitFinalization(
                finalizationTask,
                attemptID: finalizationAttemptID
            )
        }

        guard
            let recorder = activeRecorder,
            let outputFileURL = activeFileURL,
            let attemptID = activeAttemptID
        else {
            throw AudioRecorderServiceError.notRecording
        }

        let engineDuration = normalizedDuration(recorder.currentTime)
        lastFinalizationReachedMaximumDuration = durationReachedAutomaticLimit(
            elapsedRecordingDuration()
        )
        clearActiveRecording(ifAttemptID: attemptID)
        recorder.setRecordingFinishedHandler(nil)
        recorder.stop()

        let task = makeFinalizationTask(
            recorder: recorder,
            outputFileURL: outputFileURL,
            engineDuration: engineDuration
        )
        beginFinalization(task, attemptID: attemptID, recorder: recorder)
        return try await awaitFinalization(task, attemptID: attemptID)
    }

    func cancelRecording() {
        // Once finalization has begun the recorder is already closed. Let every
        // racing stop observer receive the same retained artifact.
        guard finalizationTask == nil else {
            return
        }

        let recorder = activeRecorder
        let outputFileURL = activeFileURL

        activeAttemptID = nil
        activeRecordingStartTime = nil
        recorder?.setRecordingFinishedHandler(nil)
        recorder?.stop()
        recorder?.deleteRecording()
        activeRecorder = nil
        activeFileURL = nil
        lastFinalizationReachedMaximumDuration = false

        do {
            try removeRecordingFileIfPresent(at: outputFileURL)
        } catch {
            fail(with: .cancelCleanupFailed)
            return
        }

        currentStatus = .cancelled
    }

    private func finishAutomatically(
        attemptID: UUID,
        recorderReportedSuccess: Bool
    ) async {
        guard
            activeAttemptID == attemptID,
            let recorder = activeRecorder,
            let outputFileURL = activeFileURL
        else {
            return
        }

        let engineDuration = normalizedDuration(recorder.currentTime)
        let monotonicElapsed = elapsedRecordingDuration()
        lastFinalizationReachedMaximumDuration = durationReachedAutomaticLimit(
            monotonicElapsed
        )
        clearActiveRecording(ifAttemptID: attemptID)
        recorder.setRecordingFinishedHandler(nil)

        let task = makeFinalizationTask(
            recorder: recorder,
            outputFileURL: outputFileURL,
            engineDuration: engineDuration
        )
        beginFinalization(task, attemptID: attemptID, recorder: recorder)

        let result: Result<AudioRecorderAutomaticCompletion, AudioRecorderServiceError>
        do {
            let artifact = try await awaitFinalization(task, attemptID: attemptID)
            let reason = automaticCompletionReason(
                recorderReportedSuccess: recorderReportedSuccess,
                monotonicElapsed: monotonicElapsed,
                finalizedMediaDuration: artifact.duration
            )
            if reason == .maximumDuration {
                lastFinalizationReachedMaximumDuration = true
            }
            result = .success(
                AudioRecorderAutomaticCompletion(
                    artifact: artifact,
                    reason: reason,
                    recorderReportedSuccess: recorderReportedSuccess
                )
            )
        } catch let error as AudioRecorderServiceError {
            result = .failure(error)
        } catch {
            result = .failure(.stopFailed)
        }

        automaticStopHandler?(result)
    }

    private func makeFinalizationTask(
        recorder: any AudioRecorderEngine,
        outputFileURL: URL,
        engineDuration: TimeInterval
    ) -> Task<AudioRecordingArtifact, Error> {
        let finalizedMediaDurationProvider = finalizedMediaDurationProvider
        let finalizedMediaDurationTimeout = finalizedMediaDurationTimeout
        let finalizedMediaDurationTimeoutSleeper = finalizedMediaDurationTimeoutSleeper
        let fileManager = fileManager

        return Task {
            let mediaDuration = await Self.boundedFinalizedMediaDuration(
                at: outputFileURL,
                provider: finalizedMediaDurationProvider,
                timeout: finalizedMediaDurationTimeout,
                timeoutSleeper: finalizedMediaDurationTimeoutSleeper
            )

            let duration = mediaDuration ?? engineDuration
            return try Self.recordingArtifact(
                at: outputFileURL,
                duration: duration,
                fileManager: fileManager
            )
        }
    }

    private func beginFinalization(
        _ task: Task<AudioRecordingArtifact, Error>,
        attemptID: UUID,
        recorder: any AudioRecorderEngine
    ) {
        finalizationTask = task
        finalizationAttemptID = attemptID
        finalizingRecorder = recorder
    }

    private func awaitFinalization(
        _ task: Task<AudioRecordingArtifact, Error>,
        attemptID: UUID
    ) async throws -> AudioRecordingArtifact {
        do {
            let artifact = try await task.value
            if finalizationAttemptID == attemptID {
                clearFinalization()
                currentStatus = .finished(artifact: artifact)
            }
            return artifact
        } catch let error as AudioRecorderServiceError {
            if finalizationAttemptID == attemptID {
                if shouldDeleteRecording(after: error) {
                    finalizingRecorder?.deleteRecording()
                }
                clearFinalization()
                fail(with: error)
            }
            throw error
        } catch {
            let serviceError = AudioRecorderServiceError.stopFailed
            if finalizationAttemptID == attemptID {
                clearFinalization()
                fail(with: serviceError)
            }
            throw serviceError
        }
    }

    private func clearActiveRecording(ifAttemptID attemptID: UUID) {
        guard activeAttemptID == attemptID else {
            return
        }

        activeRecorder = nil
        activeFileURL = nil
        activeAttemptID = nil
        activeRecordingStartTime = nil
    }

    private func clearFinalization() {
        finalizationTask = nil
        finalizationAttemptID = nil
        finalizingRecorder = nil
    }

    private func shouldDeleteRecording(after error: AudioRecorderServiceError) -> Bool {
        switch error {
        case .missingRecordingFile, .emptyRecording:
            return true
        default:
            return false
        }
    }

    private func normalizedDuration(_ duration: TimeInterval) -> TimeInterval {
        Self.normalizedDuration(duration) ?? 0
    }

    private func elapsedRecordingDuration() -> TimeInterval? {
        guard let activeRecordingStartTime else {
            return nil
        }

        let elapsed = monotonicClock() - activeRecordingStartTime
        return Self.normalizedDuration(elapsed)
    }

    private func automaticCompletionReason(
        recorderReportedSuccess: Bool,
        monotonicElapsed: TimeInterval?,
        finalizedMediaDuration: TimeInterval
    ) -> AudioRecorderAutomaticCompletionReason {
        let elapsedReachedLimit = durationReachedAutomaticLimit(monotonicElapsed)
        let mediaReachedLimit = durationReachedAutomaticLimit(finalizedMediaDuration)

        if elapsedReachedLimit || mediaReachedLimit {
            return .maximumDuration
        }

        return .unexpected(recorderReportedSuccess: recorderReportedSuccess)
    }

    private func durationReachedAutomaticLimit(_ duration: TimeInterval?) -> Bool {
        guard let duration, duration.isFinite else {
            return false
        }

        let tolerance = min(
            Self.automaticLimitClassificationTolerance,
            maximumRecordingDuration * 0.02
        )
        return duration >= maximumRecordingDuration - tolerance
    }

    private static func boundedFinalizedMediaDuration(
        at outputFileURL: URL,
        provider: @escaping @Sendable (URL) async throws -> TimeInterval,
        timeout: TimeInterval,
        timeoutSleeper: @escaping @Sendable (TimeInterval) async throws -> Void
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

    private static func normalizedDuration(_ duration: TimeInterval) -> TimeInterval? {
        guard duration.isFinite, duration > 0 else {
            return nil
        }

        return duration
    }

    private func startError(for permissionStatus: MicrophonePermissionStatus) -> AudioRecorderServiceError {
        switch permissionStatus {
        case .allowed:
            return .startFailed
        case .denied, .notDetermined:
            return .microphonePermissionDenied
        case .unavailable:
            return .recordingUnavailable
        }
    }

    private func fail(with error: AudioRecorderServiceError) {
        currentStatus = .failed(message: error.errorDescription ?? error.localizedDescription)
    }

    private static func recordingArtifact(
        at outputFileURL: URL,
        duration: TimeInterval,
        fileManager: FileManager
    ) throws -> AudioRecordingArtifact {
        let path = outputFileURL.path
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else {
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

    private func removeRecordingFileIfPresent(at outputFileURL: URL?) throws {
        guard let outputFileURL else {
            return
        }

        let path = outputFileURL.path
        var isDirectory: ObjCBool = false

        guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory) else {
            return
        }

        guard !isDirectory.boolValue else {
            throw AudioRecorderServiceError.cancelCleanupFailed
        }

        try fileManager.removeItem(at: outputFileURL)
    }

    private static var recordingSettings: [String: Any] {
        [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
    }
}
