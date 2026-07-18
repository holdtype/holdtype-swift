import Foundation
import HoldTypeDomain

@_spi(HoldTypeIOSCore)
public enum IOSV1PendingRecordingPhase: Equatable, Sendable {
    case readyForTranscription
    case failed
    case transcribing
    case postProcessing
    case outputDelivery
    case acceptedCleanup
}

@_spi(HoldTypeIOSCore)
public enum IOSV1PendingTextCheckpointStage: String, Equatable, Sendable {
    case transcriptionAccepted
    case correctionInFlight
    case translationReady
    case translationInFlight
    case outputReady

    init(_ stage: IOSVoiceStateTextCheckpointStage) {
        self = Self(rawValue: stage.rawValue) ?? .transcriptionAccepted
    }

    var repositoryValue: IOSVoiceStateTextCheckpointStage {
        IOSVoiceStateTextCheckpointStage(rawValue: rawValue)
            ?? .transcriptionAccepted
    }
}

@_spi(HoldTypeIOSCore)
public enum IOSV1PendingRecordingAvailability: Equatable, Sendable {
    case available
    case temporarilyUnavailable
    case missing
    case invalid
}

@_spi(HoldTypeIOSCore)
public struct IOSV1PendingRecording: Equatable, Sendable {
    public let attemptID: UUID
    public let audioRelativeIdentifier: String
    public let createdAt: Date
    public let updatedAt: Date
    public let phase: IOSV1PendingRecordingPhase
    public let outputIntent: DictationOutputIntent
    public let draftInsertionMode: IOSVoiceDraftInsertionMode
    public let forcesTextCorrection: Bool
    public let transcriptionID: UUID?
    public let transcriptionModel: String
    public let transcriptionLanguageCode: String?
    public let durationMilliseconds: Int64
    public let byteCount: Int64
    public let acceptedAudioRetention: IOSAcceptedAudioRetention
    public let transcriptionReplayBlocked: Bool
    /// Durable normalized transcription accepted before downstream work.
    /// A failed recording with this checkpoint retries post-processing only.
    public let acceptedTranscriptionID: UUID?
    public let acceptedTranscript: String?
    public let textCheckpointStage: IOSV1PendingTextCheckpointStage?
    public let textCheckpointText: String?

    let state: IOSVoiceStatePending

