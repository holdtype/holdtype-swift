#if DEBUG
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
        let exporter = Phase0BExporter(error: .exportTimedOut)
        let finalizer = DevVlogsPhase0BMediaFinalizer(exporter: exporter)

        await #expect(throws: DevVlogsPhase0BMediaFinalizerError.exportTimedOut) {
            try await finalizer.finalize(makeRequest(audioStart: 1, videoStart: 1))
        }
        #expect(exporter.requests.count == 1)
    }

    private func makeRequest(
        audioStart: TimeInterval,
        videoStart: TimeInterval
    ) -> DevVlogsPhase0BMediaFinalizationRequest {
        DevVlogsPhase0BMediaFinalizationRequest(
            videoFileURL: URL(fileURLWithPath: "/tmp/run/video.mov"),
            audioFileURL: URL(fileURLWithPath: "/tmp/run/audio.m4a"),
            outputFileURL: URL(fileURLWithPath: "/tmp/run/candidate.mp4"),
            alignment: .init(
                audioCaptureStartMonotonicTime: audioStart,
                videoCaptureStartMonotonicTime: videoStart
            ),
            timeout: .seconds(300)
        )
    }
}

@MainActor
private final class Phase0BExporter: DevVlogsPhase0BMediaExporting {
    let error: DevVlogsPhase0BMediaFinalizerError?
    private(set) var requests: [DevVlogsPhase0BMediaFinalizationRequest] = []

    init(error: DevVlogsPhase0BMediaFinalizerError? = nil) {
        self.error = error
    }

    func export(_ request: DevVlogsPhase0BMediaFinalizationRequest) async throws {
        requests.append(request)
        if let error { throw error }
    }
}
#endif
