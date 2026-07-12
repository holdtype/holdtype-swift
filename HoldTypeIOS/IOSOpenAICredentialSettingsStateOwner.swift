import Foundation
import HoldTypeIOSCore
import Observation

struct IOSOpenAICredentialSettingsClient: Sendable {
    typealias PassiveStatus = @Sendable () async
        -> IOSOpenAICredentialStatusUpdate
    typealias Refresh = @Sendable () async throws
        -> IOSOpenAICredentialStatusUpdate
    typealias SaveOrReplace = @Sendable (String) async throws
        -> IOSOpenAICredentialMutationOutcome
    typealias Remove = @Sendable () async throws
        -> IOSOpenAICredentialMutationOutcome
    typealias StatusUpdates = @Sendable () async
        -> AsyncStream<IOSOpenAICredentialStatusUpdate>

    let passiveStatus: PassiveStatus
    let refresh: Refresh
    let saveOrReplace: SaveOrReplace
    let remove: Remove
    let statusUpdates: StatusUpdates

    nonisolated init(
        passiveStatus: @escaping PassiveStatus,
        refresh: @escaping Refresh,
        saveOrReplace: @escaping SaveOrReplace,
        remove: @escaping Remove,
        statusUpdates: @escaping StatusUpdates
    ) {
        self.passiveStatus = passiveStatus
        self.refresh = refresh
        self.saveOrReplace = saveOrReplace
        self.remove = remove
        self.statusUpdates = statusUpdates
    }

    nonisolated init(coordinator: IOSOpenAICredentialCoordinator) {
        self.init(
            passiveStatus: {
                await coordinator.credentialStatusUpdate()
            },
            refresh: {
                let outcome = try await coordinator.resolve(
                    for: .openAISettingsRefresh
                )
                return outcome.statusUpdate
            },
            saveOrReplace: { candidate in
                try await coordinator.saveOrReplace(candidate)
            },
            remove: {
                try await coordinator.remove()
            },
            statusUpdates: {
                await coordinator.statusUpdates()
            }
        )
    }
}

enum IOSOpenAICredentialSettingsState: Equatable, Sendable {
    case unavailable
    case notLoaded
    case ready(IOSOpenAICredentialStatus)
}

enum IOSOpenAICredentialSettingsOperation: Equatable, Sendable {
    case idle
    case loadingStatus
    case refreshing
    case saving
    case removing
}

enum IOSOpenAICredentialSettingsNotice: Equatable, Sendable {
    case checked
    case saved
    case savedStatusNeedsRefresh
    case removed
    case removedStatusNeedsRefresh

    var message: String {
        switch self {
        case .checked:
            "Saved-key status checked."
        case .saved:
            "Saved in HoldType."
        case .savedStatusNeedsRefresh:
            "Saved in HoldType. Credential status needs refresh."
        case .removed:
            "Removed from HoldType."
        case .removedStatusNeedsRefresh:
            "Removed from HoldType. Credential status needs refresh."
        }
    }
}

enum IOSOpenAICredentialSettingsFailure: Equatable, Sendable {
    case emptyCandidate
    case emptyClipboard
    case statusUnavailable
    case unavailableWhileLocked
    case savedCredentialUnreadable
    case keychainUnavailable
    case providerRejected
    case operationCancelled
    case operationFailed

    init(error: Error) {
        if error is CancellationError {
            self = .operationCancelled
            return
        }

        guard let error = error as? IOSOpenAICredentialCoordinatorError else {
            self = .operationFailed
            return
        }

        switch error {
        case .emptyAPIKey:
            self = .emptyCandidate
        case .markerUnavailable:
            self = .statusUnavailable
        case .credentialAccessFailed(let failure, _):
            switch failure {
            case .unavailableWhileLocked:
                self = .unavailableWhileLocked
            case .invalidStoredCredential:
                self = .savedCredentialUnreadable
            case .keychainFailure:
                self = .keychainUnavailable
            }
        case .providerRejected:
            self = .providerRejected
        case .operationCancelledBeforeStart,
             .operationCancelledStatusNeedsRefresh:
            self = .operationCancelled
        }
    }

    var message: String {
        switch self {
        case .emptyCandidate:
            "Enter an OpenAI API key."
        case .emptyClipboard:
            "The clipboard does not contain an OpenAI API key."
        case .statusUnavailable:
            "Credential status is unavailable. The saved key was not changed."
        case .unavailableWhileLocked:
            "The saved key is unavailable while this device is locked."
        case .savedCredentialUnreadable:
            "The saved key could not be read. Replace or remove it to continue."
        case .keychainUnavailable:
            "HoldType could not access its saved key in Keychain."
        case .providerRejected:
            "OpenAI rejected the current key. Replace it to continue."
        case .operationCancelled:
            "The credential operation was cancelled."
        case .operationFailed:
            "The credential operation could not be completed."
        }
    }
}

@MainActor
@Observable
final class IOSOpenAICredentialSettingsStateOwner {
    private(set) var state: IOSOpenAICredentialSettingsState
    private(set) var operation = IOSOpenAICredentialSettingsOperation.idle
    private(set) var notice: IOSOpenAICredentialSettingsNotice?
    private(set) var failure: IOSOpenAICredentialSettingsFailure?

