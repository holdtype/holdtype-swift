#if DEBUG
@preconcurrency import AVFoundation
import CoreMedia
import Foundation
struct DevVlogsPhase0BCameraCaptureRequest {
    let deviceUniqueID: String, outputFileURL: URL
    let setupTimeout: Duration
}
struct DevVlogsPhase0BCameraCaptureStart: Equatable {
    let requestMonotonicTime: TimeInterval, recordingStartMonotonicTime: TimeInterval
    let deviceClass: DevVlogsPhase0BDeviceClass, redactedDeviceLabel: String
}
struct DevVlogsPhase0BCameraCaptureArtifact: Equatable {
    let fileURL: URL
    let requestMonotonicTime: TimeInterval, recordingStartMonotonicTime: TimeInterval
    let firstFrameMonotonicTime: TimeInterval?, firstFramePresentationTime: TimeInterval?
    let recordingStopMonotonicTime: TimeInterval
}
enum DevVlogsPhase0BCameraCaptureError: Error, Equatable {
    case permissionRequired, permissionDenied
    case preferredDeviceDisconnected, deviceUnavailableDuringStart, preferredDeviceBusy
    case videoInputUnavailable
    case movieOutputUnavailable, sampleOutputUnavailable
    case setupTimedOut, firstFrameUnavailable, recordingFailed
    case disconnectedDuringCapture, runtimeFailure, unknownPlatformFailure, notCapturing
}
enum DevVlogsPhase0BCameraFailureContext: Equatable { case starting, steadyCapture }
struct DevVlogsPhase0BCameraStartEvidence: Equatable {
    enum Resolution: Equatable { case pending, ready, failed(DevVlogsPhase0BCameraCaptureError) }
    private(set) var recordingStartTime: TimeInterval?, firstFrameTime: TimeInterval?
    private(set) var firstFramePresentationTime: TimeInterval?
    private(set) var resolution = Resolution.pending
    var failure: DevVlogsPhase0BCameraCaptureError? {
        if case .failed(let error) = resolution { error } else { nil }
    }
    mutating func recordingDidStart(at time: TimeInterval) {
        guard resolution == .pending, recordingStartTime == nil else { return }
        recordingStartTime = time
        resolveIfReady()
    }
    mutating func firstFrameDidArrive(at time: TimeInterval, presentationTime: TimeInterval?) {
        guard resolution == .pending, firstFrameTime == nil else { return }
        firstFrameTime = time
        firstFramePresentationTime = presentationTime
        resolveIfReady()
    }
    mutating func fail(_ error: DevVlogsPhase0BCameraCaptureError) {
        guard resolution == .pending else { return }
        resolution = .failed(error)
    }
    mutating func timeout() { fail(recordingStartTime == nil ? .setupTimedOut : .firstFrameUnavailable) }
    private mutating func resolveIfReady() {
        if recordingStartTime != nil, firstFrameTime != nil { resolution = .ready }
    }
}
extension DevVlogsPhase0BCameraCaptureError {
    static func classifyPlatformError(
        _ error: Error,
        context: DevVlogsPhase0BCameraFailureContext
    ) -> Self {
        if let captureError = error as? Self {
            if context == .starting, captureError == .disconnectedDuringCapture { return .deviceUnavailableDuringStart }
            return captureError
        }
        let platformError = error as NSError
        guard platformError.domain == AVFoundationErrorDomain else { return .unknownPlatformFailure }
        switch platformError.code {
        case AVError.applicationIsNotAuthorized.rawValue,
             AVError.applicationIsNotAuthorizedToUseDevice.rawValue:
            return .permissionDenied
        case AVError.deviceWasDisconnected.rawValue, AVError.deviceNotConnected.rawValue:
            return context == .starting ? .deviceUnavailableDuringStart : .disconnectedDuringCapture
        case AVError.deviceInUseByAnotherApplication.rawValue,
             AVError.deviceAlreadyUsedByAnotherSession.rawValue,
             AVError.deviceLockedForConfigurationByAnotherProcess.rawValue:
            return .preferredDeviceBusy
        default: return .unknownPlatformFailure
        }
    }
}
protocol DevVlogsPhase0BCameraCapturing: AnyObject {
    func startCapture(_ request: DevVlogsPhase0BCameraCaptureRequest) async throws -> DevVlogsPhase0BCameraCaptureStart
    func stopCapture() async throws -> DevVlogsPhase0BCameraCaptureArtifact
    func cancelCapture() async
}
@MainActor
final class DevVlogsPhase0BCameraCapture: NSObject, DevVlogsPhase0BCameraCapturing {
    private enum State { case idle, starting, capturing, stopping, terminal }
    private let session = AVCaptureSession(), movieOutput = AVCaptureMovieFileOutput()
    private let sampleOutput = AVCaptureVideoDataOutput(), sampleQueue = DispatchQueue.main
    private let sessionQueue = DispatchQueue(label: "app.holdtype.phase0b.camera-session")
    private let monotonicClock: () -> TimeInterval
    private var state = State.idle
    private var request: DevVlogsPhase0BCameraCaptureRequest?, requestTime: TimeInterval?
    private var startEvidence = DevVlogsPhase0BCameraStartEvidence()
    private var deviceClass = DevVlogsPhase0BDeviceClass.unknown, redactedDeviceLabel = "camera"
    private var startContinuation: CheckedContinuation<Void, Error>?, stopContinuation: CheckedContinuation<Void, Error>?
    private var startTimeoutTask: Task<Void, Never>?, stopTimeoutTask: Task<Void, Never>?
    private let steadyFailureTerminator = DevVlogsPhase0BSteadyCaptureTerminator()
    private var observers: [NSObjectProtocol] = []
    private(set) var sessionCleanupCount = 0
    var stopIsPending: Bool { stopContinuation != nil }
    var isTerminal: Bool { state == .terminal }
    private var failureContext: DevVlogsPhase0BCameraFailureContext { state == .capturing || state == .stopping ? .steadyCapture : .starting }
    init(monotonicClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) { self.monotonicClock = monotonicClock; super.init() }
    func startCapture(
        _ request: DevVlogsPhase0BCameraCaptureRequest
    ) async throws -> DevVlogsPhase0BCameraCaptureStart {
        guard state == .idle else { throw DevVlogsPhase0BCameraCaptureError.recordingFailed }
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
            return DevVlogsPhase0BCameraCaptureStart(
                requestMonotonicTime: requestTime ?? monotonicClock(),
                recordingStartMonotonicTime: startEvidence.recordingStartTime ?? monotonicClock(),
                deviceClass: deviceClass,
                redactedDeviceLabel: redactedDeviceLabel
            )
        } catch {
            try? await finishSession(timeout: request.setupTimeout)
            state = .terminal
            if let failure = startEvidence.failure { throw failure }
            throw DevVlogsPhase0BCameraCaptureError.classifyPlatformError(error, context: .starting)
        }
    }
    func stopCapture() async throws -> DevVlogsPhase0BCameraCaptureArtifact {
        if let failure = await steadyFailureTerminator.waitForFailure() {
            throw failure
        }
        guard state == .capturing, let request, let requestTime,
              let recordingStartTime = startEvidence.recordingStartTime else {
            throw DevVlogsPhase0BCameraCaptureError.notCapturing
        }
        state = .stopping
        steadyFailureTerminator.disarm()
        do {
            try await withCheckedThrowingContinuation { continuation in
                stopContinuation = continuation
                stopTimeoutTask = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: request.setupTimeout) } catch { return }
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
                firstFrameMonotonicTime: startEvidence.firstFrameTime,
                firstFramePresentationTime: startEvidence.firstFramePresentationTime,
                recordingStopMonotonicTime: monotonicClock()
            )
            try await finishSession(timeout: request.setupTimeout)
            state = .terminal
            return artifact
        } catch {
            let failure = DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
                error,
                context: failureContext
            )
            try? await finishSession(timeout: request.setupTimeout)
            state = .terminal
            throw failure
        }
    }
    func armSteadyCaptureForTesting(_ request: DevVlogsPhase0BCameraCaptureRequest) {
        state = .capturing; self.request = request
        let time = monotonicClock()
        requestTime = time
        startEvidence.recordingDidStart(at: time)
        startEvidence.firstFrameDidArrive(at: time, presentationTime: nil)
        steadyFailureTerminator.arm()
    }
    func cancelCapture() async {
        if await steadyFailureTerminator.waitForFailure() != nil {
            state = .terminal
            return
        }
        steadyFailureTerminator.disarm()
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
        case .authorized: break
        case .notDetermined: throw DevVlogsPhase0BCameraCaptureError.permissionRequired
        case .denied, .restricted: throw DevVlogsPhase0BCameraCaptureError.permissionDenied
        @unknown default: throw DevVlogsPhase0BCameraCaptureError.permissionDenied
        }
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
        guard let device = discovery.devices.first(where: { $0.uniqueID == uniqueID }) else {
            throw DevVlogsPhase0BCameraCaptureError.preferredDeviceDisconnected
        }
        guard device.isConnected else { throw DevVlogsPhase0BCameraCaptureError.preferredDeviceDisconnected }
        guard !device.isInUseByAnotherApplication else { throw DevVlogsPhase0BCameraCaptureError.preferredDeviceBusy }
        deviceClass = Self.deviceClass(for: device)
        redactedDeviceLabel = "\(deviceClass.rawValue)_camera"
        return device
    }
    private func configureSession(device: AVCaptureDevice) throws {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw DevVlogsPhase0BCameraCaptureError.videoInputUnavailable }
        session.addInput(input)
        movieOutput.movieFragmentInterval = CMTime(seconds: 10, preferredTimescale: 600)
        guard session.canAddOutput(movieOutput) else { throw DevVlogsPhase0BCameraCaptureError.movieOutputUnavailable }
        session.addOutput(movieOutput)
        sampleOutput.alwaysDiscardsLateVideoFrames = true
        sampleOutput.setSampleBufferDelegate(self, queue: sampleQueue)
        guard session.canAddOutput(sampleOutput) else { throw DevVlogsPhase0BCameraCaptureError.sampleOutputUnavailable }
        session.addOutput(sampleOutput)
    }
    private func startSession(timeout: Duration) async throws {
        let session = self.session
        let sessionQueue = self.sessionQueue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
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
                do { try await Task.sleep(for: timeout) } catch { return }
                _ = gate.resume(
                    with: .failure(DevVlogsPhase0BCameraCaptureError.setupTimedOut)
                )
            }
            gate.installTimeoutTask(timeoutTask)
        }
    }
    private func awaitMovieStart(timeout: Duration, begin: () -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            startContinuation = continuation
            if resumeStartFromEvidence() { return }
            startTimeoutTask = Task { @MainActor [weak self] in
                do { try await Task.sleep(for: timeout) } catch { return }
                self?.startEvidence.timeout()
                self?.resumeStartFromEvidence()
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
                    guard let self else { return }
                    let failure: DevVlogsPhase0BCameraCaptureError = self.failureContext == .starting
                        ? .deviceUnavailableDuringStart
                        : .disconnectedDuringCapture
                    self.failActiveCapture(with: failure)
                }
            },
            center.addObserver(forName: AVCaptureSession.runtimeErrorNotification, object: session, queue: .main) {
                [weak self] notification in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.failActiveCapture(with: Self.classifyRuntimeNotification(notification, context: self.failureContext))
                }
            },
        ]
    }
    func failActiveCapture(with error: DevVlogsPhase0BCameraCaptureError) {
        if state == .starting {
            startEvidence.fail(error)
            resumeStartFromEvidence()
            return
        }
        if stopContinuation != nil {
            resumeStop(throwing: error)
            return
        }
        guard state == .capturing else { return }
        let timeout = request?.setupTimeout ?? .seconds(30)
        let claimed = steadyFailureTerminator.terminate(with: error) { [weak self] in
            guard let self else { return }
            if self.movieOutput.isRecording {
                self.movieOutput.stopRecording()
            }
            try? await self.finishSession(timeout: timeout)
            self.state = .terminal
        }
        guard claimed else { return }
        state = .stopping
    }
    private func finishSession(timeout: Duration) async throws {
        sessionCleanupCount += 1
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
        sampleOutput.setSampleBufferDelegate(nil, queue: nil)
        try await stopSession(timeout: timeout)
    }
    private func stopSession(timeout: Duration) async throws {
        let session = self.session
        let sessionQueue = self.sessionQueue
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = DevVlogsPhase0BContinuationGate(continuation: continuation)
            sessionQueue.async {
                if session.isRunning {
                    session.stopRunning()
                }
                _ = gate.resume(with: .success(()))
            }
            let timeoutTask = Task {
                do { try await Task.sleep(for: timeout) } catch { return }
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
    @discardableResult
    private func resumeStartFromEvidence() -> Bool {
        guard let continuation = startContinuation else { return false }
        switch startEvidence.resolution {
        case .pending: return false
        case .ready:
            state = .capturing
            steadyFailureTerminator.arm()
            resumeStart()
        case .failed(let error): resumeStart(throwing: error)
        }
        return true
    }
    private func resumeStop(throwing error: Error? = nil) {
        guard let continuation = stopContinuation else { return }
        stopContinuation = nil
        stopTimeoutTask?.cancel()
        stopTimeoutTask = nil
        error.map { continuation.resume(throwing: $0) } ?? continuation.resume()
    }
    static func classifyRuntimeNotification(
        _ notification: Notification,
        context: DevVlogsPhase0BCameraFailureContext
    ) -> DevVlogsPhase0BCameraCaptureError {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? Error else {
            return .runtimeFailure
        }
        return DevVlogsPhase0BCameraCaptureError.classifyPlatformError(error, context: context)
    }
    private static func deviceClass(for device: AVCaptureDevice) -> DevVlogsPhase0BDeviceClass {
        if device.isContinuityCamera { return .continuity }
        if device.deviceType == .external { return .external }
        if device.deviceType == .builtInWideAngleCamera { return .builtIn }
        return .unknown
    }
}
@MainActor
final class DevVlogsPhase0BSteadyCaptureTerminator {
    enum Phase: Equatable { case idle, active, terminating, terminal }
    private(set) var phase = Phase.idle
    private var failure: DevVlogsPhase0BCameraCaptureError?
    private var cleanupTask: Task<Void, Never>?
    func arm() { if phase == .idle { phase = .active } }
    func disarm() { if phase == .active { phase = .terminal } }
    @discardableResult
    func terminate(
        with failure: DevVlogsPhase0BCameraCaptureError,
        cleanup: @escaping @MainActor () async -> Void
    ) -> Bool {
        guard phase == .active else { return false }
        phase = .terminating
        self.failure = failure
        cleanupTask = Task { @MainActor [weak self] in
            await cleanup()
            self?.phase = .terminal
        }
        return true
    }
    func waitForFailure() async -> DevVlogsPhase0BCameraCaptureError? { await cleanupTask?.value; return failure }
}
extension DevVlogsPhase0BCameraCapture: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        startEvidence.recordingDidStart(at: monotonicClock())
        resumeStartFromEvidence()
    }
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        guard let error else {
            if state == .starting { failActiveCapture(with: .recordingFailed) } else { resumeStop() }
            return
        }
        failActiveCapture(
            with: DevVlogsPhase0BCameraCaptureError.classifyPlatformError(
                error,
                context: failureContext
            )
        )
    }
}
extension DevVlogsPhase0BCameraCapture: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard startEvidence.firstFrameTime == nil, CMSampleBufferDataIsReady(sampleBuffer) else { return }
        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        let presentationTime = timestamp.isValid && timestamp.isNumeric ? timestamp.seconds : nil
        startEvidence.firstFrameDidArrive(at: monotonicClock(), presentationTime: presentationTime)
        resumeStartFromEvidence()
    }
}
#endif
