import Foundation

enum IOSFailedHistoryRetryReservationPreparation: Equatable, Sendable {
    case commit(IOSFailedHistoryRetryReservationAuthorization)
    case completed(IOSFailedHistoryRetryReservationReceipt)
}

struct IOSFailedHistoryRetryReservationAuthorization: Equatable, Sendable {
    let failedSource: IOSFailedHistoryJournalSnapshot
    let candidate: IOSFailedHistoryEntry
    let reservedRow: IOSFailedHistoryEntry
    let retryOperation: IOSFailedHistoryRetryOperation
    let outcome: IOSFailedHistoryEnvelope
    let policyReceipt: IOSHistoryPolicyReceipt
    let failedInventory: IOSFailedHistoryProtectedAudioInventory
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryRetryReservationAuthorizationMint,
        failedSource: IOSFailedHistoryJournalSnapshot,
        candidate: IOSFailedHistoryEntry,
        reservedRow: IOSFailedHistoryEntry,
        retryOperation: IOSFailedHistoryRetryOperation,
        outcome: IOSFailedHistoryEnvelope,
        policyReceipt: IOSHistoryPolicyReceipt,
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
        guard operationLeaseAuthorization.provesActiveLease(),
              repositoryBinding.physicalRootIdentity != nil,
              policyReceipt.capabilityOwnerIdentity == ownerIdentity,
              policyReceipt.state.historyEnabled,
              candidate.policyGeneration
                == policyReceipt.state.policyGeneration,
              candidate.ownershipState == .ready,
              candidate.retryOperation == nil,
              retryOperation.state == .reserved,
              retryOperation.createdAt == reservedRow.updatedAt,
              reservedRow.retryOperation == retryOperation,
              candidate.retryCount < IOSFailedHistoryValidation
                .maximumRetryCount,
              reservedRow.retryCount == candidate.retryCount + 1,
              Self.preservesCandidate(
                  candidate,
                  in: reservedRow,
                  allowingUpdatedAt: true,
                  allowingConfiguration: true
              ),
              failedSource.envelope.entries.allSatisfy({
                  $0.retryOperation == nil
              }),
              failedSource.envelope.audioCleanup.count
                < IOSFailedHistoryValidation.maximumAudioCleanupCount,
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
              outcome.audioCleanup == failedSource.envelope.audioCleanup,
              Self.isExactReplacement(
                  source: failedSource.envelope,
                  candidate: candidate,
                  replacement: reservedRow,
                  outcome: outcome
              ) else {
            return nil
        }

        self.failedSource = failedSource
        self.candidate = candidate
        self.reservedRow = reservedRow
        self.retryOperation = retryOperation
        self.outcome = outcome
        self.policyReceipt = policyReceipt
        self.failedInventory = failedInventory
        self.failedStoreIdentity = failedStoreIdentity
        self.expectedPendingStoreIdentity = expectedPendingStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }

    func identifiesSameReservation(
        as other: IOSFailedHistoryRetryReservationAuthorization
    ) -> Bool {
        failedSource == other.failedSource
            && candidate == other.candidate
            && reservedRow == other.reservedRow
            && retryOperation == other.retryOperation
            && outcome == other.outcome
            && policyReceipt == other.policyReceipt
            && failedStoreIdentity == other.failedStoreIdentity
            && expectedPendingStoreIdentity
                == other.expectedPendingStoreIdentity
            && ownerIdentity == other.ownerIdentity
            && repositoryBinding == other.repositoryBinding
    }
}

struct IOSFailedHistoryRetryReservationReceipt: Equatable, Sendable {
    let authorization: IOSFailedHistoryRetryReservationAuthorization
    let durableSnapshot: IOSFailedHistoryJournalSnapshot
    let row: IOSFailedHistoryEntry
    let retryOperation: IOSFailedHistoryRetryOperation
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryRetryReservationReceiptMint,
        authorization: IOSFailedHistoryRetryReservationAuthorization,
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
                  authorization.reservedRow
              ),
              authorization.retryOperation.state == .reserved else {
            return nil
        }
        self.authorization = authorization
        self.durableSnapshot = durableSnapshot
        row = authorization.reservedRow
        retryOperation = authorization.retryOperation
        failedStoreIdentity = authorization.failedStoreIdentity
        ownerIdentity = authorization.ownerIdentity
        repositoryBinding = authorization.repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }

    func identifiesSameReservation(
        as other: IOSFailedHistoryRetryReservationReceipt
    ) -> Bool {
        authorization.failedSource == other.authorization.failedSource
            && authorization.candidate == other.authorization.candidate
            && authorization.reservedRow == other.authorization.reservedRow
            && authorization.outcome == other.authorization.outcome
            && authorization.policyReceipt
                == other.authorization.policyReceipt
            && durableSnapshot == other.durableSnapshot
            && failedStoreIdentity == other.failedStoreIdentity
            && ownerIdentity == other.ownerIdentity
            && repositoryBinding == other.repositoryBinding
    }
}

