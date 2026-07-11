import Foundation
import HoldTypeDomain

/// The complete durable identity shared by an awaiting-recovery Pending record
/// and its failed-History row. It intentionally excludes Pending `updatedAt`,
/// which is not persisted by the failed row.
struct IOSFailedHistoryPendingMatchIdentity: Sendable {
    let attemptID: UUID
    let createdAt: Date
    let audioRelativeIdentifier: String
    let outputIntent: DictationOutputIntent
    let transcriptionModel: String
    let transcriptionLanguageCode: String?
    let durationMilliseconds: Int64
    let byteCount: Int64

    init?(pending recording: IOSPendingRecording) {
        guard recording.phase == .awaitingRecovery,
              recording.transcriptionID == nil else {
            return nil
        }
        self.init(
            attemptID: recording.attemptID,
            createdAt: recording.createdAt,
            audioRelativeIdentifier: recording.audioRelativeIdentifier,
            outputIntent: recording.outputIntent,
            transcriptionModel: recording.transcriptionModel,
            transcriptionLanguageCode:
                recording.transcriptionLanguageCode,
            durationMilliseconds: recording.durationMilliseconds,
            byteCount: recording.byteCount
        )
    }

    init?(failedRow row: IOSFailedHistoryEntry) {
        guard row.ownershipState == .pendingJournalRetirement,
              row.retryCount == 0,
              row.retryOperation == nil else {
            return nil
        }
        self.init(
            attemptID: row.attemptID,
            createdAt: row.createdAt,
            audioRelativeIdentifier: row.audioRelativeIdentifier,
            outputIntent: row.outputIntent,
            transcriptionModel: row.transcriptionModel,
            transcriptionLanguageCode: row.transcriptionLanguageCode,
            durationMilliseconds: row.durationMilliseconds,
            byteCount: row.byteCount
        )
    }

    private init(
        attemptID: UUID,
        createdAt: Date,
        audioRelativeIdentifier: String,
        outputIntent: DictationOutputIntent,
        transcriptionModel: String,
        transcriptionLanguageCode: String?,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) {
        self.attemptID = attemptID
        self.createdAt = createdAt
        self.audioRelativeIdentifier = audioRelativeIdentifier
        self.outputIntent = outputIntent
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguageCode = transcriptionLanguageCode
        self.durationMilliseconds = durationMilliseconds
        self.byteCount = byteCount
    }
}

extension IOSFailedHistoryPendingMatchIdentity: Equatable {
    static func == (
        lhs: IOSFailedHistoryPendingMatchIdentity,
        rhs: IOSFailedHistoryPendingMatchIdentity
    ) -> Bool {
        lhs.attemptID == rhs.attemptID
            && lhs.createdAt == rhs.createdAt
            && lhs.audioRelativeIdentifier == rhs.audioRelativeIdentifier
            && lhs.outputIntent == rhs.outputIntent
            && IOSAcceptedOutputDeliveryValidation.bytesEqual(
                lhs.transcriptionModel,
                rhs.transcriptionModel
            )
            && IOSAcceptedOutputDeliveryValidation.optionalBytesEqual(
                lhs.transcriptionLanguageCode,
                rhs.transcriptionLanguageCode
            )
            && lhs.durationMilliseconds == rhs.durationMilliseconds
            && lhs.byteCount == rhs.byteCount
    }
}

