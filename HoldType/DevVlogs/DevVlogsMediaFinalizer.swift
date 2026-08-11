@preconcurrency import AVFoundation
import CoreMedia
import Foundation

enum DevVlogsMediaFinalizerError: Error, Equatable, LocalizedError {
    case cameraAssetNotPlayable
    case audioAssetNotPlayable
    case invalidTrackLayout
    case noOverlappingMedia
    case passthroughUnavailable
    case timedOut
    case exportFailed
    case finalizedAssetNotPlayable

    var errorDescription: String? {
        switch self {
        case .cameraAssetNotPlayable:
            return "The camera fragment could not be opened."
        case .audioAssetNotPlayable:
            return "The finalized dictation audio could not be opened."
        case .invalidTrackLayout:
            return "The recorded media did not contain the expected tracks."
        case .noOverlappingMedia:
            return "The camera and dictation audio did not overlap."
        case .passthroughUnavailable:
            return "The captured video could not be finalized without re-encoding."
        case .timedOut:
            return "Finalizing the vlog clip timed out."
        case .exportFailed:
            return "The vlog clip could not be finalized."
        case .finalizedAssetNotPlayable:
            return "The finalized vlog clip could not be opened."
        }
    }
}

@MainActor
protocol DevVlogsMediaFinalizing {
    func finalize(
        camera: DevVlogsCameraCaptureResult,
        audioURL: URL,
        audioStartedAtUptime: TimeInterval,
        outputURL: URL
    ) async throws -> DevVlogsFinalizedMedia
}

@MainActor
final class AVFoundationDevVlogsMediaFinalizer: DevVlogsMediaFinalizing {
    private static let maximumExportWait: Duration = .seconds(30)

    func finalize(
        camera: DevVlogsCameraCaptureResult,
        audioURL: URL,
        audioStartedAtUptime: TimeInterval,
        outputURL: URL
    ) async throws -> DevVlogsFinalizedMedia {
        let cameraAsset = AVURLAsset(url: camera.fileURL)
        let audioAsset = AVURLAsset(url: audioURL)
        guard try await cameraAsset.load(.isPlayable) else {
            throw DevVlogsMediaFinalizerError.cameraAssetNotPlayable
        }
        guard try await audioAsset.load(.isPlayable) else {
            throw DevVlogsMediaFinalizerError.audioAssetNotPlayable
        }

        let cameraVideoTracks = try await cameraAsset.loadTracks(withMediaType: .video)
        let cameraAudioTracks = try await cameraAsset.loadTracks(withMediaType: .audio)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        let audioVideoTracks = try await audioAsset.loadTracks(withMediaType: .video)
        guard cameraVideoTracks.count == 1,
              cameraAudioTracks.isEmpty,
              audioTracks.count == 1,
              audioVideoTracks.isEmpty else {
            throw DevVlogsMediaFinalizerError.invalidTrackLayout
        }

        let cameraTrack = cameraVideoTracks[0]
        let audioTrack = audioTracks[0]
        let audioDuration = try await audioAsset.load(.duration).seconds
        let commonStart = max(camera.startedAtUptime, audioStartedAtUptime)
        let cameraOffset = max(0, commonStart - camera.startedAtUptime)
        let audioOffset = max(0, commonStart - audioStartedAtUptime)
        let commonDuration = min(
            camera.duration - cameraOffset,
            audioDuration - audioOffset
        )
        guard commonDuration.isFinite, commonDuration > 0 else {
            throw DevVlogsMediaFinalizerError.noOverlappingMedia
        }

        let composition = AVMutableComposition()
        guard let compositionVideoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
            let compositionAudioTrack = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
            throw DevVlogsMediaFinalizerError.invalidTrackLayout
        }
        let duration = CMTime(seconds: commonDuration, preferredTimescale: 600)
        try compositionVideoTrack.insertTimeRange(
            CMTimeRange(
                start: CMTime(seconds: cameraOffset, preferredTimescale: 600),
                duration: duration
            ),
            of: cameraTrack,
            at: .zero
        )
        try compositionAudioTrack.insertTimeRange(
            CMTimeRange(
                start: CMTime(seconds: audioOffset, preferredTimescale: 600),
                duration: duration
            ),
            of: audioTrack,
            at: .zero
        )
        compositionVideoTrack.preferredTransform = try await cameraTrack.load(.preferredTransform)

