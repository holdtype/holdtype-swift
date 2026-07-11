import Foundation

/// Payload-free durable treatment of a provider-completed Retry failure.
enum IOSFailedHistoryRetryFailureDisposition: Equatable, Sendable {
    case mapped(
        category: IOSFailedHistoryFailureCategory,
        stage: IOSFailedHistoryPipelineStage
    )
    case preservePrevious
}

enum IOSFailedHistoryRetryFailurePreparation: Equatable, Sendable {
    case commit(IOSFailedHistoryRetryFailureAuthorization)
    case completed(IOSFailedHistoryRetryFailureReceipt)
}

struct IOSFailedHistoryRetryFailureAuthorization: Equatable, Sendable {
    let dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt
    let providerCompletionClaim:
        IOSFailedHistoryRetryProviderCompletionClaim
    let disposition: IOSFailedHistoryRetryFailureDisposition
    let failedSource: IOSFailedHistoryJournalSnapshot
    let retryingRow: IOSFailedHistoryEntry
    let retainedRow: IOSFailedHistoryEntry
    let retryOperation: IOSFailedHistoryRetryOperation
    let outcome: IOSFailedHistoryEnvelope
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryRetryFailureAuthorizationMint,
        dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt,
        providerCompletionClaim:
            IOSFailedHistoryRetryProviderCompletionClaim,
        disposition: IOSFailedHistoryRetryFailureDisposition,
        failedSource: IOSFailedHistoryJournalSnapshot,
        retryingRow: IOSFailedHistoryEntry,
        retainedRow: IOSFailedHistoryEntry,
        retryOperation: IOSFailedHistoryRetryOperation,
        outcome: IOSFailedHistoryEnvelope,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        _ = mint
        let nextRevision = failedSource.envelope.revision
            .addingReportingOverflow(1)
        guard operationLeaseAuthorization.provesActiveLease(),
              repositoryBinding.physicalRootIdentity != nil,
              dispatchReceipt.failedStoreIdentity == failedStoreIdentity,
              dispatchReceipt.ownerIdentity == ownerIdentity,
              dispatchReceipt.repositoryBinding == repositoryBinding,
              dispatchReceipt.durableSnapshot == failedSource,
              dispatchReceipt.row == retryingRow,
              dispatchReceipt.retryOperation == retryOperation,
              providerCompletionClaim.liveOwnerToken
                == dispatchReceipt.liveOwnerToken,
              retryOperation.state == .providerDispatched,
              retryingRow.retryOperation == retryOperation,
              retainedRow.retryOperation == nil,
              retainedRow.updatedAt >= retryingRow.updatedAt,
              retainedRow.retryCount == retryingRow.retryCount,
              Self.preservesRetryRow(retryingRow, in: retainedRow),
              Self.applies(
                disposition,
                source: retryingRow,
                retained: retainedRow
              ),
              !nextRevision.overflow,
              outcome.revision == nextRevision.partialValue,
              outcome.audioCleanup == failedSource.envelope.audioCleanup,
              Self.isExactReplacement(
                source: failedSource.envelope,
                candidate: retryingRow,
                replacement: retainedRow,
                outcome: outcome
              ) else {
            return nil
        }

        self.dispatchReceipt = dispatchReceipt
        self.providerCompletionClaim = providerCompletionClaim
        self.disposition = disposition
        self.failedSource = failedSource
        self.retryingRow = retryingRow
        self.retainedRow = retainedRow
        self.retryOperation = retryOperation
        self.outcome = outcome
        self.failedStoreIdentity = failedStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }

    func identifiesSameFailure(
        as other: IOSFailedHistoryRetryFailureAuthorization
    ) -> Bool {
        dispatchReceipt.identifiesSameDispatch(as: other.dispatchReceipt)
            && providerCompletionClaim == other.providerCompletionClaim
            && disposition == other.disposition
            && failedSource == other.failedSource
            && retryingRow == other.retryingRow
            && retainedRow == other.retainedRow
            && retryOperation == other.retryOperation
            && outcome == other.outcome
            && failedStoreIdentity == other.failedStoreIdentity
            && ownerIdentity == other.ownerIdentity
            && repositoryBinding == other.repositoryBinding
    }

    private static func preservesRetryRow(
        _ source: IOSFailedHistoryEntry,
        in retained: IOSFailedHistoryEntry
    ) -> Bool {
        source.attemptID == retained.attemptID
            && source.createdAt == retained.createdAt
            && source.policyGeneration == retained.policyGeneration
            && source.retryCount == retained.retryCount
            && source.outputIntent == retained.outputIntent
            && IOSAcceptedOutputDeliveryValidation.bytesEqual(
                source.transcriptionModel,
                retained.transcriptionModel
            )
            && source.transcriptionLanguageCode
                == retained.transcriptionLanguageCode
            && source.durationMilliseconds == retained.durationMilliseconds
            && source.byteCount == retained.byteCount
            && source.audioRelativeIdentifier
                == retained.audioRelativeIdentifier
            && source.ownershipState == retained.ownershipState
    }

    private static func applies(
        _ disposition: IOSFailedHistoryRetryFailureDisposition,
        source: IOSFailedHistoryEntry,
        retained: IOSFailedHistoryEntry
    ) -> Bool {
        switch disposition {
        case .mapped(let category, let stage):
            return retained.failureCategory == category
                && retained.pipelineStage == stage
        case .preservePrevious:
            return retained.failureCategory == source.failureCategory
                && retained.pipelineStage == source.pipelineStage
        }
    }

    private static func isExactReplacement(
        source: IOSFailedHistoryEnvelope,
        candidate: IOSFailedHistoryEntry,
        replacement: IOSFailedHistoryEntry,
        outcome: IOSFailedHistoryEnvelope
    ) -> Bool {
        guard let index = source.entries.firstIndex(of: candidate) else {
            return false
        }
        var entries = source.entries
        entries[index] = replacement
        return outcome.entries
            == IOSFailedHistoryValidation.sortedEntries(entries)
    }
}

struct IOSFailedHistoryRetryFailureReceipt: Equatable, Sendable {
    let authorization: IOSFailedHistoryRetryFailureAuthorization
    let durableSnapshot: IOSFailedHistoryJournalSnapshot
    let row: IOSFailedHistoryEntry
    let retryOperation: IOSFailedHistoryRetryOperation
    let providerCompletionClaim:
        IOSFailedHistoryRetryProviderCompletionClaim
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryRetryFailureReceiptMint,
        authorization: IOSFailedHistoryRetryFailureAuthorization,
        durableSnapshot: IOSFailedHistoryJournalSnapshot,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        _ = mint
        guard operationLeaseAuthorization.provesActiveLease(),
              authorization.operationLeaseAuthorization
                .provesSameActiveLease(
                    as: operationLeaseAuthorization
                ),
              durableSnapshot.envelope == authorization.outcome,
              durableSnapshot.envelope.entries.contains(
                authorization.retainedRow
              ),
              authorization.retainedRow.retryOperation == nil else {
            return nil
        }
        self.authorization = authorization
        self.durableSnapshot = durableSnapshot
        row = authorization.retainedRow
        retryOperation = authorization.retryOperation
        providerCompletionClaim = authorization.providerCompletionClaim
        failedStoreIdentity = authorization.failedStoreIdentity
        ownerIdentity = authorization.ownerIdentity
        repositoryBinding = authorization.repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }
}

extension IOSFailedHistoryRetryFailureDisposition:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryFailureDisposition(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryFailurePreparation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryFailurePreparation(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryFailureAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryFailureAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryFailureReceipt:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryFailureReceipt(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
