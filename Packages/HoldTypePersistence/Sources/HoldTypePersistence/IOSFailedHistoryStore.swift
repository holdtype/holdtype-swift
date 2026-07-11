import Foundation

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
    fileprivate init() {}

    #if DEBUG
    init(testingToken: Void) {
        _ = testingToken
        self.init()
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

    fileprivate init(
        source: IOSFailedHistoryMutationSource,
        outcome: IOSFailedHistoryEnvelope,
        retainedIntent: IOSFailedHistoryUncertainMutationIntent?,
        storeIdentity: IOSFailedHistoryStoreIdentity,
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        self.source = source
        self.outcome = outcome
        self.retainedIntent = retainedIntent
        self.storeIdentity = storeIdentity
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
        self.operationLeaseAuthorization = operationLeaseAuthorization
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

    fileprivate init(
        snapshot: IOSFailedHistoryJournalSnapshot,
        storeIdentity: IOSFailedHistoryStoreIdentity,
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        self.snapshot = snapshot
        self.storeIdentity = storeIdentity
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
        self.operationLeaseAuthorization = operationLeaseAuthorization
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
    private var uncertainMutationIntent:
        IOSFailedHistoryUncertainMutationIntent?

    init(
        applicationSupportDirectoryURL: URL,
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        storeIdentity: IOSFailedHistoryStoreIdentity =
            IOSFailedHistoryStoreIdentity(),
        operationGateIdentity: IOSPersistenceOperationGateIdentity? = nil
    ) {
        journal = FoundationIOSFailedHistoryJournalRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL
        )
        now = { Date() }
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
        self.storeIdentity = storeIdentity
        operationGateBinding = IOSPersistenceOperationGateBinding(
            identity: operationGateIdentity
        )
    }

    init(
        journal: any IOSFailedHistoryJournalStoring,
        capabilityOwnerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        storeIdentity: IOSFailedHistoryStoreIdentity =
            IOSFailedHistoryStoreIdentity(),
        operationGateIdentity: IOSPersistenceOperationGateIdentity? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.journal = journal
        self.capabilityOwnerIdentity = capabilityOwnerIdentity
        self.storeIdentity = storeIdentity
        operationGateBinding = IOSPersistenceOperationGateBinding(
            identity: operationGateIdentity
        )
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
        try journal.load()?.envelope
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
    func performStagingMaintenance()
        throws -> IOSFailedHistoryMaintenanceReport {
        try requireNoMutationUncertainty()
        IOSFailedHistoryMaintenanceReport(
            try journal.performStagingMaintenance(now: now())
        )
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
    #endif
}

private extension IOSFailedHistoryStore {
    func reserveExactMutation(
        _ outcome: IOSFailedHistoryEnvelope,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) throws -> IOSFailedHistoryMutationCapability {
        try requireActiveLease(operationLeaseAuthorization)

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
                        operationLeaseAuthorization
                )
            }
            if let current,
               current.envelope == outcome {
                return mutationCapability(
                    source: .existing(current),
                    outcome: outcome,
                    retainedIntent: intent,
                    operationLeaseAuthorization:
                        operationLeaseAuthorization
                )
            }
            uncertainMutationIntent = nil
            throw IOSFailedHistoryError.compareAndSwapFailed
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
            operationLeaseAuthorization: operationLeaseAuthorization
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
            let snapshot: IOSFailedHistoryJournalSnapshot = switch source {
            case .missing:
                try journal.create(
                    outcome,
                    authorization:
                        IOSFailedHistoryJournalMutationAuthorization()
                )
            case .existing(let current):
                try journal.replace(
                    outcome,
                    expected: current,
                    authorization:
                        IOSFailedHistoryJournalMutationAuthorization()
                )
            }
            guard snapshot.envelope == outcome else {
                uncertainMutationIntent = attemptedIntent
                throw IOSFailedHistoryError.commitUncertain
            }
            uncertainMutationIntent = nil
            return IOSFailedHistoryMutationReceipt(
                snapshot: snapshot,
                storeIdentity: storeIdentity,
                capabilityOwnerIdentity: capabilityOwnerIdentity,
                operationLeaseAuthorization:
                    capability.operationLeaseAuthorization
            )
        } catch IOSFailedHistoryError.commitUncertain {
            uncertainMutationIntent = attemptedIntent
            throw IOSFailedHistoryError.commitUncertain
        } catch IOSFailedHistoryError.compareAndSwapFailed {
            guard let retainedIntent else {
                throw IOSFailedHistoryError.compareAndSwapFailed
            }
            uncertainMutationIntent = retainedIntent
            throw IOSFailedHistoryError.commitUncertain
        } catch {
            if let retainedIntent {
                uncertainMutationIntent = retainedIntent
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
            IOSPersistenceOperationLeaseAuthorization
    ) -> IOSFailedHistoryMutationCapability {
        IOSFailedHistoryMutationCapability(
            source: source,
            outcome: outcome,
            retainedIntent: retainedIntent,
            storeIdentity: storeIdentity,
            capabilityOwnerIdentity: capabilityOwnerIdentity,
            operationLeaseAuthorization: operationLeaseAuthorization
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
        guard receipt.storeIdentity == storeIdentity,
              receipt.capabilityOwnerIdentity == capabilityOwnerIdentity,
              receipt.operationLeaseAuthorization.provesSameActiveLease(
                  as: operationLeaseAuthorization
              ) else {
            throw IOSFailedHistoryError.compareAndSwapFailed
        }
        return receipt.snapshot
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
}