enum IOSFailedHistoryRetryDispatchPreparation: Equatable, Sendable {
    case commit(IOSFailedHistoryRetryDispatchAuthorization)
    case completed(IOSFailedHistoryRetryDispatchReceipt)
}

struct IOSFailedHistoryRetryDispatchAuthorization: Equatable, Sendable {
    let reservationReceipt: IOSFailedHistoryRetryReservationReceipt
    let failedSource: IOSFailedHistoryJournalSnapshot
    let reservedRow: IOSFailedHistoryEntry
    let dispatchedRow: IOSFailedHistoryEntry
    let retryOperation: IOSFailedHistoryRetryOperation
    let outcome: IOSFailedHistoryEnvelope
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryRetryDispatchAuthorizationMint,
        reservationReceipt: IOSFailedHistoryRetryReservationReceipt,
        failedSource: IOSFailedHistoryJournalSnapshot,
        reservedRow: IOSFailedHistoryEntry,
        dispatchedRow: IOSFailedHistoryEntry,
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
              reservationReceipt.operationLeaseAuthorization
                .provesSameActiveLease(
                    as: operationLeaseAuthorization
                ),
              reservationReceipt.failedStoreIdentity
                == failedStoreIdentity,
              reservationReceipt.ownerIdentity == ownerIdentity,
              reservationReceipt.repositoryBinding == repositoryBinding,
              reservationReceipt.durableSnapshot == failedSource,
              reservationReceipt.row == reservedRow,
              reservedRow.retryOperation
                == reservationReceipt.retryOperation,
              reservationReceipt.retryOperation.state == .reserved,
              retryOperation.state == .providerDispatched,
              retryOperation.identifiesSameAttempt(
                  as: reservationReceipt.retryOperation
              ),
              dispatchedRow.retryOperation == retryOperation,
              Self.preservesCandidate(
                  reservedRow,
                  in: dispatchedRow,
                  allowingUpdatedAt: false,
                  allowingConfiguration: false
              ),
              dispatchedRow.retryCount == reservedRow.retryCount,
              !nextRevision.overflow,
              outcome.revision == nextRevision.partialValue,
              outcome.audioCleanup == failedSource.envelope.audioCleanup,
              Self.isExactReplacement(
                  source: failedSource.envelope,
                  candidate: reservedRow,
                  replacement: dispatchedRow,
                  outcome: outcome
              ) else {
            return nil
        }

        self.reservationReceipt = reservationReceipt
        self.failedSource = failedSource
        self.reservedRow = reservedRow
        self.dispatchedRow = dispatchedRow
        self.retryOperation = retryOperation
        self.outcome = outcome
        self.failedStoreIdentity = failedStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }

    func identifiesSameDispatch(
        as other: IOSFailedHistoryRetryDispatchAuthorization
    ) -> Bool {
        reservationReceipt.identifiesSameReservation(
            as: other.reservationReceipt
        )
            && failedSource == other.failedSource
            && reservedRow == other.reservedRow
            && dispatchedRow == other.dispatchedRow
            && retryOperation == other.retryOperation
            && outcome == other.outcome
            && failedStoreIdentity == other.failedStoreIdentity
            && ownerIdentity == other.ownerIdentity
            && repositoryBinding == other.repositoryBinding
    }
}

