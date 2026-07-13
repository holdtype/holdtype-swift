import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Observation

struct IOSUsageEstimateClient: Sendable {
    typealias Load = @Sendable () async throws -> [TranscriptionUsageEvent]
    typealias Reset = @Sendable () async throws
        -> IOSTranscriptionUsageWriteToken

    let load: Load
    let reset: Reset

    nonisolated init(
        load: @escaping Load,
        reset: @escaping Reset
    ) {
        self.load = load
        self.reset = reset
    }

    nonisolated init(repository: IOSTranscriptionUsageRepository) {
        self.init(
            load: { try await repository.load() },
            reset: { try await repository.resetWithWriteFence() }
        )
    }
}

enum IOSUsageEstimateState: Equatable, Sendable {
    case notLoaded
    case ready(TranscriptionUsageSummary)
    case loadFailed(lastConfirmed: TranscriptionUsageSummary?)
    case resetFailed(lastConfirmed: TranscriptionUsageSummary?)

    var lastConfirmedSummary: TranscriptionUsageSummary? {
        switch self {
        case .notLoaded:
            nil
        case .ready(let summary):
            summary
        case .loadFailed(let summary):
            summary
        case .resetFailed(let summary):
            summary
        }
    }
}

enum IOSUsageEstimateOperation: Equatable, Sendable {
    case idle
    case refreshing(UInt64)
    case resetting(UInt64)

    var isResetting: Bool {
        guard case .resetting = self else { return false }
        return true
    }
}

enum IOSUsageEstimateNotice: Equatable, Sendable {
    case writeFailed

    var message: String {
        switch self {
        case .writeFailed:
            "Some successful transcription usage could not be saved on "
                + "this device. The estimate may be incomplete."
        }
    }
}

/// One process-owned presentation boundary over the exact usage repository
/// shared by Voice and failed-History Retry.
@MainActor
@Observable
final class IOSUsageEstimateStateOwner {
    private(set) var state = IOSUsageEstimateState.notLoaded
    private(set) var operation = IOSUsageEstimateOperation.idle
    private(set) var notice: IOSUsageEstimateNotice?

    @ObservationIgnored
    private let client: IOSUsageEstimateClient
    @ObservationIgnored
    private let calendar: Calendar
    @ObservationIgnored
    private let now: @Sendable () -> Date
    @ObservationIgnored
    private var nextOperationRevision: UInt64 = 0
    @ObservationIgnored
    private var activeOperationRevision: UInt64?
    @ObservationIgnored
    private var latestFailureToken: IOSTranscriptionUsageWriteToken?
    @ObservationIgnored
    private var acknowledgedFailureToken:
        IOSTranscriptionUsageWriteToken?

    init(
        client: IOSUsageEstimateClient,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.client = client
        self.calendar = calendar
        self.now = now
    }

    convenience init(repository: IOSTranscriptionUsageRepository) {
        self.init(client: IOSUsageEstimateClient(repository: repository))
    }

    var isBusy: Bool { operation != .idle }

    var summary: TranscriptionUsageSummary? {
        state.lastConfirmedSummary
    }

    var canReset: Bool {
        switch state {
        case .notLoaded:
            false
        case .ready(let summary):
            !summary.isEmpty
        case .loadFailed, .resetFailed:
            true
        }
    }

    @discardableResult
    func refresh() async -> Bool {
        guard let revision = begin(refreshing: true) else { return false }
        let previous = state.lastConfirmedSummary

        do {
            let events = try await client.load()
            try Task.checkCancellation()
            guard complete(revision) else { return false }
            state = .ready(
                TranscriptionUsageSummary.make(
                    events: events,
                    now: now(),
                    calendar: calendar
                )
            )
            return true
        } catch is CancellationError {
            _ = complete(revision)
            return false
        } catch {
            if Task.isCancelled {
                _ = complete(revision)
                return false
            }
            guard complete(revision) else { return false }
            state = .loadFailed(lastConfirmed: previous)
            return false
        }
    }

    @discardableResult
    func reset() async -> Bool {
        guard canReset,
              let revision = begin(refreshing: false) else {
            return false
        }
        let previous = state.lastConfirmedSummary

        do {
            let fence = try await client.reset()
            guard complete(revision) else { return false }
            state = .ready(
                .empty(now: now(), calendar: calendar)
            )
            acknowledgeFailures(through: fence)
            return true
        } catch is CancellationError {
            _ = complete(revision)
            return false
        } catch {
            guard complete(revision) else { return false }
            state = .resetFailed(lastConfirmed: previous)
            return false
        }
    }

    func reportWriteFailure(
        _ token: IOSTranscriptionUsageWriteToken
    ) {
        if token.isOrderingExhausted {
            latestFailureToken = token
            notice = .writeFailed
            return
        }
        if let acknowledgedFailureToken,
           token <= acknowledgedFailureToken {
            return
        }
        if let latestFailureToken,
           token <= latestFailureToken {
            return
        }
        latestFailureToken = token
        notice = .writeFailed
    }

    func dismissNotice() {
        if let latestFailureToken {
            acknowledgedFailureToken = max(
                acknowledgedFailureToken ?? latestFailureToken,
                latestFailureToken
            )
        }
        notice = nil
    }

    private func begin(
        refreshing: Bool
    ) -> UInt64? {
        guard operation == .idle else { return nil }
        if nextOperationRevision < UInt64.max {
            nextOperationRevision += 1
        }
        let revision = nextOperationRevision
        activeOperationRevision = revision
        operation = refreshing
            ? .refreshing(revision)
            : .resetting(revision)
        return revision
    }

    @discardableResult
    private func complete(_ revision: UInt64) -> Bool {
        guard activeOperationRevision == revision else { return false }
        activeOperationRevision = nil
        operation = .idle
        return true
    }

    private func acknowledgeFailures(
        through fence: IOSTranscriptionUsageWriteToken
    ) {
        acknowledgedFailureToken = max(
            acknowledgedFailureToken ?? fence,
            fence
        )
        if let latestFailureToken,
           latestFailureToken > fence {
            notice = .writeFailed
        } else {
            notice = nil
        }
    }
}

extension IOSUsageEstimateClient:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "IOSUsageEstimateClient(<redacted>)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSUsageEstimateStateOwner:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSUsageEstimateStateOwner(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
