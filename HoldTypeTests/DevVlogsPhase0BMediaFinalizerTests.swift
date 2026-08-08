#if DEBUG
import CoreMedia
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BMediaFinalizerTests {
    @Test func monotonicAlignmentNeverClaimsAudioSamplePTS() async throws {
        let exporter = Phase0BExporter()
        let finalizer = DevVlogsPhase0BMediaFinalizer(exporter: exporter)
        let request = makeRequest(audioStart: 4, videoStart: 4.25)

        let result = try await finalizer.finalize(request)

        #expect(result.audioInsertionOffset == 0)
        #expect(result.videoInsertionOffset == 0.25)
        #expect(result.videoSampleTimestampOffset == CMTime(seconds: 0.25, preferredTimescale: 60_000))
        #expect(exporter.requests.count == 1)
        #expect(exporter.requests.first?.timeout == .seconds(300))
    }

    @Test func earlierVideoIsRepresentedAsAudioInsertionOffset() async throws {
        let finalizer = DevVlogsPhase0BMediaFinalizer(exporter: Phase0BExporter())
        let result = try await finalizer.finalize(makeRequest(audioStart: 9.2, videoStart: 9))

        #expect(abs(result.audioInsertionOffset - 0.2) < 0.000_001)
        #expect(result.videoInsertionOffset == 0)
    }

    @Test func exporterFailureRemainsTruthfulAndDoesNotRetry() async {
        let exporter = Phase0BExporter(error: .passthroughIncompatible)
        let finalizer = DevVlogsPhase0BMediaFinalizer(exporter: exporter)

        await #expect(throws: DevVlogsPhase0BMediaFinalizerError.passthroughIncompatible) {
            try await finalizer.finalize(makeRequest(audioStart: 1, videoStart: 1))
        }
        #expect(exporter.requests.count == 1)
    }

    @Test func sourceUsesOnlyTransformPreservingQuickTimePassthrough() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BMediaFinalizer.swift"
            ),
            encoding: .utf8
        )

        #expect(source.contains("AVAssetExportPresetPassthrough"))
        #expect(source.contains("outputType = AVFileType.mov"))
        #expect(source.contains("compositionVideo.preferredTransform"))
        #expect(source.contains("videoTrack.load(.preferredTransform)"))
        #expect(source.contains("insertTimeRange(\n                videoRange"))
        #expect(source.contains("insertTimeRange(\n                audioRange"))
        #expect(!source.contains("AVAssetExportPreset1280x720"))
        #expect(!source.contains("videoComposition"))
        #expect(!source.contains("intersection("))
        #expect(!source.contains("CMTimeRangeGetIntersection"))
        #expect(!source.contains("renderSize"))
        #expect(!source.contains("setScaleRamp"))
        #expect(!source.contains("CGAffineTransform(scale"))
    }

    @Test func missingExportCallbackTimesOutWithoutBlockingAndLateCallbackIsHarmless() async {
        let fake = Phase0BExportCallback()
        let awaiter = DevVlogsPhase0BExportAwaiter(
            start: fake.start,
            cancel: fake.cancel
        )
        let clock = ContinuousClock()
        let start = clock.now

        await #expect(throws: DevVlogsPhase0BMediaFinalizerError.exportTimedOut) {
            try await awaiter.wait(timeout: .milliseconds(20))
        }

        #expect(clock.now - start < .seconds(1))
        #expect(fake.cancelCount == 1)
        #expect(awaiter.terminalCompletionCount == 1)
        fake.complete(.success(()))
        #expect(awaiter.terminalCompletionCount == 1)
        #expect(fake.cancelCount == 1)
    }

    @Test func missingExportCallbackReturnsPromptlyAfterTaskCancellation() async {
        let fake = Phase0BExportCallback()
        let awaiter = DevVlogsPhase0BExportAwaiter(
            start: fake.start,
            cancel: fake.cancel
        )
        let task = Task {
            try await awaiter.wait(timeout: .seconds(10))
        }
        await Task.yield()
        let clock = ContinuousClock()
        let cancellationStart = clock.now
        task.cancel()

        await #expect(throws: DevVlogsPhase0BMediaFinalizerError.exportCancelled) {
            try await task.value
        }

        #expect(clock.now - cancellationStart < .seconds(1))
        #expect(fake.cancelCount == 1)
        #expect(awaiter.terminalCompletionCount == 1)
        fake.complete(.success(()))
        #expect(awaiter.terminalCompletionCount == 1)
    }

    private func makeRequest(
        audioStart: TimeInterval,
        videoStart: TimeInterval
    ) -> DevVlogsPhase0BMediaFinalizationRequest {
        DevVlogsPhase0BMediaFinalizationRequest(
            videoFileURL: URL(fileURLWithPath: "/tmp/run/video.mov"),
            audioFileURL: URL(fileURLWithPath: "/tmp/run/audio.m4a"),
            outputFileURL: URL(fileURLWithPath: "/tmp/run/candidate.mov"),
            alignment: .init(
                audioCaptureStartMonotonicTime: audioStart,
                videoCaptureStartMonotonicTime: videoStart
            ),
            timeout: .seconds(300)
        )
    }
}

nonisolated private final class Phase0BExportCallback: @unchecked Sendable {
    private let lock = NSLock()
    private var completion: DevVlogsPhase0BExportAwaiter.Completion?
    private var cancellations = 0

    var cancelCount: Int {
        lock.withLock { cancellations }
    }

    func start(completion: @escaping DevVlogsPhase0BExportAwaiter.Completion) {
        lock.withLock { self.completion = completion }
    }

    func cancel() {
        lock.withLock { cancellations += 1 }
    }

    func complete(_ result: DevVlogsPhase0BExportAwaiter.ExportResult) {
        let completion = lock.withLock { self.completion }
        completion?(result)
    }
}

@MainActor
private final class Phase0BExporter: DevVlogsPhase0BMediaExporting {
    let error: DevVlogsPhase0BMediaFinalizerError?
    private(set) var requests: [DevVlogsPhase0BMediaFinalizationRequest] = []

    init(error: DevVlogsPhase0BMediaFinalizerError? = nil) {
        self.error = error
    }

    func export(_ request: DevVlogsPhase0BMediaFinalizationRequest) async throws -> CMTime {
        requests.append(request)
        if let error { throw error }
        return CMTime(seconds: request.alignment.videoInsertionOffset, preferredTimescale: 60_000)
    }
}
#endif
