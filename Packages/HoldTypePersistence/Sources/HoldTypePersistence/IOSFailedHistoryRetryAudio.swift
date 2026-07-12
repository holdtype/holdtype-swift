import Foundation

/// Pending-store proof that the exact failed-row descriptor was validated and
/// remains held for one reservation. It stores no pathname or audio payload.
struct IOSFailedHistoryRetryAudioValidationReceipt: Equatable, Sendable {
    private let reservationAuthorization:
        IOSFailedHistoryRetryReservationAuthorization
    private let pendingStoreIdentity: IOSPendingRecordingStoreIdentity
    private let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    private let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    private let repositoryBinding:
        IOSAcceptedHistoryCoordinatorRepositoryBinding
    private let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
    private let descriptorProof: IOSFailedHistoryRetryAudioDescriptorProof

    fileprivate init?(
        mint: IOSFailedHistoryRetryAudioSourceMint,
        reservationAuthorization:
            IOSFailedHistoryRetryReservationAuthorization,
        pendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization,
        descriptorProof: IOSFailedHistoryRetryAudioDescriptorProof
    ) {
        _ = mint
        guard operationLeaseAuthorization.provesActiveLease(),
              reservationAuthorization.operationLeaseAuthorization
                .provesSameActiveLease(
                    as: operationLeaseAuthorization
                ),
              reservationAuthorization.expectedPendingStoreIdentity
                == pendingStoreIdentity,
              reservationAuthorization.failedStoreIdentity
                == failedStoreIdentity,
              reservationAuthorization.ownerIdentity == ownerIdentity,
              reservationAuthorization.repositoryBinding
                == repositoryBinding,
              descriptorProof.isHeld else {
            return nil
        }
        self.reservationAuthorization = reservationAuthorization
        self.pendingStoreIdentity = pendingStoreIdentity
        self.failedStoreIdentity = failedStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
        self.descriptorProof = descriptorProof
    }

    #if DEBUG
    /// Narrow deterministic seam for pure Failed-store boundary tests.
    init?(
        testingAuthorization reservationAuthorization:
            IOSFailedHistoryRetryReservationAuthorization
    ) {
        guard reservationAuthorization.operationLeaseAuthorization
                .provesActiveLease(),
              reservationAuthorization.repositoryBinding
                .physicalRootIdentity != nil else {
            return nil
        }
        self.reservationAuthorization = reservationAuthorization
        pendingStoreIdentity =
            reservationAuthorization.expectedPendingStoreIdentity
        failedStoreIdentity = reservationAuthorization.failedStoreIdentity
        ownerIdentity = reservationAuthorization.ownerIdentity
        repositoryBinding = reservationAuthorization.repositoryBinding
        operationLeaseAuthorization =
            reservationAuthorization.operationLeaseAuthorization
        descriptorProof = IOSFailedHistoryRetryAudioDescriptorProof()
    }
    #endif

    static func == (
        lhs: IOSFailedHistoryRetryAudioValidationReceipt,
        rhs: IOSFailedHistoryRetryAudioValidationReceipt
    ) -> Bool {
        lhs.reservationAuthorization == rhs.reservationAuthorization
            && lhs.pendingStoreIdentity == rhs.pendingStoreIdentity
            && lhs.failedStoreIdentity == rhs.failedStoreIdentity
            && lhs.ownerIdentity == rhs.ownerIdentity
            && lhs.repositoryBinding == rhs.repositoryBinding
            && lhs.operationLeaseAuthorization
                == rhs.operationLeaseAuthorization
            && lhs.descriptorProof === rhs.descriptorProof
    }

    func provesHeld(
        for authorization:
            IOSFailedHistoryRetryReservationAuthorization,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) -> Bool {
        descriptorProof.isHeld
            && operationLeaseAuthorization.provesActiveLease()
            && self.operationLeaseAuthorization.provesSameActiveLease(
                as: operationLeaseAuthorization
            )
            && reservationAuthorization == authorization
            && reservationAuthorization.operationLeaseAuthorization
                .provesSameActiveLease(
                    as: operationLeaseAuthorization
                )
            && self.failedStoreIdentity == failedStoreIdentity
            && self.pendingStoreIdentity == expectedPendingStoreIdentity
            && self.ownerIdentity == ownerIdentity
            && self.repositoryBinding == repositoryBinding
            && authorization.failedStoreIdentity == failedStoreIdentity
            && authorization.expectedPendingStoreIdentity
                == expectedPendingStoreIdentity
            && authorization.ownerIdentity == ownerIdentity
            && authorization.repositoryBinding == repositoryBinding
    }
}

fileprivate final class IOSFailedHistoryRetryAudioDescriptorProof:
    @unchecked Sendable {
    private enum State {
        case held
        case transferred
        case invalidated
    }

    private let lock = NSLock()
    private var state = State.held

    var isHeld: Bool {
        lock.withLock {
            if case .held = state { return true }
            return false
        }
    }

    func transfer() -> Bool {
        lock.withLock {
            guard case .held = state else { return false }
            state = .transferred
            return true
        }
    }

    func invalidate() {
        lock.withLock {
            guard case .held = state else { return }
            state = .invalidated
        }
    }
}

