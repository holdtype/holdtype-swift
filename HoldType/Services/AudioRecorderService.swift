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
}

protocol AudioRecorderService {
    var currentStatus: AudioRecorderStatus { get }
    var lastFinalizationReachedMaximumDuration: Bool { get }
    var acceptsPreparedRecordingFileURL: Bool { get }

    func startRecording(maximumDuration: TimeInterval) async throws
    func startRecording(
        maximumDuration: TimeInterval,
        outputFileURL: URL?
    ) async throws
    func stopRecording() async throws -> AudioRecordingArtifact
    func stopRecordingOutcome() async throws -> AudioRecorderStopOutcome
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

struct AudioRecorderStopOutcome: Equatable {
    let artifact: AudioRecordingArtifact
    let automaticCompletion: AudioRecorderAutomaticCompletion?
}

typealias AudioRecorderAutomaticStopHandler = @MainActor (
    Result<AudioRecorderAutomaticCompletion, AudioRecorderServiceError>
) -> Void

extension AudioRecorderService {
    var lastFinalizationReachedMaximumDuration: Bool { false }
    var acceptsPreparedRecordingFileURL: Bool { false }

    func startRecording(
        maximumDuration: TimeInterval,
        outputFileURL: URL?
    ) async throws {
        try await startRecording(maximumDuration: maximumDuration)
    }

    func stopRecordingOutcome() async throws -> AudioRecorderStopOutcome {
        AudioRecorderStopOutcome(
            artifact: try await stopRecording(),
            automaticCompletion: nil
        )
    }

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
        }
    }
}
final class AVFoundationAudioRecorderService: AudioRecorderService {
    static let defaultMaximumRecordingDuration =
        RecordingDurationLimit.default.duration
    static let defaultFinalizedMediaDurationTimeout =
        AudioRecordingArtifactFinalizer.defaultDurationTimeout

    private static let automaticLimitClassificationTolerance: TimeInterval = 0.5

    private struct AutomaticFinalizationContext {
        let recorderReportedSuccess: Bool
        let monotonicElapsed: TimeInterval?
        let maximumRecordingDuration: TimeInterval
    }

    private let permissionStatusProvider: () -> MicrophonePermissionStatus
    private let recorderFactory: any AudioRecorderEngineFactory
    private let makeRecordingFileURL: () throws -> URL
    private let fileManager: FileManager
    private let artifactFinalizer: AudioRecordingArtifactFinalizer
    private let defaultMaximumRecordingDuration: TimeInterval
    private let monotonicClock: () -> TimeInterval

    private var activeRecorder: (any AudioRecorderEngine)?
    private var activeFileURL: URL?
    private var activeAttemptID: UUID?
    private var activeRecordingStartTime: TimeInterval?
    private var activeMaximumRecordingDuration: TimeInterval?
    private var finalizationTask: Task<AudioRecordingArtifact, Error>?
    private var finalizationAttemptID: UUID?
    private var finalizingRecorder: (any AudioRecorderEngine)?
    private var automaticFinalizationContext: AutomaticFinalizationContext?
    private var lastAutomaticCompletion: AudioRecorderAutomaticCompletion?
    private var automaticStopHandler: AudioRecorderAutomaticStopHandler?

