import Foundation
import HoldTypeDomain

public enum IOSAcceptedHistoryOutboxError: Error, Equatable, Sendable {
    case invalidEntry
    case invalidRecord
    case sourceTooLarge
    case malformedData
    case unsupportedSchemaVersion
    case readFailed
    case writeFailed
    case dataProtectionUnavailable
    case slotOccupied
    case compareAndSwapFailed
    case collision
    case stalePolicyGeneration
    case revisionOverflow
    case commitUncertain
    case capacityExceeded
    case expired
    case invalidTransition
    case clockRollbackAmbiguous
    case maintenanceFailed
}

extension IOSAcceptedHistoryOutboxError: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String { "IOSAcceptedHistoryOutboxError(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

public struct IOSAcceptedHistoryOutboxEntry: Sendable {
    public let deliveryID: UUID
    public let transcriptID: UUID
    public let acceptedText: String
    public let outputIntent: DictationOutputIntent
    public let createdAt: Date
    public let expiresAt: Date
    public let policyGeneration: Int64
    public let transcriptionModel: String
    public let transcriptionLanguageCode: String?
    public let durationMilliseconds: Int64?

    init(
        deliveryID: UUID,
        transcriptID: UUID,
        acceptedText: String,
        outputIntent: DictationOutputIntent,
        createdAt: Date,
        expiresAt: Date,
        policyGeneration: Int64,
        transcriptionModel: String,
        transcriptionLanguageCode: String?,
        durationMilliseconds: Int64?
    ) throws {
        let normalizedModel = IOSAcceptedOutputDeliveryValidation
            .normalizedMetadataText(transcriptionModel)
        let createdMilliseconds = try? IOSAcceptedOutputDeliveryTimestampCodec
            .milliseconds(from: createdAt)
        let expiresMilliseconds = try? IOSAcceptedOutputDeliveryTimestampCodec
            .milliseconds(from: expiresAt)
        let expectedExpiry = createdMilliseconds?.addingReportingOverflow(
            IOSAcceptedOutputDeliveryValidation.lifetimeMilliseconds
        )
        guard IOSAcceptedOutputDeliveryValidation.isStoredAcceptedText(
            acceptedText
        ),
            let normalizedModel,
            IOSAcceptedOutputDeliveryValidation.bytesEqual(
                normalizedModel,
                transcriptionModel
            ),
            normalizedModel.utf8.count
                <= IOSAcceptedOutputDeliveryValidation.maximumModelByteCount,
            policyGeneration > 0,
            IOSAcceptedOutputDeliveryValidation.isValidLanguageCode(
                transcriptionLanguageCode
            ),
            IOSAcceptedOutputDeliveryValidation.isValidDuration(
                durationMilliseconds
            ),
            let expiresMilliseconds,
            let expectedExpiry,
            !expectedExpiry.overflow,
            expectedExpiry.partialValue == expiresMilliseconds else {
            throw IOSAcceptedHistoryOutboxError.invalidEntry
        }

        self.deliveryID = deliveryID
        self.transcriptID = transcriptID
        self.acceptedText = acceptedText
        self.outputIntent = outputIntent
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.policyGeneration = policyGeneration
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguageCode = transcriptionLanguageCode
        self.durationMilliseconds = durationMilliseconds
    }

    func temporalState(at now: Date) -> IOSAcceptedHistoryOutboxTemporalState {
        if now < createdAt { return .clockRollbackAmbiguous }
        if now >= expiresAt { return .expired }
        return .live
    }

    func hasSameImmutableBytes(as other: Self) -> Bool {
        deliveryID == other.deliveryID
            && transcriptID == other.transcriptID
            && IOSAcceptedOutputDeliveryValidation.bytesEqual(
                acceptedText,
                other.acceptedText
            )
            && outputIntent == other.outputIntent
            && createdAt == other.createdAt
            && expiresAt == other.expiresAt
            && policyGeneration == other.policyGeneration
            && IOSAcceptedOutputDeliveryValidation.bytesEqual(
                transcriptionModel,
                other.transcriptionModel
            )
            && transcriptionLanguageCode == other.transcriptionLanguageCode
            && durationMilliseconds == other.durationMilliseconds
    }
}

extension IOSAcceptedHistoryOutboxEntry: Equatable {
    public static func == (
        lhs: IOSAcceptedHistoryOutboxEntry,
        rhs: IOSAcceptedHistoryOutboxEntry
    ) -> Bool {
        lhs.hasSameImmutableBytes(as: rhs)
    }
}

extension IOSAcceptedHistoryOutboxEntry: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSAcceptedHistoryOutboxEntry(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

public struct IOSAcceptedHistoryOutboxEnvelope: Equatable, Sendable {
    public let revision: Int64
    public let entries: [IOSAcceptedHistoryOutboxEntry]

    init(
        revision: Int64,
        entries: [IOSAcceptedHistoryOutboxEntry]
    ) throws {
        guard revision >= 1,
              entries.count
                <= IOSAcceptedHistoryOutboxValidation.maximumEntryCount,
              entries == IOSAcceptedHistoryOutboxValidation.sorted(entries),
              Set(entries.map(\.deliveryID)).count == entries.count,
              Set(entries.map(\.transcriptID)).count == entries.count else {
            throw IOSAcceptedHistoryOutboxError.invalidRecord
        }
        self.revision = revision
        self.entries = entries
    }
}

extension IOSAcceptedHistoryOutboxEnvelope: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSAcceptedHistoryOutboxEnvelope(redacted)"
    }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

public struct IOSAcceptedHistoryOutboxMaintenanceReport:
    Equatable,
    Sendable {
    public let inspectedEntryCount: Int
    public let inspectedByteCount: Int64
    public let removedFileCount: Int
    public let removedByteCount: Int64
    public let reachedLimit: Bool

    init(_ report: IOSStrictProtectedRecordMaintenanceReport) {
        inspectedEntryCount = report.inspectedEntryCount
        inspectedByteCount = report.inspectedByteCount
        removedFileCount = report.removedFileCount
        removedByteCount = report.removedByteCount
        reachedLimit = report.reachedLimit
    }
}

enum IOSAcceptedHistoryOutboxTemporalState: Equatable, Sendable {
    case live
    case expired
    case clockRollbackAmbiguous
}

enum IOSAcceptedHistoryOutboxValidation {
    static let maximumEntryCount = 20

    static func sorted(
        _ entries: [IOSAcceptedHistoryOutboxEntry]
    ) -> [IOSAcceptedHistoryOutboxEntry] {
        entries.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return canonicalIdentifier(lhs.deliveryID)
                < canonicalIdentifier(rhs.deliveryID)
        }
    }

    static func canonicalIdentifier(_ identifier: UUID) -> String {
        identifier.uuidString.lowercased()
    }
}
