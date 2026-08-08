#if DEBUG
@preconcurrency import AVFoundation
import CoreMedia
import Foundation

struct DevVlogsPhase0BMediaAlignment: Equatable {
    let audioCaptureStartMonotonicTime: TimeInterval
    let videoCaptureStartMonotonicTime: TimeInterval

    var audioInsertionOffset: TimeInterval {
        audioCaptureStartMonotonicTime - origin
    }

    var videoInsertionOffset: TimeInterval {
        videoCaptureStartMonotonicTime - origin
    }

    private var origin: TimeInterval {
        min(audioCaptureStartMonotonicTime, videoCaptureStartMonotonicTime)
    }
}

struct DevVlogsPhase0BMediaFinalizationRequest {
    let videoFileURL: URL
    let audioFileURL: URL
    let outputFileURL: URL
    let alignment: DevVlogsPhase0BMediaAlignment
    let timeout: Duration
}

struct DevVlogsPhase0BMediaFinalization: Equatable {
    let outputFileURL: URL
    let audioInsertionOffset: TimeInterval
    let videoInsertionOffset: TimeInterval
    let videoSampleTimestampOffset: CMTime
}

enum DevVlogsPhase0BMediaFinalizerError: Error, Equatable {
    case missingVideoTrack
    case missingAudioTrack
    case compositionTrackUnavailable
    case passthroughIncompatible
    case outputAlreadyExists
    case passthroughExportFailed
    case exportCancelled
    case exportTimedOut
}

protocol DevVlogsPhase0BMediaFinalizing {
    func finalize(
        _ request: DevVlogsPhase0BMediaFinalizationRequest
    ) async throws -> DevVlogsPhase0BMediaFinalization
}

protocol DevVlogsPhase0BMediaExporting {
    func export(_ request: DevVlogsPhase0BMediaFinalizationRequest) async throws -> CMTime
}

struct DevVlogsPhase0BMediaFinalizer: DevVlogsPhase0BMediaFinalizing {
    private let exporter: any DevVlogsPhase0BMediaExporting

    init(exporter: any DevVlogsPhase0BMediaExporting = DevVlogsPhase0BAppleMediaExporter()) {
        self.exporter = exporter
    }

    func finalize(
        _ request: DevVlogsPhase0BMediaFinalizationRequest
    ) async throws -> DevVlogsPhase0BMediaFinalization {
        let videoSampleTimestampOffset = try await exporter.export(request)
        return DevVlogsPhase0BMediaFinalization(
            outputFileURL: request.outputFileURL,
            audioInsertionOffset: request.alignment.audioInsertionOffset,
            videoInsertionOffset: request.alignment.videoInsertionOffset,
            videoSampleTimestampOffset: videoSampleTimestampOffset
        )
    }
}

struct DevVlogsPhase0BAppleMediaExporter: DevVlogsPhase0BMediaExporting {
    func export(_ request: DevVlogsPhase0BMediaFinalizationRequest) async throws -> CMTime {
        guard !FileManager.default.fileExists(atPath: request.outputFileURL.path) else {
            throw DevVlogsPhase0BMediaFinalizerError.outputAlreadyExists
        }

        let videoAsset = AVURLAsset(url: request.videoFileURL)
        let audioAsset = AVURLAsset(url: request.audioFileURL)
        guard let videoTrack = try await videoAsset.loadTracks(withMediaType: .video).first else {
            throw DevVlogsPhase0BMediaFinalizerError.missingVideoTrack
        }
        guard let audioTrack = try await audioAsset.loadTracks(withMediaType: .audio).first else {
            throw DevVlogsPhase0BMediaFinalizerError.missingAudioTrack
        }

        let composition = AVMutableComposition()
        guard let compositionVideo = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ), let compositionAudio = composition.addMutableTrack(
            withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw DevVlogsPhase0BMediaFinalizerError.compositionTrackUnavailable
        }

        let videoRange = try await videoTrack.load(.timeRange)
        let audioRange = try await audioTrack.load(.timeRange)
        guard videoRange.start.isValid, videoRange.start.isNumeric else {
            throw DevVlogsPhase0BMediaFinalizerError.passthroughExportFailed
        }
        do {
            try compositionVideo.insertTimeRange(
                videoRange,
                of: videoTrack,
                at: Self.time(seconds: request.alignment.videoInsertionOffset)
            )
            try compositionAudio.insertTimeRange(
                audioRange,
                of: audioTrack,
                at: Self.time(seconds: request.alignment.audioInsertionOffset)
            )
            compositionVideo.preferredTransform = try await videoTrack.load(.preferredTransform)
        } catch {
            throw DevVlogsPhase0BMediaFinalizerError.passthroughExportFailed
        }

