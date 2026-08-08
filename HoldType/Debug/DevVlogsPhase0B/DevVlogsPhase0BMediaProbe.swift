#if DEBUG
@preconcurrency import AVFoundation
import CoreMedia
import CoreVideo
import Foundation

enum DevVlogsPhase0BMediaProbeExpectation: Equatable {
    case cameraOnly
    case finalized
}

struct DevVlogsPhase0BMediaTrackProbe: Equatable {
    let codec: String
    let formatDescription: String
    let durationSeconds: TimeInterval
    let startTimestampSeconds: TimeInterval?
    let endTimestampSeconds: TimeInterval?
    let naturalDimensions: CGSize?
    let displayDimensions: CGSize?
    let nominalFrameRate: Float?
    let derivedFrameRate: Double?
    let estimatedDataRate: Float
    let preferredTransform: CGAffineTransform?
    let playable: Bool
}

struct DevVlogsPhase0BMediaProbeResult: Equatable {
    let assetPlayable: Bool
    let video: DevVlogsPhase0BMediaTrackProbe
    let audio: DevVlogsPhase0BMediaTrackProbe?
}

enum DevVlogsPhase0BMediaProbeError: Error, Equatable {
    case assetNotPlayable
    case expectedOneVideoTrack(actual: Int)
    case expectedAudioTrackCount(expected: Int, actual: Int)
    case videoNotPlayable
    case audioNotPlayable
    case invalidFormat
    case invalidDuration
    case invalidTimestampBounds
    case probeTimedOut
}

protocol DevVlogsPhase0BMediaProbing {
    func probe(
        fileURL: URL,
        expectation: DevVlogsPhase0BMediaProbeExpectation
    ) async throws -> DevVlogsPhase0BMediaProbeResult
}

