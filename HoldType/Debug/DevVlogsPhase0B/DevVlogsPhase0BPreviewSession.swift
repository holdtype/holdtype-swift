#if DEBUG
@preconcurrency import AVFoundation
import CoreImage
import Foundation
import Observation

struct DevVlogsPhase0BPreviewCamera: Equatable, Identifiable {
    let id: String
    let label: String
}

enum DevVlogsPhase0BPreviewAuthorization: Equatable {
    case authorized
    case notDetermined
    case denied
    case restricted
}

enum DevVlogsPhase0BPreviewFailure: Error, Equatable {
    case selectionRequired
    case authorizationRequired
    case authorizationDenied
    case authorizationRestricted
    case selectedDeviceMissing
    case selectedDeviceBusy
    case disconnected
    case runtimeFailure
    case frameConversionFailed
    case startTimedOut
    case cancelled
}

enum DevVlogsPhase0BPreviewState: Equatable {
    case idle
    case starting
    case previewing
    case stopping
    case stopped
    case failed(DevVlogsPhase0BPreviewFailure)
}

nonisolated protocol DevVlogsPhase0BPreviewGraph: AnyObject, Sendable {
    func start(
        onFrame: @escaping @Sendable (CGImage) -> Void,
        onFailure: @escaping @Sendable (DevVlogsPhase0BPreviewFailure) -> Void
    ) async throws
    func stop() async
}

@MainActor
protocol DevVlogsPhase0BPreviewPlatform {
    var cameras: [DevVlogsPhase0BPreviewCamera] { get }
    func authorizationStatus() -> DevVlogsPhase0BPreviewAuthorization
    func makeGraph(cameraID: String) throws -> any DevVlogsPhase0BPreviewGraph
}

@MainActor
final class DevVlogsPhase0BPreviewFrameCoalescer {
    typealias Schedule = (@escaping @MainActor () -> Void) -> Void

    private let schedule: Schedule
    private let publish: (CGImage) -> Void
    private var latest: CGImage?
    private var isScheduled = false
    private var isActive = true

    init(
        schedule: @escaping Schedule = { action in
            Task { @MainActor in
                await Task.yield()
                action()
            }
        },
        publish: @escaping (CGImage) -> Void
    ) {
        self.schedule = schedule
        self.publish = publish
    }

    func submit(_ image: CGImage) {
        guard isActive else { return }
        latest = image
        guard !isScheduled else { return }
        isScheduled = true
        schedule { [weak self] in self?.drain() }
    }

    func invalidate() {
        isActive = false
        latest = nil
    }

    private func drain() {
        isScheduled = false
        guard isActive, let latest else { return }
        self.latest = nil
        publish(latest)
    }
}

@Observable
@MainActor
final class DevVlogsPhase0BPreviewSession {
    private(set) var state: DevVlogsPhase0BPreviewState
    private(set) var frame: CGImage?
    var selectedCameraID: String?
    let cameras: [DevVlogsPhase0BPreviewCamera]

    private let platform: any DevVlogsPhase0BPreviewPlatform
    private var graph: (any DevVlogsPhase0BPreviewGraph)?
    private var startTask: Task<Void, Never>?
    private var coalescer: DevVlogsPhase0BPreviewFrameCoalescer?
    private var generation = 0

    init(
        platform: any DevVlogsPhase0BPreviewPlatform,
        state: DevVlogsPhase0BPreviewState = .idle,
        selectedCameraID: String? = nil,
        frame: CGImage? = nil
    ) {
        self.platform = platform
        cameras = platform.cameras
        self.state = state
        self.selectedCameraID = selectedCameraID
        self.frame = frame
    }

    static func live(cameraID: String) -> DevVlogsPhase0BPreviewSession {
        DevVlogsPhase0BPreviewSession(
            platform: DevVlogsPhase0BApplePreviewPlatform(allowedCameraID: cameraID)
        )
    }

