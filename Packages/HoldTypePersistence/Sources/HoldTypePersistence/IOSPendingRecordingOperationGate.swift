import Foundation

/// Serializes whole pending-recording transactions across suspension points.
actor IOSPendingRecordingOperationGate {
    enum AcquisitionError: Error, Equatable, Sendable {
        case cancelledBeforeLease
        case reentrantOperation
    }

    enum Event: Equatable, Sendable {
        case enqueued(UUID)
        case granted(UUID)
        case cancelled(UUID)
        case released(UUID)
    }

    @TaskLocal private static var activeGateIdentifier: ObjectIdentifier?

    private struct Lease: Equatable, Sendable {
        let identifier: UUID
    }

    private final class Waiter: @unchecked Sendable {
        private enum Phase {
            case pending
            case granted
            case cancelled
        }

        let identifier: UUID

        private let lock = NSLock()
        private var phase = Phase.pending
        private var continuation: CheckedContinuation<Lease, Error>?

        init(identifier: UUID) {
            self.identifier = identifier
        }

        func install(_ continuation: CheckedContinuation<Lease, Error>) -> Bool {
            lock.lock()
            switch phase {
            case .pending:
                self.continuation = continuation
                lock.unlock()
                return true
            case .cancelled:
                lock.unlock()
                continuation.resume(throwing: AcquisitionError.cancelledBeforeLease)
                return false
            case .granted:
                lock.unlock()
                assertionFailure("A pending-recording waiter cannot be granted before installation.")
                continuation.resume(throwing: AcquisitionError.cancelledBeforeLease)
                return false
            }
        }

        @discardableResult
        func cancel() -> Bool {
            let continuation: CheckedContinuation<Lease, Error>?

            lock.lock()
            guard case .pending = phase else {
                lock.unlock()
                return false
            }
            phase = .cancelled
            continuation = self.continuation
            self.continuation = nil
            lock.unlock()

            continuation?.resume(throwing: AcquisitionError.cancelledBeforeLease)
            return true
        }

        func claimGrant() -> CheckedContinuation<Lease, Error>? {
            lock.lock()
            guard case .pending = phase,
                  let continuation else {
                lock.unlock()
                return nil
            }
            phase = .granted
            self.continuation = nil
            lock.unlock()
            return continuation
        }
    }

    private let eventSink: @Sendable (Event) -> Void
    private var activeLease: Lease?
    private var waiters: [Waiter] = []

    init(eventSink: @escaping @Sendable (Event) -> Void = { _ in }) {
        self.eventSink = eventSink
    }

    func perform<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        let gateIdentifier = ObjectIdentifier(self)
        guard Self.activeGateIdentifier != gateIdentifier else {
            throw AcquisitionError.reentrantOperation
        }

        let lease = try await acquire()
        let operationTask = Task {
            try await Self.$activeGateIdentifier.withValue(gateIdentifier) {
                try await operation()
            }
        }
        let result = await operationTask.result
        release(lease)
        return try result.get()
    }

    private func acquire() async throws -> Lease {
        guard !Task.isCancelled else {
            throw AcquisitionError.cancelledBeforeLease
        }

        let identifier = UUID()
        let waiter = Waiter(identifier: identifier)
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                guard waiter.install(continuation) else {
                    return
                }
                enqueue(waiter)
            }
        } onCancel: {
            guard waiter.cancel() else {
                return
            }
            eventSink(.cancelled(identifier))
            Task {
                await self.removeCancelledWaiter(identifier: identifier)
            }
        }
    }

    private func enqueue(_ waiter: Waiter) {
        guard activeLease == nil else {
            waiters.append(waiter)
            eventSink(.enqueued(waiter.identifier))
            return
        }
        _ = grant(waiter)
    }

    @discardableResult
    private func grant(_ waiter: Waiter) -> Bool {
        guard let continuation = waiter.claimGrant() else {
            return false
        }

        let lease = Lease(identifier: waiter.identifier)
        activeLease = lease
        eventSink(.granted(waiter.identifier))
        continuation.resume(returning: lease)
        return true
    }

    private func release(_ lease: Lease) {
        guard activeLease == lease else {
            assertionFailure("Only the active pending-recording lease may be released.")
            return
        }

        activeLease = nil
        eventSink(.released(lease.identifier))
        while !waiters.isEmpty {
            if grant(waiters.removeFirst()) {
                return
            }
        }
    }

    private func removeCancelledWaiter(identifier: UUID) {
        waiters.removeAll { $0.identifier == identifier }
    }
}
