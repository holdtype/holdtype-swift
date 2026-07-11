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