/// Owns the exact descriptor-backed audio opened for one failed-row Retry.
/// It does not expose a durable path and can transfer its provider input only
/// to the dispatch that descends from the reservation used to open it.
final class IOSFailedHistoryRetryAudioSource: @unchecked Sendable {
    private let reservationAuthorization:
        IOSFailedHistoryRetryReservationAuthorization
    let validationReceipt: IOSFailedHistoryRetryAudioValidationReceipt
    private let descriptorProof: IOSFailedHistoryRetryAudioDescriptorProof
    private let lock = NSLock()
    private var audio: IOSPendingTranscriptionAudio?

    init?(
        mint: IOSFailedHistoryRetryAudioSourceMint,
        reservationAuthorization:
            IOSFailedHistoryRetryReservationAuthorization,
        pendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization,
        audioLease: any IOSPendingRecordingPublishedAudioLease
    ) {
        _ = mint
        let descriptorProof = IOSFailedHistoryRetryAudioDescriptorProof()
        guard operationLeaseAuthorization.provesActiveLease(),
              reservationAuthorization.operationLeaseAuthorization
                .provesSameActiveLease(
                    as: operationLeaseAuthorization
                ),
              reservationAuthorization.expectedPendingStoreIdentity
                == pendingStoreIdentity,
              reservationAuthorization.failedStoreIdentity
                == failedStoreIdentity,
              reservationAuthorization.ownerIdentity == ownerIdentity,
              reservationAuthorization.repositoryBinding
                == repositoryBinding,
              reservationAuthorization.candidate.ownershipState == .ready,
              reservationAuthorization.candidate.retryOperation == nil,
              audioLease.relativeIdentifier
                == reservationAuthorization.candidate
                    .audioRelativeIdentifier,
              audioLease.durationMilliseconds
                == reservationAuthorization.candidate
                    .durationMilliseconds,
              audioLease.audioArtifact.byteCount
                == reservationAuthorization.candidate.byteCount,
              let expectedAudio = IOSPendingRecordingStorageLocation
                .parseRelativeAudioIdentifier(
                    reservationAuthorization.candidate
                        .audioRelativeIdentifier
                ),
              expectedAudio.attemptID
                == reservationAuthorization.candidate.attemptID,
              IOSPendingRecordingAudioFormat(
                  sourceURL: audioLease.audioArtifact.fileURL
              ) == expectedAudio.format,
              let validationReceipt =
                IOSFailedHistoryRetryAudioValidationReceipt(
                    mint: mint,
                    reservationAuthorization: reservationAuthorization,
                    pendingStoreIdentity: pendingStoreIdentity,
                    failedStoreIdentity: failedStoreIdentity,
                    ownerIdentity: ownerIdentity,
                    repositoryBinding: repositoryBinding,
                    operationLeaseAuthorization:
                        operationLeaseAuthorization,
                    descriptorProof: descriptorProof
                ) else {
            return nil
        }
        self.reservationAuthorization = reservationAuthorization
        self.validationReceipt = validationReceipt
        self.descriptorProof = descriptorProof
        audio = IOSPendingTranscriptionAudio(lease: audioLease)
    }

    deinit { invalidate() }

    /// Transfers the descriptor-backed provider input exactly once. A receipt
    /// from another reservation has no effect on this source.
    func take(
        using dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt,
        registration: IOSFailedHistoryRetryProviderRegistration
    ) throws -> IOSPendingTranscriptionAudio {
        try lock.withLock {
            let descendant = dispatchReceipt.authorization
                .reservationReceipt.authorization
            guard registration.provesProviderDispatch(dispatchReceipt),
            reservationAuthorization == descendant,
            dispatchReceipt.authorization.reservationReceipt
                .retryOperation
                == reservationAuthorization.retryOperation,
            Self.identifiesSameAttempt(
                dispatchReceipt.retryOperation,
                reservationAuthorization.retryOperation
            ),
            dispatchReceipt.failedStoreIdentity
                == reservationAuthorization.failedStoreIdentity,
            dispatchReceipt.ownerIdentity
                == reservationAuthorization.ownerIdentity,
            dispatchReceipt.repositoryBinding
                == reservationAuthorization.repositoryBinding else {
                throw IOSPendingRecordingError.localRecoveryPending
            }
            guard let audio else {
                throw IOSPendingRecordingError.dispatchAlreadyCommitted
            }
            guard descriptorProof.transfer() else {
                throw IOSPendingRecordingError.dispatchAlreadyCommitted
            }
            self.audio = nil
            return audio
        }
    }

    /// Revokes an unconsumed source and releases its descriptor lease.
    func invalidate() {
        descriptorProof.invalidate()
        let audio = lock.withLock {
            defer { self.audio = nil }
            return self.audio
        }
        audio?.invalidate()
    }

    private static func identifiesSameAttempt(
        _ lhs: IOSFailedHistoryRetryOperation,
        _ rhs: IOSFailedHistoryRetryOperation
    ) -> Bool {
        lhs.retryID == rhs.retryID
            && lhs.createdAt == rhs.createdAt
            && lhs.transcriptionID == rhs.transcriptionID
            && lhs.deliveryID == rhs.deliveryID
            && lhs.sessionID == rhs.sessionID
            && lhs.transcriptID == rhs.transcriptID
            && lhs.keepLatestResult == rhs.keepLatestResult
    }
}

extension IOSFailedHistoryRetryAudioValidationReceipt:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryAudioValidationReceipt(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryRetryAudioSource: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryAudioSource(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
