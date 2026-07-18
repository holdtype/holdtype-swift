import Foundation
import HoldTypeDomain

enum IOSVoiceStateProcessingStage: String, Equatable, Sendable {
    case transcription
    case postProcessing
    case outputDelivery
}

struct IOSVoiceStateAcceptedResult: Equatable, Sendable {
    let resultID: UUID
    let sourceAttemptID: UUID
    let text: String
    let createdAt: Date
}

enum IOSVoiceStateTextCheckpointStage: String, Equatable, Sendable {
    case transcriptionAccepted
    case correctionInFlight
    case translationReady
    case translationInFlight
    case outputReady
}

/// The consent-consumed transcription response and the latest exact downstream
/// boundary. The original response and operation ID remain stable while `text`
/// advances, so usage identity never changes and a retry can skip every already
/// completed or outcome-unknown provider stage.
struct IOSVoiceStateTranscriptionCheckpoint: Equatable, Sendable {
    let operationID: UUID
    let acceptedTranscript: String
    let stage: IOSVoiceStateTextCheckpointStage
    let text: String

    init(
        operationID: UUID,
        acceptedTranscript: String,
        stage: IOSVoiceStateTextCheckpointStage = .transcriptionAccepted,
        text: String? = nil
    ) throws {
        let checkpointText = text ?? acceptedTranscript
        guard IOSVoiceStateValidation.isStoredText(acceptedTranscript),
              IOSVoiceStateValidation.isStoredText(checkpointText) else {
            throw IOSVoiceStateRepositoryError.invalidAcceptedText
        }
        self.operationID = operationID
        self.acceptedTranscript = acceptedTranscript
        self.stage = stage
        self.text = checkpointText
    }
}

enum IOSVoiceStatePendingStatus: Equatable, Sendable {
    case ready
    case processing(IOSVoiceStateProcessingStage, operationID: UUID)
    case failed
    case acceptedCleanup(IOSVoiceStateAcceptedResult)
}

enum IOSVoiceStateCapturePhase: String, Equatable, Sendable {
    case recording
    case finalizing
    case completed
    case discarding
}

struct IOSVoiceStateCapture: Equatable, Sendable {
    let attemptID: UUID
    let audioRelativeIdentifier: String
    let createdAt: Date
    let outputIntent: DictationOutputIntent
    let draftInsertionMode: IOSVoiceDraftInsertionMode
    let forcesTextCorrection: Bool
    let recordingDurationLimit: RecordingDurationLimit
    let phase: IOSVoiceStateCapturePhase
    let durationMilliseconds: Int64?
    let byteCount: Int64?

    init(
        attemptID: UUID,
        audioRelativeIdentifier: String,
        createdAt: Date,
        outputIntent: DictationOutputIntent,
        draftInsertionMode: IOSVoiceDraftInsertionMode = .replace,
        forcesTextCorrection: Bool = false,
        recordingDurationLimit: RecordingDurationLimit = .default,
        phase: IOSVoiceStateCapturePhase,
        durationMilliseconds: Int64? = nil,
        byteCount: Int64? = nil
    ) throws {
        let hasCompletion = durationMilliseconds != nil || byteCount != nil
        guard IOSVoiceStateValidation.isCanonicalCaptureAudioIdentifier(
                  audioRelativeIdentifier,
                  attemptID: attemptID
              ),
              IOSVoiceStateValidation.isValidDate(createdAt),
              (phase == .completed) == hasCompletion,
              (durationMilliseconds == nil && byteCount == nil)
                || ((durationMilliseconds ?? -1) >= 0
                    && (byteCount ?? 0) > 0
                    && (byteCount ?? 0) < 25_000_000) else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        self.attemptID = attemptID
        self.audioRelativeIdentifier = audioRelativeIdentifier
        self.createdAt = createdAt
        self.outputIntent = outputIntent
        self.draftInsertionMode = draftInsertionMode
        self.forcesTextCorrection = forcesTextCorrection
        self.recordingDurationLimit = recordingDurationLimit
        self.phase = phase
        self.durationMilliseconds = durationMilliseconds
        self.byteCount = byteCount
    }
}

struct IOSVoiceStatePending: Equatable, Sendable {
    let attemptID: UUID
    let audioRelativeIdentifier: String
    let createdAt: Date
    let updatedAt: Date
    let outputIntent: DictationOutputIntent
    let draftInsertionMode: IOSVoiceDraftInsertionMode
    let forcesTextCorrection: Bool
    let transcriptionModel: String
    let transcriptionLanguageCode: String?
    let durationMilliseconds: Int64
    let byteCount: Int64
    let acceptedAudioRetention: IOSAcceptedAudioRetention
    let transcriptionReplayBlocked: Bool
    let transcriptionCheckpoint: IOSVoiceStateTranscriptionCheckpoint?
    let status: IOSVoiceStatePendingStatus

