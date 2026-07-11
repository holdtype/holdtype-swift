import Foundation

/// One exact Failed-History view of the app-private protected-audio namespace.
/// The Failed store is the only production issuer; consumers may inspect the
/// canonical artifacts but cannot construct an inventory from paths or rows.
struct IOSFailedHistoryProtectedAudioInventory: Equatable, Sendable {
    enum Artifact: Equatable, Sendable {
        case row(
            attemptID: UUID,
            relativeIdentifier: String,
            durationMilliseconds: Int64,
            byteCount: Int64
        )
        case tombstone(
            attemptID: UUID,
            relativeIdentifier: String,
            byteCount: Int64
        )
    }

    let failedSource: IOSFailedHistoryJournalSnapshot?
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
    let artifacts: [Artifact]
    let hasPendingJournalRetirement: Bool

    init?(
        mint: IOSFailedHistoryProtectedAudioInventoryMint,
        failedSource: IOSFailedHistoryJournalSnapshot?,
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

        self.failedSource = failedSource
        self.failedStoreIdentity = failedStoreIdentity
        self.expectedPendingStoreIdentity = expectedPendingStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
        artifacts = Self.canonicalArtifacts(from: failedSource)
        hasPendingJournalRetirement = failedSource?.envelope.entries
            .contains(where: {
                $0.ownershipState == .pendingJournalRetirement
            }) == true
    }

    #if DEBUG
    /// Narrow seam for descriptor-level inventory tests. Production callers
    /// can obtain this capability only from `IOSFailedHistoryStore`.
    init(
        testingRepositoryBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization,
        artifacts: [Artifact]
    ) {
        failedSource = nil
        failedStoreIdentity = IOSFailedHistoryStoreIdentity()
        expectedPendingStoreIdentity = IOSPendingRecordingStoreIdentity()
        ownerIdentity = IOSAcceptedHistoryCapabilityOwnerIdentity()
        repositoryBinding = testingRepositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
        self.artifacts = artifacts
        hasPendingJournalRetirement = false
    }
    #endif

    private static func canonicalArtifacts(
        from source: IOSFailedHistoryJournalSnapshot?
    ) -> [Artifact] {
        guard let envelope = source?.envelope else { return [] }
        return envelope.entries.map {
            .row(
                attemptID: $0.attemptID,
                relativeIdentifier: $0.audioRelativeIdentifier,
                durationMilliseconds: $0.durationMilliseconds,
                byteCount: $0.byteCount
            )
        } + envelope.audioCleanup.map {
            .tombstone(
                attemptID: $0.attemptID,
                relativeIdentifier: $0.audioRelativeIdentifier,
                byteCount: $0.byteCount
            )
        }
    }
}

extension IOSFailedHistoryProtectedAudioInventory.Artifact:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryProtectedAudioInventory.Artifact(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSFailedHistoryProtectedAudioInventory:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryProtectedAudioInventory(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
