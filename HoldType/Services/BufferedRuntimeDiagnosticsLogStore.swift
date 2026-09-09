import Foundation

/// Serial disk ownership; the lock protects only the bounded in-memory inbox.
/// No producer waits for filesystem work. Export is an explicit synchronization boundary.
@MainActor
final class BufferedRuntimeDiagnosticsLogStore: RuntimeDiagnosticLogManaging {
    let directoryURL: URL
    private let writer: RuntimeDiagnosticLogWriter

    init(store: RuntimeDiagnosticsLogStore = RuntimeDiagnosticsLogStore(), capacity: Int = 512) {
        directoryURL = store.directoryURL
        writer = RuntimeDiagnosticLogWriter(store: store, capacity: capacity)
    }

    func record(_ event: RuntimeDiagnosticEvent) { writer.enqueue(event, at: Date()) }

    func recentLogLines(limit: Int) throws -> [String] {
        try writer.read { try $0.recentLogLines(limit: limit) }
    }

    func exportRecentLogs(to bundleURL: URL, since startDate: Date) throws -> RuntimeDiagnosticLogExport? {
        try writer.read { try $0.exportRecentLogs(to: bundleURL, since: startDate) }
    }
}

nonisolated private final class RuntimeDiagnosticLogWriter: @unchecked Sendable {
    private struct Entry { let event: RuntimeDiagnosticEvent; let date: Date }
    private let queue = DispatchQueue(label: "app.holdtype.runtime-log", qos: .utility)
    private let lock = NSLock()
    private let store: RuntimeDiagnosticsLogStore
    private let capacity: Int
    private var pending: [Entry] = []
    private var scheduled = false
    private var dropped = 0
    // Accessed exclusively on queue.
    private var lastPrune: TimeInterval = -.infinity

    init(store: RuntimeDiagnosticsLogStore, capacity: Int) {
        self.store = store
        self.capacity = max(1, capacity)
    }

    func enqueue(_ event: RuntimeDiagnosticEvent, at date: Date) {
        let needsSchedule = lock.withLock {
            guard pending.count < capacity else { dropped += 1; return false }
            pending.append(Entry(event: event, date: date))
            guard !scheduled else { return false }
            scheduled = true
            return true
        }
        if needsSchedule { queue.async { self.drain() } }
    }

    func read<T>(_ operation: (RuntimeDiagnosticsLogStore) throws -> T) rethrows -> T {
        try queue.sync {
            drain()
            return try operation(store)
        }
    }

    private func drain() {
        let batch = lock.withLock { () -> ([Entry], Int) in
            let result = (pending, dropped)
            pending.removeAll(keepingCapacity: true)
            dropped = 0
            scheduled = false
            return result
        }
        for entry in batch.0 { try? store.append(entry.event, at: entry.date) }
        if batch.1 > 0 {
            try? store.append(RuntimeDiagnosticEvent(
                category: "diagnostics", name: "buffer_overflow",
                fields: ["dropped": String(batch.1)]
            ))
        }
        let uptime = ProcessInfo.processInfo.systemUptime
        if uptime - lastPrune >= 60 {
            try? store.prune()
            lastPrune = uptime
        }
    }
}
