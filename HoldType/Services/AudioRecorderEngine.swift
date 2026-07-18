import AVFoundation
import Foundation

protocol AudioRecorderEngine: AnyObject {
    var currentTime: TimeInterval { get }

    func record(forDuration duration: TimeInterval) -> Bool
    func stop()
    @discardableResult func deleteRecording() -> Bool
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?)
}

private final class AVFoundationAudioRecorderEngine: NSObject, AudioRecorderEngine, AVAudioRecorderDelegate {
    private let recorder: AVAudioRecorder
    private var recordingFinishedHandler: ((Bool) -> Void)?

    init(recorder: AVAudioRecorder) {
        self.recorder = recorder
        super.init()
        recorder.delegate = self
    }

    var currentTime: TimeInterval {
        recorder.currentTime
    }

    func record(forDuration duration: TimeInterval) -> Bool {
        recorder.record(forDuration: duration)
    }

    func stop() {
        recorder.stop()
    }

    func deleteRecording() -> Bool {
        recorder.deleteRecording()
    }

    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) {
        recordingFinishedHandler = handler
    }

    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        recordingFinishedHandler?(flag)
    }
}

protocol AudioRecorderEngineFactory {
    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any]
    ) throws -> any AudioRecorderEngine
}

struct AVFoundationAudioRecorderEngineFactory: AudioRecorderEngineFactory {
    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any]
    ) throws -> any AudioRecorderEngine {
        let recorder = try AVAudioRecorder(url: outputFileURL, settings: settings)

        guard recorder.prepareToRecord() else {
            throw AudioRecorderServiceError.temporaryFileUnavailable
        }

        return AVFoundationAudioRecorderEngine(recorder: recorder)
    }
}
