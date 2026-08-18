import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct DictationSessionControllerDevVlogsTests {
    @Test func vlogFailureStateDoesNotChangeDictationProviderOrOutput() async throws {
        let recorder = FakeAudioRecorderService()
        let transcription = DevVlogsControllerTranscriptionFake()
        let output = DevVlogsControllerOutputFake()
        let vlog = DevVlogsCaptureCoordinatorSpy(failOnFinish: true)
        let controller = DictationSessionController(
            recorder: recorder,
            transcriptionService: transcription,
            settingsProvider: { .defaults },
            transcriptOutput: output,
            transcriptionFailureRecovery: FakeTranscriptionFailureRecovery(),
            recordingStopTailSleeper: DevVlogsControllerStopTailSleeper(),
            credentialResolverForUngatedActions: DevVlogsControllerCredentialResolver(),
            devVlogsCapture: vlog,
            voiceWorkReservation: VoiceWorkReservation()
        )

        await controller.performRecordingAction()
        await controller.performRecordingAction()

        #expect(vlog.beginCount == 1)
        #expect(vlog.didStartCount == 1)
        #expect(vlog.finishCount == 1)
        #expect(recorder.startCount == 1)
        #expect(recorder.stopCount == 1)
        #expect(transcription.callCount == 1)
        #expect(output.transcripts == ["ordinary transcript"])
        #expect(controller.status == .success(transcript: "ordinary transcript"))
    }

    @Test func recorderStartFailureTerminatesOnlyTheVlogAttempt() async {
        let recorder = FakeAudioRecorderService(
            startResult: .failure(.startFailed)
        )
        let vlog = DevVlogsCaptureCoordinatorSpy()
        let controller = DictationSessionController(
            recorder: recorder,
            transcriptionService: DevVlogsControllerTranscriptionFake(),
            settingsProvider: { .defaults },
            transcriptOutput: DevVlogsControllerOutputFake(),
            transcriptionFailureRecovery: FakeTranscriptionFailureRecovery(),
            recordingStopTailSleeper: DevVlogsControllerStopTailSleeper(),
            credentialResolverForUngatedActions: DevVlogsControllerCredentialResolver(),
            devVlogsCapture: vlog,
            voiceWorkReservation: VoiceWorkReservation()
        )

        await controller.performRecordingAction()

        #expect(vlog.beginCount == 1)
        #expect(vlog.didStartCount == 0)
        #expect(vlog.finishCount == 0)
        #expect(vlog.endReasons == [.dictationDidNotComplete])
        #expect(recorder.startCount == 1)
    }
}

@MainActor
private final class DevVlogsCaptureCoordinatorSpy: DevVlogsCaptureCoordinating {
    private(set) var state: DevVlogsCaptureState = .idle
    private(set) var beginCount = 0
    private(set) var didStartCount = 0
    private(set) var finishCount = 0
    private(set) var endReasons: [DevVlogsCaptureSkipReason] = []
    private(set) var disableCount = 0
    private let failOnFinish: Bool

    init(failOnFinish: Bool = false) {
        self.failOnFinish = failOnFinish
    }

    func beginAttempt() async { beginCount += 1 }
    func dictationDidStart() { didStartCount += 1 }
    func finishAttempt(audioArtifact: AudioRecordingArtifact) async {
        finishCount += 1
        if failOnFinish {
            state = .failed(attemptID: UUID(), message: "vlog failed")
        }
    }
    func endAttemptWithoutAudio(reason: DevVlogsCaptureSkipReason) {
        endReasons.append(reason)
    }
    func featureDidDisable() { disableCount += 1 }
}

@MainActor
private final class DevVlogsControllerTranscriptionFake: OpenAITranscriptionServing {
    private(set) var callCount = 0
    func transcribe(
        _ request: AudioTranscriptionRequest,
        credential: OpenAICredential
    ) async throws -> String {
        callCount += 1
        return "ordinary transcript"
    }
}

@MainActor
private final class DevVlogsControllerOutputFake: TranscriptOutputDelivering {
    private(set) var transcripts: [String] = []
    func deliver(_ request: OutputDeliveryRequest) async throws -> TextInsertionResult {
        transcripts.append(request.acceptedTranscript.text)
        return .skipped(reason: .appClipboardDisabled)
    }
}

private struct DevVlogsControllerStopTailSleeper: RecordingStopTailSleeping {
    func sleep(seconds: TimeInterval) async throws {}
}

private struct DevVlogsControllerCredentialResolver: OpenAICredentialResolving {
    func resolveOpenAICredential() throws -> OpenAICredential {
        try OpenAICredential(apiKey: "sk-dev-vlogs-test")
    }
}
