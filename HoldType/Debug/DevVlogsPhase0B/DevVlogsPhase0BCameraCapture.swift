#if DEBUG
@preconcurrency import AVFoundation
import CoreMedia
import Foundation

struct DevVlogsPhase0BCameraCaptureRequest {
    let deviceUniqueID: String
    let outputFileURL: URL
    let setupTimeout: Duration
}

struct DevVlogsPhase0BCameraCaptureStart: Equatable {
    let requestMonotonicTime: TimeInterval
    let recordingStartMonotonicTime: TimeInterval
    let deviceClass: DevVlogsPhase0BDeviceClass
    let redactedDeviceLabel: String
}

struct DevVlogsPhase0BCameraCaptureArtifact: Equatable {
    let fileURL: URL
    let requestMonotonicTime: TimeInterval
    let recordingStartMonotonicTime: TimeInterval
    let firstFrameMonotonicTime: TimeInterval?
    let firstFramePresentationTime: TimeInterval?
    let recordingStopMonotonicTime: TimeInterval
}

enum DevVlogsPhase0BCameraCaptureError: Error, Equatable {
    case permissionRequired
    case permissionDenied
    case preferredDeviceDisconnected
    case preferredDeviceBusy
    case unsupportedCandidatePreset
    case videoInputUnavailable
    case movieOutputUnavailable
    case sampleOutputUnavailable
    case setupTimedOut
    case recordingFailed
    case disconnectedDuringCapture
    case runtimeFailure
    case notCapturing
}

protocol DevVlogsPhase0BCameraCapturing: AnyObject {
    func startCapture(
        _ request: DevVlogsPhase0BCameraCaptureRequest
    ) async throws -> DevVlogsPhase0BCameraCaptureStart
    func stopCapture() async throws -> DevVlogsPhase0BCameraCaptureArtifact
    func cancelCapture() async
}

@MainActor
final class DevVlogsPhase0BCameraCapture: NSObject, DevVlogsPhase0BCameraCapturing {
    private enum State {
        case idle
        case starting
        case capturing
        case stopping
        case terminal
    }

    private let session = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()
    private let sampleOutput = AVCaptureVideoDataOutput()
    private let sampleQueue = DispatchQueue.main
    private let sessionQueue = DispatchQueue(label: "app.holdtype.phase0b.camera-session")
    private let monotonicClock: () -> TimeInterval
    private var state = State.idle
    private var request: DevVlogsPhase0BCameraCaptureRequest?
    private var requestTime: TimeInterval?
    private var recordingStartTime: TimeInterval?
    private var firstFrameTime: TimeInterval?
    private var firstFramePresentationTime: TimeInterval?
    private var deviceClass = DevVlogsPhase0BDeviceClass.unknown
    private var redactedDeviceLabel = "camera"
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var stopContinuation: CheckedContinuation<Void, Error>?
    private var startTimeoutTask: Task<Void, Never>?
    private var stopTimeoutTask: Task<Void, Never>?
    private weak var configuredDevice: AVCaptureDevice?
    private var originalFormat: AVCaptureDevice.Format?
    private var originalMinimumFrameDuration: CMTime?
    private var originalMaximumFrameDuration: CMTime?
    private var observers: [NSObjectProtocol] = []

    init(monotonicClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.monotonicClock = monotonicClock
        super.init()
    }

    func startCapture(
        _ request: DevVlogsPhase0BCameraCaptureRequest
    ) async throws -> DevVlogsPhase0BCameraCaptureStart {
        guard state == .idle else {
            throw DevVlogsPhase0BCameraCaptureError.recordingFailed
        }
        state = .starting
        self.request = request
        requestTime = monotonicClock()

        do {
            let device = try selectedDevice(uniqueID: request.deviceUniqueID)
            try configureSession(device: device)
            installObservers(device: device)
            try await startSession(timeout: request.setupTimeout)
            try await awaitMovieStart(timeout: request.setupTimeout) {
                self.movieOutput.startRecording(to: request.outputFileURL, recordingDelegate: self)
            }
            state = .capturing
            return DevVlogsPhase0BCameraCaptureStart(
                requestMonotonicTime: requestTime ?? monotonicClock(),
                recordingStartMonotonicTime: recordingStartTime ?? monotonicClock(),
                deviceClass: deviceClass,
                redactedDeviceLabel: redactedDeviceLabel
            )
        } catch {
            try? await finishSession(timeout: request.setupTimeout)
            state = .terminal
            throw classify(error)
        }
    }