protocol DevVlogsPhase0BMediaInspecting: AnyObject, Sendable {
    nonisolated func inspect(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection
    nonisolated func cancel()
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

    func probe(
        fileURL: URL,
        expectation: DevVlogsPhase0BMediaProbeExpectation
    ) async throws -> DevVlogsPhase0BMediaProbeResult {
        let inspection = try await inspectBounded(fileURL: fileURL)
        guard inspection.assetPlayable else { throw DevVlogsPhase0BMediaProbeError.assetNotPlayable }
        guard inspection.videoTracks.count == 1, let video = inspection.videoTracks.first else {
            throw DevVlogsPhase0BMediaProbeError.expectedOneVideoTrack(actual: inspection.videoTracks.count)
        }
        let expectedAudioCount = expectation == .cameraOnly ? 0 : 1
        guard inspection.audioTracks.count == expectedAudioCount else {
            throw DevVlogsPhase0BMediaProbeError.expectedAudioTrackCount(
                expected: expectedAudioCount,
                actual: inspection.audioTracks.count
            )
        }
        try Self.validate(video, video: true)
        let audio = inspection.audioTracks.first
        if let audio { try Self.validate(audio, video: false) }
        return DevVlogsPhase0BMediaProbeResult(
            assetPlayable: inspection.assetPlayable,
            video: video,
            audio: audio
        )
    }

    private static func validate(_ track: DevVlogsPhase0BMediaTrackProbe, video: Bool) throws {
        guard track.playable else {
            throw video ? DevVlogsPhase0BMediaProbeError.videoNotPlayable : .audioNotPlayable
        }
        guard track.codec != "unknown", !track.formatDescription.isEmpty else {
            throw DevVlogsPhase0BMediaProbeError.invalidFormat
        }
        guard track.estimatedDataRate.isFinite, track.estimatedDataRate >= 0 else {
            throw DevVlogsPhase0BMediaProbeError.invalidFormat
        }
        if video {
            guard Self.validDimensions(track.naturalDimensions),
                  Self.validDimensions(track.displayDimensions),
                  let transform = track.preferredTransform,
                  [transform.a, transform.b, transform.c, transform.d,
                   transform.tx, transform.ty].allSatisfy(\.isFinite),
                  (track.nominalFrameRate.map { $0.isFinite && $0 > 0 } == true ||
                   track.derivedFrameRate.map { $0.isFinite && $0 > 0 } == true) else {
                throw DevVlogsPhase0BMediaProbeError.invalidFormat
            }
        }
        guard track.durationSeconds.isFinite, track.durationSeconds > 0 else {
            throw DevVlogsPhase0BMediaProbeError.invalidDuration
        }
        guard let start = track.startTimestampSeconds, start.isFinite,
              let end = track.endTimestampSeconds, end.isFinite, end >= start else {
            throw DevVlogsPhase0BMediaProbeError.invalidTimestampBounds
        }
    }

    private static func validDimensions(_ dimensions: CGSize?) -> Bool {
        guard let dimensions else { return false }
        return dimensions.width.isFinite && dimensions.width > 0 &&
            dimensions.height.isFinite && dimensions.height > 0
    }

    private func inspectBounded(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection {
        try await withCheckedThrowingContinuation { continuation in
            let gate = DevVlogsPhase0BProbeContinuationGate(continuation: continuation)
            Task.detached {
                do { _ = gate.resume(with: .success(try await inspector.inspect(fileURL: fileURL))) }
                catch { _ = gate.resume(with: .failure(error)) }
            }
            let timeoutTask = Task {
                do { try await Task.sleep(for: timeout) } catch { return }
                inspector.cancel()
                _ = gate.resume(with: .failure(DevVlogsPhase0BMediaProbeError.probeTimedOut))
            }
            gate.installTimeoutTask(timeoutTask)
        }
    }
}

nonisolated final class DevVlogsPhase0BAVAssetInspector:
    DevVlogsPhase0BMediaInspecting, @unchecked Sendable {
    private let lock = NSLock()
    private var currentAssets: [AVURLAsset] = []
    private var currentReaders: [AVAssetReader] = []

    func inspect(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection {
        let asset = AVURLAsset(url: fileURL)
        lock.withLock { currentAssets = [asset] }
        defer { lock.withLock { currentAssets = []; currentReaders = [] } }
        async let isPlayable = asset.load(.isPlayable)
        let video = try await inspect(
            asset.loadTracks(withMediaType: .video),
            asset: asset,
            video: true
        )
        let audio = try await inspect(
            asset.loadTracks(withMediaType: .audio),
            asset: asset,
            video: false
        )
        return DevVlogsPhase0BMediaInspection(
            assetPlayable: try await isPlayable,
            videoTracks: video,
            audioTracks: audio
        )
    }

    func cancel() {
        let values = lock.withLock { (currentReaders, currentAssets) }
        values.0.forEach { $0.cancelReading() }
        values.1.forEach { $0.cancelLoading() }
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
            async let descriptions = track.load(.formatDescriptions)
            async let trackPlayable = track.load(.isPlayable)
            let naturalSize = video ? try await track.load(.naturalSize) : nil
            let transform = video ? try await track.load(.preferredTransform) : nil
            let nominalRate = video ? try await track.load(.nominalFrameRate) : nil
            let loadedRange = try await timeRange
            let sampleEvidence = try decodedSampleEvidence(asset: asset, track: track, video: video)
            let loadedDescriptions = try await descriptions
            let codec = Self.codec(from: loadedDescriptions)
            let end = CMTimeAdd(loadedRange.start, loadedRange.duration)
            results.append(
                DevVlogsPhase0BMediaTrackProbe(
                    codec: codec,
                    formatDescription: Self.sanitizedFormat(
                        codec: codec,
                        descriptionCount: loadedDescriptions.count,
                        dimensions: naturalSize
                    ),
                    durationSeconds: loadedRange.duration.seconds,
                    startTimestampSeconds: Self.seconds(loadedRange.start),
                    endTimestampSeconds: Self.seconds(end),
                    naturalDimensions: naturalSize,
                    displayDimensions: naturalSize.flatMap { size in
                        transform.map { Self.displayDimensions(size: size, transform: $0) }
                    },
                    nominalFrameRate: nominalRate,
                    derivedFrameRate: sampleEvidence.derivedFrameRate,
                    estimatedDataRate: try await estimatedDataRate,
                    preferredTransform: transform,
                    playable: try await trackPlayable && sampleEvidence.hasSample
                )
            )
        }
        return results
    }

    private func decodedSampleEvidence(
        asset: AVAsset,
        track: AVAssetTrack,
        video: Bool
    ) throws -> (hasSample: Bool, derivedFrameRate: Double?) {
        let reader = try AVAssetReader(asset: asset)
        lock.withLock { currentReaders = [reader] }
        let settings: [String: Any] = video
            ? [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
            : [AVFormatIDKey: kAudioFormatLinearPCM]
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: settings)
        guard reader.canAdd(output) else { return (false, nil) }
        reader.add(output)
        guard reader.startReading() else { return (false, nil) }
        var count = 0
        var first: CMTime?
        var last: CMTime?
        while let sample = output.copyNextSampleBuffer() {
            if Task.isCancelled { reader.cancelReading(); break }
            let time = CMSampleBufferGetPresentationTimeStamp(sample)
            if first == nil { first = time }
            last = time
            count += 1
        }
        lock.withLock { currentReaders = [] }
        let span = first.flatMap { first in last.map { CMTimeSubtract($0, first).seconds } }
        let rate = video && count > 1 && (span ?? 0) > 0 ? Double(count - 1) / (span ?? 1) : nil
        return (count > 0, rate)
    }

    private static func seconds(_ time: CMTime) -> TimeInterval? {
        time.isValid && time.isNumeric ? time.seconds : nil
    }

    private static func displayDimensions(size: CGSize, transform: CGAffineTransform) -> CGSize {
        let transformed = size.applying(transform)
        return CGSize(width: abs(transformed.width), height: abs(transformed.height))
    }

    private static func codec(from descriptions: [CMFormatDescription]) -> String {
        guard let description = descriptions.first else { return "unknown" }
        let value = CMFormatDescriptionGetMediaSubType(description)
        let bytes = [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xFF) }
        guard bytes.allSatisfy({ (0x20 ... 0x7E).contains($0) }) else { return "unknown" }
        return String(bytes: bytes, encoding: .ascii) ?? "unknown"
    }

    private static func sanitizedFormat(
        codec: String,
        descriptionCount: Int,
        dimensions: CGSize?
    ) -> String {
        let size = dimensions.map { "\(Int($0.width.rounded()))x\(Int($0.height.rounded()))" } ?? "audio"
        return "\(codec):\(size):descriptions_\(descriptionCount)"
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
        guard continuation != nil else { lock.unlock(); task.cancel(); return }
        timeoutTask = task
        lock.unlock()
    }

    @discardableResult
    func resume(with result: Result<DevVlogsPhase0BMediaInspection, Error>) -> Bool {
        lock.lock()
        guard let continuation else { lock.unlock(); return false }
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
