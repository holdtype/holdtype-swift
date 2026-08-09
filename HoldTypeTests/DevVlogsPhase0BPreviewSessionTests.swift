#if DEBUG
import CoreImage
import CoreVideo
import Foundation
import XCTest
@testable import HoldType

@MainActor
final class DevVlogsPhase0BPreviewSessionTests: XCTestCase {
    func testIdleIsPassiveSelectionIsExactAndRepeatedStartIsSuppressed() async throws {
        let graph = PreviewGraphFake(frame: makeImage(width: 2))
        let platform = PreviewPlatformFake(graphs: [graph])
        let session = DevVlogsPhase0BPreviewSession(platform: platform)
        XCTAssertEqual(session.state, .idle)
        XCTAssertEqual(platform.makeGraphCount, 0)

        session.start()
        XCTAssertEqual(session.state, .failed(.selectionRequired))
        XCTAssertEqual(platform.makeGraphCount, 0)
        session.selectedCameraID = "exact"
        session.start()
        session.start()
        await settle()
        XCTAssertEqual(platform.requestedIDs, ["exact"])
        XCTAssertEqual(graph.startCount, 1)
        XCTAssertEqual(session.state, .previewing)
        XCTAssertEqual(session.frame?.width, 2)
    }

    func testNonAuthorizedStatesFailWithoutConstructingAGraph() {
        let expectations: [(DevVlogsPhase0BPreviewAuthorization, DevVlogsPhase0BPreviewFailure)] = [
            (.notDetermined, .authorizationRequired),
            (.denied, .authorizationDenied),
            (.restricted, .authorizationRestricted),
        ]
        for (authorization, failure) in expectations {
            let platform = PreviewPlatformFake(authorization: authorization, graphs: [])
            let session = DevVlogsPhase0BPreviewSession(
                platform: platform,
                selectedCameraID: "exact"
            )
            session.start()
            XCTAssertEqual(session.state, .failed(failure))
            XCTAssertEqual(platform.makeGraphCount, 0)
        }
    }

    func testMissingBusyDisconnectRuntimeAndConversionFailuresAreTyped() async {
        let missingPlatform = PreviewPlatformFake(graphs: [])
        let missing = DevVlogsPhase0BPreviewSession(
            platform: missingPlatform,
            selectedCameraID: "other"
        )
        missing.start()
        XCTAssertEqual(missing.state, .failed(.selectedDeviceMissing))

        let busyPlatform = PreviewPlatformFake(factoryFailure: .selectedDeviceBusy)
        let busy = DevVlogsPhase0BPreviewSession(platform: busyPlatform, selectedCameraID: "exact")
        busy.start()
        XCTAssertEqual(busy.state, .failed(.selectedDeviceBusy))

        for failure in [
            DevVlogsPhase0BPreviewFailure.disconnected,
            .runtimeFailure,
            .frameConversionFailed,
        ] {
            let graph = PreviewGraphFake(startFailure: failure)
            let session = DevVlogsPhase0BPreviewSession(
                platform: PreviewPlatformFake(graphs: [graph]),
                selectedCameraID: "exact"
            )
            session.start()
            await settle()
            XCTAssertEqual(session.state, .failed(failure))
            XCTAssertEqual(graph.stopCount, 1)
        }
    }

    func testFrameConversionAndLatestOnlyCoalescingAreDeterministic() throws {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            3,
            2,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        let buffer = try XCTUnwrap(pixelBuffer)
        let converted = try XCTUnwrap(
            DevVlogsPhase0BPreviewFrameConverter().makeImage(
                pixelBuffer: buffer
            )
        )
        XCTAssertEqual(converted.width, 3)
        XCTAssertEqual(converted.height, 2)

        var scheduled: [@MainActor () -> Void] = []
        var publishedWidths: [Int] = []
        let coalescer = DevVlogsPhase0BPreviewFrameCoalescer(
            schedule: { scheduled.append($0) },
            publish: { publishedWidths.append($0.width) }
        )
        coalescer.submit(makeImage(width: 1))
        coalescer.submit(makeImage(width: 4))
        XCTAssertEqual(scheduled.count, 1)
        scheduled.removeFirst()()
        XCTAssertEqual(publishedWidths, [4])
        coalescer.invalidate()
        coalescer.submit(makeImage(width: 8))
        XCTAssertEqual(publishedWidths, [4])
    }

