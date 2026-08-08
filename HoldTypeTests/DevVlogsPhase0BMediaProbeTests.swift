#if DEBUG
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BMediaProbeTests {
    @Test func acceptsOnePlayableCandidateVideoAndAudioTrack() async throws {
        let result = try await DevVlogsPhase0BMediaProbe(
            inspector: Phase0BInspector(inspection: validInspection())
        ).probe(fileURL: URL(fileURLWithPath: "/tmp/run/candidate.mp4"))

        #expect(result.video.codec == "avc1")
        #expect(result.audio.codec == "aac ")
        #expect(result.video.startTimestampSeconds == 0)
        #expect(result.audio.startTimestampSeconds == 0)
    }

    @Test func rejectsDuplicateVideoTracksAndMissingAudio() async {
        let valid = validInspection()
        let duplicateVideo = DevVlogsPhase0BMediaInspection(
            assetPlayable: true,
            videoTracks: valid.videoTracks + valid.videoTracks,
            audioTracks: valid.audioTracks
        )
        await #expect(throws: DevVlogsPhase0BMediaProbeError.expectedOneVideoTrack(actual: 2)) {
            try await probe(duplicateVideo)
        }

        let noAudio = DevVlogsPhase0BMediaInspection(
            assetPlayable: true,
            videoTracks: valid.videoTracks,
            audioTracks: []
        )
        await #expect(throws: DevVlogsPhase0BMediaProbeError.expectedOneAudioTrack(actual: 0)) {
            try await probe(noAudio)
        }
    }

    @Test func candidateChecksRemainFunctionalNotEvidenceOnly() async {
        let invalid = DevVlogsPhase0BMediaInspection(
            assetPlayable: true,
            videoTracks: [
                .init(
                    codec: "hevc", durationSeconds: 10, startTimestampSeconds: nil,
                    dimensions: CGSize(width: 1_920, height: 1_080), nominalFrameRate: 60,
                    estimatedDataRate: 4_000_000, playable: true
                ),
            ],
            audioTracks: validInspection().audioTracks
        )
        await #expect(
            throws: DevVlogsPhase0BMediaProbeError.unexpectedDimensions(width: 1_920, height: 1_080)
        ) {
            try await probe(invalid)
        }
    }

    @Test func rejectsMissingTimestampBounds() async {
        let invalid = DevVlogsPhase0BMediaInspection(
            assetPlayable: true,
            videoTracks: [
                .init(
                    codec: "avc1", durationSeconds: 10, startTimestampSeconds: nil,
                    dimensions: CGSize(width: 1_280, height: 720), nominalFrameRate: 30,
                    estimatedDataRate: 2_000_000, playable: true
                ),
            ],
            audioTracks: validInspection().audioTracks
        )
        await #expect(throws: DevVlogsPhase0BMediaProbeError.invalidTimestampBounds) {
            try await probe(invalid)
        }
    }

    @Test func probeTimeoutCancelsTheInjectedInspector() async {
        let inspector = Phase0BCancellableInspector(inspection: validInspection())
        let probe = DevVlogsPhase0BMediaProbe(
            inspector: inspector,
            timeout: .milliseconds(1)
        )

        await #expect(throws: DevVlogsPhase0BMediaProbeError.probeTimedOut) {
            try await probe.probe(fileURL: URL(fileURLWithPath: "/tmp/run/candidate.mp4"))
        }
        #expect(inspector.cancelCount == 1)
    }

    private func probe(
        _ inspection: DevVlogsPhase0BMediaInspection
    ) async throws -> DevVlogsPhase0BMediaProbeResult {
        try await DevVlogsPhase0BMediaProbe(
            inspector: Phase0BInspector(inspection: inspection)
        ).probe(fileURL: URL(fileURLWithPath: "/tmp/run/candidate.mp4"))
    }

    private func validInspection() -> DevVlogsPhase0BMediaInspection {
        DevVlogsPhase0BMediaInspection(
            assetPlayable: true,
            videoTracks: [
                .init(
                    codec: "avc1", durationSeconds: 10, startTimestampSeconds: 0,
                    dimensions: CGSize(width: 1_280, height: 720), nominalFrameRate: 30,
                    estimatedDataRate: 2_000_000, playable: true
                ),
            ],
            audioTracks: [
                .init(
                    codec: "aac ", durationSeconds: 10, startTimestampSeconds: 0,
                    dimensions: nil, nominalFrameRate: nil, estimatedDataRate: 128_000,
                    playable: true
                ),
            ]
        )
    }
}

@MainActor
private final class Phase0BInspector: DevVlogsPhase0BMediaInspecting {
    let inspection: DevVlogsPhase0BMediaInspection

    init(inspection: DevVlogsPhase0BMediaInspection) {
        self.inspection = inspection
    }

    func inspect(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection {
        inspection
    }

    func cancel() {}
}

@MainActor
private final class Phase0BCancellableInspector: DevVlogsPhase0BMediaInspecting {
    let inspection: DevVlogsPhase0BMediaInspection
    private var task: Task<DevVlogsPhase0BMediaInspection, Error>?
    private(set) var cancelCount = 0

    init(inspection: DevVlogsPhase0BMediaInspection) {
        self.inspection = inspection
    }

    func inspect(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection {
        let task = Task {
            try await Task.sleep(for: .seconds(60))
            return inspection
        }
        self.task = task
        return try await task.value
    }

    func cancel() {
        cancelCount += 1
        task?.cancel()
    }
}
#endif
