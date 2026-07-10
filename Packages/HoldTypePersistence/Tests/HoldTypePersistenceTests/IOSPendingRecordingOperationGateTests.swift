import Foundation
import Testing
@testable import HoldTypePersistence

struct IOSPendingRecordingOperationGateTests {
    @Test func transactionsRemainFIFOAcrossSuspension() async throws {
        let events = GateEventRecorder()
        let firstBlocker = AsyncOperationBlocker()
        let gate = IOSPendingRecordingOperationGate { event in
            events.append(event)
        }

        let first = Task {
            try await gate.perform {
                events.appendValue(1)
                await firstBlocker.wait()
                events.appendValue(2)
                return 1
            }
        }
        await firstBlocker.waitUntilSuspended()

        let second = Task {
            try await gate.perform {
                events.appendValue(3)
                return 2
            }
        }
        await Task.yield()

        #expect(events.values == [1])
        await firstBlocker.open()
        #expect(try await first.value == 1)
        #expect(try await second.value == 2)
        #expect(events.values == [1, 2, 3])
        #expect(events.grantedIdentifiers.count == 2)
        #expect(events.releasedIdentifiers == events.grantedIdentifiers)
    }

    @Test func cancelledWaiterNeverRunsAfterTheActiveTransaction() async throws {
        let blocker = AsyncOperationBlocker()
        let gate = IOSPendingRecordingOperationGate()

        let first = Task {
            try await gate.perform {
                await blocker.wait()
                return 1
            }
        }
        await blocker.waitUntilSuspended()

        let didRun = LockedFlag()
        let cancelled = Task {
            try await gate.perform {
                didRun.set()
                return 2
            }
        }
        await Task.yield()
        cancelled.cancel()

        do {
            _ = try await cancelled.value
            Issue.record("A cancelled waiter must not receive a transaction lease.")
        } catch IOSPendingRecordingOperationGate.AcquisitionError.cancelledBeforeLease {
        } catch {
            Issue.record("Unexpected cancellation error: \(type(of: error))")
        }

        await blocker.open()
        #expect(try await first.value == 1)
        #expect(!didRun.value)
    }

    @Test func cancellationAfterGrantDoesNotInterruptTheTransaction() async throws {
        let blocker = AsyncOperationBlocker()
        let didFinish = LockedFlag()
        let gate = IOSPendingRecordingOperationGate()
        let task = Task {
            try await gate.perform {
                await blocker.wait()
                didFinish.set()
                return 7
            }
        }

        await blocker.waitUntilSuspended()
        task.cancel()
        await blocker.open()

        #expect(try await task.value == 7)
        #expect(didFinish.value)
    }

    @Test func transactionCannotReenterTheSameGate() async throws {
        let gate = IOSPendingRecordingOperationGate()

        do {
            _ = try await gate.perform {
                try await gate.perform { 1 }
            }
            Issue.record("Re-entry must fail before it can deadlock the FIFO gate.")
        } catch IOSPendingRecordingOperationGate.AcquisitionError.reentrantOperation {
        } catch {
            Issue.record("Unexpected re-entry error: \(type(of: error))")
        }
    }
}

nonisolated private final class GateEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [IOSPendingRecordingOperationGate.Event] = []
    private var storedValues: [Int] = []

    var values: [Int] {
        lock.withLock { storedValues }
    }

    var grantedIdentifiers: [UUID] {
        lock.withLock {
            storedEvents.compactMap { event in
                guard case .granted(let identifier) = event else {
                    return nil
                }
                return identifier
            }
        }
    }

    var releasedIdentifiers: [UUID] {
        lock.withLock {
            storedEvents.compactMap { event in
                guard case .released(let identifier) = event else {
                    return nil
                }
                return identifier
            }
        }
    }

    func append(_ event: IOSPendingRecordingOperationGate.Event) {
        lock.withLock { storedEvents.append(event) }
    }

    func appendValue(_ value: Int) {
        lock.withLock { storedValues.append(value) }
    }
}

nonisolated private final class LockedFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = false

    var value: Bool {
        lock.withLock { storedValue }
    }

    func set() {
        lock.withLock { storedValue = true }
    }
}

private actor AsyncOperationBlocker {
    private var blockingContinuation: CheckedContinuation<Void, Never>?
    private var observerContinuations: [CheckedContinuation<Void, Never>] = []
    private var isOpen = false
    private var isSuspended = false

    func wait() async {
        guard !isOpen else {
            return
        }
        await withCheckedContinuation { continuation in
            blockingContinuation = continuation
            isSuspended = true
            let observers = observerContinuations
            observerContinuations.removeAll()
            for observer in observers {
                observer.resume()
            }
        }
    }

    func waitUntilSuspended() async {
        guard !isSuspended else {
            return
        }
        await withCheckedContinuation { continuation in
            observerContinuations.append(continuation)
        }
    }

    func open() {
        isOpen = true
        blockingContinuation?.resume()
        blockingContinuation = nil
    }
}
