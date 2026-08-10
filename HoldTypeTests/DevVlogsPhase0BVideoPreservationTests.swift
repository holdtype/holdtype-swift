#if DEBUG
import CoreMedia
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BVideoPreservationTests {
    @Test func everyTypedErrorHasOneClosedRedactedDimension() {
        let mappings: [(DevVlogsPhase0BVideoPreservationError,
                        DevVlogsPhase0BVideoPreservationFailureDimension)] = [
            (.expectedOneVideoTrack, .expectedOneVideoTrack),
            (.readerUnavailable, .readerUnavailable),
            (.readingFailed(.init(assetSide: .cameraSource, operation: .sampleDataCopy)),
             .readingFailed),
            (.sampleCountMismatch, .sampleCountMismatch),
            (.sampleBoundaryMismatch, .sampleBoundaryMismatch),
            (.encodedPayloadMismatch, .encodedPayloadMismatch),
            (.sampleDurationMismatch, .sampleDurationMismatch),
            (.presentationTimestampMismatch, .presentationTimestampMismatch),
            (.decodeTimestampMismatch, .decodeTimestampMismatch),
            (.formatDescriptionMismatch, .formatDescriptionMismatch),
            (.dimensionsMismatch, .dimensionsMismatch), (.transformMismatch, .transformMismatch),
            (.cancelled, .cancelled), (.timedOut, .timedOut),
        ]
        #expect(mappings.count == DevVlogsPhase0BVideoPreservationFailureDimension.allCases.count - 1)
        for (error, expected) in mappings {
            #expect(DevVlogsPhase0BVideoPreservationFailureDimension(error: error) == expected)
        }
        #expect(DevVlogsPhase0BVideoPreservationFailureDimension(error: MaliciousError()) == .unknown)
        let values = DevVlogsPhase0BVideoPreservationFailureDimension.allCases.map(\.rawValue)
        #expect(Set(values).count == values.count)
        #expect(values.allSatisfy { !$0.contains("/") && !$0.contains("private") })
        for side in DevVlogsPhase0BVideoPreservationAssetSide.allCases {
            for operation in DevVlogsPhase0BVideoPreservationReaderOperation.allCases {
                let detail = DevVlogsPhase0BVideoPreservationReaderFailureDetail(
                    assetSide: side, operation: operation
                )
                let error = DevVlogsPhase0BAppleStoredVideoComparator.readerFailure(
                    side: side, operation: operation
                )
                #expect(DevVlogsPhase0BVideoPreservationFailureDimension(error: error) == .readingFailed)
                #expect(DevVlogsPhase0BVideoPreservationReaderFailureDetail(error: error) == detail)
            }
        }
    }

    @Test func identicalStoredSamplesWithOneConstantInsertionOffsetPass() throws {
        let camera = try [
            sample([1, 2, 3], pts: 0, dts: -0.02, duration: 0.04),
            sample([4, 5], pts: 0.04, dts: 0.02, duration: 0.04),
        ]
        let finalized = try [
            sample([1, 2, 3], pts: 0.25, dts: 0.23, duration: 0.04),
            sample([4, 5], pts: 0.29, dts: 0.27, duration: 0.04),
        ]

        let result = try DevVlogsPhase0BAppleStoredVideoComparator.compareSequence(
            camera: camera,
            finalized: finalized,
            expectedOffset: time(0.25)
        )

        #expect(result.sampleCount == 2)
        #expect(result.encodedByteCount == 5)
        #expect(DevVlogsPhase0BVideoPreservationResult.method == "stored_sample_exact_v1")
    }

    @Test func payloadBoundaryCountAndDurationChangesFailClosed() throws {
        let source = try [sample([1, 2, 3], pts: 0, dts: 0, duration: 0.04)]
        try expect(
            .encodedPayloadMismatch,
            source: source,
            finalized: [sample([1, 9, 3], pts: 0, dts: 0, duration: 0.04)]
        )
        try expect(
            .sampleBoundaryMismatch,
            source: source,
            finalized: [sample([1, 2], pts: 0, dts: 0, duration: 0.04)]
        )
        try expect(.sampleCountMismatch, source: source, finalized: [])
        try expect(
            .sampleDurationMismatch,
            source: source,
            finalized: [sample([1, 2, 3], pts: 0, dts: 0, duration: 0.05)]
        )
    }

    @Test func nonconstantPresentationOrDecodeOffsetFailsClosed() throws {
        let source = try [sample([1], pts: 1, dts: 0.9, duration: 0.04)]
        try expect(
            .presentationTimestampMismatch,
            source: source,
            finalized: [sample([1], pts: 1.3, dts: 1.15, duration: 0.04)],
            offset: 0.25
        )
        try expect(
            .decodeTimestampMismatch,
            source: source,
            finalized: [sample([1], pts: 1.25, dts: 1.2, duration: 0.04)],
            offset: 0.25
        )
    }

    @Test func formatEncodedNaturalDisplayAndTransformEvidenceMustAllMatch() throws {
        let rotation = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1_080, ty: 0)
        let valid = evidence(transform: rotation)
        #expect(try DevVlogsPhase0BAppleStoredVideoComparator.validate(valid) == "hvc1")

        for mismatch in [
            evidence(format: false, transform: rotation),
            evidence(encoded: false, transform: rotation),
            evidence(natural: false, transform: rotation),
            evidence(display: false, transform: rotation),
        ] {
            #expect(throws: DevVlogsPhase0BVideoPreservationError.self) {
                try DevVlogsPhase0BAppleStoredVideoComparator.validate(mismatch)
            }
        }
        let mirrored = CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0)
        #expect(throws: DevVlogsPhase0BVideoPreservationError.transformMismatch) {
            try DevVlogsPhase0BAppleStoredVideoComparator.validate(
                evidence(transform: rotation, finalizedTransform: mirrored)
            )
        }
    }

    @Test func timeoutCancelsComparatorAndLateCompletionCannotReplaceResult() async {
        let comparator = Phase0BPendingStoredVideoComparator()
        let preservation = DevVlogsPhase0BVideoPreservation(comparator: comparator)
        let request = DevVlogsPhase0BVideoPreservationRequest(
            cameraFileURL: URL(fileURLWithPath: "/tmp/run/camera.mov"),
            finalizedFileURL: URL(fileURLWithPath: "/tmp/run/final.mov"),
            expectedInsertionOffset: CMTime(seconds: 0.25, preferredTimescale: 600),
            timeout: .milliseconds(10)
        )
        let clock = ContinuousClock()
        let start = clock.now

        await #expect(throws: DevVlogsPhase0BVideoPreservationError.timedOut) {
            try await preservation.compare(request)
        }
        #expect(clock.now - start < .seconds(1))
        #expect(comparator.cancelCount == 1)
        comparator.complete(.init(sampleCount: 1, encodedByteCount: 3, mediaSubtype: "avc1"))
        await Task.yield()
        #expect(comparator.cancelCount == 1)
    }

    private func expect(
        _ expected: DevVlogsPhase0BVideoPreservationError,
        source: [CMSampleBuffer],
        finalized: [CMSampleBuffer],
        offset: TimeInterval = 0
    ) throws {
        do {
            _ = try DevVlogsPhase0BAppleStoredVideoComparator.compareSequence(
                camera: source,
                finalized: finalized,
                expectedOffset: time(offset)
            )
            Issue.record("Expected preservation mismatch \(expected)")
        } catch let error as DevVlogsPhase0BVideoPreservationError {
            #expect(error == expected)
        }
    }

    private func evidence(
        format: Bool = true,
        encoded: Bool = true,
        natural: Bool = true,
        display: Bool = true,
        transform: CGAffineTransform,
        finalizedTransform: CGAffineTransform? = nil
    ) -> DevVlogsPhase0BVideoTrackPreservationEvidence {
        .init(
            formatDescriptionsEqual: format,
            encodedDimensionsEqual: encoded,
            naturalDimensionsEqual: natural,
            displayDimensionsEqual: display,
            sourceTransform: transform,
            finalizedTransform: finalizedTransform ?? transform,
            mediaSubtype: "hvc1"
        )
    }

    private func sample(
        _ bytes: [UInt8],
        pts: TimeInterval,
        dts: TimeInterval,
        duration: TimeInterval
    ) throws -> CMSampleBuffer {
        var block: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: bytes.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: bytes.count,
            flags: 0,
            blockBufferOut: &block
        )
        guard status == kCMBlockBufferNoErr, let block else {
            throw DevVlogsPhase0BVideoPreservationError.readerUnavailable
        }
        status = bytes.withUnsafeBytes {
            CMBlockBufferReplaceDataBytes(
                with: $0.baseAddress!,
                blockBuffer: block,
                offsetIntoDestination: 0,
                dataLength: bytes.count
            )
        }
        guard status == kCMBlockBufferNoErr else {
            throw DevVlogsPhase0BVideoPreservationError.readingFailed(
                .init(assetSide: .cameraSource, operation: .sampleDataCopy)
            )
        }
        var timing = CMSampleTimingInfo(
            duration: time(duration),
            presentationTimeStamp: time(pts),
            decodeTimeStamp: time(dts)
        )
        var size = bytes.count
        var sample: CMSampleBuffer?
        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: block,
            formatDescription: nil,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &size,
            sampleBufferOut: &sample
        )
        guard status == noErr, let sample else {
            throw DevVlogsPhase0BVideoPreservationError.readingFailed(
                .init(assetSide: .cameraSource, operation: .sampleSizeTimingMetadata)
            )
        }
        return sample
    }

    private func time(_ seconds: TimeInterval) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 60_000)
    }
}

private struct MaliciousError: Error, CustomStringConvertible {
    var description: String { "NSError /tmp/private.mov userInfo sample-bytes" }
}

nonisolated private final class Phase0BPendingStoredVideoComparator:
    DevVlogsPhase0BStoredVideoComparing, @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<DevVlogsPhase0BVideoPreservationResult, Error>?
    private var cancellations = 0
    var cancelCount: Int { lock.withLock { cancellations } }
    func compare(_ request: DevVlogsPhase0BVideoPreservationRequest) async throws
        -> DevVlogsPhase0BVideoPreservationResult {
        try await withCheckedThrowingContinuation { value in
            lock.withLock { continuation = value }
        }
    }
    func cancel() { lock.withLock { cancellations += 1 } }
    func complete(_ result: DevVlogsPhase0BVideoPreservationResult) {
        let value = lock.withLock { let value = continuation; continuation = nil; return value }
        value?.resume(returning: result)
    }
}
#endif
