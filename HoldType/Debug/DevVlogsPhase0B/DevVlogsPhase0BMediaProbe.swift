#if DEBUG
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

struct DevVlogsPhase0BMediaTrackProbe: Equatable {
    let codec: String
    let durationSeconds: TimeInterval
    let startTimestampSeconds: TimeInterval?
    let dimensions: CGSize?
    let nominalFrameRate: Float?
    let estimatedDataRate: Float
    let playable: Bool
}

struct DevVlogsPhase0BMediaProbeResult: Equatable {
    let assetPlayable: Bool
    let video: DevVlogsPhase0BMediaTrackProbe
    let audio: DevVlogsPhase0BMediaTrackProbe
}

enum DevVlogsPhase0BMediaProbeError: Error, Equatable {
    case assetNotPlayable
    case expectedOneVideoTrack(actual: Int)
    case expectedOneAudioTrack(actual: Int)
    case videoNotPlayable
    case audioNotPlayable
    case unexpectedDimensions(width: Int, height: Int)
    case unexpectedFrameRate(Float)
    case unexpectedVideoCodec(String)
    case unexpectedAudioCodec(String)
    case invalidDuration
    case invalidTimestampBounds
    case probeTimedOut
}

protocol DevVlogsPhase0BMediaProbing {
    func probe(fileURL: URL) async throws -> DevVlogsPhase0BMediaProbeResult
}

protocol DevVlogsPhase0BMediaInspecting: AnyObject {
    func inspect(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection
    func cancel()
}

struct DevVlogsPhase0BMediaInspection: Equatable {
    let assetPlayable: Bool
    let videoTracks: [DevVlogsPhase0BMediaTrackProbe]
    let audioTracks: [DevVlogsPhase0BMediaTrackProbe]
}

struct DevVlogsPhase0BMediaProbe: DevVlogsPhase0BMediaProbing {
    private let inspector: any DevVlogsPhase0BMediaInspecting
    private let timeout: Duration

    init(
        inspector: any DevVlogsPhase0BMediaInspecting = DevVlogsPhase0BAVAssetInspector(),
        timeout: Duration = .seconds(300)
    ) {
        self.inspector = inspector
        self.timeout = timeout
    }

    func probe(fileURL: URL) async throws -> DevVlogsPhase0BMediaProbeResult {
        let inspection = try await inspectBounded(fileURL: fileURL)
        guard inspection.assetPlayable else {
            throw DevVlogsPhase0BMediaProbeError.assetNotPlayable
        }
        guard inspection.videoTracks.count == 1, let video = inspection.videoTracks.first else {
            throw DevVlogsPhase0BMediaProbeError.expectedOneVideoTrack(
                actual: inspection.videoTracks.count
            )
        }
        guard inspection.audioTracks.count == 1, let audio = inspection.audioTracks.first else {
            throw DevVlogsPhase0BMediaProbeError.expectedOneAudioTrack(
                actual: inspection.audioTracks.count
            )
        }
        guard video.playable else {
            throw DevVlogsPhase0BMediaProbeError.videoNotPlayable
        }
        guard audio.playable else {
            throw DevVlogsPhase0BMediaProbeError.audioNotPlayable
        }
        guard let dimensions = video.dimensions,
              Int(dimensions.width.rounded()) == 1_280,
              Int(dimensions.height.rounded()) == 720 else {
            throw DevVlogsPhase0BMediaProbeError.unexpectedDimensions(
                width: Int(video.dimensions?.width.rounded() ?? 0),
                height: Int(video.dimensions?.height.rounded() ?? 0)
            )
        }
        guard let frameRate = video.nominalFrameRate,
              (29 ... 31).contains(frameRate) else {
            throw DevVlogsPhase0BMediaProbeError.unexpectedFrameRate(
                video.nominalFrameRate ?? 0
            )
        }
        guard ["avc1", "h264"].contains(video.codec.lowercased()) else {
            throw DevVlogsPhase0BMediaProbeError.unexpectedVideoCodec(video.codec)
        }
        guard ["aac ", "mp4a"].contains(audio.codec.lowercased()) else {
            throw DevVlogsPhase0BMediaProbeError.unexpectedAudioCodec(audio.codec)
        }
        guard video.durationSeconds.isFinite, video.durationSeconds > 0,
              audio.durationSeconds.isFinite, audio.durationSeconds > 0 else {
            throw DevVlogsPhase0BMediaProbeError.invalidDuration
        }
        guard let videoStart = video.startTimestampSeconds, videoStart.isFinite,
              let audioStart = audio.startTimestampSeconds, audioStart.isFinite else {
            throw DevVlogsPhase0BMediaProbeError.invalidTimestampBounds
        }

        return DevVlogsPhase0BMediaProbeResult(
            assetPlayable: inspection.assetPlayable,
            video: video,
            audio: audio
        )
    }