    func testStopIsExactOnceClearsFrameAndIgnoresLateFrames() async {
        let graph = PreviewGraphFake(frame: makeImage(width: 2))
        let session = DevVlogsPhase0BPreviewSession(
            platform: PreviewPlatformFake(graphs: [graph]),
            selectedCameraID: "exact"
        )
        session.start()
        await settle()
        XCTAssertNotNil(session.frame)
        async let first: Void = session.stop()
        async let second: Void = session.stop()
        _ = await (first, second)
        XCTAssertEqual(graph.stopCount, 1)
        XCTAssertEqual(graph.events, ["start", "stop"])
        XCTAssertEqual(session.state, .stopped)
        XCTAssertNil(session.frame)
        graph.emitFrame(makeImage(width: 9))
        await settle()
        XCTAssertNil(session.frame)
        XCTAssertEqual(session.state, .stopped)
    }

    func testCancelWhileStartingCleansUpBeforeStopped() async {
        let graph = PreviewGraphFake(suspendStart: true)
        let session = DevVlogsPhase0BPreviewSession(
            platform: PreviewPlatformFake(graphs: [graph]),
            selectedCameraID: "exact"
        )
        session.start()
        await settle()
        XCTAssertEqual(session.state, .starting)
        await session.stop()
        XCTAssertEqual(graph.stopCount, 1)
        XCTAssertEqual(session.state, .stopped)
        XCTAssertNil(session.frame)
    }

    func testStartStopStartCreatesAFreshGraph() async {
        let first = PreviewGraphFake(frame: makeImage(width: 1))
        let second = PreviewGraphFake(frame: makeImage(width: 2))
        let platform = PreviewPlatformFake(graphs: [first, second])
        let session = DevVlogsPhase0BPreviewSession(
            platform: platform,
            selectedCameraID: "exact"
        )
        session.start()
        await settle()
        await session.stop()
        session.start()
        await settle()
        XCTAssertEqual(platform.makeGraphCount, 2)
        XCTAssertEqual(first.stopCount, 1)
        XCTAssertEqual(second.startCount, 1)
        XCTAssertEqual(session.state, .previewing)
        XCTAssertEqual(session.frame?.width, 2)
        await session.stop()
    }

    func testSourceUsesDisplayOnlyMirrorAndNoMediaOrFormatMutation() throws {
        let sessionSource = try ownedSource("DevVlogsPhase0BPreviewSession.swift")
        let viewSource = try ownedSource("DevVlogsPhase0BPreviewView.swift")
        let forbidden = [
            "AVCaptureMovieFileOutput", "AVCaptureAudioDataOutput", "AVCaptureVideoPreviewLayer",
            "NSViewRepresentable", "isVideoMirrored", "activeFormat", "sessionPreset", "videoSettings",
        ]
        XCTAssertTrue([sessionSource, viewSource].allSatisfy { source in
            source.hasPrefix("#if DEBUG") && forbidden.allSatisfy { !source.contains($0) }
        })
        let requiredSession = [
            "AVCaptureVideoDataOutput", "alwaysDiscardsLateVideoFrames = true",
            "setSampleBufferDelegate(nil",
        ]
        let requiredView = [
            ".scaleEffect(x: -1, y: 1)", "#Preview(\"Idle\")", "#Preview(\"Previewing\")",
            "#Preview(\"Failure\")", "devVlogsPhase0B.preview.cameraPicker",
            "devVlogsPhase0B.preview.start", "devVlogsPhase0B.preview.stop",
            "devVlogsPhase0B.preview.status",
        ]
        XCTAssertTrue(requiredSession.allSatisfy(sessionSource.contains))
        XCTAssertTrue(requiredView.allSatisfy(viewSource.contains))

        let sessionStop = try sourceSlice(
            sessionSource,
            after: "final class DevVlogsPhase0BPreviewSession",
            from: "func stop() async {",
            until: "private func performStart"
        )
        try assertOrdered([
            "generation += 1", "startTask?.cancel()", "coalescer?.invalidate()",
            "self.graph = nil", "await graph?.stop()", "frame = nil", "state = .stopped",
        ], in: sessionStop)

        let graphStop = try sourceSlice(
            sessionSource,
            after: "private final class DevVlogsPhase0BApplePreviewGraph",
            from: "func stop() async {",
            until: "private func configureAndStart"
        )
        try assertOrdered([
            "isActive = false", "setSampleBufferDelegate(nil", "removeObserver",
            "stopRunning()", "session = nil", "self.output = nil",
        ], in: graphStop)
    }