    init(_ state: IOSVoiceStatePending) {
        self.state = state
        attemptID = state.attemptID
        audioRelativeIdentifier = state.audioRelativeIdentifier
        createdAt = state.createdAt
        updatedAt = state.updatedAt
        outputIntent = state.outputIntent
        draftInsertionMode = state.draftInsertionMode
        forcesTextCorrection = state.forcesTextCorrection
        transcriptionModel = state.transcriptionModel
        transcriptionLanguageCode = state.transcriptionLanguageCode
        durationMilliseconds = state.durationMilliseconds
        byteCount = state.byteCount
        acceptedAudioRetention = state.acceptedAudioRetention
        transcriptionReplayBlocked = state.transcriptionReplayBlocked
        acceptedTranscriptionID = state.transcriptionCheckpoint?.operationID
        acceptedTranscript = state.transcriptionCheckpoint?.acceptedTranscript
        textCheckpointStage = state.transcriptionCheckpoint.map {
            IOSV1PendingTextCheckpointStage($0.stage)
        }
        textCheckpointText = state.transcriptionCheckpoint?.text
        switch state.status {
        case .ready:
            phase = .readyForTranscription
            transcriptionID = nil
        case .failed:
            phase = .failed
            transcriptionID = nil
        case .processing(let stage, let operationID):
            transcriptionID = operationID
            switch stage {
            case .transcription: phase = .transcribing
            case .postProcessing: phase = .postProcessing
            case .outputDelivery: phase = .outputDelivery
            }
        case .acceptedCleanup:
            phase = .acceptedCleanup
            transcriptionID = nil
        }
    }

#if DEBUG
    public static func qualificationFixture(
        attemptID: UUID = UUID(),
        outputIntent: DictationOutputIntent = .standard,
        draftInsertionMode: IOSVoiceDraftInsertionMode = .replace,
        forcesTextCorrection: Bool = false,
        phase: IOSV1PendingRecordingPhase = .readyForTranscription,
        transcriptionID: UUID? = nil,
        transcriptionConfiguration: TranscriptionConfiguration = .init(),
        acceptedAudioRetention: IOSAcceptedAudioRetention =
            .recordingCachePolicy,
        transcriptionReplayBlocked: Bool = false,
        acceptedTranscriptionID: UUID? = nil,
        acceptedTranscript: String? = nil,
        textCheckpointStage: IOSV1PendingTextCheckpointStage? = nil,
        textCheckpointText: String? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_800_000_000),
        durationMilliseconds: Int64 = 1_000,
        byteCount: Int64 = 1_024
    ) throws -> Self {
        let status: IOSVoiceStatePendingStatus
        switch phase {
        case .readyForTranscription:
            guard transcriptionID == nil else {
                throw IOSV1ForegroundVoicePersistenceError.invalidTransition
            }
            status = .ready
        case .failed:
            guard transcriptionID == nil else {
                throw IOSV1ForegroundVoicePersistenceError.invalidTransition
            }
            status = .failed
        case .transcribing, .postProcessing, .outputDelivery:
            guard let transcriptionID else {
                throw IOSV1ForegroundVoicePersistenceError.invalidTransition
            }
            let stage: IOSVoiceStateProcessingStage = switch phase {
            case .transcribing: .transcription
            case .postProcessing: .postProcessing
            case .outputDelivery: .outputDelivery
            default: preconditionFailure("unreachable phase")
            }
            status = .processing(stage, operationID: transcriptionID)
        case .acceptedCleanup:
            throw IOSV1ForegroundVoicePersistenceError.invalidTransition
        }
        let transcriptionCheckpoint: IOSVoiceStateTranscriptionCheckpoint?
        switch (
            acceptedTranscriptionID,
            acceptedTranscript,
            textCheckpointStage,
            textCheckpointText
        ) {
        case (nil, nil, nil, nil):
            transcriptionCheckpoint = nil
        case let (
            .some(operationID),
            .some(acceptedTranscript),
            .some(stage),
            .some(text)
        ):
            transcriptionCheckpoint = try IOSVoiceStateTranscriptionCheckpoint(
                operationID: operationID,
                acceptedTranscript: acceptedTranscript,
                stage: stage.repositoryValue,
                text: text
            )
        default:
            throw IOSV1ForegroundVoicePersistenceError.invalidTransition
        }
        return Self(
            try IOSVoiceStatePending(
                attemptID: attemptID,
                audioRelativeIdentifier:
                    IOSVoiceStateStorageLocation.relativeAudioIdentifier(
                        for: attemptID
                    ),
                createdAt: createdAt,
                updatedAt: createdAt,
                outputIntent: outputIntent,
                draftInsertionMode: draftInsertionMode,
                forcesTextCorrection: forcesTextCorrection,
                transcriptionModel:
                    transcriptionConfiguration.resolvedModel,
                transcriptionLanguageCode:
                    transcriptionConfiguration.resolvedLanguageCode,
                durationMilliseconds: durationMilliseconds,
                byteCount: byteCount,
                acceptedAudioRetention: acceptedAudioRetention,
                transcriptionReplayBlocked: transcriptionReplayBlocked,
                transcriptionCheckpoint: transcriptionCheckpoint,
                status: status
            )
        )
    }
#endif
}

@_spi(HoldTypeIOSCore)
public struct IOSV1PendingRecordingExpectation: Equatable, Sendable {
    public let attemptID: UUID

    let recording: IOSV1PendingRecording

    public init(recording: IOSV1PendingRecording) {
        self.recording = recording
        attemptID = recording.attemptID
    }
}

@_spi(HoldTypeIOSCore)
public struct IOSV1PendingRecordingObservation: Equatable, Sendable {
    public let recording: IOSV1PendingRecording
    public let availability: IOSV1PendingRecordingAvailability

    public var expectation: IOSV1PendingRecordingExpectation {
        IOSV1PendingRecordingExpectation(recording: recording)
    }

    public init(
        recording: IOSV1PendingRecording,
        availability: IOSV1PendingRecordingAvailability
    ) {
        self.recording = recording
        self.availability = availability
    }
}

@_spi(HoldTypeIOSCore)
public enum IOSV1PendingRecordingDiscardResult: Equatable, Sendable {
    case discarded
    case alreadyAbsent
}

@_spi(HoldTypeIOSCore)
public enum IOSV1PendingRecordingAudioFormat: Equatable, Sendable {
    case m4a
    case wav
}

extension IOSV1PendingRecording: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSV1PendingRecording(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