    private func inspectBounded(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection {
        try await withCheckedThrowingContinuation { continuation in
            let gate = DevVlogsPhase0BProbeContinuationGate(continuation: continuation)
            Task {
                do {
                    _ = gate.resume(with: .success(try await inspector.inspect(fileURL: fileURL)))
                } catch {
                    _ = gate.resume(with: .failure(error))
                }
            }
            let timeoutTask = Task {
                do {
                    try await Task.sleep(for: timeout)
                } catch {
                    return
                }
                inspector.cancel()
                _ = gate.resume(with: .failure(DevVlogsPhase0BMediaProbeError.probeTimedOut))
            }
            gate.installTimeoutTask(timeoutTask)
        }
    }
}

final class DevVlogsPhase0BAVAssetInspector: DevVlogsPhase0BMediaInspecting {
    private var currentAsset: AVURLAsset?
    private var currentReader: AVAssetReader?

    func inspect(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection {
        let asset = AVURLAsset(url: fileURL)
        currentAsset = asset
        defer {
            currentAsset = nil
            currentReader = nil
        }
        async let isPlayable = asset.load(.isPlayable)
        let loadedVideoTracks = try await asset.loadTracks(withMediaType: .video)
        let loadedAudioTracks = try await asset.loadTracks(withMediaType: .audio)
        let videoTracks = try await inspect(loadedVideoTracks, asset: asset, video: true)
        let audioTracks = try await inspect(loadedAudioTracks, asset: asset, video: false)
        return DevVlogsPhase0BMediaInspection(
            assetPlayable: try await isPlayable,
            videoTracks: videoTracks,
            audioTracks: audioTracks
        )
    }

    func cancel() {
        currentReader?.cancelReading()
        currentAsset?.cancelLoading()
    }

    private func inspect(
        _ tracks: [AVAssetTrack],
        asset: AVAsset,
        video: Bool
    ) async throws -> [DevVlogsPhase0BMediaTrackProbe] {
        var results: [DevVlogsPhase0BMediaTrackProbe] = []
        for track in tracks {
            async let timeRange = track.load(.timeRange)
            async let estimatedDataRate = track.load(.estimatedDataRate)
            async let formatDescriptions = track.load(.formatDescriptions)
            async let trackPlayable = track.load(.isPlayable)
            let dimensions: CGSize?
            let nominalFrameRate: Float?
            if video {
                async let naturalSize = track.load(.naturalSize)
                async let preferredTransform = track.load(.preferredTransform)
                dimensions = Self.displayDimensions(
                    size: try await naturalSize,
                    transform: try await preferredTransform
                )
                nominalFrameRate = try await track.load(.nominalFrameRate)
            } else {
                dimensions = nil
                nominalFrameRate = nil
            }
            let loadedTimeRange = try await timeRange
            let start = loadedTimeRange.start
            let hasDecodableSample = try containsDecodableSample(
                asset: asset,
                track: track,
                video: video
            )
            results.append(
                DevVlogsPhase0BMediaTrackProbe(
                    codec: Self.codec(from: try await formatDescriptions),
                    durationSeconds: loadedTimeRange.duration.seconds,
                    startTimestampSeconds: start.isValid && start.isNumeric ? start.seconds : nil,
                    dimensions: dimensions,
                    nominalFrameRate: nominalFrameRate,
                    estimatedDataRate: try await estimatedDataRate,
                    playable: try await trackPlayable && hasDecodableSample
                )
            )
        }
        return results
    }

    private func containsDecodableSample(
        asset: AVAsset,
        track: AVAssetTrack,
        video: Bool
    ) throws -> Bool {
        let reader = try AVAssetReader(asset: asset)
        currentReader = reader
        let outputSettings: [String: Any] = video
            ? [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            : [AVFormatIDKey: kAudioFormatLinearPCM]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        guard reader.canAdd(output) else { return false }
        reader.add(output)
        guard reader.startReading() else { return false }
        let sample = output.copyNextSampleBuffer()
        reader.cancelReading()
        currentReader = nil
        return sample != nil
    }

    private static func displayDimensions(size: CGSize, transform: CGAffineTransform) -> CGSize {
        let transformed = size.applying(transform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }

    private static func codec(from descriptions: [CMFormatDescription]) -> String {
        guard let description = descriptions.first else { return "unknown" }
        let value = CMFormatDescriptionGetMediaSubType(description)
        let bytes = [24, 16, 8, 0].map { shift in
            UInt8((value >> UInt32(shift)) & 0xFF)
        }
        return String(bytes: bytes, encoding: .ascii) ?? "unknown"
    }
}

private final class DevVlogsPhase0BProbeContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<DevVlogsPhase0BMediaInspection, Error>?
    private var timeoutTask: Task<Void, Never>?

    init(continuation: CheckedContinuation<DevVlogsPhase0BMediaInspection, Error>) {
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
    func resume(with result: Result<DevVlogsPhase0BMediaInspection, Error>) -> Bool {
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
#endif
