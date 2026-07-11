import Foundation

final class IOSFailedHistoryMutationInterlock: @unchecked Sendable {
    private let lock = NSLock()
    private var blocked = false

    var isBlocked: Bool { lock.withLock { blocked } }

    fileprivate func retainUncertainty() {
        lock.withLock { blocked = true }
    }

    fileprivate func clearUncertainty() {
        lock.withLock { blocked = false }
    }
}

struct IOSFailedHistoryStoreIdentity: Equatable, Sendable {
    private let value = UUID()
}

extension IOSFailedHistoryStoreIdentity:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "IOSFailedHistoryStoreIdentity(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

struct IOSFailedHistoryJournalMutationAuthorization: Sendable {
    let expectedRepositoryRoot: IOSPersistenceRepositoryRootIdentity?

    fileprivate init(
        expectedRepositoryRoot: IOSPersistenceRepositoryRootIdentity?
    ) {
        self.expectedRepositoryRoot = expectedRepositoryRoot
    }

    #if DEBUG
    init(testingToken: Void) {
        _ = testingToken
        self.init(expectedRepositoryRoot: nil)
    }
    #endif
}

fileprivate enum IOSFailedHistoryMutationSource: Equatable, Sendable {
    case missing
    case existing(IOSFailedHistoryJournalSnapshot)
}

fileprivate struct IOSFailedHistoryUncertainMutationIntent:
    Equatable,
    Sendable {
    let source: IOSFailedHistoryMutationSource
    let outcome: IOSFailedHistoryEnvelope
}

struct IOSFailedHistoryMutationCapability: Equatable, Sendable {
    fileprivate let source: IOSFailedHistoryMutationSource
    fileprivate let outcome: IOSFailedHistoryEnvelope
    fileprivate let retainedIntent: IOSFailedHistoryUncertainMutationIntent?
    let storeIdentity: IOSFailedHistoryStoreIdentity
    let capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
    fileprivate let repositoryBinding:
        IOSAcceptedHistoryCoordinatorRepositoryBinding?

    fileprivate init(
        source: IOSFailedHistoryMutationSource,
        outcome: IOSFailedHistoryEnvelope,
        retainedIntent: IOSFailedHistoryUncertainMutationIntent?,
        storeIdentity: IOSFailedHistoryStoreIdentity,
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization,
        repositoryBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding?
    ) {
        self.source = source
        self.outcome = outcome
        self.retainedIntent = retainedIntent
        self.storeIdentity = storeIdentity
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
        self.operationLeaseAuthorization = operationLeaseAuthorization
        self.repositoryBinding = repositoryBinding
    }
}