struct IOSFailedHistoryRetryDispatchReceipt: Equatable, Sendable {
    let authorization: IOSFailedHistoryRetryDispatchAuthorization
    let durableSnapshot: IOSFailedHistoryJournalSnapshot
    let row: IOSFailedHistoryEntry
    let retryOperation: IOSFailedHistoryRetryOperation
    let liveOwnerToken: IOSFailedHistoryRetryLiveOwnerToken
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryRetryDispatchReceiptMint,
        authorization: IOSFailedHistoryRetryDispatchAuthorization,
        durableSnapshot: IOSFailedHistoryJournalSnapshot,
        liveOwnerToken: IOSFailedHistoryRetryLiveOwnerToken,
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
                  authorization.dispatchedRow
              ),
              authorization.retryOperation.state == .providerDispatched,
              liveOwnerToken.failedSource == durableSnapshot,
              liveOwnerToken.row == authorization.dispatchedRow,
              liveOwnerToken.retryOperation == authorization.retryOperation,
              liveOwnerToken.failedStoreIdentity
                == authorization.failedStoreIdentity,
              liveOwnerToken.ownerIdentity == authorization.ownerIdentity,
              liveOwnerToken.repositoryBinding
                == authorization.repositoryBinding,
              liveOwnerToken.operationLeaseAuthorization
                .provesSameActiveLease(
                    as: operationLeaseAuthorization
                ) else {
            return nil
        }
        self.authorization = authorization
        self.durableSnapshot = durableSnapshot
        row = authorization.dispatchedRow
        retryOperation = authorization.retryOperation
        self.liveOwnerToken = liveOwnerToken
        failedStoreIdentity = authorization.failedStoreIdentity
        ownerIdentity = authorization.ownerIdentity
        repositoryBinding = authorization.repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }

    func identifiesSameDispatch(
        as other: IOSFailedHistoryRetryDispatchReceipt
    ) -> Bool {
        authorization.failedSource == other.authorization.failedSource
            && authorization.reservedRow == other.authorization.reservedRow
            && authorization.dispatchedRow
                == other.authorization.dispatchedRow
            && authorization.outcome == other.authorization.outcome
            && authorization.reservationReceipt.identifiesSameReservation(
                as: other.authorization.reservationReceipt
            )
            && durableSnapshot == other.durableSnapshot
            && failedStoreIdentity == other.failedStoreIdentity
            && ownerIdentity == other.ownerIdentity
            && repositoryBinding == other.repositoryBinding
    }
}

enum IOSFailedHistoryRetryCancellationSource: Equatable, Sendable {
    case reservation(IOSFailedHistoryRetryReservationReceipt)
    case dispatch(IOSFailedHistoryRetryDispatchReceipt)

    var durableSnapshot: IOSFailedHistoryJournalSnapshot {
        switch self {
        case .reservation(let receipt): receipt.durableSnapshot
        case .dispatch(let receipt): receipt.durableSnapshot
        }
    }

    var row: IOSFailedHistoryEntry {
        switch self {
        case .reservation(let receipt): receipt.row
        case .dispatch(let receipt): receipt.row
        }
    }

    var retryOperation: IOSFailedHistoryRetryOperation {
        switch self {
        case .reservation(let receipt): receipt.retryOperation
        case .dispatch(let receipt): receipt.retryOperation
        }
    }

    var failedStoreIdentity: IOSFailedHistoryStoreIdentity {
        switch self {
        case .reservation(let receipt): receipt.failedStoreIdentity
        case .dispatch(let receipt): receipt.failedStoreIdentity
        }
    }

    var ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity {
        switch self {
        case .reservation(let receipt): receipt.ownerIdentity
        case .dispatch(let receipt): receipt.ownerIdentity
        }
    }

    var repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding {
        switch self {
        case .reservation(let receipt): receipt.repositoryBinding
        case .dispatch(let receipt): receipt.repositoryBinding
        }
    }

    func identifiesSameSource(
        as other: IOSFailedHistoryRetryCancellationSource
    ) -> Bool {
        switch (self, other) {
        case (.reservation(let lhs), .reservation(let rhs)):
            lhs.identifiesSameReservation(as: rhs)
        case (.dispatch(let lhs), .dispatch(let rhs)):
            lhs.identifiesSameDispatch(as: rhs)
        case (.reservation, .dispatch), (.dispatch, .reservation):
            false
        }
    }
}

enum IOSFailedHistoryRetryCancellationPreparation: Equatable, Sendable {
    case commit(IOSFailedHistoryRetryCancellationAuthorization)
    case completed(IOSFailedHistoryRetryCancellationReceipt)
}

