import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsCameraStartRaceTests {
    @Test func lateStartFailureCannotEraseReplacementCaptureOwnership() async throws {
        let oldSession = PendingCameraSession(shouldWait: true)
        let nextSession = PendingCameraSession(shouldWait: false)
        var count = 0
        let service = AVFoundationDevVlogsCameraCaptureService(maximumOperationWait: .seconds(2)) { _, _ in
            count += 1
            return count == 1 ? oldSession : nextSession
        }
        let url = URL(fileURLWithPath: "/tmp/holdtype-camera-race-fixture.mov")
        let oldStart = Task { @MainActor in
            try await service.startCapture(cameraID: "camera", outputURL: url, onStarted: { _ in })
        }
        for _ in 0..<100 where oldSession.continuation == nil { await Task.yield() }
        #expect(oldSession.continuation != nil)
        await service.cancelCurrentCapture()
        let nextID = try await service.startCapture(cameraID: "camera", outputURL: url, onStarted: { _ in })
        oldSession.continuation?.resume(throwing: DevVlogsCameraCaptureError.startFailed)
        await #expect(throws: DevVlogsCameraCaptureError.startFailed) { try await oldStart.value }
        _ = try await service.stopCapture(id: nextID)
        #expect(nextSession.stopCount == 1)
    }
}

@MainActor
private final class PendingCameraSession: DevVlogsCameraSessionControlling {
    let shouldWait: Bool
    var continuation: CheckedContinuation<Void, Error>?
    var stopCount = 0
    init(shouldWait: Bool) { self.shouldWait = shouldWait }
    func start(cameraID: String) async throws {
        if shouldWait { try await withCheckedThrowingContinuation { continuation = $0 } }
    }
    func stop() async throws -> DevVlogsCameraCaptureResult {
        stopCount += 1
        return DevVlogsCameraCaptureResult(fileURL: URL(fileURLWithPath: "/tmp/holdtype-camera-race-fixture.mov"),
                                          duration: 1, startedAtUptime: 0)
    }
    func forceStop() {}
}
