import Foundation

/// Joins native file completion without blocking the recorder's callback queue.
nonisolated final class AudioRecordingFinishBarrier: @unchecked Sendable {
    private let lock = NSLock()
    private var result: Result<Void, Error>?
    private var continuation: CheckedContinuation<Void, Error>?

    func wait(timeout: TimeInterval, stop: @escaping @Sendable () -> Void) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let previous: Result<Void, Error>? = lock.withLock {
                    if let result { return result }
                    self.continuation = continuation
                    return nil as Result<Void, Error>?
                }
                if let previous { continuation.resume(with: previous) }
                // Even a cancelled waiter must stop the native recorder.
                stop()
                DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { [weak self] in
                    self?.resolve(.failure(AudioRecorderServiceError.stopFailed))
                }
            }
        } onCancel: {
            self.resolve(.failure(CancellationError()))
        }
    }

    func finish() { resolve(.success(())) }

    private func resolve(_ result: Result<Void, Error>) {
        let waiter = lock.withLock {
            guard self.result == nil else { return nil as CheckedContinuation<Void, Error>? }
            self.result = result
            let waiter = continuation
            continuation = nil
            return waiter
        }
        waiter?.resume(with: result)
    }
}
