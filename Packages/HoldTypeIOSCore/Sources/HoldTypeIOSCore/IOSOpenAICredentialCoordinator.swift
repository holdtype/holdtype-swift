import Foundation
import HoldTypeOpenAI
import HoldTypePersistence

/// App-only orchestration for Keychain truth, the transient credential cache,
/// and the non-secret last-known marker.
///
/// The production composition root must create exactly one instance for the
/// app process and route every credential operation through it. Creating a
/// coordinator per scene or using its Keychain and marker adapters directly
/// would bypass this instance's transaction gate and runtime truth.
public actor IOSOpenAICredentialCoordinator {
    private enum RuntimeCache {
        case unresolved
        case available(IOSResolvedOpenAICredential)
        case knownAbsent
        case unavailableWhileLocked
    }

    private enum MarkerObservation {
        case readable(CredentialPresenceMarker?)
        case unreadable
    }

    private enum ActualPresence {
        case present
        case absent
    }

    private let keychainStorage: any OpenAIAPIKeyStoring
    private let markerStore: any IOSCredentialPresenceMarkerStoring
    private let now: @Sendable () -> Date
    private let operationGate: CredentialOperationGate

    private var runtimeCache = RuntimeCache.unresolved
    private var rejectedGeneration: IOSOpenAICredentialGeneration?

    public init(
        applicationSupportDirectoryURL: URL,
        applicationIdentifierAccessGroup: String
    ) throws {
        keychainStorage = try OpenAIAPIKeyKeychainStorage(
            applicationIdentifierAccessGroup: applicationIdentifierAccessGroup
        )
        markerStore = RepositoryCredentialPresenceMarkerStore(
            repository: CredentialPresenceMarkerRepository(
                fileURL: IOSCredentialPresenceMarkerStorageLocation.fileURL(
                    in: applicationSupportDirectoryURL
                )
            )
        )
        now = { Date() }
        operationGate = CredentialOperationGate()
    }

    init(
        keychainStorage: any OpenAIAPIKeyStoring,
        markerRepository: CredentialPresenceMarkerRepository,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.keychainStorage = keychainStorage
        markerStore = RepositoryCredentialPresenceMarkerStore(
            repository: markerRepository
        )
        self.now = now
        operationGate = CredentialOperationGate()
    }

    init(
        keychainStorage: any OpenAIAPIKeyStoring,
        markerStore: any IOSCredentialPresenceMarkerStoring,
        now: @escaping @Sendable () -> Date = { Date() },
        operationGate: CredentialOperationGate = CredentialOperationGate()
    ) {
        self.keychainStorage = keychainStorage
        self.markerStore = markerStore
        self.now = now
        self.operationGate = operationGate
    }

    /// Reads only the app-private non-secret marker. It never touches Keychain.
    public func credentialStatus() -> IOSOpenAICredentialStatus {
        status(for: loadMarkerObservation())
    }

    public func saveOrReplace(
        _ candidate: String
    ) async throws -> IOSOpenAICredentialMutationOutcome {
        let credential: OpenAICredential
        do {
            credential = try OpenAICredential(apiKey: candidate)
        } catch OpenAICredential.ValidationError.missingAPIKey {
            throw IOSOpenAICredentialCoordinatorError.emptyAPIKey
        } catch {
            throw IOSOpenAICredentialCoordinatorError.emptyAPIKey
        }

        return try await performExclusiveOperation { [self] in
            try await performSaveOrReplace(credential)
        }
    }

    private func performSaveOrReplace(
        _ credential: OpenAICredential
    ) async throws -> IOSOpenAICredentialMutationOutcome {
        let priorMarker = try loadReadableMarkerForMutation()
        try saveMarker(
            state: .mutationInProgress,
            mutationKind: .saveOrReplace
        )

        do {
            try await keychainStorage.saveOrReplaceAPIKey(credential.apiKey)
        } catch {
            let exactMarkerRestored = restorePriorMarker(priorMarker)
            if error is CancellationError {
                guard !exactMarkerRestored else {
                    throw CancellationError()
                }
                throw IOSOpenAICredentialCoordinatorError
                    .operationCancelledStatusNeedsRefresh
            }
            throw mappedAccessError(
                error,
                markerRestorationFailed: !exactMarkerRestored
            )
        }

        runtimeCache = .available(makeHandle(for: credential))
        rejectedGeneration = nil

        do {
            try saveMarker(state: .present)
            return .applied
        } catch {
            return .appliedStatusNeedsRefresh
        }
    }

    public func remove() async throws -> IOSOpenAICredentialMutationOutcome {
        try await performExclusiveOperation { [self] in
            try await performRemove()
        }
    }

    private func performRemove() async throws -> IOSOpenAICredentialMutationOutcome {
        let priorMarker = try loadReadableMarkerForMutation()
        try saveMarker(
            state: .mutationInProgress,
            mutationKind: .remove
        )

        do {
            try await keychainStorage.removeAPIKey()
        } catch {
            let exactMarkerRestored = restorePriorMarker(priorMarker)
            if error is CancellationError {
                guard !exactMarkerRestored else {
                    throw CancellationError()
                }
                throw IOSOpenAICredentialCoordinatorError
                    .operationCancelledStatusNeedsRefresh
            }
            throw mappedAccessError(
                error,
                markerRestorationFailed: !exactMarkerRestored
            )
        }

        runtimeCache = .knownAbsent
        rejectedGeneration = nil

        do {
            try saveMarker(state: .absent)
            return .applied
        } catch {
            return .appliedStatusNeedsRefresh
        }
    }

    public func resolve(
        for purpose: IOSOpenAICredentialResolutionPurpose
    ) async throws -> IOSOpenAICredentialResolutionOutcome {
        try await performExclusiveOperation { [self] in
            try await performResolve(for: purpose)
        }
    }

    private func performResolve(
        for purpose: IOSOpenAICredentialResolutionPurpose
    ) async throws -> IOSOpenAICredentialResolutionOutcome {
        let markerObservation = loadMarkerObservation()
        if purpose == .voicePreflight {
            switch runtimeCache {
            case .available(let handle):
                let markerIssue = reconcileMarker(
                    to: .present,
                    from: markerObservation
                )
                if rejectedGeneration == handle.generation {
                    throw IOSOpenAICredentialCoordinatorError.providerRejected
                }
                return makeResolutionOutcome(
                    .available(handle),
                    markerIssue: markerIssue
                )
            case .knownAbsent:
                return makeResolutionOutcome(
                    .notConfigured,
                    markerIssue: reconcileMarker(
                        to: .absent,
                        from: markerObservation
                    )
                )
            case .unresolved, .unavailableWhileLocked:
                break
            }
        }

        return try await resolveFromKeychain(markerObservation: markerObservation)
    }

    /// Records only process-local presentation state for the exact credential
    /// generation that produced the provider rejection.
    public func recordProviderRejection(
        for generation: IOSOpenAICredentialGeneration
    ) {
        guard case .available(let handle) = runtimeCache,
              handle.generation == generation else {
            return
        }

        rejectedGeneration = generation
    }

    private func resolveFromKeychain(
        markerObservation: MarkerObservation
    ) async throws -> IOSOpenAICredentialResolutionOutcome {
        let storedAPIKey: String?
        do {
            storedAPIKey = try await keychainStorage.loadAPIKey()
        } catch {
            if error is CancellationError {
                throw error
            }
            let failure = mappedAccessFailure(error)
            updateRuntimeCache(after: failure)
            throw IOSOpenAICredentialCoordinatorError.credentialAccessFailed(
                failure,
                markerRestorationFailed: false
            )
        }

        guard let storedAPIKey else {
            runtimeCache = .knownAbsent
            rejectedGeneration = nil
            return makeResolutionOutcome(
                .notConfigured,
                markerIssue: reconcileMarker(
                    to: .absent,
                    from: markerObservation
                )
            )
        }

        let credential: OpenAICredential
        do {
            credential = try OpenAICredential(apiKey: storedAPIKey)
        } catch {
            updateRuntimeCache(after: .invalidStoredCredential)
            throw IOSOpenAICredentialCoordinatorError.credentialAccessFailed(
                .invalidStoredCredential,
                markerRestorationFailed: false
            )
        }

        let handle: IOSResolvedOpenAICredential
        if case .available(let currentHandle) = runtimeCache,
           currentHandle.credential == credential {
            handle = currentHandle
        } else {
            handle = makeHandle(for: credential)
            rejectedGeneration = nil
        }
        runtimeCache = .available(handle)

        return makeResolutionOutcome(
            .available(handle),
            markerIssue: reconcileMarker(
                to: .present,
                from: markerObservation
            )
        )
    }

    private func makeResolutionOutcome(
        _ resolution: IOSOpenAICredentialResolution,
        markerIssue: IOSOpenAICredentialLocalMarkerIssue?
    ) -> IOSOpenAICredentialResolutionOutcome {
        let currentStatus = status(for: loadMarkerObservation())
        let outcomeStatus = IOSOpenAICredentialStatus(
            primary: currentStatus.primary,
            statusNeedsRefresh: currentStatus.statusNeedsRefresh,
            localMarkerIssue: markerIssue ?? currentStatus.localMarkerIssue
        )
        return IOSOpenAICredentialResolutionOutcome(
            resolution: resolution,
            status: outcomeStatus
        )
    }

    private func loadReadableMarkerForMutation() throws -> CredentialPresenceMarker? {
        do {
            return try markerStore.load()
        } catch {
            throw IOSOpenAICredentialCoordinatorError.markerUnavailable
        }
    }

    private func loadMarkerObservation() -> MarkerObservation {
        do {
            return .readable(try markerStore.load())
        } catch {
            return .unreadable
        }
    }

    private func saveMarker(
        state: CredentialPresenceMarker.State,
        mutationKind: CredentialPresenceMarker.MutationKind? = nil
    ) throws {
        let marker: CredentialPresenceMarker
        do {
            marker = try CredentialPresenceMarker(
                state: state,
                updatedAt: now(),
                mutationKind: mutationKind
            )
        } catch {
            throw IOSOpenAICredentialCoordinatorError.markerUnavailable
        }

        do {
            try markerStore.save(marker)
        } catch {
            throw IOSOpenAICredentialCoordinatorError.markerUnavailable
        }
    }

    private func restorePriorMarker(
        _ priorMarker: CredentialPresenceMarker?
    ) -> Bool {
        do {
            if let priorMarker {
                try markerStore.save(priorMarker)
            } else {
                try markerStore.removeIfPresent()
            }
            return true
        } catch {
            do {
                try saveMarker(state: .unknown)
            } catch {
                // The durable mutation marker remains fail-closed.
            }
            return false
        }
    }

    private func reconcileMarker(
        to actualPresence: ActualPresence,
        from observation: MarkerObservation
    ) -> IOSOpenAICredentialLocalMarkerIssue? {
        guard case .readable(let marker) = observation else {
            return .unavailable
        }

        let finalState: CredentialPresenceMarker.State = switch actualPresence {
        case .present:
            .present
        case .absent:
            .absent
        }

        if marker?.state == finalState {
            return nil
        }

        switch marker?.state {
        case .unknown, .mutationInProgress:
            break
        case .present, .absent, .none:
            try? saveMarker(state: .unknown)
        }

        do {
            try saveMarker(state: finalState)
            return nil
        } catch {
            return .unavailable
        }
    }

    private func status(
        for markerObservation: MarkerObservation
    ) -> IOSOpenAICredentialStatus {
        let marker: CredentialPresenceMarker?
        let localMarkerIssue: IOSOpenAICredentialLocalMarkerIssue?
        switch markerObservation {
        case .readable(let readableMarker):
            marker = readableMarker
            localMarkerIssue = nil
        case .unreadable:
            marker = nil
            localMarkerIssue = .unavailable
        }

        let primary: IOSOpenAICredentialPrimaryStatus = switch runtimeCache {
        case .available(let handle):
            rejectedGeneration == handle.generation
                ? .providerRejected
                : .availableInThisProcess
        case .knownAbsent:
            .notConfigured
        case .unavailableWhileLocked:
            .unavailableWhileLocked
        case .unresolved:
            switch marker?.state {
            case .present:
                .savedLastKnown
            case .absent:
                .notConfigured
            case .unknown, .mutationInProgress, .none:
                .notCheckedInThisProcess
            }
        }

        let statusNeedsRefresh = switch marker?.state {
        case .unknown, .mutationInProgress:
            true
        case .present, .absent, .none:
            false
        }

        return IOSOpenAICredentialStatus(
            primary: primary,
            statusNeedsRefresh: statusNeedsRefresh,
            localMarkerIssue: localMarkerIssue
        )
    }

    private func makeHandle(
        for credential: OpenAICredential
    ) -> IOSResolvedOpenAICredential {
        IOSResolvedOpenAICredential(
            credential: credential,
            generation: IOSOpenAICredentialGeneration(rawValue: UUID())
        )
    }

    private func mappedAccessError(
        _ error: Error,
        markerRestorationFailed: Bool
    ) -> IOSOpenAICredentialCoordinatorError {
        .credentialAccessFailed(
            mappedAccessFailure(error),
            markerRestorationFailed: markerRestorationFailed
        )
    }

    private func mappedAccessFailure(
        _ error: Error
    ) -> IOSOpenAICredentialAccessFailure {
        guard let error = error as? OpenAIAPIKeyKeychainStorageError else {
            return .keychainFailure
        }

        switch error {
        case .unavailableWhileLocked:
            return .unavailableWhileLocked
        case .invalidResult, .invalidStoredAPIKey, .emptyAPIKey:
            return .invalidStoredCredential
        case .invalidApplicationIdentifierAccessGroup, .keychainFailure:
            return .keychainFailure
        }
    }

    private func updateRuntimeCache(
        after failure: IOSOpenAICredentialAccessFailure
    ) {
        switch (runtimeCache, failure) {
        case (.unresolved, .unavailableWhileLocked):
            runtimeCache = .unavailableWhileLocked
        case (.unavailableWhileLocked, .invalidStoredCredential),
             (.unavailableWhileLocked, .keychainFailure):
            runtimeCache = .unresolved
        case (.unresolved, .invalidStoredCredential),
             (.unresolved, .keychainFailure),
             (.available, _),
             (.knownAbsent, _),
             (.unavailableWhileLocked, .unavailableWhileLocked):
            break
        }
    }

    private func performExclusiveOperation<Value: Sendable>(
        _ operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        do {
            return try await operationGate.perform(operation)
        } catch CredentialOperationGate.AcquisitionError.cancelledBeforeLease {
            throw IOSOpenAICredentialCoordinatorError.operationCancelledBeforeStart
        }
    }
}

protocol IOSCredentialPresenceMarkerStoring: Sendable {
    func load() throws -> CredentialPresenceMarker?
    func save(_ marker: CredentialPresenceMarker) throws
    func removeIfPresent() throws
}

private struct RepositoryCredentialPresenceMarkerStore:
    IOSCredentialPresenceMarkerStoring
{
    let repository: CredentialPresenceMarkerRepository

    func load() throws -> CredentialPresenceMarker? {
        try repository.load()
    }

    func save(_ marker: CredentialPresenceMarker) throws {
        try repository.save(marker)
    }

    func removeIfPresent() throws {
        try repository.removeIfPresent()
    }
}
