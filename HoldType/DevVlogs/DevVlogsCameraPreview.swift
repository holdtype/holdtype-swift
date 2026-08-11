@preconcurrency import AVFoundation
import Combine
import CoreImage
import Foundation

enum DevVlogsCameraPreviewError: Error, Equatable, LocalizedError {
    case notAuthorized
    case preferredCameraUnavailable
    case cameraBusy
    case startTimedOut
    case startFailed
    case disconnected

    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Camera access is required before preview can start."
        case .preferredCameraUnavailable:
            return "The preferred camera is unavailable. HoldType did not substitute another camera."
        case .cameraBusy:
            return "The preferred camera is busy in another app."
        case .startTimedOut:
            return "The preferred camera did not produce a preview in time."
        case .startFailed:
            return "The preferred camera preview could not start."
        case .disconnected:
            return "The preferred camera disconnected."
        }
    }
}

enum DevVlogsCameraPreviewState: Equatable {
    case idle
    case starting
    case previewing
    case failed(String)

    var isActive: Bool {
        self == .starting || self == .previewing
    }
}

@MainActor
protocol DevVlogsCameraPreviewing: AnyObject {
    func start(
        cameraID: String,
        onFrame: @escaping @MainActor (CGImage) -> Void,
        onFailure: @escaping @MainActor (DevVlogsCameraPreviewError) -> Void
    ) async throws
    func stop() async
}

@MainActor
final class AVFoundationDevVlogsCameraPreviewService: DevVlogsCameraPreviewing {
    private let maximumStartWait: Duration
    private var graph: DevVlogsCameraPreviewGraph?

    init(maximumStartWait: Duration = .seconds(15)) {
        self.maximumStartWait = maximumStartWait
    }

    func start(
        cameraID: String,
        onFrame: @escaping @MainActor (CGImage) -> Void,
        onFailure: @escaping @MainActor (DevVlogsCameraPreviewError) -> Void
    ) async throws {
        guard graph == nil else { throw DevVlogsCameraPreviewError.startFailed }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            throw DevVlogsCameraPreviewError.notAuthorized
        }
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: DevVlogsCameraDiscovery.deviceTypes,
            mediaType: .video,
            position: .unspecified
        ).devices.first(where: {
            $0.uniqueID == cameraID && $0.isConnected && !$0.isSuspended
        }) else {
            throw DevVlogsCameraPreviewError.preferredCameraUnavailable
        }
        guard !device.isInUseByAnotherApplication else {
            throw DevVlogsCameraPreviewError.cameraBusy
        }

        let graph = DevVlogsCameraPreviewGraph(device: device, maximumStartWait: maximumStartWait)
        self.graph = graph
        do {
            try await graph.start(onFrame: onFrame, onFailure: onFailure)
        } catch {
            self.graph = nil
            await graph.stop()
            throw error
        }
    }

    func stop() async {
        let graph = graph
        self.graph = nil
        await graph?.stop()
    }
}

@MainActor
final class DevVlogsCameraPreviewStore: ObservableObject {
    @Published private(set) var state: DevVlogsCameraPreviewState = .idle
    @Published private(set) var frame: CGImage?

    private let client: any DevVlogsCameraPreviewing
    private var generation = 0

    convenience init() {
        self.init(client: AVFoundationDevVlogsCameraPreviewService())
    }

    init(client: any DevVlogsCameraPreviewing) {
        self.client = client
    }

