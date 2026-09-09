import AVFoundation
import Foundation

protocol AudioRecorderEngine: AnyObject {
    var currentTime: TimeInterval { get async }

    func record(forDuration duration: TimeInterval) async throws -> Bool
    func record(forDuration duration: TimeInterval, authorization: RecordingStartAuthorization?) async throws -> Bool
    func stop() async
    @discardableResult func deleteRecording() async -> Bool
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?)
}

protocol AudioRecorderEngineFactory {
    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any]
    ) throws -> any AudioRecorderEngine
    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any],
        inputPreference: AudioInputPreference
    ) throws -> any AudioRecorderEngine
}

extension AudioRecorderEngineFactory {
    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any],
        inputPreference: AudioInputPreference
    ) throws -> any AudioRecorderEngine {
        try makeRecorder(outputFileURL: outputFileURL, settings: settings)
    }
}

struct AVFoundationAudioRecorderEngineFactory: AudioRecorderEngineFactory {
    func makeRecorder(outputFileURL: URL, settings: [String: Any]) throws -> any AudioRecorderEngine {
        try makeRecorder(outputFileURL: outputFileURL, settings: settings, inputPreference: .systemDefault)
    }

    func makeRecorder(
        outputFileURL: URL, settings: [String: Any], inputPreference: AudioInputPreference
    ) throws -> any AudioRecorderEngine {
        QueuedAudioRecorderEngine(outputFileURL: outputFileURL, settings: settings, inputPreference: inputPreference)
    }
}

extension AudioRecorderEngine {
    func record(forDuration duration: TimeInterval, authorization: RecordingStartAuthorization?) async throws -> Bool {
        guard authorization?.commitCapture() ?? true else { throw CancellationError() }
        return try await record(forDuration: duration)
    }
}
