import AVFoundation
import CoreVideo
import Foundation
@testable import HoldType

enum DevVlogsMediaFixtureError: Error {
    case writerUnavailable
    case pixelBufferUnavailable
    case writerTimedOut
    case writerFailed
}

@MainActor
enum DevVlogsMediaFixtureFactory {
    static func makeArchivedClip(
        rootURL: URL,
        clipID: UUID,
        createdAt: Date,
        appName: String,
        bundleIdentifier: String,
        size: CGSize = CGSize(width: 64, height: 64),
        color: (UInt8, UInt8, UInt8) = (220, 30, 30),
        duration: TimeInterval = 0.6
    ) async throws -> URL {
        let archive = FileSystemDevVlogsArchive()
        let workspace = try archive.prepareWorkspace(attemptID: clipID, destinationURL: rootURL)
        try await makeVideoOnly(
            at: workspace.cameraURL,
            size: size,
            color: color,
            duration: duration
        )
        try makeAudio(at: workspace.audioURL, duration: duration)
        let finalized = try await AVFoundationDevVlogsMediaFinalizer().finalize(
            camera: DevVlogsCameraCaptureResult(
                fileURL: workspace.cameraURL,
                duration: duration,
                startedAtUptime: 100
            ),
            audioURL: workspace.audioURL,
            audioStartedAtUptime: 100,
            outputURL: workspace.finalizedURL
        )
        return try archive.publish(
            snapshot: DevVlogsCaptureSnapshot(
                attemptID: clipID,
                startedAt: createdAt,
                triggerApplication: DevVlogsTriggerApplication(
                    bundleIdentifier: bundleIdentifier,
                    displayName: appName
                ),
                preferredCamera: DevVlogsCamera(id: "fixture-camera", label: "Fixture Camera")
            ),
            workspace: workspace,
            media: finalized
        ).fileURL
    }

    static func makeVideoOnly(
        at url: URL,
        size: CGSize,
        color: (UInt8, UInt8, UInt8),
        duration: TimeInterval
    ) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: Int(size.width),
                AVVideoHeightKey: Int(size.height)
            ]
        )
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: Int(size.width),
                kCVPixelBufferHeightKey as String: Int(size.height)
            ]
        )
        guard writer.canAdd(input) else { throw DevVlogsMediaFixtureError.writerUnavailable }
        writer.add(input)
        guard writer.startWriting() else { throw DevVlogsMediaFixtureError.writerFailed }
        writer.startSession(atSourceTime: .zero)

        let frameRate: Int32 = 30
        let frameCount = max(1, Int(duration * Double(frameRate)))
        for frame in 0..<frameCount {
            try waitUntilReady(input)
            let buffer = try pixelBuffer(size: size, color: color)
            guard adaptor.append(
                buffer,
                withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: frameRate)
            ) else {
                throw DevVlogsMediaFixtureError.writerFailed
            }
        }
        input.markAsFinished()
        await withCheckedContinuation { continuation in
            writer.finishWriting { continuation.resume() }
        }
        guard writer.status == .completed else { throw DevVlogsMediaFixtureError.writerFailed }
    }

    static func makeAudio(at url: URL, duration: TimeInterval) throws {
        let sampleRate = 44_100.0
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(
                pcmFormat: format,
                frameCapacity: AVAudioFrameCount(sampleRate * duration)
              ) else {
            throw DevVlogsMediaFixtureError.writerUnavailable
        }
        buffer.frameLength = buffer.frameCapacity
        if let samples = buffer.floatChannelData?[0] {
            for frame in 0..<Int(buffer.frameLength) {
                samples[frame] = 0.12 * sin(Float(frame) * 2 * .pi * 440 / Float(sampleRate))
            }
        }
        let file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 64_000
            ]
        )
        try file.write(from: buffer)
    }

    private static func waitUntilReady(_ input: AVAssetWriterInput) throws {
        let deadline = Date().addingTimeInterval(2)
        while !input.isReadyForMoreMediaData {
            guard Date() < deadline else { throw DevVlogsMediaFixtureError.writerTimedOut }
            RunLoop.current.run(until: Date().addingTimeInterval(0.001))
        }
    }

    private static func pixelBuffer(
        size: CGSize,
        color: (UInt8, UInt8, UInt8)
    ) throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            nil,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32BGRA,
            nil,
            &buffer
        )
        guard status == kCVReturnSuccess, let buffer else {
            throw DevVlogsMediaFixtureError.pixelBufferUnavailable
        }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            throw DevVlogsMediaFixtureError.pixelBufferUnavailable
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        for row in 0..<Int(size.height) {
            let pixels = baseAddress.advanced(by: row * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for column in 0..<Int(size.width) {
                let offset = column * 4
                pixels[offset] = color.2
                pixels[offset + 1] = color.1
                pixels[offset + 2] = color.0
                pixels[offset + 3] = 255
            }
        }
        return buffer
    }
}
