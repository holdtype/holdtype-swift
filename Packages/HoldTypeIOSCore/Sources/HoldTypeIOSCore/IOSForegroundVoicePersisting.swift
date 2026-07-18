import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence

protocol IOSForegroundVoicePersisting: Sendable {
    func load() async throws -> IOSV1PendingRecordingObservation?

    func beginTranscription(
        expected: IOSV1PendingRecordingExpectation,
        transcriptionID: UUID
    ) async throws -> IOSV1ForegroundVoiceTranscriptionDispatch

    func retryTranscription(
        expected: IOSV1PendingRecordingExpectation,
        transcriptionID: UUID,
        transcriptionConfiguration: TranscriptionConfiguration
    ) async throws -> IOSV1ForegroundVoiceTranscriptionDispatch

    func checkpointTranscription(
        expected: IOSV1PendingRecordingExpectation,
        acceptedTranscript: String
    ) async throws -> IOSV1PendingRecording

    func checkpointPostProcessing(
        expected: IOSV1PendingRecordingExpectation,
        stage: IOSV1PendingTextCheckpointStage,
        text: String
    ) async throws -> IOSV1PendingRecording

    func retryPostProcessing(
        expected: IOSV1PendingRecordingExpectation,
        operationID: UUID
    ) async throws -> IOSV1PendingRecording

    func markOutputDelivery(
        expected: IOSV1PendingRecordingExpectation
    ) async throws -> IOSV1PendingRecording

    func markFailed(
        expected: IOSV1PendingRecordingExpectation,
        transcriptionReplayBlocked: Bool
    ) async throws -> IOSV1PendingRecording

    func accept(
        _ preparation: IOSV1ForegroundVoiceAcceptedOutputPreparation,
        expectedPending: IOSV1PendingRecordingExpectation
    ) async throws -> IOSV1ForegroundVoiceAcceptanceResult

    func reconcileAcceptance(
        matching preparation: IOSV1ForegroundVoiceAcceptedOutputPreparation
    ) async throws -> IOSV1ForegroundVoiceAcceptanceResult?
}

extension IOSV1ForegroundVoicePersistenceOwner: IOSForegroundVoicePersisting {}