    func stopCapture() async throws -> DevVlogsPhase0BCameraCaptureArtifact {
        guard state == .capturing, let request, let requestTime, let recordingStartTime else {
            throw DevVlogsPhase0BCameraCaptureError.notCapturing
        }
        state = .stopping

        do {
            try await withCheckedThrowingContinuation { continuation in
                stopContinuation = continuation
                stopTimeoutTask = Task { @MainActor [weak self] in
                    do {
                        try await Task.sleep(for: request.setupTimeout)
                    } catch {
                        return
                    }
                    self?.resumeStop(
                        throwing: DevVlogsPhase0BCameraCaptureError.setupTimedOut
                    )
                }
                movieOutput.stopRecording()
            }
            let artifact = DevVlogsPhase0BCameraCaptureArtifact(
                fileURL: request.outputFileURL,
                requestMonotonicTime: requestTime,
                recordingStartMonotonicTime: recordingStartTime,
                firstFrameMonotonicTime: firstFrameTime,
                firstFramePresentationTime: firstFramePresentationTime,
                recordingStopMonotonicTime: monotonicClock()
            )
            try await finishSession(timeout: request.setupTimeout)
            state = .terminal
            return artifact
        } catch {
            try? await finishSession(timeout: request.setupTimeout)
            state = .terminal
            throw classify(error)
        }
    }

    func cancelCapture() async {
        if movieOutput.isRecording {
            movieOutput.stopRecording()
        }
        resumeStart(throwing: CancellationError())
        resumeStop(throwing: CancellationError())
        try? await finishSession(timeout: request?.setupTimeout ?? .seconds(30))
        state = .terminal
    }

    private func selectedDevice(uniqueID: String) throws -> AVCaptureDevice {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            throw DevVlogsPhase0BCameraCaptureError.permissionRequired
        case .denied, .restricted:
            throw DevVlogsPhase0BCameraCaptureError.permissionDenied
        @unknown default:
            throw DevVlogsPhase0BCameraCaptureError.permissionDenied
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = discovery.devices.first(where: { $0.uniqueID == uniqueID }) else {
            throw DevVlogsPhase0BCameraCaptureError.preferredDeviceDisconnected
        }
        guard device.isConnected else {
            throw DevVlogsPhase0BCameraCaptureError.preferredDeviceDisconnected
        }
        guard !device.isInUseByAnotherApplication else {
            throw DevVlogsPhase0BCameraCaptureError.preferredDeviceBusy
        }
        deviceClass = Self.deviceClass(for: device)
        redactedDeviceLabel = "\(deviceClass.rawValue)_camera"
        return device
    }

    private func configureSession(device: AVCaptureDevice) throws {
        try configureCandidateFrameRate(device: device)
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        guard session.canSetSessionPreset(.hd1280x720) else {
            throw DevVlogsPhase0BCameraCaptureError.unsupportedCandidatePreset
        }
        session.sessionPreset = .hd1280x720

        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else {
            throw DevVlogsPhase0BCameraCaptureError.videoInputUnavailable
        }
        session.addInput(input)
        movieOutput.movieFragmentInterval = CMTime(seconds: 10, preferredTimescale: 600)
        guard session.canAddOutput(movieOutput) else {
            throw DevVlogsPhase0BCameraCaptureError.movieOutputUnavailable
        }
        session.addOutput(movieOutput)
        sampleOutput.alwaysDiscardsLateVideoFrames = true
        sampleOutput.setSampleBufferDelegate(self, queue: sampleQueue)
        guard session.canAddOutput(sampleOutput) else {
            throw DevVlogsPhase0BCameraCaptureError.sampleOutputUnavailable
        }
        session.addOutput(sampleOutput)
    }

