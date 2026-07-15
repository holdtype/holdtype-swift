import Foundation
import HoldTypePersistence

/// Rebuilds the keyboard's bounded App Group cache from canonical app-owned
/// state. This actor is the cache's only writer; it owns no durable state of
/// its own.
actor IOSKeyboardSnapshotPublisher {
    typealias HistoryLoader = @Sendable () async throws
        -> IOSAcceptedTextHistoryRecord

    private let store: KeyboardBridgeStore?
    private let loadHistory: HistoryLoader

    private var operationIsActive = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(
        store: KeyboardBridgeStore?,
        loadHistory: @escaping HistoryLoader
    ) {
        self.store = store
        self.loadHistory = loadHistory
    }

    /// Publishes one replacement snapshot. Failure leaves canonical app state
    /// untouched and never reports an unavailable or invalid cache as current.
    func publishCurrent(at publishedAt: Date = Date()) async -> Bool {
        await acquireOperation()
        defer { releaseOperation() }

        guard let store else {
            return false
        }

        let history: IOSAcceptedTextHistoryRecord
        do {
            try Task.checkCancellation()
            history = try await loadHistory()
            try Task.checkCancellation()
        } catch is CancellationError {
            return false
        } catch {
            _ = try? saveEmptySnapshot(store: store, publishedAt: publishedAt)
            return false
        }

        do {
            let revision = try store.nextRevision()
            let projection = try Self.makeSnapshot(
                revision: revision,
                publishedAt: publishedAt,
                history: history
            )
            try store.save(projection.snapshot)
            return projection.representsCanonicalHistory
        } catch {
            return false
        }
    }

    private func saveEmptySnapshot(
        store: KeyboardBridgeStore,
        publishedAt: Date
    ) throws {
        let snapshot = try KeyboardBridgeSnapshot(
            revision: store.nextRevision(),
            publishedAt: publishedAt,
            latest: nil
        )
        try store.save(snapshot)
    }

    private static func makeSnapshot(
        revision: UInt64,
        publishedAt: Date,
        history: IOSAcceptedTextHistoryRecord
    ) throws -> (
        snapshot: KeyboardBridgeSnapshot,
        representsCanonicalHistory: Bool
    ) {
        let latestItem: KeyboardBridgeItem?
        let representsCanonicalHistory: Bool
        guard history.isEnabled, let latest = history.entries.first else {
            latestItem = nil
            representsCanonicalHistory = true
            return try (
                KeyboardBridgeSnapshot(
                    revision: revision,
                    publishedAt: publishedAt,
                    latest: latestItem
                ),
                representsCanonicalHistory
            )
        }

        do {
            latestItem = try KeyboardBridgeItem.latest(
                resultID: latest.resultID,
                text: latest.text,
                createdAt: latest.createdAt
            )
            representsCanonicalHistory = true
        } catch is KeyboardBridgeItem.ValidationError {
            // Never leave a deleted or replaced History item presented when
            // the current first entry is unsafe to share.
            latestItem = nil
            representsCanonicalHistory = false
        }

        return try (
            KeyboardBridgeSnapshot(
                revision: revision,
                publishedAt: publishedAt,
                latest: latestItem
            ),
            representsCanonicalHistory
        )
    }

    private func acquireOperation() async {
        guard operationIsActive else {
            operationIsActive = true
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    private func releaseOperation() {
        guard !waiters.isEmpty else {
            operationIsActive = false
            return
        }

        waiters.removeFirst().resume()
    }
}