extension IOSFailedHistoryMutationCapability:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryMutationCapability(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

struct IOSFailedHistoryMutationReceipt: Equatable, Sendable {
    fileprivate let snapshot: IOSFailedHistoryJournalSnapshot
    let storeIdentity: IOSFailedHistoryStoreIdentity
    let capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
    fileprivate let repositoryBinding:
        IOSAcceptedHistoryCoordinatorRepositoryBinding?

    fileprivate init(
        snapshot: IOSFailedHistoryJournalSnapshot,
        storeIdentity: IOSFailedHistoryStoreIdentity,
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization,
        repositoryBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding?
    ) {
        self.snapshot = snapshot
        self.storeIdentity = storeIdentity
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
        self.operationLeaseAuthorization = operationLeaseAuthorization
        self.repositoryBinding = repositoryBinding
    }
}

extension IOSFailedHistoryMutationReceipt:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "IOSFailedHistoryMutationReceipt(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

struct IOSFailedHistoryGuardedBaselineEvidence: Sendable {
    let capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity

    fileprivate init(
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    ) {
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
    }
}

extension IOSFailedHistoryGuardedBaselineEvidence:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryGuardedBaselineEvidence(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Internal raw repository. App-facing reads are added only with policy
/// filtering and audio-availability projection in the integration checkpoint.
actor IOSFailedHistoryStore {
    nonisolated let capabilityOwnerIdentity:
        IOSAcceptedHistoryCapabilityOwnerIdentity
    nonisolated let storeIdentity: IOSFailedHistoryStoreIdentity
    private let journal: any IOSFailedHistoryJournalStoring
    private let now: @Sendable () -> Date
    private let operationGateBinding: IOSPersistenceOperationGateBinding
    private let repositoryGuard:
        IOSAcceptedHistoryCoordinatorRepositoryGuard?
    nonisolated let mutationInterlock: IOSFailedHistoryMutationInterlock
    private var uncertainMutationIntent:
        IOSFailedHistoryUncertainMutationIntent?

    init(
        applicationSupportDirectoryURL: URL,
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        storeIdentity: IOSFailedHistoryStoreIdentity =
            IOSFailedHistoryStoreIdentity(),
        operationGateIdentity: IOSPersistenceOperationGateIdentity? = nil,
        repositoryGuard:
            IOSAcceptedHistoryCoordinatorRepositoryGuard? = nil,
        mutationInterlock: IOSFailedHistoryMutationInterlock =
            IOSFailedHistoryMutationInterlock()
    ) {
        journal = FoundationIOSFailedHistoryJournalRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            repositoryGuard: repositoryGuard
        )
        now = { Date() }
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
        self.storeIdentity = storeIdentity
        operationGateBinding = IOSPersistenceOperationGateBinding(
            identity: operationGateIdentity
        )
        self.repositoryGuard = repositoryGuard
        self.mutationInterlock = mutationInterlock
    }

    init(
        journal: any IOSFailedHistoryJournalStoring,
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        storeIdentity: IOSFailedHistoryStoreIdentity =
            IOSFailedHistoryStoreIdentity(),
        operationGateIdentity: IOSPersistenceOperationGateIdentity? = nil,
        repositoryGuard:
            IOSAcceptedHistoryCoordinatorRepositoryGuard? = nil,
        mutationInterlock: IOSFailedHistoryMutationInterlock =
            IOSFailedHistoryMutationInterlock(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.journal = journal
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
        self.storeIdentity = storeIdentity
        operationGateBinding = IOSPersistenceOperationGateBinding(
            identity: operationGateIdentity
        )
        self.repositoryGuard = repositoryGuard
        self.mutationInterlock = mutationInterlock
        self.now = now
    }

    nonisolated func bindOperationGateIdentity(
        _ identity: IOSPersistenceOperationGateIdentity
    ) -> Bool {
        operationGateBinding.bind(identity)
    }

    /// Raw state is coordinator-only because old policy generations and audio
    /// cleanup tombstones intentionally survive until bounded reconciliation.
    func load() throws -> IOSFailedHistoryEnvelope? {
        try requireNoMutationUncertainty()
        return try journal.load()?.envelope
    }

    func proveGuardedBaseline()
        throws -> IOSFailedHistoryGuardedBaselineEvidence {
        try requireNoMutationUncertainty()
        if let envelope = try journal.load()?.envelope {
            guard envelope.entries.isEmpty,
                  envelope.audioCleanup.isEmpty else {
                throw IOSFailedHistoryError.compareAndSwapFailed
            }
        }
        return IOSFailedHistoryGuardedBaselineEvidence(
            capabilityOwnerIdentity: capabilityOwnerIdentity
        )
    }

    @discardableResult
    func performStagingMaintenance(
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    )
        throws -> IOSFailedHistoryMaintenanceReport {
        try requireActiveLease(operationLeaseAuthorization)
        try requireNoMutationUncertainty()
        let repositoryBinding = try currentRepositoryBinding()
        do {
            let report = try journal.performStagingMaintenance(
                now: now(),
                expectedRepositoryRoot:
                    repositoryBinding?.physicalRootIdentity
            )
            try requireRepositoryBinding(repositoryBinding)
            return IOSFailedHistoryMaintenanceReport(report)
        } catch {
            do {
                try requireRepositoryBinding(repositoryBinding)
            } catch {
                throw IOSFailedHistoryError.repositoryIdentityConflict
            }
            throw error
        }
    }

    #if DEBUG
    func reserveExactMutationForTesting(
        _ outcome: IOSFailedHistoryEnvelope,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) throws -> IOSFailedHistoryMutationCapability {
        try reserveExactMutation(
            outcome,
            operationLeaseAuthorization: operationLeaseAuthorization
        )
    }

    func commitExactMutationForTesting(
        _ capability: IOSFailedHistoryMutationCapability
    ) throws -> IOSFailedHistoryMutationReceipt {
        try commitExactMutation(capability)
    }

    func mutateExactForTesting(
        _ outcome: IOSFailedHistoryEnvelope,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) throws -> IOSFailedHistoryMutationReceipt {
        let capability = try reserveExactMutation(
            outcome,
            operationLeaseAuthorization: operationLeaseAuthorization
        )
        return try commitExactMutation(capability)
    }

    func validateMutationReceiptForTesting(
        _ receipt: IOSFailedHistoryMutationReceipt,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) throws -> IOSFailedHistoryEnvelope {
        try validatedSnapshot(
            for: receipt,
            operationLeaseAuthorization: operationLeaseAuthorization
        ).envelope
    }

    func retainMutationUncertaintyForTesting() {
        mutationInterlock.retainUncertainty()
    }
    #endif
}

private extension IOSFailedHistoryStore {
    func reserveExactMutation(
        _ outcome: IOSFailedHistoryEnvelope,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) throws -> IOSFailedHistoryMutationCapability {
        try requireActiveLease(operationLeaseAuthorization)
        let repositoryBinding = try currentRepositoryBinding()

        if let intent = uncertainMutationIntent {
            guard intent.outcome == outcome else {
                throw IOSFailedHistoryError.commitUncertain
            }
            let current = try journal.load()
            let sourceStillCurrent: Bool = switch (intent.source, current) {
            case (.missing, .none): true
            case (.existing(let source), .some(let current)):
                source == current
            default: false
            }
            if sourceStillCurrent {
                return mutationCapability(
                    source: intent.source,
                    outcome: outcome,
                    retainedIntent: intent,
                    operationLeaseAuthorization:
                        operationLeaseAuthorization,
                    repositoryBinding: repositoryBinding
                )
            }
            if let current,
               current.envelope == outcome {
                return mutationCapability(
                    source: .existing(current),
                    outcome: outcome,
                    retainedIntent: intent,
                    operationLeaseAuthorization:
                        operationLeaseAuthorization,
                    repositoryBinding: repositoryBinding
                )
            }
            throw IOSFailedHistoryError.commitUncertain
        }

        let source: IOSFailedHistoryMutationSource =
            if let current = try journal.load() {
                .existing(current)
            } else {
                .missing
            }
        try requireNextRevision(outcome, after: source)
        return mutationCapability(
            source: source,
            outcome: outcome,
            retainedIntent: nil,
            operationLeaseAuthorization: operationLeaseAuthorization,
            repositoryBinding: repositoryBinding
        )
    }

    func commitExactMutation(
        _ capability: IOSFailedHistoryMutationCapability
    ) throws -> IOSFailedHistoryMutationReceipt {
        try requireCapability(capability)
        if let retainedIntent = capability.retainedIntent {
            guard uncertainMutationIntent == retainedIntent,
                  retainedIntent.outcome == capability.outcome else {
                throw IOSFailedHistoryError.commitUncertain
            }
        } else {
            guard uncertainMutationIntent == nil else {
                throw IOSFailedHistoryError.commitUncertain
            }
        }
        return try publish(
            capability.outcome,
            source: capability.source,
            capability: capability
        )
    }

    func publish(
        _ outcome: IOSFailedHistoryEnvelope,
        source: IOSFailedHistoryMutationSource,
        capability: IOSFailedHistoryMutationCapability
    ) throws -> IOSFailedHistoryMutationReceipt {
        let attemptedIntent = IOSFailedHistoryUncertainMutationIntent(
            source: source,
            outcome: outcome
        )
        let retainedIntent = capability.retainedIntent
        do {
            try requireRepositoryBinding(capability.repositoryBinding)
            let snapshot: IOSFailedHistoryJournalSnapshot = switch source {
            case .missing:
                try journal.create(
                    outcome,
                    authorization:
                        IOSFailedHistoryJournalMutationAuthorization(
                            expectedRepositoryRoot: capability
                                .repositoryBinding?.physicalRootIdentity
                        )
                )
            case .existing(let current):
                try journal.replace(
                    outcome,
                    expected: current,
                    authorization:
                        IOSFailedHistoryJournalMutationAuthorization(
                            expectedRepositoryRoot: capability
                                .repositoryBinding?.physicalRootIdentity
                        )
                )
            }
            guard snapshot.envelope == outcome else {
                retainMutationIntent(attemptedIntent)
                throw IOSFailedHistoryError.commitUncertain
            }
            do {
                try requireRepositoryBinding(capability.repositoryBinding)
            } catch {
                retainMutationIntent(attemptedIntent)
                throw error
            }
            clearMutationIntent()
            return IOSFailedHistoryMutationReceipt(
                snapshot: snapshot,
                storeIdentity: storeIdentity,
                capabilityOwnerIdentity: capabilityOwnerIdentity,
                operationLeaseAuthorization:
                    capability.operationLeaseAuthorization,
                repositoryBinding: capability.repositoryBinding
            )
        } catch IOSFailedHistoryError.commitUncertain {
            retainMutationIntent(attemptedIntent)
            throw IOSFailedHistoryError.commitUncertain
        } catch IOSFailedHistoryError.compareAndSwapFailed {
            guard let retainedIntent else {
                throw IOSFailedHistoryError.compareAndSwapFailed
            }
            retainMutationIntent(retainedIntent)
            throw IOSFailedHistoryError.commitUncertain
        } catch {
            do {
                try requireRepositoryBinding(capability.repositoryBinding)
            } catch {
                throw IOSFailedHistoryError.repositoryIdentityConflict
            }
            if let retainedIntent {
                retainMutationIntent(retainedIntent)
                throw IOSFailedHistoryError.commitUncertain
            }
            throw error
        }
    }

    func mutationCapability(
        source: IOSFailedHistoryMutationSource,
        outcome: IOSFailedHistoryEnvelope,
        retainedIntent: IOSFailedHistoryUncertainMutationIntent?,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization,
        repositoryBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding?
    ) -> IOSFailedHistoryMutationCapability {
        IOSFailedHistoryMutationCapability(
            source: source,
            outcome: outcome,
            retainedIntent: retainedIntent,
            storeIdentity: storeIdentity,
            capabilityOwnerIdentity: capabilityOwnerIdentity,
            operationLeaseAuthorization: operationLeaseAuthorization,
            repositoryBinding: repositoryBinding
        )
    }

    func requireNextRevision(
        _ outcome: IOSFailedHistoryEnvelope,
        after source: IOSFailedHistoryMutationSource
    ) throws {
        switch source {
        case .missing:
            guard outcome.revision == 1 else {
                throw IOSFailedHistoryError.compareAndSwapFailed
            }
        case .existing(let current):
            let next = current.envelope.revision.addingReportingOverflow(1)
            guard !next.overflow else {
                throw IOSFailedHistoryError.revisionOverflow
            }
            guard outcome.revision == next.partialValue else {
                throw IOSFailedHistoryError.compareAndSwapFailed
            }
        }
    }

    func validatedSnapshot(
        for receipt: IOSFailedHistoryMutationReceipt,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) throws -> IOSFailedHistoryJournalSnapshot {
        try requireActiveLease(operationLeaseAuthorization)
        try requireNoMutationUncertainty()
        guard receipt.storeIdentity == storeIdentity,
              receipt.capabilityOwnerIdentity == capabilityOwnerIdentity,
              receipt.operationLeaseAuthorization.provesSameActiveLease(
                  as: operationLeaseAuthorization
              ) else {
            throw IOSFailedHistoryError.compareAndSwapFailed
        }
        try requireRepositoryBinding(receipt.repositoryBinding)
        guard let current = try journal.load(),
              current == receipt.snapshot else {
            throw IOSFailedHistoryError.compareAndSwapFailed
        }
        try requireRepositoryBinding(receipt.repositoryBinding)
        return current
    }

    func requireCapability(
        _ capability: IOSFailedHistoryMutationCapability
    ) throws {
        try requireActiveLease(capability.operationLeaseAuthorization)
        guard capability.storeIdentity == storeIdentity,
              capability.capabilityOwnerIdentity
                == capabilityOwnerIdentity else {
            throw IOSFailedHistoryError.compareAndSwapFailed
        }
        try requireRepositoryBinding(capability.repositoryBinding)
    }

    func requireActiveLease(
        _ authorization: IOSPersistenceOperationLeaseAuthorization
    ) throws {
        guard operationGateBinding.proves(authorization) else {
            throw IOSFailedHistoryError.compareAndSwapFailed
        }
    }

    func requireNoMutationUncertainty() throws {
        guard uncertainMutationIntent == nil else {
            throw IOSFailedHistoryError.commitUncertain
        }
    }

    func retainMutationIntent(
        _ intent: IOSFailedHistoryUncertainMutationIntent
    ) {
        uncertainMutationIntent = intent
        mutationInterlock.retainUncertainty()
    }

    func clearMutationIntent() {
        uncertainMutationIntent = nil
        mutationInterlock.clearUncertainty()
    }

    func currentRepositoryBinding()
        throws -> IOSAcceptedHistoryCoordinatorRepositoryBinding? {
        guard let repositoryGuard else { return nil }
        do {
            return try repositoryGuard.revalidate()
        } catch {
            throw IOSFailedHistoryError.repositoryIdentityConflict
        }
    }

    func requireRepositoryBinding(
        _ expected: IOSAcceptedHistoryCoordinatorRepositoryBinding?
    ) throws {
        switch (repositoryGuard, expected) {
        case (.none, .none):
            return
        case (.some(let repositoryGuard), .some(let expected)):
            do {
                _ = try repositoryGuard.revalidate(
                    expectedBinding: expected
                )
            } catch {
                throw IOSFailedHistoryError.repositoryIdentityConflict
            }
        case (.none, .some), (.some, .none):
            throw IOSFailedHistoryError.compareAndSwapFailed
        }
    }
}
