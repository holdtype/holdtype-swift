import Foundation

nonisolated final class DevVlogsMediaProbeGate<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var isTerminal = false
    private var terminalResult: Result<Value, Error>?

    func wait(
        timeout: Duration,
        operation: @escaping @MainActor () async throws -> Value
    ) async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let pendingResult = lock.withLock {
                    () -> Result<Value, Error>? in
                    if let terminalResult { return terminalResult }
                    self.continuation = continuation
                    return nil
                }
                if let pendingResult {
                    continuation.resume(with: pendingResult)
                    return
                }
                let operationTask = Task { @MainActor [self] in
                    do { finish(.success(try await operation())) }
                    catch { finish(.failure(error)) }
                }
                registerOperationTask(operationTask)
                let timeoutTask = Task { @MainActor [self] in
                    do { try await Task.sleep(for: timeout) } catch { return }
                    finish(.failure(DevVlogsBuildError.timedOut), cancelOperation: true)
                }
                registerTimeoutTask(timeoutTask)
            }
        } onCancel: {
            finish(.failure(DevVlogsBuildError.cancelled), cancelOperation: true)
        }
    }

    private func finish(_ result: Result<Value, Error>, cancelOperation: Bool = false) {
        let terminal = lock.withLock {
            () -> (CheckedContinuation<Value, Error>?, Task<Void, Never>?)? in
            guard !isTerminal else { return nil }
            isTerminal = true
            let continuation = self.continuation
            self.continuation = nil
            if continuation == nil { terminalResult = result }
            let taskToCancel = cancelOperation ? operationTask : timeoutTask
            operationTask = nil
            timeoutTask = nil
            return (continuation, taskToCancel)
        }
        guard let (continuation, taskToCancel) = terminal else { return }
        taskToCancel?.cancel()
        continuation?.resume(with: result)
    }

    private func registerOperationTask(_ task: Task<Void, Never>) {
        let shouldCancel = lock.withLock {
            guard !isTerminal else { return true }
            operationTask = task
            return false
        }
        if shouldCancel { task.cancel() }
    }

    private func registerTimeoutTask(_ task: Task<Void, Never>) {
        let shouldCancel = lock.withLock {
            guard !isTerminal else { return true }
            timeoutTask = task
            return false
        }
        if shouldCancel { task.cancel() }
    }
}