    private func settle() async {
        for _ in 0 ..< 8 { await Task.yield() }
    }

    private func makeImage(width: Int) -> CGImage {
        let context = CGContext(
            data: nil,
            width: width,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        return context.makeImage()!
    }

    private func ownedSource(_ name: String) throws -> String {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        return try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "HoldType/Debug/DevVlogsPhase0B/\(name)"
            ),
            encoding: .utf8
        )
    }

    private func sourceSlice(
        _ source: String,
        after owner: String,
        from start: String,
        until end: String
    ) throws -> Substring {
        let ownerRange = try XCTUnwrap(source.range(of: owner))
        let ownerTail = source[ownerRange.upperBound...]
        let startRange = try XCTUnwrap(ownerTail.range(of: start))
        let startTail = ownerTail[startRange.lowerBound...]
        let endRange = try XCTUnwrap(startTail.range(of: end))
        return startTail[..<endRange.lowerBound]
    }

    private func assertOrdered(_ tokens: [String], in source: Substring) throws {
        var tail = source
        for token in tokens {
            let range = try XCTUnwrap(tail.range(of: token), "Missing ordered token: \(token)")
            tail = tail[range.upperBound...]
        }
    }
}

@MainActor
private final class PreviewPlatformFake: DevVlogsPhase0BPreviewPlatform {
    let cameras = [DevVlogsPhase0BPreviewCamera(id: "exact", label: "Camera")]
    let authorization: DevVlogsPhase0BPreviewAuthorization
    let factoryFailure: DevVlogsPhase0BPreviewFailure?
    private var graphs: [PreviewGraphFake]
    private(set) var requestedIDs: [String] = []
    var makeGraphCount: Int { requestedIDs.count }

    init(
        authorization: DevVlogsPhase0BPreviewAuthorization = .authorized,
        graphs: [PreviewGraphFake] = [],
        factoryFailure: DevVlogsPhase0BPreviewFailure? = nil
    ) {
        self.authorization = authorization
        self.graphs = graphs
        self.factoryFailure = factoryFailure
    }

    func authorizationStatus() -> DevVlogsPhase0BPreviewAuthorization { authorization }

    func makeGraph(cameraID: String) throws -> any DevVlogsPhase0BPreviewGraph {
        requestedIDs.append(cameraID)
        if let factoryFailure { throw factoryFailure }
        return graphs.removeFirst()
    }
}

nonisolated private final class PreviewGraphFake: DevVlogsPhase0BPreviewGraph, @unchecked Sendable {
    private let lock = NSLock()
    private let frame: CGImage?
    private let startFailure: DevVlogsPhase0BPreviewFailure?
    private let suspendStart: Bool
    private var frameHandler: (@Sendable (CGImage) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var events: [String] = []

    init(
        frame: CGImage? = nil,
        startFailure: DevVlogsPhase0BPreviewFailure? = nil,
        suspendStart: Bool = false
    ) {
        self.frame = frame
        self.startFailure = startFailure
        self.suspendStart = suspendStart
    }

    func start(
        onFrame: @escaping @Sendable (CGImage) -> Void,
        onFailure: @escaping @Sendable (DevVlogsPhase0BPreviewFailure) -> Void
    ) async throws {
        lock.withLock {
            startCount += 1
            events.append("start")
            frameHandler = onFrame
        }
        if let startFailure { throw startFailure }
        if suspendStart {
            try await Task.sleep(for: .seconds(60))
        } else if let frame {
            onFrame(frame)
        }
    }

    func stop() async {
        lock.withLock {
            stopCount += 1
            events.append("stop")
        }
    }

    func emitFrame(_ image: CGImage) {
        lock.withLock { frameHandler }?(image)
    }
}
#endif