    func start() {
        guard state != .starting, state != .previewing, state != .stopping else { return }
        guard let selectedCameraID else {
            state = .failed(.selectionRequired)
            return
        }
        guard cameras.contains(where: { $0.id == selectedCameraID }) else {
            state = .failed(.selectedDeviceMissing)
            return
        }
        switch platform.authorizationStatus() {
        case .authorized: break
        case .notDetermined:
            state = .failed(.authorizationRequired)
            return
        case .denied:
            state = .failed(.authorizationDenied)
            return
        case .restricted:
            state = .failed(.authorizationRestricted)
            return
        }

        generation += 1
        let activeGeneration = generation
        state = .starting
        frame = nil
        do {
            let graph = try platform.makeGraph(cameraID: selectedCameraID)
            self.graph = graph
            coalescer = DevVlogsPhase0BPreviewFrameCoalescer { [weak self] image in
                guard let self, self.generation == activeGeneration else { return }
                self.frame = image
            }
            startTask = Task { [weak self] in
                await self?.performStart(graph: graph, generation: activeGeneration)
            }
        } catch let failure as DevVlogsPhase0BPreviewFailure {
            state = .failed(failure)
        } catch {
            state = .failed(.runtimeFailure)
        }
    }

    func stop() async {
        guard state != .idle, state != .stopped, state != .stopping else { return }
        state = .stopping
        generation += 1
        startTask?.cancel()
        startTask = nil
        coalescer?.invalidate()
        coalescer = nil
        let graph = graph
        self.graph = nil
        await graph?.stop()
        frame = nil
        state = .stopped
    }

    private func performStart(
        graph: any DevVlogsPhase0BPreviewGraph,
        generation activeGeneration: Int
    ) async {
        do {
            try await graph.start(
                onFrame: { [weak self] image in
                    Task { @MainActor [weak self] in
                        guard let self, self.generation == activeGeneration else { return }
                        self.coalescer?.submit(image)
                    }
                },
                onFailure: { [weak self] failure in
                    Task { @MainActor [weak self] in
                        await self?.finishFailure(failure, generation: activeGeneration)
                    }
                }
            )
            guard generation == activeGeneration else { return }
            state = .previewing
            startTask = nil
        } catch let failure as DevVlogsPhase0BPreviewFailure {
            await finishFailure(failure, generation: activeGeneration)
        } catch is CancellationError {
            await finishFailure(.cancelled, generation: activeGeneration)
        } catch {
            await finishFailure(.runtimeFailure, generation: activeGeneration)
        }
    }

    private func finishFailure(
        _ failure: DevVlogsPhase0BPreviewFailure,
        generation activeGeneration: Int
    ) async {
        guard generation == activeGeneration else { return }
        generation += 1
        startTask?.cancel()
        startTask = nil
        coalescer?.invalidate()
        coalescer = nil
        let graph = graph
        self.graph = nil
        await graph?.stop()
        frame = nil
        state = .failed(failure)
    }
}

@MainActor
private struct DevVlogsPhase0BApplePreviewPlatform: DevVlogsPhase0BPreviewPlatform {
    let allowedCameraID: String

    var cameras: [DevVlogsPhase0BPreviewCamera] {
        discovery.devices.compactMap { device in
            guard device.uniqueID == allowedCameraID else { return nil }
            return DevVlogsPhase0BPreviewCamera(id: device.uniqueID, label: device.localizedName)
        }
    }

    func authorizationStatus() -> DevVlogsPhase0BPreviewAuthorization {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .authorized
        case .notDetermined: .notDetermined
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .restricted
        }
    }

    func makeGraph(cameraID: String) throws -> any DevVlogsPhase0BPreviewGraph {
        guard cameraID == allowedCameraID,
              let device = discovery.devices.first(where: { $0.uniqueID == cameraID }),
              device.isConnected else {
            throw DevVlogsPhase0BPreviewFailure.selectedDeviceMissing
        }
        guard !device.isInUseByAnotherApplication else {
            throw DevVlogsPhase0BPreviewFailure.selectedDeviceBusy
        }
        return DevVlogsPhase0BApplePreviewGraph(device: device)
    }

    private var discovery: AVCaptureDevice.DiscoverySession {
        AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video,
            position: .unspecified
        )
    }
}

nonisolated final class DevVlogsPhase0BPreviewFrameConverter: @unchecked Sendable {
    private let context: CIContext

    init(context: CIContext = CIContext()) {
        self.context = context
    }

    func makeImage(pixelBuffer: CVPixelBuffer) -> CGImage? {
        let image = CIImage(cvPixelBuffer: pixelBuffer)
        return context.createCGImage(image, from: image.extent)
    }
}

