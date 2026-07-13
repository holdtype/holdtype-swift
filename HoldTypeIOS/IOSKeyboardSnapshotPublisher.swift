import Foundation
@_spi(HoldTypeIOSCore) import HoldTypePersistence

nonisolated enum IOSKeyboardSnapshotProductionGate {
    static let debugEnvironmentKey =
        "HOLDTYPE_ENABLE_UNQUALIFIED_KEYBOARD_PROJECTION"

    static func isEnabled(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        #if DEBUG
        environment[debugEnvironmentKey] == "1"
        #else
        KeyboardBridgeConfiguration.productionProjectionIsQualified
        #endif
    }
}

/// Rebuilds the keyboard's bounded App Group cache from canonical app-owned
/// state. This actor is the cache's only writer; it owns no durable state of
/// its own.
actor IOSKeyboardSnapshotPublisher {
    typealias LatestLoader = @Sendable () async throws
        -> IOSV1ForegroundVoiceLatestResultObservation
    typealias HistoryLoader = @Sendable () async throws
        -> IOSAcceptedTextHistoryRecord

    private let store: KeyboardBridgeStore?
    private let loadLatest: LatestLoader
    private let loadHistory: HistoryLoader

    private var operationIsActive = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(
        store: KeyboardBridgeStore?,
        loadLatest: @escaping LatestLoader,
        loadHistory: @escaping HistoryLoader
    ) {
        self.store = store
        self.loadLatest = loadLatest
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

        do {
            try Task.checkCancellation()
            let latest = try await loadLatest()
            try Task.checkCancellation()
            let history = try await loadHistory()
            try Task.checkCancellation()

            let revision = try store.nextRevision()
            let snapshot = try Self.makeSnapshot(
                revision: revision,
                publishedAt: publishedAt,
                latest: latest,
                history: history
            )
            try store.save(snapshot)
            return true
        } catch {
            return false
        }
    }

    private static func makeSnapshot(
        revision: UInt64,
        publishedAt: Date,
        latest: IOSV1ForegroundVoiceLatestResultObservation,
        history: IOSAcceptedTextHistoryRecord
    ) throws -> KeyboardBridgeSnapshot {
        let latestItem: KeyboardBridgeItem?
        switch latest {
        case .absent:
            latestItem = nil
        case .resultReady(let record):
            latestItem = try KeyboardBridgeItem.latest(
                resultID: record.resultID,
                text: record.acceptedText,
                createdAt: record.createdAt
            )
        }

        let recentItems: [KeyboardBridgeItem]
        if history.isEnabled {
            var seenResultIDs = Set<UUID>()
            recentItems = try history.entries
                .sorted(by: isOrderedBefore)
                .filter { entry in
                    guard seenResultIDs.insert(entry.resultID).inserted else {
                        return false
                    }
                    return entry.createdAt.addingTimeInterval(
                        KeyboardBridgeConfiguration.recentResultLifetime
                    ) > publishedAt
                }
                .prefix(KeyboardBridgeConfiguration.maximumRecentResults)
                .map { entry in
                    try KeyboardBridgeItem.recent(
                        resultID: entry.resultID,
                        text: entry.text,
                        createdAt: entry.createdAt
                    )
                }
        } else {
            recentItems = []
        }

        return try KeyboardBridgeSnapshot(
            revision: revision,
            publishedAt: publishedAt,
            historyEnabled: history.isEnabled,
            latest: latestItem,
            recentResults: recentItems
        )
    }

    private static func isOrderedBefore(
        _ lhs: IOSAcceptedTextHistoryEntry,
        _ rhs: IOSAcceptedTextHistoryEntry
    ) -> Bool {
        if lhs.createdAt != rhs.createdAt {
            return lhs.createdAt > rhs.createdAt
        }
        return lhs.resultID.uuidString < rhs.resultID.uuidString
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
