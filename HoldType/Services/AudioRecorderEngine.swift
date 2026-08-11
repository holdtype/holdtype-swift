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

    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any],
        inputPreference: AudioInputPreference
    ) throws -> any AudioRecorderEngine {
        guard let deviceID = inputPreference.deviceID else {
            return try makeRecorder(outputFileURL: outputFileURL, settings: settings)
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone],
            mediaType: .audio,
            position: .unspecified
        )
        guard let device = discovery.devices.first(where: {
            $0.uniqueID == deviceID && $0.isConnected && !$0.isSuspended
        }) else {
            throw AudioRecorderServiceError.selectedMicrophoneUnavailable
        }

        return try AVCaptureAudioRecorderEngine(
            device: device,
            outputFileURL: outputFileURL,
            settings: settings
        )
    }
}

private final class AVCaptureAudioRecorderEngine: NSObject, AudioRecorderEngine {
    private let captureSession = AVCaptureSession()
    private let audioOutput = AVCaptureAudioFileOutput()
    private let device: AVCaptureDevice
    private let outputFileURL: URL
    private let fileManager: FileManager
    private let notificationCenter: NotificationCenter
    private var recordingFinishedHandler: ((Bool) -> Void)?
    private var disconnectObserver: NSObjectProtocol?
    private var deleteWhenFinished = false
    private var retainedWhileFinishing: AVCaptureAudioRecorderEngine?

    init(
        device: AVCaptureDevice,
        outputFileURL: URL,
        settings: [String: Any],
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default
    ) throws {
        self.device = device
        self.outputFileURL = outputFileURL
        self.fileManager = fileManager
        self.notificationCenter = notificationCenter
        super.init()

        let input = try AVCaptureDeviceInput(device: device)
        captureSession.beginConfiguration()
        guard captureSession.canAddInput(input), captureSession.canAddOutput(audioOutput) else {
            captureSession.commitConfiguration()
            throw AudioRecorderServiceError.recordingUnavailable
        }
        captureSession.addInput(input)
        audioOutput.audioSettings = settings
        captureSession.addOutput(audioOutput)
        captureSession.commitConfiguration()

        disconnectObserver = notificationCenter.addObserver(
            forName: AVCaptureDevice.wasDisconnectedNotification,
            object: device,
            queue: .main
        ) { [weak self] _ in
            self?.finishAfterDeviceDisconnect()
        }

        captureSession.startRunning()
        guard captureSession.isRunning else {
            throw AudioRecorderServiceError.startFailed
        }
    }

    deinit {
        if let disconnectObserver {
            notificationCenter.removeObserver(disconnectObserver)
        }
        captureSession.stopRunning()
    }

    var currentTime: TimeInterval {
        audioOutput.recordedDuration.seconds
    }

    func record(forDuration duration: TimeInterval) -> Bool {
        guard captureSession.isRunning,
              !audioOutput.isRecording,
              !fileManager.fileExists(atPath: outputFileURL.path),
              AVCaptureAudioFileOutput.availableOutputFileTypes().contains(.m4a) else {
            return false
        }

        audioOutput.maxRecordedDuration = CMTime(
            seconds: duration,
            preferredTimescale: 600
        )
        retainedWhileFinishing = self
        audioOutput.startRecording(
            to: outputFileURL,
            outputFileType: .m4a,
            recordingDelegate: self
        )
        guard audioOutput.isRecording else {
            retainedWhileFinishing = nil
            return false
        }
        return true
    }

    func stop() {
        guard audioOutput.isRecording else {
            return
        }
        audioOutput.stopRecording()
    }

    func deleteRecording() -> Bool {
        deleteWhenFinished = true
        return removeOutputFileIfPresent()
    }

    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) {
        recordingFinishedHandler = handler
    }

    private func finishAfterDeviceDisconnect() {
        guard audioOutput.isRecording else {
            return
        }
        audioOutput.stopRecording()
    }

    private func removeOutputFileIfPresent() -> Bool {
        guard fileManager.fileExists(atPath: outputFileURL.path) else {
            return true
        }

        do {
            try fileManager.removeItem(at: outputFileURL)
            return true
        } catch {
            return false
        }
    }
}

extension AVCaptureAudioRecorderEngine: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        captureSession.stopRunning()
        if deleteWhenFinished {
            _ = removeOutputFileIfPresent()
        }

        let recordedSuccessfully = error.map {
            ($0 as NSError).userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool ?? false
        } ?? true
        recordingFinishedHandler?(recordedSuccessfully)
        retainedWhileFinishing = nil
    }
}