nonisolated private final class DevVlogsPhase0BApplePreviewGraph: NSObject,
    DevVlogsPhase0BPreviewGraph, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let device: AVCaptureDevice
    private let sessionQueue = DispatchQueue(label: "app.holdtype.phase0b.preview.session")
    private let frameQueue = DispatchQueue(label: "app.holdtype.phase0b.preview.frames")
    private let lock = NSLock()
    private let converter = DevVlogsPhase0BPreviewFrameConverter()
    private var session: AVCaptureSession?
    private var output: AVCaptureVideoDataOutput?
    private var observers: [NSObjectProtocol] = []
    private var frameHandler: (@Sendable (CGImage) -> Void)?
    private var failureHandler: (@Sendable (DevVlogsPhase0BPreviewFailure) -> Void)?
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var timeoutTask: Task<Void, Never>?
    private var isActive = false
    private var firstFrameDelivered = false

    init(device: AVCaptureDevice) {
        self.device = device
    }

    func start(
        onFrame: @escaping @Sendable (CGImage) -> Void,
        onFailure: @escaping @Sendable (DevVlogsPhase0BPreviewFailure) -> Void
    ) async throws {
        lock.withLock {
            frameHandler = onFrame
            failureHandler = onFailure
            isActive = true
            firstFrameDelivered = false
        }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                lock.withLock { startContinuation = continuation }
                let timeoutTask = Task { [weak self] in
                    do { try await Task.sleep(for: .seconds(30)) } catch { return }
                    self?.finishStart(.failure(DevVlogsPhase0BPreviewFailure.startTimedOut))
                }
                lock.withLock { self.timeoutTask = timeoutTask }
                let wasCancelled = withUnsafeCurrentTask { $0?.isCancelled == true }
                if wasCancelled {
                    finishStart(.failure(CancellationError()))
                } else {
                    configureAndStart()
                }
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
                let snapshot = lock.withLock {
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
            guard let self else { return }
            guard self.lock.withLock({ self.isActive }) else { return }
            do {
                let session = AVCaptureSession()
                let input = try AVCaptureDeviceInput(device: self.device)
                let output = AVCaptureVideoDataOutput()
                output.alwaysDiscardsLateVideoFrames = true
                output.setSampleBufferDelegate(self, queue: self.frameQueue)
                session.beginConfiguration()
                guard session.canAddInput(input), session.canAddOutput(output) else {
                    session.commitConfiguration()
                    throw DevVlogsPhase0BPreviewFailure.runtimeFailure
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
                guard session.isRunning else { throw DevVlogsPhase0BPreviewFailure.runtimeFailure }
            } catch let failure as DevVlogsPhase0BPreviewFailure {
                self.finishStart(.failure(failure))
            } catch {
                self.finishStart(.failure(DevVlogsPhase0BPreviewFailure.runtimeFailure))
            }
        }
    }

    private func installObservers(session: AVCaptureSession) {
        let center = NotificationCenter.default
        let values = [
            center.addObserver(
                forName: AVCaptureDevice.wasDisconnectedNotification,
                object: device,
                queue: nil
            ) { [weak self] _ in self?.fail(.disconnected) },
            center.addObserver(
                forName: AVCaptureSession.runtimeErrorNotification,
                object: session,
                queue: nil
            ) { [weak self] _ in self?.fail(.runtimeFailure) },
        ]
        lock.withLock { observers = values }
    }

    private func fail(_ failure: DevVlogsPhase0BPreviewFailure) {
        let handler = lock.withLock { isActive ? failureHandler : nil }
        finishStart(.failure(failure))
        handler?(failure)
    }

    private func finishStart(_ result: Result<Void, Error>) {
        let snapshot = lock.withLock { () -> (
            CheckedContinuation<Void, Error>?, Task<Void, Never>?
        ) in
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
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        guard let image = converter.makeImage(pixelBuffer: pixelBuffer) else {
            fail(.frameConversionFailed)
            return
        }
        var didDeliverFirstFrame = false
        let handler = lock.withLock { () -> (@Sendable (CGImage) -> Void)? in
            guard isActive else { return nil }
            if !firstFrameDelivered {
                firstFrameDelivered = true
                didDeliverFirstFrame = true
            }
            return frameHandler
        }
        if didDeliverFirstFrame { finishStart(.success(())) }
        handler?(image)
    }
}
#endif
