import Foundation
import HoldTypeDomain

extension IOSVoiceStateTranscriptionCheckpoint {
    func advancing(
        to stage: IOSVoiceStateTextCheckpointStage,
        text: String
    ) throws -> Self {
        let allowed = switch (self.stage, stage) {
        case (.transcriptionAccepted, .correctionInFlight),
             (.transcriptionAccepted, .translationReady),
             (.transcriptionAccepted, .outputReady),
             (.correctionInFlight, .translationReady),
             (.correctionInFlight, .outputReady),
             (.translationReady, .translationInFlight),
             (.translationInFlight, .translationReady),
             (.translationInFlight, .outputReady):
            true
        default:
            self.stage == stage && self.text == text
        }
        guard allowed else {
            throw IOSVoiceStateRepositoryError.invalidTransition
        }
        return try Self(
            operationID: operationID,
            acceptedTranscript: acceptedTranscript,
            stage: stage,
            text: text
        )
    }
}

extension IOSVoiceStateCapture {
    func replacing(
        phase: IOSVoiceStateCapturePhase,
        durationMilliseconds: Int64? = nil,
        byteCount: Int64? = nil
    ) throws -> Self {
        try Self(
            attemptID: attemptID,
            audioRelativeIdentifier: audioRelativeIdentifier,
            createdAt: createdAt,
            outputIntent: outputIntent,
            draftInsertionMode: draftInsertionMode,
            forcesTextCorrection: forcesTextCorrection,
            recordingDurationLimit: recordingDurationLimit,
            phase: phase,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount
        )
    }
}

extension IOSVoiceStatePending {
    func replacing(
        status: IOSVoiceStatePendingStatus,
        updatedAt: Date
    ) throws -> Self {
        try Self(
            attemptID: attemptID,
            audioRelativeIdentifier: audioRelativeIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt,
            outputIntent: outputIntent,
            draftInsertionMode: draftInsertionMode,
            forcesTextCorrection: forcesTextCorrection,
            transcriptionModel: transcriptionModel,
            transcriptionLanguageCode: transcriptionLanguageCode,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount,
            acceptedAudioRetention: acceptedAudioRetention,
            transcriptionReplayBlocked: transcriptionReplayBlocked,
            transcriptionCheckpoint: transcriptionCheckpoint,
            status: status
        )
    }

    func replacing(
        status: IOSVoiceStatePendingStatus,
        transcriptionCheckpoint: IOSVoiceStateTranscriptionCheckpoint,
        updatedAt: Date
    ) throws -> Self {
        try Self(
            attemptID: attemptID,
            audioRelativeIdentifier: audioRelativeIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt,
            outputIntent: outputIntent,
            draftInsertionMode: draftInsertionMode,
            forcesTextCorrection: forcesTextCorrection,
            transcriptionModel: transcriptionModel,
            transcriptionLanguageCode: transcriptionLanguageCode,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount,
            acceptedAudioRetention: acceptedAudioRetention,
            transcriptionReplayBlocked: transcriptionReplayBlocked,
            transcriptionCheckpoint: transcriptionCheckpoint,
            status: status
        )
    }

    func replacing(
        transcriptionConfiguration: TranscriptionConfiguration,
        status: IOSVoiceStatePendingStatus,
        updatedAt: Date
    ) throws -> Self {
        guard !transcriptionConfiguration.customLanguageCodeValidation
            .isInvalid else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        return try Self(
            attemptID: attemptID,
            audioRelativeIdentifier: audioRelativeIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt,
            outputIntent: outputIntent,
            draftInsertionMode: draftInsertionMode,
            forcesTextCorrection: forcesTextCorrection,
            transcriptionModel: transcriptionConfiguration.resolvedModel,
            transcriptionLanguageCode:
                transcriptionConfiguration.resolvedLanguageCode,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount,
            acceptedAudioRetention: acceptedAudioRetention,
            transcriptionReplayBlocked: transcriptionReplayBlocked,
            transcriptionCheckpoint: transcriptionCheckpoint,
            status: status
        )
    }

    func replacing(
        status: IOSVoiceStatePendingStatus,
        transcriptionReplayBlocked: Bool,
        updatedAt: Date
    ) throws -> Self {
        try Self(
            attemptID: attemptID,
            audioRelativeIdentifier: audioRelativeIdentifier,
            createdAt: createdAt,
            updatedAt: updatedAt,
            outputIntent: outputIntent,
            draftInsertionMode: draftInsertionMode,
            forcesTextCorrection: forcesTextCorrection,
            transcriptionModel: transcriptionModel,
            transcriptionLanguageCode: transcriptionLanguageCode,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount,
            acceptedAudioRetention: acceptedAudioRetention,
            transcriptionReplayBlocked: transcriptionReplayBlocked,
            transcriptionCheckpoint: transcriptionCheckpoint,
            status: status
        )
    }
}