    private(set) var currentStatus: AudioRecorderStatus = .idle
    private(set) var lastFinalizationReachedMaximumDuration = false
    let acceptsPreparedRecordingFileURL = true

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
        self.artifactFinalizer = AudioRecordingArtifactFinalizer(
            fileManager: fileManager,
            minimumRecordingDuration: minimumRecordingDuration,
            finalizedMediaDurationProvider: finalizedMediaDurationProvider,
            finalizedMediaDurationTimeout: finalizedMediaDurationTimeout,
            finalizedMediaDurationTimeoutSleeper:
                finalizedMediaDurationTimeoutSleeper
        )
        self.defaultMaximumRecordingDuration = maximumRecordingDuration.isFinite
            && maximumRecordingDuration > 0
            ? maximumRecordingDuration
            : Self.defaultMaximumRecordingDuration
        self.monotonicClock = monotonicClock
        self.makeRecordingFileURL = makeRecordingFileURL
    }

    func setAutomaticStopHandler(_ handler: AudioRecorderAutomaticStopHandler?) {
        automaticStopHandler = handler
    }

    func startRecording() async throws {
        try await startRecording(
            maximumDuration: defaultMaximumRecordingDuration
        )
    }

    func startRecording(maximumDuration: TimeInterval) async throws {
        try await startRecording(
            maximumDuration: maximumDuration,
            outputFileURL: nil
        )
    }

    func startRecording(
        maximumDuration: TimeInterval,
        outputFileURL preparedOutputFileURL: URL?
    ) async throws {
        lastFinalizationReachedMaximumDuration = false
        let resolvedMaximumDuration = maximumDuration.isFinite
            && maximumDuration > 0
            ? maximumDuration
            : defaultMaximumRecordingDuration
        let permissionStatus = permissionStatusProvider()
        guard permissionStatus.canRecord else {
            let error = startError(for: permissionStatus)
            fail(with: error)
            throw error
        }

        guard activeRecorder == nil, finalizationTask == nil else {
            throw AudioRecorderServiceError.alreadyRecording
        }

        automaticFinalizationContext = nil
        lastAutomaticCompletion = nil

        do {
            let outputFileURL = try preparedOutputFileURL ?? makeRecordingFileURL()
            let recorder = try recorderFactory.makeRecorder(
                outputFileURL: outputFileURL,
                settings: Self.recordingSettings
            )
            let attemptID = UUID()

            activeRecorder = recorder
            activeFileURL = outputFileURL
            activeAttemptID = attemptID
            activeRecordingStartTime = monotonicClock()
            activeMaximumRecordingDuration = resolvedMaximumDuration
            recorder.setRecordingFinishedHandler { [weak self] recorderReportedSuccess in
                Task { @MainActor [weak self] in
                    await self?.finishAutomatically(
                        attemptID: attemptID,
                        recorderReportedSuccess: recorderReportedSuccess
                    )
                }
            }

            guard recorder.record(forDuration: resolvedMaximumDuration) else {
                clearActiveRecording(ifAttemptID: attemptID)
                recorder.setRecordingFinishedHandler(nil)
                if preparedOutputFileURL == nil {
                    recorder.deleteRecording()
                }
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
        try await stopRecordingOutcome().artifact
    }

    func stopRecordingOutcome() async throws -> AudioRecorderStopOutcome {
        // A key-up may already be waiting in the configured stop tail when the
        // recorder reaches its hard limit. The automatic callback can finish
        // first; the manual consumer must still join that exact artifact and
        // inherit the terminal authority that began finalization.
        if case .finished(let artifact) = currentStatus {
            return AudioRecorderStopOutcome(
                artifact: artifact,
                automaticCompletion: lastAutomaticCompletion
            )
        }

        if let finalizationTask, let finalizationAttemptID {
            let automaticContext = automaticFinalizationContext
            let artifact = try await awaitFinalization(
                finalizationTask,
                attemptID: finalizationAttemptID
            )
            let automaticCompletion = automaticContext.map {
                makeAutomaticCompletion(artifact: artifact, context: $0)
            }
            if let automaticCompletion {
                lastAutomaticCompletion = automaticCompletion
            }
            return AudioRecorderStopOutcome(
                artifact: artifact,
                automaticCompletion: automaticCompletion
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
        let maximumRecordingDuration = activeMaximumRecordingDuration
            ?? defaultMaximumRecordingDuration
        lastFinalizationReachedMaximumDuration = durationReachedAutomaticLimit(
            elapsedRecordingDuration(),
            maximumDuration: maximumRecordingDuration
        )
        automaticFinalizationContext = nil
        lastAutomaticCompletion = nil
        clearActiveRecording(ifAttemptID: attemptID)
        recorder.setRecordingFinishedHandler(nil)
        recorder.stop()

        let task = artifactFinalizer.makeFinalizationTask(
            outputFileURL: outputFileURL,
            fallbackDuration: engineDuration
        )
        beginFinalization(task, attemptID: attemptID, recorder: recorder)
        let artifact = try await awaitFinalization(task, attemptID: attemptID)
        return AudioRecorderStopOutcome(
            artifact: artifact,
            automaticCompletion: nil
        )
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
        activeMaximumRecordingDuration = nil
        recorder?.setRecordingFinishedHandler(nil)
        recorder?.stop()
        recorder?.deleteRecording()
        activeRecorder = nil
        activeFileURL = nil
        automaticFinalizationContext = nil
        lastAutomaticCompletion = nil
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
        let maximumRecordingDuration = activeMaximumRecordingDuration
            ?? defaultMaximumRecordingDuration
        lastFinalizationReachedMaximumDuration = durationReachedAutomaticLimit(
            monotonicElapsed,
            maximumDuration: maximumRecordingDuration
        )
        let automaticContext = AutomaticFinalizationContext(
            recorderReportedSuccess: recorderReportedSuccess,
            monotonicElapsed: monotonicElapsed,
            maximumRecordingDuration: maximumRecordingDuration
        )
        automaticFinalizationContext = automaticContext
        lastAutomaticCompletion = nil
        clearActiveRecording(ifAttemptID: attemptID)
        recorder.setRecordingFinishedHandler(nil)

        let task = artifactFinalizer.makeFinalizationTask(
            outputFileURL: outputFileURL,
            fallbackDuration: engineDuration
        )
        beginFinalization(task, attemptID: attemptID, recorder: recorder)

        let result: Result<AudioRecorderAutomaticCompletion, AudioRecorderServiceError>
        do {
            let artifact = try await awaitFinalization(task, attemptID: attemptID)
            let completion = makeAutomaticCompletion(
                artifact: artifact,
                context: automaticContext
            )
            lastAutomaticCompletion = completion
            if completion.reason == .maximumDuration {
                lastFinalizationReachedMaximumDuration = true
            }
            result = .success(completion)
        } catch let error as AudioRecorderServiceError {
            result = .failure(error)
        } catch {
            result = .failure(.stopFailed)
        }

        automaticStopHandler?(result)
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
                if artifactFinalizer.shouldDeleteRecorderOutput(after: error) {
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
        activeMaximumRecordingDuration = nil
    }

    private func clearFinalization() {
        finalizationTask = nil
        finalizationAttemptID = nil
        finalizingRecorder = nil
        automaticFinalizationContext = nil
    }

    private func normalizedDuration(_ duration: TimeInterval) -> TimeInterval {
        AudioRecordingArtifactFinalizer.normalizedDuration(duration) ?? 0
    }

    private func elapsedRecordingDuration() -> TimeInterval? {
        guard let activeRecordingStartTime else {
            return nil
        }

        let elapsed = monotonicClock() - activeRecordingStartTime
        return AudioRecordingArtifactFinalizer.normalizedDuration(elapsed)
    }

    private func automaticCompletionReason(
        recorderReportedSuccess: Bool,
        monotonicElapsed: TimeInterval?,
        finalizedMediaDuration: TimeInterval,
        maximumDuration: TimeInterval
    ) -> AudioRecorderAutomaticCompletionReason {
        let elapsedReachedLimit = durationReachedAutomaticLimit(
            monotonicElapsed,
            maximumDuration: maximumDuration
        )
        let mediaReachedLimit = durationReachedAutomaticLimit(
            finalizedMediaDuration,
            maximumDuration: maximumDuration
        )

        if elapsedReachedLimit || mediaReachedLimit {
            return .maximumDuration
        }

        return .unexpected(recorderReportedSuccess: recorderReportedSuccess)
    }

    private func makeAutomaticCompletion(
        artifact: AudioRecordingArtifact,
        context: AutomaticFinalizationContext
    ) -> AudioRecorderAutomaticCompletion {
        AudioRecorderAutomaticCompletion(
            artifact: artifact,
            reason: automaticCompletionReason(
                recorderReportedSuccess: context.recorderReportedSuccess,
                monotonicElapsed: context.monotonicElapsed,
                finalizedMediaDuration: artifact.duration,
                maximumDuration: context.maximumRecordingDuration
            ),
            recorderReportedSuccess: context.recorderReportedSuccess
        )
    }

    private func durationReachedAutomaticLimit(
        _ duration: TimeInterval?,
        maximumDuration: TimeInterval
    ) -> Bool {
        guard let duration, duration.isFinite else {
            return false
        }

        let tolerance = min(
            Self.automaticLimitClassificationTolerance,
            maximumDuration * 0.02
        )
        return duration >= maximumDuration - tolerance
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
