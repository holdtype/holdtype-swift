import Foundation

struct IOSFailedHistoryAudioCleanupOperationID: Equatable, Sendable {
    private let value = UUID()

    init() {}
}

enum IOSFailedHistoryAudioCleanupPurpose: Equatable, Sendable {
    case nextHead
    case explicitDelete(IOSFailedHistoryTombstoneReceipt)
}

/// Failed-store authority for reconciling exactly one cleanup tombstone and
/// its protected audio under one active root lease.
struct IOSFailedHistoryAudioCleanupAuthorization: Equatable, Sendable {
    let failedSource: IOSFailedHistoryJournalSnapshot
    let tombstone: IOSFailedHistoryAudioCleanup
    let outcome: IOSFailedHistoryEnvelope
    let purpose: IOSFailedHistoryAudioCleanupPurpose
    let operationID: IOSFailedHistoryAudioCleanupOperationID
    let failedInventory: IOSFailedHistoryProtectedAudioInventory
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryAudioCleanupAuthorizationMint,
        failedSource: IOSFailedHistoryJournalSnapshot,
        tombstone: IOSFailedHistoryAudioCleanup,
        outcome: IOSFailedHistoryEnvelope,
        purpose: IOSFailedHistoryAudioCleanupPurpose,
        operationID: IOSFailedHistoryAudioCleanupOperationID,
        failedInventory: IOSFailedHistoryProtectedAudioInventory,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        _ = mint
        let nextRevision = failedSource.envelope.revision
            .addingReportingOverflow(1)
        var expectedCleanup = failedSource.envelope.audioCleanup
        guard let tombstoneIndex = expectedCleanup.firstIndex(of: tombstone) else {
            return nil
        }
        expectedCleanup.remove(at: tombstoneIndex)
        guard operationLeaseAuthorization.provesActiveLease(),
              repositoryBinding.physicalRootIdentity != nil,
              failedInventory.failedSource == failedSource,
              failedInventory.failedStoreIdentity == failedStoreIdentity,
              failedInventory.expectedPendingStoreIdentity
                == expectedPendingStoreIdentity,
              failedInventory.ownerIdentity == ownerIdentity,
              failedInventory.repositoryBinding == repositoryBinding,
              failedInventory.operationLeaseAuthorization
                .provesSameActiveLease(
                    as: operationLeaseAuthorization
                ),
              !nextRevision.overflow,
              outcome.revision == nextRevision.partialValue,
              outcome.entries == failedSource.envelope.entries,
              outcome.audioCleanup == expectedCleanup else {
            return nil
        }
        switch purpose {
        case .nextHead:
            guard failedSource.envelope.audioCleanup.first == tombstone else {
                return nil
            }
        case .explicitDelete(let receipt):
            guard receipt.tombstone == tombstone,
                  receipt.outcome == failedSource.envelope,
                  receipt.failedStoreIdentity == failedStoreIdentity,
                  receipt.expectedPendingStoreIdentity
                    == expectedPendingStoreIdentity,
                  receipt.ownerIdentity == ownerIdentity,
                  receipt.repositoryBinding == repositoryBinding else {
                return nil
            }
        }

        self.failedSource = failedSource
        self.tombstone = tombstone
        self.outcome = outcome
        self.purpose = purpose
        self.operationID = operationID
        self.failedInventory = failedInventory
        self.failedStoreIdentity = failedStoreIdentity
        self.expectedPendingStoreIdentity = expectedPendingStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }
}

/// Completion-only capability for clearing the process-local cleanup interlock
/// after the exact tombstone-retirement outcome is already durable.
struct IOSFailedHistoryAudioCleanupCompletionAuthorization:
    Equatable,
    Sendable {
    let operationID: IOSFailedHistoryAudioCleanupOperationID
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryAudioCleanupCompletionAuthorizationMint,
        operationID: IOSFailedHistoryAudioCleanupOperationID,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        _ = mint
        guard operationLeaseAuthorization.provesActiveLease(),
              repositoryBinding.physicalRootIdentity != nil else {
            return nil
        }
        self.operationID = operationID
        self.failedStoreIdentity = failedStoreIdentity
        self.expectedPendingStoreIdentity = expectedPendingStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }
}

/// Pending-store proof that the exact authorized protected audio is durably
/// absent. The filesystem evidence remains opaque and descriptor-derived.
struct IOSFailedHistoryAudioCleanupReceipt: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case removed(
            evidence: IOSPendingRecordingProtectedAudioCleanupEvidence
        )
        case alreadyAbsent(
            evidence: IOSPendingRecordingProtectedAudioCleanupEvidence
        )
    }

    let issuerStoreIdentity: IOSPendingRecordingStoreIdentity
    let authorization: IOSFailedHistoryAudioCleanupAuthorization
    let outcome: Outcome

    init?(
        mint: IOSFailedHistoryAudioCleanupReceiptMint,
        issuerStoreIdentity: IOSPendingRecordingStoreIdentity,
        authorization: IOSFailedHistoryAudioCleanupAuthorization,
        outcome: Outcome
    ) {
        _ = mint
        guard issuerStoreIdentity
                == authorization.expectedPendingStoreIdentity,
              authorization.operationLeaseAuthorization.provesActiveLease()
        else {
            return nil
        }
        switch outcome {
        case .removed(let evidence):
            guard evidence.provesRemoval(of: authorization) else {
                return nil
            }
        case .alreadyAbsent(let evidence):
            guard evidence.provesPreexistingAbsence(of: authorization) else {
                return nil
            }
        }
        self.issuerStoreIdentity = issuerStoreIdentity
        self.authorization = authorization
        self.outcome = outcome
    }
}

extension IOSFailedHistoryAudioCleanupOperationID:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryAudioCleanupOperationID(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryAudioCleanupPurpose:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryAudioCleanupPurpose(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryAudioCleanupAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryAudioCleanupAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryAudioCleanupCompletionAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryAudioCleanupCompletionAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryAudioCleanupReceipt.Outcome:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryAudioCleanupReceipt.Outcome(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryAudioCleanupReceipt:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryAudioCleanupReceipt(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
