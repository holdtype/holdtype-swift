@preconcurrency import AVFoundation
import CoreMedia
import Foundation

@MainActor
protocol DevVlogsMediaBuilding {
    func build(
        sources: [DevVlogsBuildSource],
        outputURL: URL,
        outputPrepared: @escaping @MainActor (DevVlogsFileIdentity) async throws -> Void,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> DevVlogsBuildOutput
    func validateOutput(at url: URL) async throws -> DevVlogsBuildOutput
}

@MainActor
final class AVFoundationDevVlogsMediaBuilder: DevVlogsMediaBuilding {
    private struct MediaSignature: Equatable {
        let videoCodec: FourCharCode
        let videoSize: CGSize
        let nominalFrameRate: Float
        let videoTransform: CGAffineTransform
        let audioFormatID: AudioFormatID
        let audioSampleRate: Float64
        let audioChannels: UInt32
    }

    private struct LoadedSource {
        let source: DevVlogsBuildSource
        let asset: AVURLAsset
        let videoTrack: AVAssetTrack
        let audioTrack: AVAssetTrack
        let duration: CMTime
        let signature: MediaSignature
    }

    private static let maximumExportWait: Duration = .seconds(60)
    private let maximumProbeWait: Duration
    private let sourceProbeBarrier: @MainActor () async throws -> Void
    private let signatureProbeBarrier: @MainActor () async throws -> Void
    private let outputProbeBarrier: @MainActor () async throws -> Void

    convenience init() {
        self.init(
            maximumProbeWait: .seconds(10),
            sourceProbeBarrier: {},
            signatureProbeBarrier: {},
            outputProbeBarrier: {}
        )
    }

    init(
        maximumProbeWait: Duration,
        sourceProbeBarrier: @escaping @MainActor () async throws -> Void,
        signatureProbeBarrier: @escaping @MainActor () async throws -> Void = {},
        outputProbeBarrier: @escaping @MainActor () async throws -> Void
    ) {
        self.maximumProbeWait = maximumProbeWait
        self.sourceProbeBarrier = sourceProbeBarrier
        self.signatureProbeBarrier = signatureProbeBarrier
        self.outputProbeBarrier = outputProbeBarrier
    }

    func build(
        sources: [DevVlogsBuildSource],
        outputURL: URL,
        outputPrepared: @escaping @MainActor (DevVlogsFileIdentity) async throws -> Void,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> DevVlogsBuildOutput {
        guard !sources.isEmpty else { throw DevVlogsBuildError.noSelectedClips }
        guard !FileManager.default.fileExists(atPath: outputURL.path) else {
            throw DevVlogsBuildError.outputAlreadyExists
        }

        let loaded = try await loadSources(sources)
        guard loaded.dropFirst().allSatisfy({ compatible($0.signature, loaded[0].signature) }) else {
            throw DevVlogsBuildError.incompatibleSources
        }
        guard loaded.allSatisfy({ item in
            item.source.resourceIdentity.validateSourceAndMetadata()
                && item.source.resourceIdentity.mediaURL == item.source.fileURL
        }) else {
            throw DevVlogsBuildError.sourceInvalid
        }

        let composition = AVMutableComposition()
        guard let compositionVideo = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ),
            let compositionAudio = composition.addMutableTrack(
                withMediaType: .audio,
                preferredTrackID: kCMPersistentTrackID_Invalid
            ) else {
            throw DevVlogsBuildError.sourceInvalid
        }

        var cursor = CMTime.zero
        for item in loaded {
            let range = CMTimeRange(start: .zero, duration: item.duration)
            try compositionVideo.insertTimeRange(range, of: item.videoTrack, at: cursor)
            try compositionAudio.insertTimeRange(range, of: item.audioTrack, at: cursor)
            cursor = cursor + item.duration
        }
        compositionVideo.preferredTransform = loaded[0].signature.videoTransform

        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: AVAssetExportPresetPassthrough
        ),
            session.supportedFileTypes.contains(.mov) else {
            throw DevVlogsBuildError.incompatibleSources
        }
        session.outputURL = outputURL
        session.outputFileType = .mov
        session.shouldOptimizeForNetworkUse = false
        try await export(session, progress: progress)
        guard let outputIdentity = DevVlogsFileIdentity.capture(
            at: outputURL,
            kind: .regularFile,
            requireSingleLink: true
        ) else {
            throw DevVlogsBuildError.outputInvalid
        }
        try await outputPrepared(outputIdentity)
        return try await validateOutput(at: outputURL)
    }