    @ObservationIgnored
    private let client: IOSOpenAICredentialSettingsClient?
    @ObservationIgnored
    private var statusObservationTask: Task<Void, Never>?
    @ObservationIgnored
    private var latestStatusRevision: UInt64?

    init(client: IOSOpenAICredentialSettingsClient?) {
        self.client = client
        state = client == nil ? .unavailable : .notLoaded
    }

    deinit {
        statusObservationTask?.cancel()
    }

    var isBusy: Bool { operation != .idle }

    var currentStatus: IOSOpenAICredentialStatus? {
        guard case .ready(let status) = state else { return nil }
        return status
    }

    func activateForDetailAppearance() async {
        guard begin(.loadingStatus, clearsMessages: false),
              let client else {
            return
        }
        notice = nil

        if statusObservationTask == nil {
            let updates = await client.statusUpdates()
            statusObservationTask = Task { @MainActor [weak self] in
                for await update in updates {
                    guard let self else { return }
                    receiveObservedStatus(update)
                }
                self?.statusObservationTask = nil
            }
        }
        applyStatusUpdate(
            await client.passiveStatus(),
            clearsMessagesWhenNewer: false
        )
        operation = .idle
    }

    func refresh() async {
        guard begin(.refreshing), let client else { return }

        do {
            let update = try await client.refresh()
            notice = .checked
            completeAction(with: update)
        } catch {
            failure = IOSOpenAICredentialSettingsFailure(error: error)
            let update = await client.passiveStatus()
            completeAction(with: update)
        }
    }

    @discardableResult
    func saveOrReplace(_ candidate: String) async -> Bool {
        let normalizedCandidate = candidate.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedCandidate.isEmpty else {
            notice = nil
            failure = .emptyCandidate
            return false
        }
        guard begin(.saving), let client else { return false }

        do {
            let outcome = try await client.saveOrReplace(normalizedCandidate)
            let update = await client.passiveStatus()
            notice = switch outcome {
            case .applied:
                .saved
            case .appliedStatusNeedsRefresh:
                .savedStatusNeedsRefresh
            }
            completeAction(with: update)
            return true
        } catch {
            failure = IOSOpenAICredentialSettingsFailure(error: error)
            let update = await client.passiveStatus()
            completeAction(with: update)
            return false
        }
    }

    @discardableResult
    func remove() async -> Bool {
        guard begin(.removing), let client else { return false }

        do {
            let outcome = try await client.remove()
            let update = await client.passiveStatus()
            notice = switch outcome {
            case .applied:
                .removed
            case .appliedStatusNeedsRefresh:
                .removedStatusNeedsRefresh
            }
            completeAction(with: update)
            return true
        } catch {
            failure = IOSOpenAICredentialSettingsFailure(error: error)
            let update = await client.passiveStatus()
            completeAction(with: update)
            return false
        }
    }

    func reportEmptyCandidate() {
        guard !isBusy else { return }
        notice = nil
        failure = .emptyCandidate
    }

    func reportEmptyClipboard() {
        guard !isBusy else { return }
        notice = nil
        failure = .emptyClipboard
    }

    private func begin(
        _ nextOperation: IOSOpenAICredentialSettingsOperation,
        clearsMessages: Bool = true
    ) -> Bool {
        guard operation == .idle, client != nil else { return false }
        operation = nextOperation
        if clearsMessages {
            notice = nil
            failure = nil
        }
        return true
    }

    private func receiveObservedStatus(
        _ update: IOSOpenAICredentialStatusUpdate
    ) {
        applyStatusUpdate(
            update,
            clearsMessagesWhenNewer: operation == .idle
        )
    }

    private func completeAction(
        with update: IOSOpenAICredentialStatusUpdate
    ) {
        applyStatusUpdate(
            update,
            clearsMessagesWhenNewer: false
        )
        operation = .idle
    }

    @discardableResult
    private func applyStatusUpdate(
        _ update: IOSOpenAICredentialStatusUpdate,
        clearsMessagesWhenNewer: Bool
    ) -> Bool {
        if let latestStatusRevision,
           update.revision < latestStatusRevision {
            return false
        }

        let isNewer = latestStatusRevision.map {
            update.revision > $0
        } ?? true
        let previousStatus = currentStatus
        latestStatusRevision = update.revision
        state = .ready(update.status)
        if isNewer, clearsMessagesWhenNewer {
            if previousStatus != update.status {
                notice = nil
            }
            if let failure,
               !failure.remainsRelevant(to: update.status) {
                self.failure = nil
            }
        }
        return true
    }
}

private extension IOSOpenAICredentialSettingsFailure {
    func remainsRelevant(
        to status: IOSOpenAICredentialStatus
    ) -> Bool {
        switch self {
        case .providerRejected:
            status.primary == .providerRejected
        case .statusUnavailable:
            status.localMarkerIssue != nil || status.statusNeedsRefresh
        case .emptyCandidate, .emptyClipboard, .unavailableWhileLocked,
             .savedCredentialUnreadable, .keychainUnavailable,
             .operationCancelled, .operationFailed:
            true
        }
    }
}

extension IOSOpenAICredentialSettingsClient:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    var description: String {
        "IOSOpenAICredentialSettingsClient(<redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSOpenAICredentialSettingsStateOwner:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    nonisolated var description: String {
        "IOSOpenAICredentialSettingsStateOwner(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
