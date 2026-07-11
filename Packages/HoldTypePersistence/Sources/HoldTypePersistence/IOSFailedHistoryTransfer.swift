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
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding?
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
    let policyReceipt: IOSHistoryPolicyReceipt

    private let audioLease: any IOSPendingRecordingPublishedAudioLease
    private let releaseLock = NSLock()
    private var didReleaseAudioLease = false

    init(
        pendingSnapshot: IOSPendingRecordingJournalMetadataSnapshot,
        intendedRow: IOSFailedHistoryEntry,
        audioLease: any IOSPendingRecordingPublishedAudioLease,
        pendingStoreIdentity: IOSPendingRecordingStoreIdentity,
        failedStoreIdentity: IOSFailedHistoryStoreIdentity,
        ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity,
        repositoryBinding:
            IOSAcceptedHistoryCoordinatorRepositoryBinding?,
        operationLeaseAuthorization:
            IOSPersistenceOperationLeaseAuthorization,
        policyReceipt: IOSHistoryPolicyReceipt
    ) {
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
        let recording = pendingSnapshot.recording
        return audioLease.relativeIdentifier
                == recording.audioRelativeIdentifier
            && audioLease.durationMilliseconds
                == recording.durationMilliseconds
            && audioLease.audioArtifact.byteCount == recording.byteCount
    }

    func revalidateAudio() async throws -> AudioRecordingArtifact {
        try await audioLease.revalidate()
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
    }

    let failedSource: IOSFailedHistoryJournalSnapshot
    let row: IOSFailedHistoryEntry
    let origin: Origin
    let failedStoreIdentity: IOSFailedHistoryStoreIdentity
    let expectedPendingStoreIdentity: IOSPendingRecordingStoreIdentity
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding?
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
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
    }

    let issuerStoreIdentity: IOSPendingRecordingStoreIdentity
    let authority: IOSFailedHistoryPendingMetadataRetirementAuthority
    let outcome: Outcome

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
    let repositoryBinding: IOSAcceptedHistoryCoordinatorRepositoryBinding?
    let operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
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
    case committingRow(IOSFailedHistoryEntry)
    case retiringPendingMetadata(IOSFailedHistoryEntry)
    case committingReady(IOSFailedHistoryEntry)
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

actor IOSFailedHistoryTransferOperationState {
    private var phase: IOSFailedHistoryTransferSemanticPhase?

    func current() -> IOSFailedHistoryTransferSemanticPhase? { phase }

    func store(_ phase: IOSFailedHistoryTransferSemanticPhase) {
        self.phase = phase
    }

    func clear() {
        phase = nil
    }
}
