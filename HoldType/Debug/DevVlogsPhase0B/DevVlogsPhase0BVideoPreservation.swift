#if DEBUG
@preconcurrency import AVFoundation
import CoreMedia
import Foundation

struct DevVlogsPhase0BVideoPreservationResult: Equatable {
    static let method = "stored_sample_exact_v1"
    let sampleCount: Int
    let encodedByteCount: Int64
    let mediaSubtype: String
}

struct DevVlogsPhase0BVideoTrackPreservationEvidence: Equatable {
    let formatDescriptionsEqual: Bool
    let encodedDimensionsEqual: Bool
    let naturalDimensionsEqual: Bool
    let displayDimensionsEqual: Bool
    let sourceTransform: CGAffineTransform
    let finalizedTransform: CGAffineTransform
    let mediaSubtype: String
}

enum DevVlogsPhase0BVideoPreservationError: Error, Equatable {
    case expectedOneVideoTrack
    case readerUnavailable
    case readingFailed(DevVlogsPhase0BVideoPreservationReaderFailureDetail)
    case sampleCountMismatch
    case sampleBoundaryMismatch
    case encodedPayloadMismatch
    case sampleDurationMismatch
    case presentationTimestampMismatch
    case decodeTimestampMismatch
    case formatDescriptionMismatch
    case dimensionsMismatch
    case transformMismatch
    case cancelled
    case timedOut
}

enum DevVlogsPhase0BVideoPreservationAssetSide: String, Codable, Equatable, CaseIterable {
    case cameraSource = "camera_source"
    case finalized
}

enum DevVlogsPhase0BVideoPreservationReaderOperation: String, Codable, Equatable, CaseIterable {
    case sampleDataCopy = "sample_data_copy"
    case sampleSizeTimingMetadata = "sample_size_timing_metadata"
    case readerTerminalStatus = "reader_terminal_status"
}

struct DevVlogsPhase0BVideoPreservationReaderFailureDetail: Codable, Equatable {
    let assetSide: DevVlogsPhase0BVideoPreservationAssetSide
    let operation: DevVlogsPhase0BVideoPreservationReaderOperation
}

struct DevVlogsPhase0BVideoPreservationRequest {
    let cameraFileURL: URL
    let finalizedFileURL: URL
    let expectedInsertionOffset: CMTime
    let timeout: Duration
}

protocol DevVlogsPhase0BVideoPreserving {
    func compare(
        _ request: DevVlogsPhase0BVideoPreservationRequest
    ) async throws -> DevVlogsPhase0BVideoPreservationResult
}

protocol DevVlogsPhase0BStoredVideoComparing: AnyObject, Sendable {
    nonisolated func compare(
        _ request: DevVlogsPhase0BVideoPreservationRequest
    ) async throws -> DevVlogsPhase0BVideoPreservationResult
    nonisolated func cancel()
}

struct DevVlogsPhase0BVideoPreservation: DevVlogsPhase0BVideoPreserving {
    private let comparator: any DevVlogsPhase0BStoredVideoComparing

    init(
        comparator: any DevVlogsPhase0BStoredVideoComparing = DevVlogsPhase0BAppleStoredVideoComparator()
    ) {
        self.comparator = comparator
    }

    func compare(
        _ request: DevVlogsPhase0BVideoPreservationRequest
    ) async throws -> DevVlogsPhase0BVideoPreservationResult {
        let gate = DevVlogsPhase0BPreservationGate()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                gate.install(continuation)
                Task.detached {
                    do { gate.resume(.success(try await comparator.compare(request))) }
                    catch { gate.resume(.failure(error)) }
                }
                let timeout = Task {
                    do { try await Task.sleep(for: request.timeout) } catch { return }
                    comparator.cancel()
                    gate.resume(.failure(DevVlogsPhase0BVideoPreservationError.timedOut))
                }
                gate.installTimeout(timeout)
            }
        } onCancel: {
            comparator.cancel()
            gate.resume(.failure(DevVlogsPhase0BVideoPreservationError.cancelled))
        }
    }
}

