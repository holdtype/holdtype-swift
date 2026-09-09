import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct DictationStartResponsivenessTests {
    @Test func releaseBeforeCommitCannotStartCapture() {
        let permission = RecordingStartAuthorization()
        permission.release()
        #expect(!permission.commitCapture())
        #expect(!permission.hasCommittedCapture)
    }

    @Test func releaseAfterCommitPreservesCaptureOwnership() {
        let permission = RecordingStartAuthorization()
        #expect(permission.commitCapture())
        permission.release()
        #expect(permission.hasCommittedCapture)
        #expect(!permission.isRequested)
    }

    @Test func slowCameraDoesNotGateMicrophoneAndLateCompletionCannotEndNextAttempt() async throws {
        let camera = DelayedVlog()
        let recorder = FakeAudioRecorderService()
        let controller = DictationSessionController(
            recorder: recorder, devVlogsCapture: camera, voiceWorkReservation: VoiceWorkReservation()
        )
        let credential = try OpenAICredential(apiKey: "test-only")
        await controller.performRecordingAction(credential: credential)
        #expect(controller.status == .recording)
        #expect(recorder.startCount == 1)
        for _ in 0..<20 { await Task.yield() }
        #expect(camera.isPreparing)
        await controller.cancelRecording()
        let ends = camera.ends
        camera.releasePreparation()
        for _ in 0..<20 { await Task.yield() }
        #expect(camera.ends == ends)
        #expect(controller.status == .idle)
    }

    @Test func discardSerializesAgainstAnotherRecordingAction() async throws {
        let recorder = DelayedDiscardRecorder()
        let controller = DictationSessionController(recorder: recorder,
            devVlogsCapture: ImmediateVlog(), voiceWorkReservation: VoiceWorkReservation())
        let credential = try OpenAICredential(apiKey: "test-only")
        await controller.performRecordingAction(credential: credential)
        let discard = Task { @MainActor in await controller.cancelRecording() }
        for _ in 0..<100 where recorder.continuation == nil { await Task.yield() }
        #expect(recorder.continuation != nil)
        await controller.performRecordingAction(credential: credential)
        #expect(recorder.stops == 0)
        recorder.continuation?.resume()
        await discard.value
        #expect(controller.status == .idle)
    }

    @Test func cancelReleasesAuthorizationWhileNativePreparationIsPending() async throws {
        let engine = DelayedStartEngine()
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: DelayedStartEngineFactory(engine: engine),
            makeRecordingFileURL: { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
        )
        let start = Task { @MainActor in try await recorder.startRecording() }
        for _ in 0..<100 where engine.continuation == nil { await Task.yield() }
        #expect(engine.continuation != nil)
        await recorder.cancelRecording()
        engine.continuation?.resume()
        await #expect(throws: CancellationError.self) { try await start.value }
        #expect(!engine.didCapture)
        #expect(recorder.currentStatus == .cancelled)
    }

    @Test func backgroundJournalRetainsTheSameDurableIdentityThroughRelease() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let journal = RecordingCaptureJournal(
            directoryURL: root.appendingPathComponent("active", isDirectory: true),
            releasedDirectoryURL: root.appendingPathComponent("released", isDirectory: true)
        )
        let lease = try await journal.prepareCaptureForStart(settings: .defaults, maximumDuration: 300)
        let bytes = Data("retained audio fixture".utf8)
        try bytes.write(to: lease.audioFileURL)
        let released = try journal.releaseCapture(lease,
            artifact: AudioRecordingArtifact(fileURL: lease.audioFileURL, duration: 2, byteCount: Int64(bytes.count)),
            recoveryAttemptID: UUID())
        #expect(try Data(contentsOf: released.fileURL) == bytes)
        #expect(!FileManager.default.fileExists(atPath: lease.audioFileURL.path))
    }

    @Test func releasedStartAfterJournalDoesNotReachRecorder() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let recorder = PreparedRecorder()
        let authorization = RecordingStartAuthorization()
        authorization.release()
        let controller = DictationSessionController(
            recorder: recorder,
            recordingCaptureJournal: RecordingCaptureJournal(directoryURL: directory),
            voiceWorkReservation: VoiceWorkReservation()
        )
        await controller.performRecordingAction(
            credential: try OpenAICredential(apiKey: "test-only"), authorization: authorization
        )
        #expect(recorder.starts == 0)
        #expect(controller.status == .idle)
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }
}

@MainActor
private final class DelayedVlog: DevVlogsCaptureCoordinating {
    var state: DevVlogsCaptureState = .idle
    var isPreparing = false
    var ends = 0
    var continuation: CheckedContinuation<Void, Never>?
    func beginAttempt() async {
        isPreparing = true
        await withCheckedContinuation { continuation = $0 }
    }
    func releasePreparation() { continuation?.resume(); continuation = nil }
    func dictationDidStart() {}
    func finishAttempt(audioArtifact: AudioRecordingArtifact) async {}
    func endAttemptWithoutAudio(reason: DevVlogsCaptureSkipReason) { ends += 1 }
    func featureDidDisable() {}
}

@MainActor
private final class PreparedRecorder: AudioRecorderService {
    var currentStatus: AudioRecorderStatus = .idle
    let acceptsPreparedRecordingFileURL = true
    var starts = 0
    func startRecording(maximumDuration: TimeInterval) async throws { starts += 1 }
    func stopRecording() async throws -> AudioRecordingArtifact { throw AudioRecorderServiceError.notRecording }
    func cancelRecording() {}
}

@MainActor
private final class DelayedDiscardRecorder: AudioRecorderService {
    var currentStatus: AudioRecorderStatus = .idle
    var continuation: CheckedContinuation<Void, Never>?
    var stops = 0
    func startRecording(maximumDuration: TimeInterval) async throws { currentStatus = .recording }
    func stopRecording() async throws -> AudioRecordingArtifact {
        stops += 1
        throw AudioRecorderServiceError.notRecording
    }
    func cancelRecording() async {
        await withCheckedContinuation { continuation = $0 }
        currentStatus = .cancelled
    }
}

@MainActor
private final class ImmediateVlog: DevVlogsCaptureCoordinating {
    var state: DevVlogsCaptureState = .idle
    func beginAttempt() async {}
    func dictationDidStart() {}
    func finishAttempt(audioArtifact: AudioRecordingArtifact) async {}
    func endAttemptWithoutAudio(reason: DevVlogsCaptureSkipReason) {}
    func featureDidDisable() {}
}

@MainActor
private final class DelayedStartEngine: AudioRecorderEngine {
    var currentTime: TimeInterval { 0 }
    var continuation: CheckedContinuation<Void, Never>?
    var didCapture = false
    func record(forDuration duration: TimeInterval) async throws -> Bool { false }
    func record(forDuration duration: TimeInterval, authorization: RecordingStartAuthorization?) async throws -> Bool {
        await withCheckedContinuation { continuation = $0 }
        guard authorization?.commitCapture() == true else { throw CancellationError() }
        didCapture = true
        return true
    }
    func stop() {}
    func deleteRecording() -> Bool { true }
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) {}
}

private struct DelayedStartEngineFactory: AudioRecorderEngineFactory {
    let engine: DelayedStartEngine
    func makeRecorder(outputFileURL: URL, settings: [String: Any]) throws -> any AudioRecorderEngine { engine }
}
