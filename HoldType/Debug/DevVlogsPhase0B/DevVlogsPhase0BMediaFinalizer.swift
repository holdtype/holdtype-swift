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
}

enum DevVlogsPhase0BMediaFinalizerError: Error, Equatable {
    case missingVideoTrack
    case missingAudioTrack
    case compositionTrackUnavailable
    case candidatePresetUnavailable
    case outputAlreadyExists
    case exportFailed
    case exportCancelled
    case exportTimedOut
}

protocol DevVlogsPhase0BMediaFinalizing {
    func finalize(
        _ request: DevVlogsPhase0BMediaFinalizationRequest
    ) async throws -> DevVlogsPhase0BMediaFinalization
}

protocol DevVlogsPhase0BMediaExporting {
    func export(_ request: DevVlogsPhase0BMediaFinalizationRequest) async throws
}

struct DevVlogsPhase0BMediaFinalizer: DevVlogsPhase0BMediaFinalizing {
    private let exporter: any DevVlogsPhase0BMediaExporting

    init(exporter: any DevVlogsPhase0BMediaExporting = DevVlogsPhase0BAppleMediaExporter()) {
        self.exporter = exporter
    }

    func finalize(
        _ request: DevVlogsPhase0BMediaFinalizationRequest
    ) async throws -> DevVlogsPhase0BMediaFinalization {
        try await exporter.export(request)
        return DevVlogsPhase0BMediaFinalization(
            outputFileURL: request.outputFileURL,
            audioInsertionOffset: request.alignment.audioInsertionOffset,
            videoInsertionOffset: request.alignment.videoInsertionOffset
        )
    }
}

struct DevVlogsPhase0BAppleMediaExporter: DevVlogsPhase0BMediaExporting {
    func export(_ request: DevVlogsPhase0BMediaFinalizationRequest) async throws {
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

        let isCompatible = await AVAssetExportSession.compatibility(
            ofExportPreset: AVAssetExportPreset1280x720,
            with: composition,
            outputFileType: .mp4
        )
        guard isCompatible,
              let exportSession = AVAssetExportSession(
                  asset: composition,
                  presetName: AVAssetExportPreset1280x720
              ), exportSession.supportedFileTypes.contains(.mp4) else {
            throw DevVlogsPhase0BMediaFinalizerError.candidatePresetUnavailable
        }
        exportSession.outputURL = request.outputFileURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = false
        try await export(exportSession, timeout: request.timeout)
    }

    private func export(_ exportSession: AVAssetExportSession, timeout: Duration) async throws {
        let sessionBox = DevVlogsPhase0BExportSessionBox(exportSession)
        do {
            try await withTaskCancellationHandler {
                try await withThrowingTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await withCheckedContinuation { continuation in
                            sessionBox.session.exportAsynchronously {
                                continuation.resume()
                            }
                        }
                        switch sessionBox.session.status {
                        case .completed:
                            return
                        case .cancelled:
                            throw DevVlogsPhase0BMediaFinalizerError.exportCancelled
                        default:
                            throw DevVlogsPhase0BMediaFinalizerError.exportFailed
                        }
                    }
                    group.addTask {
                        try await Task.sleep(for: timeout)
                        throw DevVlogsPhase0BMediaFinalizerError.exportTimedOut
                    }
                    do {
                        _ = try await group.next()
                        group.cancelAll()
                    } catch {
                        sessionBox.session.cancelExport()
                        group.cancelAll()
                        throw error
                    }
                }
            } onCancel: {
                sessionBox.session.cancelExport()
            }
        } catch is CancellationError {
            throw DevVlogsPhase0BMediaFinalizerError.exportCancelled
        }
    }

    private static func time(seconds: TimeInterval) -> CMTime {
        CMTime(seconds: max(0, seconds), preferredTimescale: 60_000)
    }
}

nonisolated private final class DevVlogsPhase0BExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}
#endif
