import Foundation
import Testing
@testable import HoldType

@MainActor
struct QueuedAudioRecorderFinalizationTests {
    @Test func stopWaitsForFileCompletionEvenAfterCaptureHasStopped() async throws {
        let native = DeferredNativeRecorder()
        let engine = QueuedAudioRecorderEngine(makeEngine: { native })
        #expect(try await engine.record(forDuration: 10))
        var returned = false
        let stop = Task { try await engine.stop(); returned = true }
        try await native.waitForStop()
        #expect(!returned)
        native.completeFile()
        try await stop.value
        #expect(returned)
        // Subsequent stops must not wait for another delegate callback.
        try await engine.stop()
    }

    @Test func completionBeforeStopAndDuplicateCallbacksAreSafe() async throws {
        let native = DeferredNativeRecorder()
        let engine = QueuedAudioRecorderEngine(makeEngine: { native })
        _ = try await engine.record(forDuration: 10)
        native.completeFile()
        native.completeFile()
        try await engine.stop()
    }

    @Test func missingCallbackTimesOutAndLateCompletionDoesNotResumeTwice() async throws {
        let native = DeferredNativeRecorder()
        let engine = QueuedAudioRecorderEngine(makeEngine: { native }, stopTimeout: 0.03)
        _ = try await engine.record(forDuration: 10)
        await #expect(throws: AudioRecorderServiceError.stopFailed) { try await engine.stop() }
        native.completeFile()
        #expect(native.deleteCount == 0)
    }

    @Test func cancelledWaitStillStopsCaptureAndPreservesAudio() async throws {
        let native = DeferredNativeRecorder()
        let engine = QueuedAudioRecorderEngine(makeEngine: { native })
        _ = try await engine.record(forDuration: 10)
        let stop = Task { try await engine.stop() }
        try await native.waitForStop()
        stop.cancel()
        await #expect(throws: CancellationError.self) { try await stop.value }
        native.completeFile()
        #expect(native.deleteCount == 0)
    }

    @Test func concurrentStopWaitersJoinOneCompletion() async throws {
        let native = DeferredNativeRecorder()
        let engine = QueuedAudioRecorderEngine(makeEngine: { native })
        _ = try await engine.record(forDuration: 10)
        async let first: Void = engine.stop()
        async let second: Void = engine.stop()
        try await native.waitForStop()
        native.completeFile()
        _ = try await (first, second)
    }
}

nonisolated private final class DeferredNativeRecorder: NativeAudioRecorderEngine, @unchecked Sendable {
    private let lock = NSLock()
    private var waiters: [@Sendable () -> Void] = []
    private var completed = false
    private var requested = false
    private var deletions = 0
    var currentTime: TimeInterval { 2 }
    var deleteCount: Int { lock.withLock { deletions } }
    func record(forDuration duration: TimeInterval) -> Bool { true }
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) {}
    func stop() { lock.withLock { requested = true } }
    func stop(completion: @escaping @Sendable () -> Void) {
        let finished = lock.withLock {
            requested = true
            if completed { return true }
            waiters.append(completion)
            return false
        }
        if finished { completion() }
    }
    func deleteRecording() -> Bool { lock.withLock { deletions += 1 }; return true }
    func completeFile() {
        let callbacks = lock.withLock {
            completed = true
            let callbacks = waiters
            waiters.removeAll()
            return callbacks
        }
        callbacks.forEach { $0() }
    }
    func waitForStop() async throws {
        for _ in 0..<100 {
            if lock.withLock({ requested }) { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw CocoaError(.fileReadUnknown)
    }
}