    init(
        attemptID: UUID,
        audioRelativeIdentifier: String,
        createdAt: Date,
        updatedAt: Date,
        outputIntent: DictationOutputIntent,
        draftInsertionMode: IOSVoiceDraftInsertionMode = .replace,
        forcesTextCorrection: Bool = false,
        transcriptionModel: String,
        transcriptionLanguageCode: String?,
        durationMilliseconds: Int64,
        byteCount: Int64,
        acceptedAudioRetention: IOSAcceptedAudioRetention =
            .recordingCachePolicy,
        transcriptionReplayBlocked: Bool = false,
        transcriptionCheckpoint: IOSVoiceStateTranscriptionCheckpoint? = nil,
        status: IOSVoiceStatePendingStatus
    ) throws {
        guard IOSVoiceStateValidation.isCanonicalRelativeAudioIdentifier(
                  audioRelativeIdentifier,
                  attemptID: attemptID
              ),
              IOSVoiceStateValidation.isValidDate(createdAt),
              IOSVoiceStateValidation.isValidDate(updatedAt),
              updatedAt >= createdAt,
              IOSVoiceStateValidation.isValidModel(transcriptionModel),
              IOSVoiceStateValidation.isValidLanguageCode(
                  transcriptionLanguageCode
              ),
              durationMilliseconds >= 0,
              byteCount > 0,
              byteCount < 25_000_000,
              !(transcriptionReplayBlocked
                && transcriptionCheckpoint != nil) else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        if transcriptionReplayBlocked, status != .failed {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        if let transcriptionCheckpoint {
            switch status {
            case .ready, .processing(.transcription, _):
                throw IOSVoiceStateRepositoryError.invalidRecord
            case .processing(.outputDelivery, _)
                where transcriptionCheckpoint.stage != .outputReady:
                throw IOSVoiceStateRepositoryError.invalidRecord
            case .acceptedCleanup
                where transcriptionCheckpoint.stage != .outputReady:
                throw IOSVoiceStateRepositoryError.invalidRecord
            case .processing(.postProcessing, _), .failed,
                 .processing(.outputDelivery, _), .acceptedCleanup:
                break
            }
        }
        if case .acceptedCleanup(let accepted) = status {
            guard accepted.sourceAttemptID == attemptID else {
                throw IOSVoiceStateRepositoryError.invalidRecord
            }
        }

        self.attemptID = attemptID
        self.audioRelativeIdentifier = audioRelativeIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.outputIntent = outputIntent
        self.draftInsertionMode = draftInsertionMode
        self.forcesTextCorrection = forcesTextCorrection
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguageCode = transcriptionLanguageCode
        self.durationMilliseconds = durationMilliseconds
        self.byteCount = byteCount
        self.acceptedAudioRetention = acceptedAudioRetention
        self.transcriptionReplayBlocked = transcriptionReplayBlocked
        self.transcriptionCheckpoint = transcriptionCheckpoint
        self.status = status
    }
}

struct IOSVoiceStateLatest: Equatable, Sendable {
    let resultID: UUID
    let sourceAttemptID: UUID
    let text: String
    let createdAt: Date

    init(
        resultID: UUID,
        sourceAttemptID: UUID,
        text: String,
        createdAt: Date
    ) throws {
        guard IOSVoiceStateValidation.isStoredText(text),
              IOSVoiceStateValidation.isValidDate(createdAt) else {
            throw IOSVoiceStateRepositoryError.invalidAcceptedText
        }
        self.resultID = resultID
        self.sourceAttemptID = sourceAttemptID
        self.text = text
        self.createdAt = createdAt
    }
}

struct IOSVoiceStateSnapshot: Equatable, Sendable {
    var capture: IOSVoiceStateCapture?
    var pending: IOSVoiceStatePending?
    var latest: IOSVoiceStateLatest?

    static let empty = Self(capture: nil, pending: nil, latest: nil)
}

enum IOSVoiceStateMutationResult: Equatable, Sendable {
    case changed(IOSVoiceStateSnapshot)
    case unchanged(IOSVoiceStateSnapshot)
}

extension IOSVoiceStatePending: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    var description: String { "IOSVoiceStatePending(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSVoiceStateLatest: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    var description: String { "IOSVoiceStateLatest(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
