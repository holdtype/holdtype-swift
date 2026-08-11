import Foundation

@MainActor
final class RecordingArtifactReadLease {
    let fileURL: URL

    private weak var registry: RecordingArtifactReadLeaseRegistry?
    private let token: UUID
    private(set) var isReleased = false

    fileprivate init(
        fileURL: URL,
        token: UUID,
        registry: RecordingArtifactReadLeaseRegistry
    ) {
        self.fileURL = fileURL
        self.token = token
        self.registry = registry
    }

    func release() {
        guard !isReleased else { return }
        isReleased = true
        registry?.release(token: token, for: fileURL)
    }
}

/// Protects only exact finalized recording artifacts while bounded readers use them.
@MainActor
final class RecordingArtifactReadLeaseRegistry {
    static let shared = RecordingArtifactReadLeaseRegistry()

    private struct Entry {
        var tokens: Set<UUID> = []
        var deferredCleanup: [() -> Void] = []
    }

    private var entries: [String: Entry] = [:]

    func acquire(for fileURL: URL) -> RecordingArtifactReadLease {
        let token = UUID()
        let key = Self.key(for: fileURL)
        entries[key, default: Entry()].tokens.insert(token)
        return RecordingArtifactReadLease(fileURL: fileURL, token: token, registry: self)
    }

    func isProtected(_ fileURL: URL) -> Bool {
        entries[Self.key(for: fileURL)]?.tokens.isEmpty == false
    }

    @discardableResult
    func deferCleanupIfProtected(
        for fileURL: URL,
        _ cleanup: @escaping () -> Void
    ) -> Bool {
        let key = Self.key(for: fileURL)
        guard entries[key]?.tokens.isEmpty == false else { return false }
        entries[key]?.deferredCleanup.append(cleanup)
        return true
    }

    fileprivate func release(token: UUID, for fileURL: URL) {
        let key = Self.key(for: fileURL)
        guard var entry = entries[key], entry.tokens.remove(token) != nil else { return }
        guard entry.tokens.isEmpty else {
            entries[key] = entry
            return
        }
        entries[key] = nil
        entry.deferredCleanup.forEach { $0() }
    }

    private nonisolated static func key(for fileURL: URL) -> String {
        fileURL.standardizedFileURL.path
    }
}
