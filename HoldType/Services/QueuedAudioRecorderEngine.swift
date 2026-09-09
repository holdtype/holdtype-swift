import AVFoundation
import Foundation

/// The main-actor handle owns callbacks only. Every native audio operation and
/// native object lifetime belongs to the worker's serial queue.
@MainActor
final class QueuedAudioRecorderEngine: AudioRecorderEngine {
    private let worker: AudioRecorderWorker
    private var finished: ((Bool) -> Void)?

    init(outputFileURL: URL, settings: [String: Any], inputPreference: AudioInputPreference) {
        worker = AudioRecorderWorker(url: outputFileURL, settings: settings, preference: inputPreference)
    }

    var currentTime: TimeInterval {
        get async { await worker.duration() }
    }

    func record(forDuration duration: TimeInterval) async throws -> Bool {
        try await record(forDuration: duration, authorization: nil)
    }

    func record(forDuration duration: TimeInterval, authorization: RecordingStartAuthorization?) async throws -> Bool {
        try await worker.start(duration: duration, authorization: authorization) { [weak self] success in
            Task { @MainActor [weak self] in self?.finished?(success) }
        }
    }

    func stop() async { await worker.stop() }
    func deleteRecording() async -> Bool { await worker.delete() }
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) { finished = handler }
}

nonisolated private final class AudioRecorderWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.holdtype.audio-recorder", qos: .userInitiated)
    private let url: URL
    private let settings: [String: Any]
    private let preference: AudioInputPreference
    private var engine: (any NativeAudioRecorderEngine)?

    init(url: URL, settings: [String: Any], preference: AudioInputPreference) {
        self.url = url
        self.settings = settings
        self.preference = preference
    }

    func start(duration: TimeInterval, authorization: RecordingStartAuthorization?, finished: @escaping @Sendable (Bool) -> Void) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    DictationStartTiming.mark("audio_prepare")
                    let engine = try makeEngine()
                    self.engine = engine
                    engine.setRecordingFinishedHandler(finished)
                    guard authorization?.commitCapture() ?? true else {
                        engine.deleteRecording()
                        engine.stop()
                        throw CancellationError()
                    }
                    let result = engine.record(forDuration: duration)
                    DictationStartTiming.mark(result ? "audio_started" : "audio_failed")
                    continuation.resume(returning: result)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func duration() async -> TimeInterval {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.engine?.currentTime ?? 0) }
        }
    }

    func stop() async {
        await withCheckedContinuation { continuation in
            queue.async { self.engine?.stop(); continuation.resume() }
        }
    }

    func delete() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: self.engine?.deleteRecording() ?? true) }
        }
    }

    private func makeEngine() throws -> any NativeAudioRecorderEngine {
        if let deviceID = preference.deviceID {
            let discovery = AVCaptureDevice.DiscoverySession(
                deviceTypes: [.microphone], mediaType: .audio, position: .unspecified
            )
            guard let device = discovery.devices.first(where: {
                $0.uniqueID == deviceID && $0.isConnected && !$0.isSuspended
            }) else { throw AudioRecorderServiceError.selectedMicrophoneUnavailable }
            return try AVCaptureAudioRecorderEngine(device: device, outputFileURL: url, settings: settings, callbackQueue: queue)
        }
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        guard recorder.prepareToRecord() else { throw AudioRecorderServiceError.temporaryFileUnavailable }
        return AVFoundationAudioRecorderEngine(recorder: recorder, callbackQueue: queue)
    }

    deinit {
        let retainedEngine = engine
        queue.async { retainedEngine?.stop() }
    }
}
