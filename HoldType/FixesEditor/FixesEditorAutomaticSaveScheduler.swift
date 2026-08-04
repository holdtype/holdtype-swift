import Foundation

@MainActor
final class FixesEditorAutomaticSaveScheduler {
    private var task: Task<Void, Never>?

    private(set) var actionID: String?

    func schedule(
        id: String,
        after delay: Duration,
        operation: @escaping @MainActor () async -> Void
    ) {
        cancel()
        actionID = id
        task = Task { @MainActor [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else {
                return
            }

            await operation()
            self?.clearIfCurrent(id: id)
        }
    }

    func cancel(for id: String? = nil) {
        guard id == nil || actionID == id else {
            return
        }
        task?.cancel()
        task = nil
        actionID = nil
    }

    private func clearIfCurrent(id: String) {
        guard actionID == id else {
            return
        }
        task = nil
        actionID = nil
    }
}
