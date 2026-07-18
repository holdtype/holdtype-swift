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
