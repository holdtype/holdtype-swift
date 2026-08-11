@preconcurrency import AVFoundation
import Foundation

enum DevVlogsCameraCaptureError: Error, Equatable, LocalizedError {
    case alreadyCapturing
    case preferredCameraUnavailable
    case cameraBusy
    case startFailed
    case stopFailed

    var errorDescription: String? {
        switch self {
        case .alreadyCapturing:
            return "Another Dev Vlogs capture is already active."
        case .preferredCameraUnavailable:
            return "The preferred camera is unavailable."
        case .cameraBusy:
            return "The preferred camera is busy in another app."
        case .startFailed:
            return "The preferred camera could not start."
        case .stopFailed:
            return "The camera recording could not be finalized."
        }
    }
}

@MainActor
protocol DevVlogsCameraCapturing {
    func startCapture(
        cameraID: String,
        outputURL: URL,
        onStarted: @escaping @MainActor (TimeInterval) -> Void
    ) async throws -> UUID
    func stopCapture(id: UUID) async throws -> DevVlogsCameraCaptureResult
    func cancelCapture(id: UUID) async
}

@MainActor
final class AVFoundationDevVlogsCameraCaptureService: DevVlogsCameraCapturing {
    private static let maximumOperationWait: Duration = .seconds(30)

    private struct ActiveCapture {
        let id: UUID
        let box: DevVlogsCameraSessionBox
    }

    private var activeCapture: ActiveCapture?

    func startCapture(
        cameraID: String,
        outputURL: URL,
        onStarted: @escaping @MainActor (TimeInterval) -> Void
    ) async throws -> UUID {
        guard activeCapture == nil else {
            throw DevVlogsCameraCaptureError.alreadyCapturing
        }

        let id = UUID()
        let box = DevVlogsCameraSessionBox(
            outputURL: outputURL,
            onStarted: onStarted
        )
        activeCapture = ActiveCapture(id: id, box: box)
        do {
            let gate = DevVlogsCameraStartOperationGate()
            try await gate.wait(
                timeout: Self.maximumOperationWait,
                operation: { try await box.start(cameraID: cameraID) },
                onLateSuccess: { _ = try? await box.stop() }
            )
            return id
        } catch {
            activeCapture = nil
            throw error
        }
    }

    func stopCapture(id: UUID) async throws -> DevVlogsCameraCaptureResult {
        guard let capture = activeCapture, capture.id == id else {
            throw DevVlogsCameraCaptureError.stopFailed
        }
        activeCapture = nil
        return try await DevVlogsCameraStopOperationGate().wait(
            timeout: Self.maximumOperationWait,
            operation: { try await capture.box.stop() }
        )
    }

    func cancelCapture(id: UUID) async {
        guard let capture = activeCapture, capture.id == id else {
            return
        }
        activeCapture = nil
        _ = try? await DevVlogsCameraStopOperationGate().wait(
            timeout: Self.maximumOperationWait,
            operation: { try await capture.box.stop() }
        )
    }
}

nonisolated private final class DevVlogsCameraSessionBox: NSObject,
    AVCaptureFileOutputRecordingDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.holdtype.dev-vlogs.camera-capture")
    private let outputURL: URL
    private let onStarted: @MainActor (TimeInterval) -> Void
    private let captureSession = AVCaptureSession()
    private let movieOutput = AVCaptureMovieFileOutput()

    private var startedAtUptime = ProcessInfo.processInfo.systemUptime
    private var stopContinuation: CheckedContinuation<DevVlogsCameraCaptureResult, Error>?
    private var terminalResult: Result<DevVlogsCameraCaptureResult, Error>?

    init(
        outputURL: URL,
        onStarted: @escaping @MainActor (TimeInterval) -> Void
    ) {
        self.outputURL = outputURL
        self.onStarted = onStarted
    }

    func start(cameraID: String) async throws {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                do {
                    let device = try preferredCamera(id: cameraID)
                    let input = try AVCaptureDeviceInput(device: device)
                    captureSession.beginConfiguration()
                    guard captureSession.canAddInput(input),
                          captureSession.canAddOutput(movieOutput) else {
                        captureSession.commitConfiguration()
                        throw DevVlogsCameraCaptureError.cameraBusy
                    }
                    captureSession.addInput(input)
                    captureSession.addOutput(movieOutput)
                    captureSession.commitConfiguration()
                    captureSession.startRunning()
                    guard captureSession.isRunning else {
                        throw DevVlogsCameraCaptureError.startFailed
                    }
                    movieOutput.startRecording(to: outputURL, recordingDelegate: self)
                    continuation.resume()
                } catch let error as DevVlogsCameraCaptureError {
                    captureSession.stopRunning()
                    continuation.resume(throwing: error)
                } catch {
                    captureSession.stopRunning()
                    continuation.resume(throwing: DevVlogsCameraCaptureError.startFailed)
                }
            }
        }
    }

    func stop() async throws -> DevVlogsCameraCaptureResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { [self] in
                if let terminalResult {
                    continuation.resume(with: terminalResult)
                    return
                }
                stopContinuation = continuation
                if movieOutput.isRecording {
                    movieOutput.stopRecording()
                } else {
                    finish(.failure(DevVlogsCameraCaptureError.stopFailed))
                }
            }
        }
    }

    private func preferredCamera(id: String) throws -> AVCaptureDevice {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: DevVlogsCameraDiscovery.deviceTypes,
            mediaType: .video,
            position: .unspecified
        ).devices.first(where: { $0.uniqueID == id && $0.isConnected && !$0.isSuspended }) else {
            throw DevVlogsCameraCaptureError.preferredCameraUnavailable
        }
        return device
    }

    private func finish(_ result: Result<DevVlogsCameraCaptureResult, Error>) {
        guard terminalResult == nil else {
            return
        }
        terminalResult = result
        captureSession.stopRunning()
        let continuation = stopContinuation
        stopContinuation = nil
        continuation?.resume(with: result)
    }
}

extension DevVlogsCameraSessionBox {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        queue.async { [self] in
            startedAtUptime = ProcessInfo.processInfo.systemUptime
            let startedAt = startedAtUptime
            Task { @MainActor [self] in
                self.onStarted(startedAt)
            }
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        queue.async { [self] in
            if let error {
                let nsError = error as NSError
                let completed = nsError.userInfo[AVErrorRecordingSuccessfullyFinishedKey] as? Bool
                if completed != true {
                    finish(.failure(DevVlogsCameraCaptureError.stopFailed))
                    return
                }
            }
            let duration = movieOutput.recordedDuration.seconds
            finish(
                .success(
                    DevVlogsCameraCaptureResult(
                        fileURL: outputFileURL,
                        duration: duration.isFinite ? max(0, duration) : 0,
                        startedAtUptime: startedAtUptime
                    )
                )
            )
        }
    }
}