struct IOSFailedHistoryRetryCancellationAuthorization: Equatable, Sendable {
    let sourceReceipt: IOSFailedHistoryRetryCancellationSource
    let failedSource: IOSFailedHistoryJournalSnapshot
    let retryingRow: IOSFailedHistoryEntry
    let retainedRow: IOSFailedHistoryEntry
    let retryOperation: IOSFailedHistoryRetryOperation
    let outcome: IOSFailedHistoryEnvelope
    let providerCancellationClaim:
        IOSFailedHistoryRetryProviderCancellationClaim?
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryRetryCancellationAuthorizationMint,
        sourceReceipt: IOSFailedHistoryRetryCancellationSource,
        failedSource: IOSFailedHistoryJournalSnapshot,
        retryingRow: IOSFailedHistoryEntry,
        retainedRow: IOSFailedHistoryEntry,
        retryOperation: IOSFailedHistoryRetryOperation,
        outcome: IOSFailedHistoryEnvelope,
        providerCancellationClaim:
            IOSFailedHistoryRetryProviderCancellationClaim?,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        _ = mint
        let nextRevision = failedSource.envelope.revision
            .addingReportingOverflow(1)
        let providerClaimIsValid: Bool = switch sourceReceipt {
        case .reservation:
            providerCancellationClaim == nil
        case .dispatch(let receipt):
            providerCancellationClaim?.liveOwnerToken
                == receipt.liveOwnerToken
        }
        guard operationLeaseAuthorization.provesActiveLease(),
              providerClaimIsValid,
              repositoryBinding.physicalRootIdentity != nil,
              sourceReceipt.failedStoreIdentity == failedStoreIdentity,
              sourceReceipt.ownerIdentity == ownerIdentity,
              sourceReceipt.repositoryBinding == repositoryBinding,
              sourceReceipt.durableSnapshot == failedSource,
              sourceReceipt.row == retryingRow,
              sourceReceipt.retryOperation == retryOperation,
              retryOperation.state == .reserved
                || retryOperation.state == .providerDispatched,
              retryingRow.retryOperation == retryOperation,
              retainedRow.retryOperation == nil,
              Self.preservesCandidate(
                  retryingRow,
                  in: retainedRow,
                  allowingUpdatedAt: true,
                  allowingConfiguration: false
              ),
              retainedRow.retryCount == retryingRow.retryCount,
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

        self.sourceReceipt = sourceReceipt
        self.failedSource = failedSource
        self.retryingRow = retryingRow
        self.retainedRow = retainedRow
        self.retryOperation = retryOperation
        self.outcome = outcome
        self.providerCancellationClaim = providerCancellationClaim
        self.failedStoreIdentity = failedStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }

    func identifiesSameCancellation(
        as other: IOSFailedHistoryRetryCancellationAuthorization
    ) -> Bool {
        sourceReceipt.identifiesSameSource(as: other.sourceReceipt)
            && failedSource == other.failedSource
            && retryingRow == other.retryingRow
            && retainedRow == other.retainedRow
            && retryOperation == other.retryOperation
            && outcome == other.outcome
            && providerCancellationClaim
                == other.providerCancellationClaim
            && failedStoreIdentity == other.failedStoreIdentity
            && ownerIdentity == other.ownerIdentity
            && repositoryBinding == other.repositoryBinding
    }
}

struct IOSFailedHistoryRetryCancellationReceipt: Equatable, Sendable {
    let authorization: IOSFailedHistoryRetryCancellationAuthorization
    let durableSnapshot: IOSFailedHistoryJournalSnapshot
    let row: IOSFailedHistoryEntry
    let retryOperation: IOSFailedHistoryRetryOperation
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryRetryCancellationReceiptMint,
        authorization: IOSFailedHistoryRetryCancellationAuthorization,
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
        failedStoreIdentity = authorization.failedStoreIdentity
        ownerIdentity = authorization.ownerIdentity
        repositoryBinding = authorization.repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }
}