    private func startSession(timeout: Duration) async throws {
        let session = self.session
        let sessionQueue = self.sessionQueue
        try await withCheckedThrowingContinuation { continuation in
            let gate = DevVlogsPhase0BContinuationGate(continuation: continuation)
            sessionQueue.async {
                session.startRunning()
                let result: Result<Void, Error> = session.isRunning
                    ? .success(())
                    : .failure(DevVlogsPhase0BCameraCaptureError.runtimeFailure)
                if !gate.resume(with: result), session.isRunning {
                    session.stopRunning()
                }
            }
            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return
                }
                _ = gate.resume(
                    with: .failure(DevVlogsPhase0BCameraCaptureError.setupTimedOut)
                )
            }
            gate.installTimeoutTask(timeoutTask)
        }
    }

    private func awaitMovieStart(timeout: Duration, begin: () -> Void) async throws {
        try await withCheckedThrowingContinuation { continuation in
            startContinuation = continuation
            startTimeoutTask = Task { @MainActor [weak self] in
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return
                }
                self?.resumeStart(
                    throwing: DevVlogsPhase0BCameraCaptureError.setupTimedOut
                )
            }
            begin()
        }
    }

    private func installObservers(device: AVCaptureDevice) {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: AVCaptureDevice.wasDisconnectedNotification, object: device, queue: .main) {
                [weak self] _ in
                MainActor.assumeIsolated {
                    self?.failActiveCapture(with: .disconnectedDuringCapture)
                }
            },
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main) {
                [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.failActiveCapture(with: self.classify(notification))
                }
            },
        ]
    }

    private func failActiveCapture(with error: DevVlogsPhase0BCameraCaptureError) {
        resumeStart(throwing: error)
        resumeStop(throwing: error)
    }

    private func finishSession(timeout: Duration) async throws {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        sampleOutput.setSampleBufferDelegate(nil, queue: nil)
        try await stopSession(timeout: timeout)
        restoreDeviceConfiguration()
    }

    private func stopSession(timeout: Duration) async throws {
        let session = self.session
        let sessionQueue = self.sessionQueue
        try await withCheckedThrowingContinuation { continuation in
            let gate = DevVlogsPhase0BContinuationGate(continuation: continuation)
            sessionQueue.async {
                if session.isRunning {
                    session.stopRunning()
                }
                _ = gate.resume(with: .success(()))
            }
            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return
                }
                _ = gate.resume(
                    with: .failure(DevVlogsPhase0BCameraCaptureError.setupTimedOut)
                )
            }
            gate.installTimeoutTask(timeoutTask)
        }
    }

    private func resumeStart(throwing error: Error? = nil) {
        guard let continuation = startContinuation else { return }
        startContinuation = nil
        startTimeoutTask?.cancel()
        startTimeoutTask = nil
        error.map { continuation.resume(throwing: $0) } ?? continuation.resume()
    }

    private func resumeStop(throwing error: Error? = nil) {
        guard let continuation = stopContinuation else { return }
        stopContinuation = nil
        stopTimeoutTask?.cancel()
        stopTimeoutTask = nil
        error.map { continuation.resume(throwing: $0) } ?? continuation.resume()
    }

    private func configureCandidateFrameRate(device: AVCaptureDevice) throws {
        let dimensions = CMVideoDimensions(width: 1_280, height: 720)
        guard let format = device.formats.first(where: { format in
            let formatDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription)
            return formatDimensions.width == dimensions.width
                && formatDimensions.height == dimensions.height
                && format.videoSupportedFrameRateRanges.contains { range in
                    range.minFrameRate <= 30 && range.maxFrameRate >= 30
                }
        }) else {
            throw DevVlogsPhase0BCameraCaptureError.unsupportedCandidatePreset
        }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        configuredDevice = device
        originalFormat = device.activeFormat
        originalMinimumFrameDuration = device.activeVideoMinFrameDuration
        originalMaximumFrameDuration = device.activeVideoMaxFrameDuration
        device.activeFormat = format
        let frameDuration = CMTime(value: 1, timescale: 30)
        device.activeVideoMinFrameDuration = frameDuration
        device.activeVideoMaxFrameDuration = frameDuration
    }

    private func restoreDeviceConfiguration() {
        guard let device = configuredDevice, let originalFormat else { return }
        do {
            try device.lockForConfiguration()
            device.activeFormat = originalFormat
            if let originalMinimumFrameDuration {
                device.activeVideoMinFrameDuration = originalMinimumFrameDuration
            }
            if let originalMaximumFrameDuration {
                device.activeVideoMaxFrameDuration = originalMaximumFrameDuration
            }
            device.unlockForConfiguration()
        } catch {
            // Debug evidence records terminal media truth; restoration failure is not retried here.
        }
        configuredDevice = nil
        self.originalFormat = nil
        originalMinimumFrameDuration = nil
        originalMaximumFrameDuration = nil
    }

    private func classify(_ error: Error) -> DevVlogsPhase0BCameraCaptureError {
        if let captureError = error as? DevVlogsPhase0BCameraCaptureError { return captureError }
        let nsError = error as NSError
        switch nsError.code {
        case AVError.deviceWasDisconnected.rawValue, AVError.deviceNotConnected.rawValue:
            return .disconnectedDuringCapture
        case AVError.deviceInUseByAnotherApplication.rawValue,
             AVError.deviceAlreadyUsedByAnotherSession.rawValue,
             AVError.deviceLockedForConfigurationByAnotherProcess.rawValue:
            return .preferredDeviceBusy
        default:
            return .recordingFailed
        }
    }

    private func classify(_ notification: Notification) -> DevVlogsPhase0BCameraCaptureError {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error else {
            return .runtimeFailure
        }
        return classify(error)
    }

    private static func deviceClass(for device: AVCaptureDevice) -> DevVlogsPhase0BDeviceClass {
        if device.isContinuityCamera { return .continuity }
        if device.deviceType == .external { return .external }
        if device.deviceType == .builtInWideAngleCamera { return .builtIn }
        return .unknown
    }
}

private final class DevVlogsPhase0BContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func installTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        if continuation == nil {
            lock.unlock()
            task.cancel()
            return
        }
        timeoutTask = task
        lock.unlock()
    }

    @discardableResult
    func resume(with result: Result<Void, Error>) -> Bool {
        lock.lock()
        guard let continuation else {
            lock.unlock()
            return false
        }
        self.continuation = nil
        let timeoutTask = self.timeoutTask
        self.timeoutTask = nil
        lock.unlock()
        timeoutTask?.cancel()
        continuation.resume(with: result)
        return true
    }
}

extension DevVlogsPhase0BCameraCapture: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        recordingStartTime = monotonicClock()
        resumeStart()
    }

    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error { resumeStop(throwing: error) } else { resumeStop() }
    }
}

extension DevVlogsPhase0BCameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard firstFrameTime == nil, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        firstFrameTime = monotonicClock()
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        if timestamp.isValid, timestamp.isNumeric {
            firstFramePresentationTime = timestamp.seconds
        }
    }
}
#endif