extension IOSFailedHistoryPendingMatchIdentity:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryPendingMatchIdentity(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Descriptor-backed, process-local preparation retained only across the
/// failed-row commit. Equality is intentionally not an authority mechanism.
final class IOSPendingFailedHistoryTransferPreparation: @unchecked Sendable {
    let pendingSnapshot: IOSPendingRecordingJournalMetadataSnapshot
    let intendedRow: IOSFailedHistoryEntry
    let pendingStoreIdentity: IOSPendingRecordingStoreIdentity
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
    let policyReceipt: IOSHistoryPolicyReceipt

    private let audioLease: any IOSPendingRecordingPublishedAudioLease
    private let releaseLock = NSLock()
    private var didReleaseAudioLease = false

    init?(
        mint: IOSPendingFailedHistoryTransferPreparationMint,
        pendingSnapshot: IOSPendingRecordingJournalMetadataSnapshot,
        intendedRow: IOSFailedHistoryEntry,
        audioLease: any IOSPendingRecordingPublishedAudioLease,
        pendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization,
        policyReceipt: IOSHistoryPolicyReceipt
    ) {
        _ = mint
        guard operationLeaseAuthorization.provesActiveLease(),
              repositoryBinding.physicalRootIdentity != nil,
              policyReceipt.state.historyEnabled,
              policyReceipt.state.policyGeneration
                == intendedRow.policyGeneration,
              policyReceipt.capabilityOwnerIdentity == ownerIdentity,
              IOSFailedHistoryPendingMatchIdentity(
                  pending: pendingSnapshot.recording
              ) == IOSFailedHistoryPendingMatchIdentity(
                  failedRow: intendedRow
              ),
              audioLease.relativeIdentifier
                == pendingSnapshot.recording.audioRelativeIdentifier,
              audioLease.durationMilliseconds
                == pendingSnapshot.recording.durationMilliseconds,
              audioLease.audioArtifact.byteCount
                == pendingSnapshot.recording.byteCount else {
            return nil
        }
        self.pendingSnapshot = pendingSnapshot
        self.intendedRow = intendedRow
        self.audioLease = audioLease
        self.pendingStoreIdentity = pendingStoreIdentity
        self.failedStoreIdentity = failedStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
        self.policyReceipt = policyReceipt
    }

    deinit {
        releaseAudioLease()
    }

    var audioMetadataMatchesPendingSnapshot: Bool {
        guard !releaseLock.withLock({ didReleaseAudioLease }) else {
            return false
        }
        let recording = pendingSnapshot.recording
        return audioLease.relativeIdentifier
                == recording.audioRelativeIdentifier
            && audioLease.durationMilliseconds
                == recording.durationMilliseconds
            && audioLease.audioArtifact.byteCount == recording.byteCount
    }

    func revalidateAudio() async throws {
        guard !releaseLock.withLock({ didReleaseAudioLease }) else {
            throw IOSPendingRecordingError.linkedAudioInvalid
        }
        let artifact = try await audioLease.revalidate()
        guard !releaseLock.withLock({ didReleaseAudioLease }),
              audioMetadataMatchesPendingSnapshot,
              artifact.byteCount == pendingSnapshot.recording.byteCount else {
            throw IOSPendingRecordingError.linkedAudioInvalid
        }
    }

    func releaseAudioLease() {
        let shouldRelease = releaseLock.withLock {
            guard !didReleaseAudioLease else { return false }
            didReleaseAudioLease = true
            return true
        }
        if shouldRelease {
            audioLease.release()
        }
    }
}

extension IOSPendingFailedHistoryTransferPreparation: Equatable {
    static func == (
        lhs: IOSPendingFailedHistoryTransferPreparation,
        rhs: IOSPendingFailedHistoryTransferPreparation
    ) -> Bool {
        lhs === rhs
    }
}

extension IOSPendingFailedHistoryTransferPreparation:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSPendingFailedHistoryTransferPreparation(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Failed-store authority for removing only the redundant Pending metadata.
/// A committed origin retains the exact pre-row Pending physical snapshot;
/// relaunch intentionally does not invent one.
struct IOSFailedHistoryPendingMetadataRetirementAuthority:
    Equatable,
    Sendable {
    enum Origin: Equatable, Sendable {
        case committed(IOSPendingRecordingJournalMetadataSnapshot)
        case relaunched
        case readyOutcomeConfirmation
    }

    let failedSource: IOSFailedHistoryJournalSnapshot
    let row: IOSFailedHistoryEntry
    let origin: Origin
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryMetadataRetirementAuthorityMint,
        failedSource: IOSFailedHistoryJournalSnapshot,
        row: IOSFailedHistoryEntry,
        origin: Origin,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        _ = mint
        guard operationLeaseAuthorization.provesActiveLease(),
              repositoryBinding.physicalRootIdentity != nil,
              failedSource.envelope.entries.contains(row),
              let rowIdentity = IOSFailedHistoryPendingMatchIdentity(
                  failedRow: row
              ) else {
            return nil
        }
        if case .committed(let pendingSource) = origin {
            guard IOSFailedHistoryPendingMatchIdentity(
                pending: pendingSource.recording
            ) == rowIdentity else {
                return nil
            }
        }

        self.failedSource = failedSource
        self.row = row
        self.origin = origin
        self.failedStoreIdentity = failedStoreIdentity
        self.expectedPendingStoreIdentity = expectedPendingStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }
}

extension IOSFailedHistoryPendingMetadataRetirementAuthority:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryPendingMetadataRetirementAuthority(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Exact present-source authorization retained across metadata-removal
/// uncertainty so a semantically equal replacement is never resampled.
struct IOSPendingRecordingMetadataRemovalAuthorization:
    Equatable,
    Sendable {
    let authority: IOSFailedHistoryPendingMetadataRetirementAuthority
    let source: IOSPendingRecordingJournalMetadataSnapshot

    init?(
        mint: IOSPendingRecordingMetadataRemovalAuthorizationMint,
        authority: IOSFailedHistoryPendingMetadataRetirementAuthority,
        source: IOSPendingRecordingJournalMetadataSnapshot
    ) {
        _ = mint
        guard authority.operationLeaseAuthorization.provesActiveLease(),
              IOSFailedHistoryPendingMatchIdentity(
                  pending: source.recording
              ) == IOSFailedHistoryPendingMatchIdentity(
                  failedRow: authority.row
              ) else {
            return nil
        }
        if case .committed(let expectedSource) = authority.origin {
            guard source == expectedSource else { return nil }
        }
        self.authority = authority
        self.source = source
    }
}

extension IOSPendingRecordingMetadataRemovalAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSPendingRecordingMetadataRemovalAuthorization(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Pending-store proof that the one canonical journal path is durably absent.
/// The low-level evidence remains opaque and path-typed.
struct IOSPendingRecordingMetadataAbsenceReceipt: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case removed(
            source: IOSPendingRecordingJournalMetadataSnapshot,
            evidence: IOSPendingRecordingJournalMetadataAbsenceEvidence
        )
        case alreadyAbsent(
            evidence: IOSPendingRecordingJournalMetadataAbsenceEvidence
        )

        func provesRemoval(
            of source: IOSPendingRecordingJournalMetadataSnapshot
        ) -> Bool {
            guard case .removed(
                let recordedSource,
                let evidence
            ) = self else {
                return false
            }
            return recordedSource == source
                && evidence.provesRemoval(of: source)
        }

        var provesPreexistingAbsence: Bool {
            guard case .alreadyAbsent(let evidence) = self else {
                return false
            }
            return evidence.provesPreexistingAbsence
        }
    }

    let issuerStoreIdentity: IOSPendingRecordingStoreIdentity
    let authority: IOSFailedHistoryPendingMetadataRetirementAuthority
    let outcome: Outcome

    init?(
        mint: IOSPendingRecordingMetadataAbsenceReceiptMint,
        issuerStoreIdentity: IOSPendingRecordingStoreIdentity,
        authority: IOSFailedHistoryPendingMetadataRetirementAuthority,
        outcome: Outcome
    ) {
        _ = mint
        guard issuerStoreIdentity
                == authority.expectedPendingStoreIdentity,
              authority.operationLeaseAuthorization.provesActiveLease(),
              let expectedRoot = authority.repositoryBinding
                .physicalRootIdentity else {
            return nil
        }

        let evidence: IOSPendingRecordingJournalMetadataAbsenceEvidence
        switch outcome {
        case .removed(let source, let removedEvidence):
            guard authority.origin != .readyOutcomeConfirmation else {
                return nil
            }
            guard removedEvidence.provesRemoval(of: source),
                  IOSFailedHistoryPendingMatchIdentity(
                      pending: source.recording
                  ) == IOSFailedHistoryPendingMatchIdentity(
                      failedRow: authority.row
                  ) else {
                return nil
            }
            if case .committed(let expectedSource) = authority.origin {
                guard source == expectedSource else { return nil }
            }
            evidence = removedEvidence
        case .alreadyAbsent(let absenceEvidence):
            guard absenceEvidence.provesPreexistingAbsence else {
                return nil
            }
            evidence = absenceEvidence
        }
        guard evidence.provesCanonicalPendingRecordingPath,
              evidence.binding.repositoryRoot == expectedRoot else {
            return nil
        }

        self.issuerStoreIdentity = issuerStoreIdentity
        self.authority = authority
        self.outcome = outcome
    }

    var evidence: IOSPendingRecordingJournalMetadataAbsenceEvidence {
        switch outcome {
        case .removed(_, let evidence), .alreadyAbsent(let evidence):
            evidence
        }
    }
}

extension IOSPendingRecordingMetadataAbsenceReceipt:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSPendingRecordingMetadataAbsenceReceipt(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// Immediate proof used by ordinary Pending APIs before they may regain
/// provider or audio-removal authority.
struct IOSFailedHistoryPendingOwnershipKey: Equatable, Sendable {
    let attemptID: UUID
    let audioRelativeIdentifier: String

    init(recording: IOSPendingRecording) {
        attemptID = recording.attemptID
        audioRelativeIdentifier = recording.audioRelativeIdentifier
    }
}

extension IOSFailedHistoryPendingOwnershipKey:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryPendingOwnershipKey(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

struct IOSFailedHistoryPendingOwnershipAbsenceProof: Equatable, Sendable {
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let pendingKey: IOSFailedHistoryPendingOwnershipKey
    let failedSource: IOSFailedHistoryJournalSnapshot?
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization

    init?(
        mint: IOSFailedHistoryPendingOwnershipAbsenceProofMint,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        pendingKey: IOSFailedHistoryPendingOwnershipKey,
        failedSource: IOSFailedHistoryJournalSnapshot?,
        repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) {
        _ = mint
        guard operationLeaseAuthorization.provesActiveLease(),
              repositoryBinding.physicalRootIdentity != nil else {
            return nil
        }
        self.failedStoreIdentity = failedStoreIdentity
        self.expectedPendingStoreIdentity = expectedPendingStoreIdentity
        self.ownerIdentity = ownerIdentity
        self.pendingKey = pendingKey
        self.failedSource = failedSource
        self.repositoryBinding = repositoryBinding
        self.operationLeaseAuthorization = operationLeaseAuthorization
    }
}

extension IOSFailedHistoryPendingOwnershipAbsenceProof:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryPendingOwnershipAbsenceProof(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

protocol IOSPendingRecordingFailedOwnershipInspecting: Sendable {
    func provePendingOwnershipAbsent(
        for pendingKey: IOSFailedHistoryPendingOwnershipKey,
        expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization
    ) async throws -> IOSFailedHistoryPendingOwnershipAbsenceProof
}

struct IOSFailedHistoryTransferFailure: Equatable, Sendable {
    let category: IOSFailedHistoryFailureCategory
    let pipelineStage: IOSFailedHistoryPipelineStage
}

extension IOSFailedHistoryTransferFailure:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "IOSFailedHistoryTransferFailure(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

enum IOSFailedHistoryTransferResult: Equatable, Sendable {
    case transferred
    case reconciled
    case noWork
}

extension IOSFailedHistoryTransferResult:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String { "IOSFailedHistoryTransferResult(redacted)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

enum IOSFailedHistoryTransferSemanticPhase: Equatable, Sendable {
    case committingRow(IOSPendingFailedHistoryTransferPreparation)
    case observingPendingMetadata(
        IOSFailedHistoryPendingMetadataRetirementAuthority
    )
    case removingPendingMetadata(
        IOSPendingRecordingMetadataRemovalAuthorization
    )
    case committingReady(IOSPendingRecordingMetadataAbsenceReceipt)
}

extension IOSFailedHistoryTransferSemanticPhase:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryTransferSemanticPhase(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

fileprivate struct IOSFailedHistoryTransferStateMutationAuthorization {
    fileprivate init() {}
}

actor IOSFailedHistoryTransferOperationState {
    private var phase: IOSFailedHistoryTransferSemanticPhase?

    func current() -> IOSFailedHistoryTransferSemanticPhase? { phase }

    fileprivate func begin(
        _ preparation: IOSPendingFailedHistoryTransferPreparation,
        authorization: IOSFailedHistoryTransferStateMutationAuthorization
    ) -> Bool {
        _ = authorization
        guard phase == nil else { return false }
        phase = .committingRow(preparation)
        return true
    }

    fileprivate func recordRowCommitted(
        _ authority: IOSFailedHistoryPendingMetadataRetirementAuthority,
        from preparation: IOSPendingFailedHistoryTransferPreparation,
        authorization: IOSFailedHistoryTransferStateMutationAuthorization
    ) -> Bool {
        _ = authorization
        guard phase == .committingRow(preparation) else { return false }
        phase = .observingPendingMetadata(authority)
        preparation.releaseAudioLease()
        return true
    }

    fileprivate func recordMetadataRemovalAuthorized(
        _ removalAuthorization:
            IOSPendingRecordingMetadataRemovalAuthorization,
        authorization: IOSFailedHistoryTransferStateMutationAuthorization
    ) -> Bool {
        _ = authorization
        guard phase
                == .observingPendingMetadata(
                    removalAuthorization.authority
                ) else {
            return false
        }
        phase = .removingPendingMetadata(removalAuthorization)
        return true
    }

    fileprivate func recordMetadataAbsent(
        _ receipt: IOSPendingRecordingMetadataAbsenceReceipt,
        authorization: IOSFailedHistoryTransferStateMutationAuthorization
    ) -> Bool {
        _ = authorization
        let matchesCurrentPhase: Bool = switch phase {
        case .observingPendingMetadata(let authority):
            authority == receipt.authority
                && receipt.outcome.provesPreexistingAbsence
        case .removingPendingMetadata(let removalAuthorization):
            removalAuthorization.authority == receipt.authority
                && receipt.outcome.provesRemoval(
                    of: removalAuthorization.source
                )
        default:
            false
        }
        guard matchesCurrentPhase else {
            return false
        }
        phase = .committingReady(receipt)
        return true
    }

    fileprivate func abandonBeforeRowCommit(
        _ preparation: IOSPendingFailedHistoryTransferPreparation,
        authorization: IOSFailedHistoryTransferStateMutationAuthorization
    ) -> Bool {
        _ = authorization
        guard phase == .committingRow(preparation) else { return false }
        preparation.releaseAudioLease()
        phase = nil
        return true
    }

    fileprivate func clearCompleted(
        _ receipt: IOSPendingRecordingMetadataAbsenceReceipt,
        authorization: IOSFailedHistoryTransferStateMutationAuthorization
    ) -> Bool {
        _ = authorization
        guard phase == .committingReady(receipt) else { return false }
        phase = nil
        return true
    }
}