fileprivate extension IOSFailedHistoryRetryOperation {
    func identifiesSameAttempt(
        as other: IOSFailedHistoryRetryOperation
    ) -> Bool {
        retryID == other.retryID
            && createdAt == other.createdAt
            && transcriptionID == other.transcriptionID
            && deliveryID == other.deliveryID
            && sessionID == other.sessionID
            && transcriptID == other.transcriptID
            && keepLatestResult == other.keepLatestResult
    }
}

fileprivate extension IOSFailedHistoryRetryReservationAuthorization {
    static func preservesCandidate(
        _ candidate: IOSFailedHistoryEntry,
        in replacement: IOSFailedHistoryEntry,
        allowingUpdatedAt: Bool,
        allowingConfiguration: Bool
    ) -> Bool {
        candidate.attemptID == replacement.attemptID
            && candidate.createdAt == replacement.createdAt
            && (allowingUpdatedAt
                ? replacement.updatedAt >= candidate.updatedAt
                : replacement.updatedAt == candidate.updatedAt)
            && candidate.policyGeneration == replacement.policyGeneration
            && candidate.failureCategory == replacement.failureCategory
            && candidate.pipelineStage == replacement.pipelineStage
            && candidate.outputIntent == replacement.outputIntent
            && (allowingConfiguration
                || IOSAcceptedOutputDeliveryValidation.bytesEqual(
                    candidate.transcriptionModel,
                    replacement.transcriptionModel
                ))
            && (allowingConfiguration
                || candidate.transcriptionLanguageCode
                    == replacement.transcriptionLanguageCode)
            && candidate.durationMilliseconds
                == replacement.durationMilliseconds
            && candidate.byteCount == replacement.byteCount
            && candidate.audioRelativeIdentifier
                == replacement.audioRelativeIdentifier
            && candidate.ownershipState == replacement.ownershipState
    }

    static func isExactReplacement(
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

fileprivate extension IOSFailedHistoryRetryDispatchAuthorization {
    static func preservesCandidate(
        _ candidate: IOSFailedHistoryEntry,
        in replacement: IOSFailedHistoryEntry,
        allowingUpdatedAt: Bool,
        allowingConfiguration: Bool
    ) -> Bool {
        IOSFailedHistoryRetryReservationAuthorization.preservesCandidate(
            candidate,
            in: replacement,
            allowingUpdatedAt: allowingUpdatedAt,
            allowingConfiguration: allowingConfiguration
        )
    }

    static func isExactReplacement(
        source: IOSFailedHistoryEnvelope,
        candidate: IOSFailedHistoryEntry,
        replacement: IOSFailedHistoryEntry,
        outcome: IOSFailedHistoryEnvelope
    ) -> Bool {
        IOSFailedHistoryRetryReservationAuthorization.isExactReplacement(
            source: source,
            candidate: candidate,
            replacement: replacement,
            outcome: outcome
        )
    }
}

fileprivate extension IOSFailedHistoryRetryCancellationAuthorization {
    static func preservesCandidate(
        _ candidate: IOSFailedHistoryEntry,
        in replacement: IOSFailedHistoryEntry,
        allowingUpdatedAt: Bool,
        allowingConfiguration: Bool
    ) -> Bool {
        IOSFailedHistoryRetryReservationAuthorization.preservesCandidate(
            candidate,
            in: replacement,
            allowingUpdatedAt: allowingUpdatedAt,
            allowingConfiguration: allowingConfiguration
        )
    }

    static func isExactReplacement(
        source: IOSFailedHistoryEnvelope,
        candidate: IOSFailedHistoryEntry,
        replacement: IOSFailedHistoryEntry,
        outcome: IOSFailedHistoryEnvelope
    ) -> Bool {
        IOSFailedHistoryRetryReservationAuthorization.isExactReplacement(
            source: source,
            candidate: candidate,
            replacement: replacement,
            outcome: outcome
        )
    }
}

extension IOSFailedHistoryRetryReservationPreparation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryReservationPreparation(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryReservationAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryReservationAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryReservationReceipt:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryReservationReceipt(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryDispatchPreparation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryDispatchPreparation(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryDispatchAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryDispatchAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryDispatchReceipt:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryDispatchReceipt(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryCancellationSource:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryCancellationSource(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryCancellationPreparation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryCancellationPreparation(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryCancellationAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryCancellationAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryCancellationReceipt:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryCancellationReceipt(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
