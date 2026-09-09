import AVFoundation
import Foundation

nonisolated protocol NativeAudioRecorderEngine: AnyObject {
    var currentTime: TimeInterval { get }
    func record(forDuration duration: TimeInterval) -> Bool
    func stop()
    @discardableResult func deleteRecording() -> Bool
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?)
}

nonisolated final class AVFoundationAudioRecorderEngine: NSObject, NativeAudioRecorderEngine, AVAudioRecorderDelegate, @unchecked Sendable {
    private let callbackQueue: DispatchQueue
    private let recorder: AVAudioRecorder
    private var recordingFinishedHandler: ((Bool) -> Void)?

    init(recorder: AVAudioRecorder, callbackQueue: DispatchQueue) {
        self.callbackQueue = callbackQueue
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
        callbackQueue.async { self.recordingFinishedHandler?(flag) }
    }
}


nonisolated final class AVCaptureAudioRecorderEngine: NSObject, NativeAudioRecorderEngine, @unchecked Sendable {
    private let callbackQueue: DispatchQueue
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
        callbackQueue: DispatchQueue,
        fileManager: FileManager = .default,
        notificationCenter: NotificationCenter = .default
    ) throws {
        self.callbackQueue = callbackQueue
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
            queue: nil
        ) { [weak self] _ in
            guard let self else { return }
            self.callbackQueue.async { self.finishAfterDeviceDisconnect() }
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

nonisolated extension AVCaptureAudioRecorderEngine: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        callbackQueue.async { [self] in
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
}
