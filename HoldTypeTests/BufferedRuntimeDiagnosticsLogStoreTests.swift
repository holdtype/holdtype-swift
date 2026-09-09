import Foundation
import Testing
@testable import HoldType

@MainActor
struct BufferedRuntimeDiagnosticsLogStoreTests {
    @Test func slowDiskDoesNotBlockProducerAndReadIncludesQueuedEvents() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = BlockingLogFileManager()
        let store = BufferedRuntimeDiagnosticsLogStore(
            store: RuntimeDiagnosticsLogStore(directoryURL: directory, fileManager: manager), capacity: 4
        )
        store.record(RuntimeDiagnosticEvent(category: "test", name: "first"))
        // Observe the writer reaching disk without blocking the main actor.
        for _ in 0..<100 where !manager.hasEntered {
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(manager.hasEntered)
        let clock = ContinuousClock()
        let started = clock.now
        store.record(RuntimeDiagnosticEvent(category: "test", name: "second"))
        #expect(started.duration(to: clock.now) < .milliseconds(50))
        manager.release()
        let lines = try store.recentLogLines(limit: 10)
        #expect(lines.count == 2)
        #expect(lines[0].contains("event=first"))
        #expect(lines[1].contains("event=second"))
    }

    @Test func enqueueCostComparedWithSynchronousWriter() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = RuntimeDiagnosticsLogStore(directoryURL: directory)
        let buffered = BufferedRuntimeDiagnosticsLogStore(store: disk)
        let event = RuntimeDiagnosticEvent(category: "test", name: "benchmark")
        let clock = ContinuousClock()
        let syncStart = clock.now
        for _ in 0..<100 { disk.record(event) }
        let syncTime = syncStart.duration(to: clock.now)
        let bufferedStart = clock.now
        for _ in 0..<100 { buffered.record(event) }
        let bufferedTime = bufferedStart.duration(to: clock.now)
        #expect(try buffered.recentLogLines(limit: 300).count == 200)
        print("Log producer 100 events: synchronous=\(syncTime), buffered=\(bufferedTime)")
    }
}

nonisolated private final class BlockingLogFileManager: FileManager, @unchecked Sendable {
    private let lock = NSLock()
    private let gate = DispatchSemaphore(value: 0)
    private var entered = false
    var hasEntered: Bool { lock.withLock { entered } }
    func release() { gate.signal() }
    override func createDirectory(at url: URL, withIntermediateDirectories create: Bool,
                                  attributes: [FileAttributeKey: Any]? = nil) throws {
        let first = lock.withLock { let first = !entered; entered = true; return first }
        if first { _ = gate.wait(timeout: .now() + 2) }
        try super.createDirectory(at: url, withIntermediateDirectories: create, attributes: attributes)
    }
}
