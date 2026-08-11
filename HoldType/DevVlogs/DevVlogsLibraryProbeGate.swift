import Foundation

nonisolated final class DevVlogsLibraryProbeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<DevVlogsLibraryMediaProbeResult, Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var isTerminal = false
    private var terminalResult: Result<DevVlogsLibraryMediaProbeResult, Error>?

    func wait(
        timeout: Duration,
        operation: @escaping @Sendable () async throws -> DevVlogsLibraryMediaProbeResult
    ) async throws -> DevVlogsLibraryMediaProbeResult {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let pendingResult = lock.withLock {
                    () -> Result<DevVlogsLibraryMediaProbeResult, Error>? in
                    if let terminalResult { return terminalResult }
                    self.continuation = continuation
                    return nil
                }
                if let pendingResult {
                    continuation.resume(with: pendingResult)
                    return
                }
                let operationTask = Task {
                    do { finish(.success(try await operation())) }
                    catch { finish(.failure(error)) }
                }
                registerOperationTask(operationTask)
                let timeoutTask = Task {
                    do { try await Task.sleep(for: timeout) } catch { return }
                    finish(.failure(DevVlogsLibraryError.archiveUnreadable), cancelOperation: true)
                }
                registerTimeoutTask(timeoutTask)
            }
        } onCancel: {
            finish(.failure(CancellationError()), cancelOperation: true)
        }
    }

    private func finish(
        _ result: Result<DevVlogsLibraryMediaProbeResult, Error>,
        cancelOperation: Bool = false
    ) {
        let terminal = lock.withLock {
            () -> (CheckedContinuation<DevVlogsLibraryMediaProbeResult, Error>?, Task<Void, Never>?)? in
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