    func startPreview(
        isEnabled: Bool,
        permissionStatus: DevVlogsCameraPermissionStatus,
        preferredCamera: DevVlogsCamera?,
        availableCameras: [DevVlogsCamera]
    ) async {
        guard !state.isActive else { return }
        guard isEnabled else {
            state = .failed("Enable Dev Vlogs before starting preview.")
            return
        }
        guard permissionStatus == .allowed else {
            state = .failed("Allow Camera access before starting preview.")
            return
        }
        guard let preferredCamera,
              availableCameras.contains(where: { $0.id == preferredCamera.id }) else {
            state = .failed(DevVlogsCameraPreviewError.preferredCameraUnavailable.localizedDescription)
            return
        }

        generation += 1
        let requestGeneration = generation
        frame = nil
        state = .starting
        do {
            try await client.start(
                cameraID: preferredCamera.id,
                onFrame: { [weak self] image in
                    guard let self, self.generation == requestGeneration, self.state.isActive else { return }
                    self.frame = image
                },
                onFailure: { [weak self] error in
                    self?.receiveFailure(error, generation: requestGeneration)
                }
            )
            guard generation == requestGeneration, state == .starting else {
                await client.stop()
                return
            }
            state = .previewing
        } catch is CancellationError {
            guard generation == requestGeneration else { return }
            state = .idle
            frame = nil
        } catch {
            guard generation == requestGeneration else { return }
            state = .failed((error as? LocalizedError)?.errorDescription ?? "Camera preview failed.")
            frame = nil
        }
    }

    func stopPreview() async {
        generation += 1
        state = .idle
        frame = nil
        await client.stop()
    }

    func reconcile(
        isEnabled: Bool,
        permissionStatus: DevVlogsCameraPermissionStatus,
        preferredCamera: DevVlogsCamera?,
        availableCameras: [DevVlogsCamera]
    ) async {
        guard state.isActive else { return }
        let preferredIsAvailable = preferredCamera.map { preferred in
            availableCameras.contains(where: { $0.id == preferred.id })
        } == true
        guard isEnabled, permissionStatus == .allowed, preferredIsAvailable else {
            await stopPreview()
            if isEnabled, permissionStatus == .allowed {
                state = .failed(DevVlogsCameraPreviewError.disconnected.localizedDescription)
            }
            return
        }
    }

    private func receiveFailure(_ error: DevVlogsCameraPreviewError, generation: Int) {
        guard self.generation == generation else { return }
        self.generation += 1
        frame = nil
        state = .failed(error.localizedDescription)
        Task { @MainActor [client] in
            await client.stop()
        }
    }
}

nonisolated private final class DevVlogsCameraPreviewFrameConverter: @unchecked Sendable {
    private let context = CIContext()

    func makeImage(pixelBuffer: CVPixelBuffer) -> CGImage? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        return context.createCGImage(image, from: image.extent)
    }
}

