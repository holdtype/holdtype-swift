import Foundation

@MainActor
final class DevVlogsCameraStartOperationGate {
    private var continuation: CheckedContinuation<Void, Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var onLateSuccess: (@MainActor () async -> Void)?
    private var isTerminal = false

    func wait(
        timeout: Duration,
        operation: @escaping @MainActor () async throws -> Void,
        onLateSuccess: @escaping @MainActor () async -> Void
    ) async throws {
        self.onLateSuccess = onLateSuccess
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            operationTask = Task { @MainActor [self] in
                do {
                    try await operation()
                    finish(.success(()))
                } catch {
                    finish(.failure(error))
                }
            }
            timeoutTask = Task { @MainActor [self] in
                do { try await Task.sleep(for: timeout) } catch { return }
                finish(.failure(DevVlogsCameraCaptureError.startFailed), cancelOperation: true)
            }
        }
    }

    private func finish(_ result: Result<Void, Error>, cancelOperation: Bool = false) {
        guard !isTerminal else {
            if case .success = result, let onLateSuccess {
                Task { @MainActor in await onLateSuccess() }
            }
            return
        }
        isTerminal = true
        let continuation = continuation
        self.continuation = nil
        cancelOperation ? operationTask?.cancel() : timeoutTask?.cancel()
        operationTask = nil
        timeoutTask = nil
        continuation?.resume(with: result)
    }
}

@MainActor
final class DevVlogsCameraStopOperationGate {
    private var continuation: CheckedContinuation<DevVlogsCameraCaptureResult, Error>?
    private var operationTask: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var isTerminal = false

    func wait(
        timeout: Duration,
        operation: @escaping @MainActor () async throws -> DevVlogsCameraCaptureResult,
        onTimeout: @escaping @MainActor () -> Void
    ) async throws -> DevVlogsCameraCaptureResult {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            operationTask = Task { @MainActor [self] in
                do {
                    finish(.success(try await operation()))
                } catch {
                    finish(.failure(error))
                }
            }
            timeoutTask = Task { @MainActor [self] in
                do { try await Task.sleep(for: timeout) } catch { return }
                onTimeout()
                finish(.failure(DevVlogsCameraCaptureError.stopFailed), cancelOperation: true)
            }
        }
    }

    private func finish(
        _ result: Result<DevVlogsCameraCaptureResult, Error>,
        cancelOperation: Bool = false
    ) {
        guard !isTerminal else { return }
        isTerminal = true
        let continuation = continuation
        self.continuation = nil
        cancelOperation ? operationTask?.cancel() : timeoutTask?.cancel()
        operationTask = nil
        timeoutTask = nil
        continuation?.resume(with: result)
    }
}