        guard let exportSession = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ),
            exportSession.supportedFileTypes.contains(.mov) else {
            throw DevVlogsMediaFinalizerError.passthroughUnavailable
        }
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mov
        exportSession.shouldOptimizeForNetworkUse = false
        try await export(exportSession)

        let finalizedAsset = AVURLAsset(url: outputURL)
        let finalizedVideoTracks = try await finalizedAsset.loadTracks(withMediaType: .video)
        let finalizedAudioTracks = try await finalizedAsset.loadTracks(withMediaType: .audio)
        guard try await finalizedAsset.load(.isPlayable),
              finalizedVideoTracks.count == 1,
              finalizedAudioTracks.count == 1 else {
            throw DevVlogsMediaFinalizerError.finalizedAssetNotPlayable
        }
        let finalizedDuration = try await finalizedAsset.load(.duration).seconds
        guard finalizedDuration.isFinite, finalizedDuration > 0 else {
            throw DevVlogsMediaFinalizerError.finalizedAssetNotPlayable
        }
        let format = try await realizedFormat(finalizedVideoTracks[0])
        let values = try outputURL.resourceValues(forKeys: [.fileSizeKey])
        return DevVlogsFinalizedMedia(
            fileURL: outputURL,
            duration: finalizedDuration,
            byteCount: Int64(values.fileSize ?? 0),
            realizedVideoFormat: format
        )
    }

    private func export(_ session: AVAssetExportSession) async throws {
        let operation = DevVlogsExportOperation(session: session)
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await operation.run()
            }
            group.addTask {
                try await Task.sleep(for: Self.maximumExportWait)
                operation.cancel()
                throw DevVlogsMediaFinalizerError.timedOut
            }
            _ = try await group.next()
            group.cancelAll()
        }
    }

    private func realizedFormat(
        _ track: AVAssetTrack
    ) async throws -> DevVlogsRealizedVideoFormat {
        let size = try await track.load(.naturalSize)
        let frameRate = try await track.load(.nominalFrameRate)
        let descriptions = try await track.load(.formatDescriptions)
        guard let description = descriptions.first else {
            throw DevVlogsMediaFinalizerError.invalidTrackLayout
        }
        return DevVlogsRealizedVideoFormat(
            width: Int(abs(size.width.rounded())),
            height: Int(abs(size.height.rounded())),
            nominalFrameRate: Double(frameRate),
            codec: Self.fourCharacterCode(CMFormatDescriptionGetMediaSubType(description))
        )
    }

    private static func fourCharacterCode(_ code: FourCharCode) -> String {
        let bytes: [UInt8] = [
            UInt8((code >> 24) & 0xff),
            UInt8((code >> 16) & 0xff),
            UInt8((code >> 8) & 0xff),
            UInt8(code & 0xff)
        ]
        return String(bytes: bytes, encoding: .macOSRoman) ?? String(code)
    }
}

nonisolated private final class DevVlogsExportOperation: @unchecked Sendable {
    private let session: AVAssetExportSession

    init(session: AVAssetExportSession) {
        self.session = session
    }

    nonisolated func run() async throws {
        await session.export()
        switch session.status {
        case .completed:
            return
        case .cancelled:
            throw DevVlogsMediaFinalizerError.timedOut
        default:
            throw DevVlogsMediaFinalizerError.exportFailed
        }
    }

    nonisolated func cancel() {
        session.cancelExport()
    }
}