nonisolated private final class DevVlogsCameraPreviewGraph: NSObject,
    AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let device: AVCaptureDevice
    private let maximumStartWait: Duration
    private let sessionQueue = DispatchQueue(label: "app.holdtype.dev-vlogs.camera-preview.session")
    private let frameQueue = DispatchQueue(label: "app.holdtype.dev-vlogs.camera-preview.frames")
    private let lock = NSLock()
    private let converter = DevVlogsCameraPreviewFrameConverter()
    private var session: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var observers: [NSObjectProtocol] = []
    private var frameHandler: (@MainActor (CGImage) -> Void)?
    private var failureHandler: (@MainActor (DevVlogsCameraPreviewError) -> Void)?
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var isActive = false
    private var deliveredFirstFrame = false

    init(device: AVCaptureDevice, maximumStartWait: Duration) {
        self.device = device
        self.maximumStartWait = maximumStartWait
    }

    func start(
        onFrame: @escaping @MainActor (CGImage) -> Void,
        onFailure: @escaping @MainActor (DevVlogsCameraPreviewError) -> Void
    ) async throws {
        lock.withLock {
            frameHandler = onFrame
            failureHandler = onFailure
            isActive = true
            deliveredFirstFrame = false
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock { startContinuation = continuation }
                let timeoutTask = Task { [weak self, maximumStartWait] in
                    do { try await Task.sleep(for: maximumStartWait) } catch { return }
                    self?.finishStart(.failure(DevVlogsCameraPreviewError.startTimedOut))
                }
                lock.withLock { self.timeoutTask = timeoutTask }
                configureAndStart()
            }
        } onCancel: { [weak self] in
            self?.finishStart(.failure(CancellationError()))
        }
    }

    func stop() async {
        finishStart(.failure(CancellationError()))
        lock.withLock {
            isActive = false
            frameHandler = nil
            failureHandler = nil
        }
        await withCheckedContinuation { continuation in
            sessionQueue.async { [self] in
                let snapshot = lock.withLock { () -> (AVCaptureSession?, AVCaptureVideoDataOutput?, [NSObjectProtocol]) in
                    let value = (session, output, observers)
                    observers.removeAll()
                    return value
                }
                snapshot.1?.setSampleBufferDelegate(nil, queue: nil)
                snapshot.2.forEach(NotificationCenter.default.removeObserver)
                if snapshot.0?.isRunning == true { snapshot.0?.stopRunning() }
                if let output = snapshot.1 { snapshot.0?.removeOutput(output) }
                snapshot.0?.inputs.forEach { snapshot.0?.removeInput($0) }
                lock.withLock {
                    session = nil
                    self.output = nil
                }
                continuation.resume()
            }
        }
    }

    private func configureAndStart() {
        sessionQueue.async { [weak self] in
            guard let self, self.lock.withLock({ self.isActive }) else { return }
            do {
                let session = AVCaptureSession()
                let input = try AVCaptureDeviceInput(device: self.device)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.frameQueue)
                session.beginConfiguration()
                guard session.canAddInput(input), session.canAddOutput(output) else {
                    session.commitConfiguration()
                    throw DevVlogsCameraPreviewError.cameraBusy
                }
                session.addInput(input)
                session.addOutput(output)
                session.commitConfiguration()
                self.installObservers(session: session)
                self.lock.withLock {
                    self.session = session
                    self.output = output
                }
                session.startRunning()
                guard session.isRunning else { throw DevVlogsCameraPreviewError.startFailed }
            } catch let error as DevVlogsCameraPreviewError {
                self.finishStart(.failure(error))
            } catch {
                self.finishStart(.failure(DevVlogsCameraPreviewError.startFailed))
            }
        }
    }

    private func installObservers(session: AVCaptureSession) {
        let center = NotificationCenter.default
        let observers = [
            center.addObserver(
                forName: AVCaptureDevice.wasDisconnectedNotification,
                object: device,
                queue: nil
            ) { [weak self] _ in self?.fail(.disconnected) },
            center.addObserver(
                forName: AVCaptureSession.runtimeErrorNotification,
                object: session,
                queue: nil
            ) { [weak self] _ in self?.fail(.startFailed) }
        ]
        lock.withLock { self.observers = observers }
    }

    private func fail(_ error: DevVlogsCameraPreviewError) {
        let handler = lock.withLock { isActive ? failureHandler : nil }
        finishStart(.failure(error))
        if let handler {
            Task { @MainActor in handler(error) }
        }
    }

    private func finishStart(_ result: Result<Void, Error>) {
        let snapshot = lock.withLock { () -> (CheckedContinuation<Void, Error>?, Task<Void, Never>?) in
            let continuation = startContinuation
            startContinuation = nil
            let timeoutTask = timeoutTask
            self.timeoutTask = nil
            return (continuation, timeoutTask)
        }
        snapshot.1?.cancel()
        snapshot.0?.resume(with: result)
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard CMSampleBufferDataIsReady(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
              let image = converter.makeImage(pixelBuffer: pixelBuffer) else { return }
        var firstFrame = false
        let handler = lock.withLock { () -> (@MainActor (CGImage) -> Void)? in
            guard isActive else { return nil }
            if !deliveredFirstFrame {
                deliveredFirstFrame = true
                firstFrame = true
            }
            return frameHandler
        }
        if firstFrame { finishStart(.success(())) }
        if let handler {
            Task { @MainActor in handler(image) }
        }
    }
}
