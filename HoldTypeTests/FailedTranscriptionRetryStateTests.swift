import Foundation
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct FailedTranscriptionRetryStateTests {
    @Test func malformedRecordingDoesNotStartRetry() async throws {
        let fixture = try makeFixture(named: "malformed-retry")
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }
        try Data("This is not audio.".utf8).write(to: fixture.audioURL)
        let attempt = FailedTranscriptionAttempt(
            audioFileURL: fixture.audioURL,
            audioDuration: 12,
            transcriptionModel: "gpt-transcribe",
            languageCode: nil,
            reason: .networkUnavailable
        )
        let recovery = FakeTranscriptionFailureRecovery(initialAttempts: [attempt])
        let service = RetryStateTranscriptionService(result: .success("must not run"))
        let controller = DictationSessionController(
            transcriptionService: service,
            settingsProvider: { .defaults },
            transcriptionFailureRecovery: recovery
        )

        await controller.retryFailedTranscription(
            id: attempt.id,
            credential: try OpenAICredential(apiKey: "test-key")
        )

        #expect(service.callCount == 0)
        #expect(controller.status == .failure(message: FailedTranscriptionReason.invalidRecording.message))
        #expect(controller.failurePresentation?.title == "Recording unavailable")
        #expect(controller.failurePresentation?.canRetry == false)
        #expect(recovery.failedAttempts.first?.state == .failed)
        #expect(recovery.failedAttempts.first?.reason == .invalidRecording)
    }

    @Test func invalidRecordingFailureAfterTranscribeAgainIsTerminalBeforeAndAfterDismiss() async throws {
        let fixture = try makeFixture(named: "duplicate-retry")
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }
        try validWAVFixture.write(to: fixture.audioURL)
        let attempt = FailedTranscriptionAttempt(
            audioFileURL: fixture.audioURL,
            audioDuration: 12,
            transcriptionModel: "gpt-transcribe",
            languageCode: nil,
            state: .failed,
            reason: .providerOutcomeUncertain
        )
        let recovery = FakeTranscriptionFailureRecovery(initialAttempts: [attempt])
        let service = RetryStateTranscriptionService(
            result: .failure(.invalidRecording(.unreadableAudioFile(fixture.audioURL)))
        )
        let controller = DictationSessionController(
            transcriptionService: service,
            settingsProvider: { .defaults },
            transcriptionFailureRecovery: recovery
        )

        await controller.retryFailedTranscription(
            id: attempt.id,
            credential: try OpenAICredential(apiKey: "test-key"),
            authorization: .confirmedDuplicateSubmission
        )

        #expect(service.callCount == 1)
        #expect(recovery.failedAttempts.first?.state == .failed)
        #expect(recovery.failedAttempts.first?.reason == .invalidRecording)
        #expect(recovery.failedAttempts.first?.retryCount == 1)
        #expect(controller.status == .failure(message: FailedTranscriptionReason.invalidRecording.message))

        controller.dismissFailurePresentation()

        #expect(controller.status == .idle)
        #expect(controller.failurePresentation == nil)
        #expect(recovery.failedAttempts.first?.state == .failed)
        #expect(recovery.failedAttempts.first?.reason == .invalidRecording)
    }

    @Test func failClosedStoreAcceptsInvalidRecordingAsTerminalState() throws {
        let fixture = try makeFixture(named: "fail-closed-store")
        defer { try? FileManager.default.removeItem(at: fixture.directoryURL) }
        try validWAVFixture.write(to: fixture.audioURL)
        let store = TranscriptionFailureRecoveryStore(
            directoryURL: fixture.directoryURL.appendingPathComponent("Recovery", isDirectory: true)
        )
        let checkpoint = try store.recordProcessingCheckpoint(
            audioFileURL: fixture.audioURL,
            settings: .defaults,
            audioDuration: 12
        )
        try store.sealProviderDispatch(id: checkpoint.id)
        store.markProviderOutcomeUncertain(id: checkpoint.id)
        try store.beginConfirmedDuplicateRetry(id: checkpoint.id)

        #expect(store.failedAttempts.first?.state == .processing)

        try store.updateFailedAttempt(id: checkpoint.id, reason: .invalidRecording)

        #expect(store.failedAttempts.first?.state == .failed)
        #expect(store.failedAttempts.first?.reason == .invalidRecording)
    }

    private func makeFixture(named name: String) throws -> (directoryURL: URL, audioURL: URL) {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return (directoryURL, directoryURL.appendingPathComponent("recording.m4a"))
    }

    private var validWAVFixture: Data {
        Data([
            0x52, 0x49, 0x46, 0x46, 0x26, 0x00, 0x00, 0x00,
            0x57, 0x41, 0x56, 0x45, 0x66, 0x6D, 0x74, 0x20,
            0x10, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01, 0x00,
            0x40, 0x1F, 0x00, 0x00, 0x80, 0x3E, 0x00, 0x00,
            0x02, 0x00, 0x10, 0x00, 0x64, 0x61, 0x74, 0x61,
            0x02, 0x00, 0x00, 0x00, 0x00, 0x00,
        ])
    }
}

private final class RetryStateTranscriptionService: OpenAITranscriptionServing {
    private let result: Result<String, OpenAITranscriptionServiceError>
    private(set) var callCount = 0

    init(result: Result<String, OpenAITranscriptionServiceError>) {
        self.result = result
    }

    func transcribe(
        _ request: AudioTranscriptionRequest,
        credential: OpenAICredential
    ) async throws -> String {
        callCount += 1
        return try result.get()
    }
}
