import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct VoicePromptFixSessionTests {
    @Test func finishUsesTransientTranscriptionWithoutNearbyText() async throws {
        let recorder = FakeAudioRecorderService()
        let transcription = VoicePromptTranscriptionFake(output: "Make it concise")
        let recovery = FakeTranscriptionFailureRecovery()
        let cache = VoicePromptCacheFake()
        let usage = VoicePromptUsageFake()
        let reservation = VoiceWorkReservation()
        let session = VoicePromptFixSession(
            recorder: recorder,
            setupPreflight: VoicePromptPreflightFake(),
            transcriptionService: transcription,
            textCorrectionService: VoicePromptCorrectionFake(),
            recoveryStore: recovery,
            captureJournal: VoicePromptCaptureJournalFake(),
            recordingCache: cache,
            usageRecorder: usage,
            voiceWorkReservation: reservation
        )
        var settings = AppSettings.defaults
        settings.useActiveTextContext = true
        settings.prompt = "Keep product names exact."
        settings.customDictionary = ["HoldType"]

        try await session.start(
            settings: settings,
            credential: try OpenAICredential(apiKey: "test-key"),
            automaticCompletionStarted: {},
            automaticCompletion: { _ in }
        )
        let instruction = try await session.finish()

        #expect(recorder.requestedMaximumDurations == [60])
        #expect(instruction.text == "Make it concise")
        let request = try #require(transcription.requests.first)
        #expect(request.promptComposition.contextEchoGuardText == nil)
        #expect(request.promptComposition.providerPrompt?.contains("Keep product names exact.") == true)
        #expect(request.promptComposition.providerPrompt?.contains("HoldType") == true)
        #expect(recovery.failedAttempts.first?.completionKind == .voicePrompt)
        #expect(cache.policies == [.deleteImmediately])
        #expect(usage.values.count == 1)
        #expect(reservation.owner == .voicePromptFix)

        session.completeApplication()

        #expect(recovery.failedAttempts.isEmpty)
        #expect(reservation.owner == nil)
    }

    @Test func cancelDiscardsActiveCaptureWithoutProviderWork() async throws {
        let recorder = FakeAudioRecorderService()
        let transcription = VoicePromptTranscriptionFake(output: "Unused")
        let recovery = FakeTranscriptionFailureRecovery()
        let reservation = VoiceWorkReservation()
        let session = makeSession(
            recorder: recorder,
            transcription: transcription,
            recovery: recovery,
            reservation: reservation
        )

        try await session.start(
            settings: .defaults,
            credential: try OpenAICredential(apiKey: "test-key"),
            automaticCompletionStarted: {},
            automaticCompletion: { _ in }
        )
        session.cancel()

        #expect(recorder.cancelCount == 1)
        #expect(transcription.requests.isEmpty)
        #expect(recovery.failedAttempts.isEmpty)
        #expect(reservation.owner == nil)
    }

    @Test func failedApplicationKeepsPlayDeleteOnlyVoicePromptRecovery() async throws {
        let recovery = FakeTranscriptionFailureRecovery()
        let session = makeSession(
            recorder: FakeAudioRecorderService(),
            transcription: VoicePromptTranscriptionFake(output: "Make it clearer"),
            recovery: recovery,
            reservation: VoiceWorkReservation()
        )
        try await session.start(
            settings: .defaults,
            credential: try OpenAICredential(apiKey: "test-key"),
            automaticCompletionStarted: {},
            automaticCompletion: { _ in }
        )
        _ = try await session.finish()

        session.failApplication()

        let attempt = try #require(recovery.failedAttempts.first)
        #expect(attempt.completionKind == .voicePrompt)
        #expect(attempt.state == .failed)
        #expect(attempt.reason == .voicePromptFailed)
        #expect(attempt.canRetry == false)
        #expect(attempt.canDelete)
        #expect(
            TranscriptionRecoveryHistoryRowPresentation(attempt: attempt).title
                == "Voice Prompt Saved Recording"
        )
    }

    @Test func cancelAfterTranscriptionDiscardsVoicePromptRecovery() async throws {
        let recovery = FakeTranscriptionFailureRecovery()
        let reservation = VoiceWorkReservation()
        let session = makeSession(
            recorder: FakeAudioRecorderService(),
            transcription: VoicePromptTranscriptionFake(output: "Make it clearer"),
            recovery: recovery,
            reservation: reservation
        )
        try await session.start(
            settings: .defaults,
            credential: try OpenAICredential(apiKey: "test-key"),
            automaticCompletionStarted: {},
            automaticCompletion: { _ in }
        )
        _ = try await session.finish()

        session.cancel()

        #expect(recovery.failedAttempts.isEmpty)
        #expect(reservation.owner == nil)
    }

    @Test func ordinaryDictationReservationBlocksVoicePromptCapture() async throws {
        let recorder = FakeAudioRecorderService()
        let reservation = VoiceWorkReservation()
        #expect(reservation.acquire(.dictation))
        let session = makeSession(
            recorder: recorder,
            transcription: VoicePromptTranscriptionFake(output: "Unused"),
            recovery: FakeTranscriptionFailureRecovery(),
            reservation: reservation
        )

        await #expect(throws: VoicePromptFixSessionError.voiceWorkUnavailable) {
            try await session.start(
                settings: .defaults,
                credential: try OpenAICredential(apiKey: "test-key"),
                automaticCompletionStarted: {},
                automaticCompletion: { _ in }
            )
        }

        #expect(recorder.startCount == 0)
        #expect(reservation.owner == .dictation)
        #expect(reservation.acquire(.dictation) == false)
    }

    private func makeSession(
        recorder: FakeAudioRecorderService,
        transcription: VoicePromptTranscriptionFake,
        recovery: FakeTranscriptionFailureRecovery,
        reservation: VoiceWorkReservation
    ) -> VoicePromptFixSession {
        VoicePromptFixSession(
            recorder: recorder,
            setupPreflight: VoicePromptPreflightFake(),
            transcriptionService: transcription,
            textCorrectionService: VoicePromptCorrectionFake(),
            recoveryStore: recovery,
            captureJournal: VoicePromptCaptureJournalFake(),
            recordingCache: VoicePromptCacheFake(),
            usageRecorder: VoicePromptUsageFake(),
            voiceWorkReservation: reservation
        )
    }
}

