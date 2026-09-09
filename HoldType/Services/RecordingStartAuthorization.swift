import Foundation

/// Linearizes key release against the moment native capture commits. This is
/// shared by the input owner and audio queue, never a second recording state.
nonisolated final class RecordingStartAuthorization: @unchecked Sendable {
    private let lock = NSLock()
    private var requested = true
    private var committed = false

    func release() { lock.withLock { requested = false } }
    var isRequested: Bool { lock.withLock { requested } }
    var hasCommittedCapture: Bool { lock.withLock { committed } }

    func commitCapture() -> Bool {
        lock.withLock {
            guard requested else { return false }
            committed = true
            return true
        }
    }
}