    private func loadSources(_ sources: [DevVlogsBuildSource]) async throws -> [LoadedSource] {
        var loaded: [LoadedSource] = []
        for source in sources {
            loaded.append(try await DevVlogsMediaProbeGate<LoadedSource>().wait(
                timeout: maximumProbeWait
            ) { [sourceProbeBarrier] in
                try await sourceProbeBarrier()
                guard source.resourceIdentity.validateSourceAndMetadata(),
                      source.resourceIdentity.mediaURL == source.fileURL else {
                    throw DevVlogsBuildError.sourceInvalid
                }
                let asset = AVURLAsset(url: source.fileURL)
                let videoTracks = try await asset.loadTracks(withMediaType: .video)
                let audioTracks = try await asset.loadTracks(withMediaType: .audio)
                let duration = try await asset.load(.duration)
                guard try await asset.load(.isPlayable),
                      videoTracks.count == 1,
                      audioTracks.count == 1,
                      duration.isValid,
                      duration.isNumeric,
                      duration > .zero else {
                    throw DevVlogsBuildError.sourceInvalid
                }
                try await self.signatureProbeBarrier()
                let signature = try await self.signature(video: videoTracks[0], audio: audioTracks[0])
                guard source.resourceIdentity.validateSourceAndMetadata(),
                      source.resourceIdentity.mediaURL == source.fileURL else {
                    throw DevVlogsBuildError.sourceInvalid
                }
                return LoadedSource(
                    source: source,
                    asset: asset,
                    videoTrack: videoTracks[0],
                    audioTrack: audioTracks[0],
                    duration: duration,
                    signature: signature
                )
            })
        }
        return loaded
    }

    private func signature(video: AVAssetTrack, audio: AVAssetTrack) async throws -> MediaSignature {
        let videoDescriptions = try await video.load(.formatDescriptions)
        let audioDescriptions = try await audio.load(.formatDescriptions)
        guard let videoDescription = videoDescriptions.first,
              let audioDescription = audioDescriptions.first,
              let audioBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(audioDescription) else {
            throw DevVlogsBuildError.sourceInvalid
        }
        return MediaSignature(
            videoCodec: CMFormatDescriptionGetMediaSubType(videoDescription),
            videoSize: try await video.load(.naturalSize),
            nominalFrameRate: try await video.load(.nominalFrameRate),
            videoTransform: try await video.load(.preferredTransform),
            audioFormatID: audioBasicDescription.pointee.mFormatID,
            audioSampleRate: audioBasicDescription.pointee.mSampleRate,
            audioChannels: audioBasicDescription.pointee.mChannelsPerFrame
        )
    }

    private func compatible(_ lhs: MediaSignature, _ rhs: MediaSignature) -> Bool {
        lhs.videoCodec == rhs.videoCodec
            && lhs.videoSize == rhs.videoSize
            && abs(lhs.nominalFrameRate - rhs.nominalFrameRate) < 0.01
            && lhs.videoTransform == rhs.videoTransform
            && lhs.audioFormatID == rhs.audioFormatID
            && abs(lhs.audioSampleRate - rhs.audioSampleRate) < 0.01
            && lhs.audioChannels == rhs.audioChannels
    }

    private func export(
        _ session: AVAssetExportSession,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws {
        let operation = DevVlogsBuildExportOperation(session: session)
        let progressTask = Task { @MainActor in
            while !Task.isCancelled {
                progress(Double(session.progress))
                if session.status == .completed || session.status == .failed || session.status == .cancelled {
                    return
                }
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        defer { progressTask.cancel() }

        try await withTaskCancellationHandler {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await operation.run() }
                group.addTask {
                    try await Task.sleep(for: Self.maximumExportWait)
                    operation.cancel()
                    throw DevVlogsBuildError.timedOut
                }
                _ = try await group.next()
                group.cancelAll()
            }
        } onCancel: {
            operation.cancel()
        }
        progress(1)
    }

    func validateOutput(at url: URL) async throws -> DevVlogsBuildOutput {
        try await DevVlogsMediaProbeGate<DevVlogsBuildOutput>().wait(
            timeout: maximumProbeWait
        ) { [outputProbeBarrier] in
            guard let identity = DevVlogsFileIdentity.capture(
                at: url,
                kind: .regularFile,
                requireSingleLink: true
            ) else {
                throw DevVlogsBuildError.outputInvalid
            }
            try await outputProbeBarrier()
            let asset = AVURLAsset(url: url)
            let videoTracks = try await asset.loadTracks(withMediaType: .video)
            let audioTracks = try await asset.loadTracks(withMediaType: .audio)
            let duration = try await asset.load(.duration).seconds
            guard try await asset.load(.isPlayable),
                  videoTracks.count == 1,
                  audioTracks.count == 1,
                  duration.isFinite,
                  duration > 0,
                  identity.matches(url, requireSingleLink: true) else {
                throw DevVlogsBuildError.outputInvalid
            }
            return DevVlogsBuildOutput(fileURL: url, duration: duration, byteCount: identity.size)
        }
    }
}

nonisolated private final class DevVlogsBuildExportOperation: @unchecked Sendable {
    private let session: AVAssetExportSession

    init(session: AVAssetExportSession) {
        self.session = session
    }

    func run() async throws {
        await session.export()
        switch session.status {
        case .completed:
            return
        case .cancelled:
            throw DevVlogsBuildError.cancelled
        default:
            throw DevVlogsBuildError.exportFailed
        }
    }

    func cancel() {
        session.cancelExport()
    }
}