private struct VoicePromptPreflightFake: VoicePromptRecordingPreflighting {
    func requestMicrophonePermissionIfNeeded() async -> MicrophonePermissionStatus? {
        nil
    }
}

@MainActor
private final class VoicePromptTranscriptionFake: OpenAITranscriptionServing {
    let output: String
    private(set) var requests: [AudioTranscriptionRequest] = []

    init(output: String) {
        self.output = output
    }

    func transcribe(
        _ request: AudioTranscriptionRequest,
        credential: OpenAICredential
    ) async throws -> String {
        requests.append(request)
        return output
    }

    func cancelActiveTranscription() {}
}

private struct VoicePromptCorrectionFake: TextCorrectionServing {
    func correct(
        _ request: TextCorrectionRequest,
        credential: OpenAICredential
    ) async throws -> String {
        request.acceptedTranscript.text
    }

    func cancelActiveCorrection() {}
}

@MainActor
private final class VoicePromptCacheFake: RecordingCacheLifecycleHandling {
    private(set) var policies: [RecordingCachePolicy] = []

    func handleCompletedRecording(
        _ artifact: AudioRecordingArtifact,
        policy: RecordingCachePolicy
    ) throws {
        policies.append(policy)
    }
}

@MainActor
private final class VoicePromptUsageFake: TranscriptionUsageRecording {
    private(set) var values: [SuccessfulTranscriptionUsage] = []

    func recordSuccessfulTranscriptionUsage(_ usage: SuccessfulTranscriptionUsage) {
        values.append(usage)
    }
}

@MainActor
private final class VoicePromptCaptureJournalFake: RecordingCaptureJournaling {
    func prepareCapture(
        settings: AppSettings,
        maximumDuration: TimeInterval
    ) throws -> RecordingCaptureLease {
        throw VoicePromptTestError.unexpectedCaptureJournalCall
    }

    func releaseCapture(
        _ lease: RecordingCaptureLease,
        artifact: AudioRecordingArtifact,
        recoveryAttemptID: FailedTranscriptionAttempt.ID
    ) throws -> AudioRecordingArtifact {
        throw VoicePromptTestError.unexpectedCaptureJournalCall
    }

    func retireCaptureAfterRecovery(
        _ lease: RecordingCaptureLease,
        recoveryAttemptID: FailedTranscriptionAttempt.ID
    ) throws {
        throw VoicePromptTestError.unexpectedCaptureJournalCall
    }

    func discardCapture(_ lease: RecordingCaptureLease) throws {
        throw VoicePromptTestError.unexpectedCaptureJournalCall
    }

    func inspectCapture(
        _ lease: RecordingCaptureLease,
        fallbackDuration: TimeInterval
    ) -> RecordingCaptureInspection {
        .missing
    }

    func repairInterruptedCaptures(
        into recoveryStore: any TranscriptionFailureRecoveryRecording,
        onRepair: (UUID, RecordingDurabilityOutcome) -> Void
    ) -> Int {
        0
    }
}

private enum VoicePromptTestError: Error {
    case unexpectedCaptureJournalCall
}
