#if DEBUG
import Foundation
import CoreGraphics
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BMediaProbeTests {
    @Test func cameraOnlyAcceptsRealizedHEVC1080p5994WithoutAudio() async throws {
        let video = makeTrack(
            codec: "hvc1",
            size: CGSize(width: 1_920, height: 1_080),
            nominalRate: 59.94,
            derivedRate: 59.91
        )
        let result = try await probe(
            .init(assetPlayable: true, videoTracks: [video], audioTracks: []),
            expectation: .cameraOnly
        )

        #expect(result.video.codec == "hvc1")
        #expect(result.video.naturalDimensions == CGSize(width: 1_920, height: 1_080))
        #expect(result.video.nominalFrameRate == 59.94)
        #expect(result.audio == nil)
    }

    @Test func finalizedAcceptsObservedH264720p30AndOneAudioTrack() async throws {
        let result = try await probe(validFinalInspection(), expectation: .finalized)

        #expect(result.video.codec == "avc1")
        #expect(result.video.naturalDimensions == CGSize(width: 1_280, height: 720))
        #expect(result.video.nominalFrameRate == 30)
        #expect(result.audio?.codec == "aac ")
    }

    @Test func variableAndNonwhitelistedCadenceIsReportedRatherThanRejected() async throws {
        let video = makeTrack(codec: "ap4h", nominalRate: 0, derivedRate: 23.417)
        let result = try await probe(
            .init(assetPlayable: true, videoTracks: [video], audioTracks: []),
            expectation: .cameraOnly
        )

        #expect(result.video.codec == "ap4h")
        #expect(result.video.nominalFrameRate == 0)
        #expect(result.video.derivedFrameRate == 23.417)
    }

    @Test func enforcesCameraOnlyAndFinalTrackCardinality() async {
        let valid = validFinalInspection()
        await #expect(throws: DevVlogsPhase0BMediaProbeError.expectedOneVideoTrack(actual: 2)) {
            try await probe(
                .init(
                    assetPlayable: true,
                    videoTracks: valid.videoTracks + valid.videoTracks,
                    audioTracks: []
                ),
                expectation: .cameraOnly
            )
        }
        await #expect(
            throws: DevVlogsPhase0BMediaProbeError.expectedAudioTrackCount(expected: 0, actual: 1)
        ) {
            try await probe(valid, expectation: .cameraOnly)
        }
        await #expect(
            throws: DevVlogsPhase0BMediaProbeError.expectedAudioTrackCount(expected: 1, actual: 0)
        ) {
            try await probe(
                .init(assetPlayable: true, videoTracks: valid.videoTracks, audioTracks: []),
                expectation: .finalized
            )
        }
    }

    @Test func decodedPlayabilityAndTimestampBoundsRemainFunctionalGates() async {
        var invalid = makeTrack(playable: false)
        await #expect(throws: DevVlogsPhase0BMediaProbeError.videoNotPlayable) {
            try await probe(
                .init(assetPlayable: true, videoTracks: [invalid], audioTracks: []),
                expectation: .cameraOnly
            )
        }
        invalid = makeTrack(start: nil)
        await #expect(throws: DevVlogsPhase0BMediaProbeError.invalidTimestampBounds) {
            try await probe(
                .init(assetPlayable: true, videoTracks: [invalid], audioTracks: []),
                expectation: .cameraOnly
            )
        }
        invalid = makeTrack(size: nil, nominalRate: nil, derivedRate: nil)
        await #expect(throws: DevVlogsPhase0BMediaProbeError.invalidFormat) {
            try await probe(
                .init(assetPlayable: true, videoTracks: [invalid], audioTracks: []),
                expectation: .cameraOnly
            )
        }
    }

    @Test func transformReportsNaturalAndDisplayOrientationWithoutMirroring() async throws {
        let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1_080, ty: 0)
        let video = makeTrack(
            size: CGSize(width: 1_920, height: 1_080),
            displaySize: CGSize(width: 1_080, height: 1_920),
            transform: transform
        )
        let result = try await probe(
            .init(assetPlayable: true, videoTracks: [video], audioTracks: []),
            expectation: .cameraOnly
        )

        #expect(result.video.naturalDimensions == CGSize(width: 1_920, height: 1_080))
        #expect(result.video.displayDimensions == CGSize(width: 1_080, height: 1_920))
        #expect(result.video.preferredTransform == transform)
        let stored = result.video.preferredTransform
        #expect(stored.map { $0.a * $0.d - $0.b * $0.c } == 1)
    }

    @Test func probeTimeoutCancelsTheInjectedInspector() async {
        let inspector = Phase0BCancellableInspector(inspection: validFinalInspection())
        let probe = DevVlogsPhase0BMediaProbe(inspector: inspector, timeout: .milliseconds(1))

        await #expect(throws: DevVlogsPhase0BMediaProbeError.probeTimedOut) {
            try await probe.probe(
                fileURL: URL(fileURLWithPath: "/tmp/run/candidate.mov"),
                expectation: .finalized
            )
        }
        #expect(inspector.cancelCount == 1)
    }

    private func probe(
        _ inspection: DevVlogsPhase0BMediaInspection,
        expectation: DevVlogsPhase0BMediaProbeExpectation
    ) async throws -> DevVlogsPhase0BMediaProbeResult {
        try await DevVlogsPhase0BMediaProbe(
            inspector: Phase0BInspector(inspection: inspection)
        ).probe(fileURL: URL(fileURLWithPath: "/tmp/run/media.mov"), expectation: expectation)
    }

    private func validFinalInspection() -> DevVlogsPhase0BMediaInspection {
        .init(
            assetPlayable: true,
            videoTracks: [makeTrack()],
            audioTracks: [makeTrack(codec: "aac ", size: nil, nominalRate: nil, derivedRate: nil)]
        )
    }

    private func makeTrack(
        codec: String = "avc1",
        size: CGSize? = CGSize(width: 1_280, height: 720),
        displaySize: CGSize? = nil,
        nominalRate: Float? = 30,
        derivedRate: Double? = 30,
        start: TimeInterval? = 0,
        playable: Bool = true,
        transform: CGAffineTransform? = .identity
    ) -> DevVlogsPhase0BMediaTrackProbe {
        .init(
            codec: codec,
            formatDescription: "\(codec):realized",
            durationSeconds: 10,
            startTimestampSeconds: start,
            endTimestampSeconds: 10,
            naturalDimensions: size,
            displayDimensions: displaySize ?? size,
            nominalFrameRate: nominalRate,
            derivedFrameRate: derivedRate,
            estimatedDataRate: 4_000_000,
            preferredTransform: size == nil ? nil : transform,
            playable: playable
        )
    }
}

nonisolated private final class Phase0BInspector:
    DevVlogsPhase0BMediaInspecting, @unchecked Sendable {
    let inspection: DevVlogsPhase0BMediaInspection
    init(inspection: DevVlogsPhase0BMediaInspection) { self.inspection = inspection }
    func inspect(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection { inspection }
    func cancel() {}
}

nonisolated private final class Phase0BCancellableInspector:
    DevVlogsPhase0BMediaInspecting, @unchecked Sendable {
    let inspection: DevVlogsPhase0BMediaInspection
    private let lock = NSLock()
    private var task: Task<DevVlogsPhase0BMediaInspection, Error>?
    private var storedCancelCount = 0
    var cancelCount: Int { lock.withLock { storedCancelCount } }
    init(inspection: DevVlogsPhase0BMediaInspection) { self.inspection = inspection }
    func inspect(fileURL: URL) async throws -> DevVlogsPhase0BMediaInspection {
        let task = Task { try await Task.sleep(for: .seconds(60)); return inspection }
        lock.withLock { self.task = task }
        return try await task.value
    }
    func cancel() {
        let task = lock.withLock { storedCancelCount += 1; return self.task }
        task?.cancel()
    }
}
#endif