nonisolated final class DevVlogsPhase0BAppleStoredVideoComparator:
    DevVlogsPhase0BStoredVideoComparing, @unchecked Sendable {
    private let lock = NSLock()
    private var currentReaders: [AVAssetReader] = []
    private var currentAssets: [AVURLAsset] = []

    func compare(
        _ request: DevVlogsPhase0BVideoPreservationRequest
    ) async throws -> DevVlogsPhase0BVideoPreservationResult {
        let cameraAsset = AVURLAsset(url: request.cameraFileURL)
        let finalizedAsset = AVURLAsset(url: request.finalizedFileURL)
        lock.withLock { currentAssets = [cameraAsset, finalizedAsset] }
        defer { lock.withLock { currentAssets = []; currentReaders = [] } }
        let cameraTracks = try await cameraAsset.loadTracks(withMediaType: .video)
        let finalizedTracks = try await finalizedAsset.loadTracks(withMediaType: .video)
        guard cameraTracks.count == 1, finalizedTracks.count == 1,
              let cameraTrack = cameraTracks.first, let finalizedTrack = finalizedTracks.first else {
            throw DevVlogsPhase0BVideoPreservationError.expectedOneVideoTrack
        }
        let mediaSubtype = try await compareTrackMetadata(cameraTrack, finalizedTrack)
        return try compareStoredSamples(
            cameraAsset: cameraAsset,
            cameraTrack: cameraTrack,
            finalizedAsset: finalizedAsset,
            finalizedTrack: finalizedTrack,
            expectedOffset: request.expectedInsertionOffset,
            mediaSubtype: mediaSubtype
        )
    }

    func cancel() {
        let values = lock.withLock { (currentReaders, currentAssets) }
        values.0.forEach { $0.cancelReading() }
        values.1.forEach { $0.cancelLoading() }
    }

    private func compareTrackMetadata(
        _ camera: AVAssetTrack,
        _ finalized: AVAssetTrack
    ) async throws -> String {
        async let cameraDescriptions = camera.load(.formatDescriptions)
        async let finalDescriptions = finalized.load(.formatDescriptions)
        async let cameraNatural = camera.load(.naturalSize)
        async let finalNatural = finalized.load(.naturalSize)
        async let cameraTransform = camera.load(.preferredTransform)
        async let finalTransform = finalized.load(.preferredTransform)
        let descriptions = try await (cameraDescriptions, finalDescriptions)
        let descriptionsEqual = descriptions.0.count == descriptions.1.count &&
            zip(descriptions.0, descriptions.1).allSatisfy({
                  CMFormatDescriptionEqual($0, otherFormatDescription: $1)
            })
        let encodedDimensionsEqual = descriptions.0.count == descriptions.1.count &&
            zip(descriptions.0, descriptions.1).allSatisfy {
                let source = CMVideoFormatDescriptionGetDimensions($0)
                let output = CMVideoFormatDescriptionGetDimensions($1)
                return source.width == output.width && source.height == output.height
            }
        let natural = try await (cameraNatural, finalNatural)
        let transforms = try await (cameraTransform, finalTransform)
        guard let description = descriptions.0.first else {
            throw DevVlogsPhase0BVideoPreservationError.formatDescriptionMismatch
        }
        let evidence = DevVlogsPhase0BVideoTrackPreservationEvidence(
            formatDescriptionsEqual: descriptionsEqual,
            encodedDimensionsEqual: encodedDimensionsEqual,
            naturalDimensionsEqual: natural.0 == natural.1,
            displayDimensionsEqual: Self.displayDimensions(natural.0, transforms.0) ==
                Self.displayDimensions(natural.1, transforms.1),
            sourceTransform: transforms.0,
            finalizedTransform: transforms.1,
            mediaSubtype: Self.fourCC(CMFormatDescriptionGetMediaSubType(description))
        )
        return try Self.validate(evidence)
    }

    static func validate(_ evidence: DevVlogsPhase0BVideoTrackPreservationEvidence) throws -> String {
        guard evidence.formatDescriptionsEqual else {
            throw DevVlogsPhase0BVideoPreservationError.formatDescriptionMismatch
        }
        guard evidence.encodedDimensionsEqual, evidence.naturalDimensionsEqual,
              evidence.displayDimensionsEqual else {
            throw DevVlogsPhase0BVideoPreservationError.dimensionsMismatch
        }
        guard evidence.sourceTransform == evidence.finalizedTransform else {
            throw DevVlogsPhase0BVideoPreservationError.transformMismatch
        }
        return evidence.mediaSubtype
    }

    private func compareStoredSamples(
        cameraAsset: AVAsset,
        cameraTrack: AVAssetTrack,
        finalizedAsset: AVAsset,
        finalizedTrack: AVAssetTrack,
        expectedOffset: CMTime,
        mediaSubtype: String
    ) throws -> DevVlogsPhase0BVideoPreservationResult {
        let cameraReader = try AVAssetReader(asset: cameraAsset)
        let finalizedReader = try AVAssetReader(asset: finalizedAsset)
        let cameraOutput = AVAssetReaderTrackOutput(track: cameraTrack, outputSettings: nil)
        let finalizedOutput = AVAssetReaderTrackOutput(track: finalizedTrack, outputSettings: nil)
        guard cameraReader.canAdd(cameraOutput), finalizedReader.canAdd(finalizedOutput) else {
            throw DevVlogsPhase0BVideoPreservationError.readerUnavailable
        }
        cameraReader.add(cameraOutput)
        finalizedReader.add(finalizedOutput)
        lock.withLock { currentReaders = [cameraReader, finalizedReader] }
        guard cameraReader.startReading(), finalizedReader.startReading() else {
            throw DevVlogsPhase0BVideoPreservationError.readerUnavailable
        }
        var sampleCount = 0
        var encodedBytes: Int64 = 0
        while true {
            if Task.isCancelled { throw DevVlogsPhase0BVideoPreservationError.cancelled }
            let cameraSample = cameraOutput.copyNextSampleBuffer()
            let finalizedSample = finalizedOutput.copyNextSampleBuffer()
            switch (cameraSample, finalizedSample) {
            case (nil, nil):
                try Self.validateReader(cameraReader, side: .cameraSource)
                try Self.validateReader(finalizedReader, side: .finalized)
                return DevVlogsPhase0BVideoPreservationResult(
                    sampleCount: sampleCount,
                    encodedByteCount: encodedBytes,
                    mediaSubtype: mediaSubtype
                )
            case (.some(let camera), .some(let finalized)):
                let byteCount = try Self.compare(camera, finalized, expectedOffset: expectedOffset)
                sampleCount += 1
                encodedBytes += Int64(byteCount)
            default:
                throw DevVlogsPhase0BVideoPreservationError.sampleCountMismatch
            }
        }
    }

    static func compare(
        _ camera: CMSampleBuffer,
        _ finalized: CMSampleBuffer,
        expectedOffset: CMTime
    ) throws -> Int {
        let cameraSize = CMSampleBufferGetTotalSampleSize(camera)
        let finalizedSize = CMSampleBufferGetTotalSampleSize(finalized)
        guard cameraSize == finalizedSize,
              CMSampleBufferGetNumSamples(camera) == CMSampleBufferGetNumSamples(finalized),
              try sampleSizes(camera, side: .cameraSource) ==
              sampleSizes(finalized, side: .finalized) else {
            throw DevVlogsPhase0BVideoPreservationError.sampleBoundaryMismatch
        }
        switch (CMSampleBufferGetFormatDescription(camera),
                CMSampleBufferGetFormatDescription(finalized)) {
        case (nil, nil): break
        case (.some(let source), .some(let output)):
            guard CMFormatDescriptionEqual(source, otherFormatDescription: output) else {
                throw DevVlogsPhase0BVideoPreservationError.formatDescriptionMismatch
            }
        default:
            throw DevVlogsPhase0BVideoPreservationError.formatDescriptionMismatch
        }
        let sourceTiming = try sampleTiming(camera, side: .cameraSource)
        let outputTiming = try sampleTiming(finalized, side: .finalized)
        guard !sourceTiming.isEmpty, sourceTiming.count == outputTiming.count else {
            throw DevVlogsPhase0BVideoPreservationError.sampleBoundaryMismatch
        }
        for (source, output) in zip(sourceTiming, outputTiming) {
            guard source.duration == output.duration else {
                throw DevVlogsPhase0BVideoPreservationError.sampleDurationMismatch
            }
            try compareTimestamp(
                source.presentationTimeStamp,
                output.presentationTimeStamp,
                offset: expectedOffset,
                mismatch: .presentationTimestampMismatch
            )
            try compareTimestamp(
                source.decodeTimeStamp,
                output.decodeTimeStamp,
                offset: expectedOffset,
                mismatch: .decodeTimestampMismatch
            )
        }
        guard try sampleData(camera, side: .cameraSource) ==
              sampleData(finalized, side: .finalized) else {
            throw DevVlogsPhase0BVideoPreservationError.encodedPayloadMismatch
        }
        return cameraSize
    }

    static func compareSequence(
        camera: [CMSampleBuffer],
        finalized: [CMSampleBuffer],
        expectedOffset: CMTime
    ) throws -> (sampleCount: Int, encodedByteCount: Int64) {
        guard camera.count == finalized.count else {
            throw DevVlogsPhase0BVideoPreservationError.sampleCountMismatch
        }
        var byteCount: Int64 = 0
        for (source, output) in zip(camera, finalized) {
            byteCount += Int64(try compare(source, output, expectedOffset: expectedOffset))
        }
        return (camera.count, byteCount)
    }

    private static func compareTimestamp(
        _ source: CMTime,
        _ finalized: CMTime,
        offset: CMTime,
        mismatch: DevVlogsPhase0BVideoPreservationError
    ) throws {
        if !source.isValid && !finalized.isValid { return }
        guard source.isValid, finalized.isValid,
              CMTimeCompare(CMTimeSubtract(finalized, source), offset) == 0 else {
            throw mismatch
        }
    }

    private static func sampleData(
        _ sample: CMSampleBuffer,
        side: DevVlogsPhase0BVideoPreservationAssetSide
    ) throws -> Data {
        guard let buffer = CMSampleBufferGetDataBuffer(sample) else {
            throw DevVlogsPhase0BVideoPreservationError.sampleBoundaryMismatch
        }
        let length = CMBlockBufferGetDataLength(buffer)
        guard length > 0 else { return Data() }
        var data = Data(count: length)
        let status = data.withUnsafeMutableBytes { bytes in
            guard let destination = bytes.baseAddress else {
                return kCMBlockBufferBadLengthParameterErr
            }
            return CMBlockBufferCopyDataBytes(
                buffer,
                atOffset: 0,
                dataLength: length,
                destination: destination
            )
        }
        guard status == kCMBlockBufferNoErr else {
            throw readerFailure(side: side, operation: .sampleDataCopy)
        }
        return data
    }

    private static func sampleSizes(
        _ sample: CMSampleBuffer,
        side: DevVlogsPhase0BVideoPreservationAssetSide
    ) throws -> [Int] {
        var count = 0
        guard CMSampleBufferGetSampleSizeArray(
            sample,
            entryCount: 0,
            arrayToFill: nil,
            entriesNeededOut: &count
        ) == noErr else {
            throw readerFailure(side: side, operation: .sampleSizeTimingMetadata)
        }
        var sizes = [Int](repeating: 0, count: count)
        guard CMSampleBufferGetSampleSizeArray(
            sample,
            entryCount: count,
            arrayToFill: &sizes,
            entriesNeededOut: &count
        ) == noErr else {
            throw readerFailure(side: side, operation: .sampleSizeTimingMetadata)
        }
        return sizes
    }

    private static func sampleTiming(
        _ sample: CMSampleBuffer,
        side: DevVlogsPhase0BVideoPreservationAssetSide
    ) throws -> [CMSampleTimingInfo] {
        var count = 0
        guard CMSampleBufferGetSampleTimingInfoArray(
            sample,
            entryCount: 0,
            arrayToFill: nil,
            entriesNeededOut: &count
        ) == noErr else {
            throw readerFailure(side: side, operation: .sampleSizeTimingMetadata)
        }
        let empty = CMSampleTimingInfo(
            duration: .invalid,
            presentationTimeStamp: .invalid,
            decodeTimeStamp: .invalid
        )
        var timing = [CMSampleTimingInfo](repeating: empty, count: count)
        guard CMSampleBufferGetSampleTimingInfoArray(
            sample,
            entryCount: count,
            arrayToFill: &timing,
            entriesNeededOut: &count
        ) == noErr else {
            throw readerFailure(side: side, operation: .sampleSizeTimingMetadata)
        }
        return timing
    }

    private static func validateReader(
        _ reader: AVAssetReader,
        side: DevVlogsPhase0BVideoPreservationAssetSide
    ) throws {
        switch reader.status {
        case .completed: return
        case .cancelled: throw DevVlogsPhase0BVideoPreservationError.cancelled
        default: throw readerFailure(side: side, operation: .readerTerminalStatus)
        }
    }

    static func readerFailure(
        side: DevVlogsPhase0BVideoPreservationAssetSide,
        operation: DevVlogsPhase0BVideoPreservationReaderOperation
    ) -> DevVlogsPhase0BVideoPreservationError {
        .readingFailed(.init(assetSide: side, operation: operation))
    }

    private static func displayDimensions(_ size: CGSize, _ transform: CGAffineTransform) -> CGSize {
        let value = size.applying(transform)
        return CGSize(width: abs(value.width), height: abs(value.height))
    }

    private static func fourCC(_ value: FourCharCode) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((value >> UInt32($0)) & 0xFF) }
        guard bytes.allSatisfy({ (0x20 ... 0x7E).contains($0) }) else { return "unknown" }
        return String(bytes: bytes, encoding: .ascii) ?? "unknown"
    }
}

nonisolated final class DevVlogsPhase0BPreservationGate: @unchecked Sendable {
    typealias Result = Swift.Result<DevVlogsPhase0BVideoPreservationResult, Error>
    private let lock = NSLock()
    private var continuation: CheckedContinuation<DevVlogsPhase0BVideoPreservationResult, Error>?
    private var pending: Result?
    private var timeoutTask: Task<Void, Never>?

    func install(_ continuation: CheckedContinuation<DevVlogsPhase0BVideoPreservationResult, Error>) {
        lock.lock()
        if let pending {
            lock.unlock()
            continuation.resume(with: pending)
            return
        }
        self.continuation = continuation
        lock.unlock()
    }

    func installTimeout(_ task: Task<Void, Never>) {
        lock.lock()
        guard pending == nil, continuation != nil else { lock.unlock(); task.cancel(); return }
        timeoutTask = task
        lock.unlock()
    }

    func resume(_ result: Result) {
        lock.lock()
        guard pending == nil else { lock.unlock(); return }
        pending = result
        let continuation = self.continuation
        self.continuation = nil
        let timeoutTask = self.timeoutTask
        self.timeoutTask = nil
        lock.unlock()
        timeoutTask?.cancel()
        continuation?.resume(with: result)
    }
}
#endif