        let outputType = AVFileType.mov
        let isCompatible = await AVAssetExportSession.compatibility(
            ofExportPreset: AVAssetExportPresetPassthrough,
            with: composition,
            outputFileType: outputType
        )
        guard isCompatible,
              let exportSession = AVAssetExportSession(
                  asset: composition,
                  presetName: AVAssetExportPresetPassthrough
              ), exportSession.supportedFileTypes.contains(outputType) else {
            throw DevVlogsPhase0BMediaFinalizerError.passthroughIncompatible
        }
        exportSession.outputURL = request.outputFileURL
        exportSession.outputFileType = outputType
        exportSession.shouldOptimizeForNetworkUse = false
        try await export(exportSession, timeout: request.timeout)
        return CMTimeSubtract(
            Self.time(seconds: request.alignment.videoInsertionOffset),
            videoRange.start
        )
    }

    private func export(_ exportSession: AVAssetExportSession, timeout: Duration) async throws {
        let sessionBox = DevVlogsPhase0BExportSessionBox(exportSession)
        let awaiter = DevVlogsPhase0BExportAwaiter(
            start: { completion in
                sessionBox.session.exportAsynchronously {
                    let result: Result<Void, DevVlogsPhase0BMediaFinalizerError>
                    switch sessionBox.session.status {
                    case .completed:
                        result = .success(())
                    case .cancelled:
                        result = .failure(.exportCancelled)
                    default:
                        result = .failure(.passthroughExportFailed)
                    }
                    completion(result)
                }
            },
            cancel: {
                sessionBox.session.cancelExport()
            }
        )
        try await awaiter.wait(timeout: timeout)
    }

    private static func time(seconds: TimeInterval) -> CMTime {
        CMTime(seconds: max(0, seconds), preferredTimescale: 60_000)
    }
}

nonisolated final class DevVlogsPhase0BExportAwaiter: @unchecked Sendable {
    typealias ExportResult = Result<Void, DevVlogsPhase0BMediaFinalizerError>
    typealias Completion = @Sendable (ExportResult) -> Void
    typealias Start = @Sendable (@escaping Completion) -> Void

    private let lock = NSLock()
    private let start: Start
    private let cancel: @Sendable () -> Void
    private var continuation: CheckedContinuation<ExportResult, Never>?
    private var terminalResult: ExportResult?
    private var timeoutTask: Task<Void, Never>?
    private var completionCount = 0

    var terminalCompletionCount: Int {
        lock.withLock { completionCount }
    }

    init(start: @escaping Start, cancel: @escaping @Sendable () -> Void) {
        self.start = start
        self.cancel = cancel
    }

    func wait(timeout: Duration) async throws {
        let result = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                begin(continuation: continuation, timeout: timeout)
            }
        } onCancel: {
            complete(.failure(.exportCancelled), cancelExport: true)
        }
        try result.get()
    }

    private func begin(
        continuation: CheckedContinuation<ExportResult, Never>,
        timeout: Duration
    ) {
        lock.lock()
        if let terminalResult {
            lock.unlock()
            continuation.resume(returning: terminalResult)
            return
        }
        self.continuation = continuation
        lock.unlock()

        start { [weak self] result in
            self?.complete(result, cancelExport: false)
        }
        let timeoutTask = Task { [weak self] in
            do {
                try await Task.sleep(for: timeout)
            } catch {
                return
            }
            self?.complete(.failure(.exportTimedOut), cancelExport: true)
        }
        installTimeoutTask(timeoutTask)
    }

    private func installTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        guard terminalResult == nil else {
            lock.unlock()
            task.cancel()
            return
        }
        timeoutTask = task
        lock.unlock()
    }

    private func complete(_ result: ExportResult, cancelExport: Bool) {
        lock.lock()
        guard terminalResult == nil else {
            lock.unlock()
            return
        }
        terminalResult = result
        completionCount += 1
        let continuation = self.continuation
        self.continuation = nil
        let timeoutTask = self.timeoutTask
        self.timeoutTask = nil
        lock.unlock()

        if cancelExport { cancel() }
        timeoutTask?.cancel()
        continuation?.resume(returning: result)
    }
}

final class DevVlogsPhase0BContinuationGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var timeoutTask: Task<Void, Never>?

    init(continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func installTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        guard continuation != nil else {
            lock.unlock()
            task.cancel()
            return
        }
        timeoutTask = task
        lock.unlock()
    }

    @discardableResult
    func resume(with result: Result<Value, Error>) -> Bool {
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

nonisolated private final class DevVlogsPhase0BExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
#endif
