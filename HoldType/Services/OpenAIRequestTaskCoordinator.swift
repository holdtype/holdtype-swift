//
//  OpenAIRequestTaskCoordinator.swift
//  HoldType
//
//  Created by Codex on 7/10/26.
//

import Foundation

nonisolated final class OpenAIRequestTaskCoordinator: @unchecked Sendable {
    private struct ActiveRequest {
        let identifier: UUID
        let cancel: @Sendable () -> Void
    }

    private let lock = NSLock()
    private var activeRequest: ActiveRequest?

    func perform<Value>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try Task.checkCancellation()

        let identifier = UUID()
        let task = Task {
            let value = try await operation()
            try Task.checkCancellation()
            return value
        }

        replaceActiveRequest(
            ActiveRequest(
                identifier: identifier,
                cancel: { task.cancel() }
            )
        )

        return try await withTaskCancellationHandler {
            defer { clearActiveRequest(matching: identifier) }
            return try await task.value
        } onCancel: {
            task.cancel()
        }
    }

    func cancelActiveRequest() {
        let cancel = lock.withLock { activeRequest?.cancel }
        cancel?()
    }

    private func replaceActiveRequest(_ request: ActiveRequest) {
        let previousCancel = lock.withLock {
            let previousCancel = activeRequest?.cancel
            activeRequest = request
            return previousCancel
        }
        previousCancel?()
    }

    private func clearActiveRequest(matching identifier: UUID) {
        lock.withLock {
            guard activeRequest?.identifier == identifier else {
                return
            }
            activeRequest = nil
        }
    }
}
