import Foundation
import HoldTypeDomain

public enum IOSAcceptedHistoryError: Error, Equatable, Sendable {
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
    case maintenanceFailed
}

extension IOSAcceptedHistoryError: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String { "IOSAcceptedHistoryError(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

public struct IOSAcceptedHistoryEntry: Sendable {
    public let deliveryID: UUID
    public let transcriptID: UUID
    public let acceptedText: String
    public let outputIntent: DictationOutputIntent
    public let createdAt: Date
    public let policyGeneration: Int64
    public let transcriptionModel: String
    public let transcriptionLanguageCode: String?
    public let durationMilliseconds: Int64?
    public let cachedAudioRelativeIdentifier: String?

    init(
        deliveryID: UUID,
        transcriptID: UUID,
        acceptedText: String,
        outputIntent: DictationOutputIntent,
        createdAt: Date,
        policyGeneration: Int64,
        transcriptionModel: String,
        transcriptionLanguageCode: String?,
        durationMilliseconds: Int64?,
        cachedAudioRelativeIdentifier: String?
    ) throws {
        let normalizedModel = IOSAcceptedOutputDeliveryValidation
            .normalizedMetadataText(transcriptionModel)
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
            IOSAcceptedHistoryValidation.isValidCacheIdentifier(
                cachedAudioRelativeIdentifier
            ),
            (try? IOSAcceptedOutputDeliveryTimestampCodec.milliseconds(
                from: createdAt
            )) != nil else {
            throw IOSAcceptedHistoryError.invalidEntry
        }

        self.deliveryID = deliveryID
        self.transcriptID = transcriptID
        self.acceptedText = acceptedText
        self.outputIntent = outputIntent
        self.createdAt = createdAt
        self.policyGeneration = policyGeneration
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguageCode = transcriptionLanguageCode
        self.durationMilliseconds = durationMilliseconds
        self.cachedAudioRelativeIdentifier = cachedAudioRelativeIdentifier
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
            && policyGeneration == other.policyGeneration
            && IOSAcceptedOutputDeliveryValidation.bytesEqual(
                transcriptionModel,
                other.transcriptionModel
            )
            && transcriptionLanguageCode == other.transcriptionLanguageCode
            && durationMilliseconds == other.durationMilliseconds
    }
}

extension IOSAcceptedHistoryEntry: Equatable {
    public static func == (
        lhs: IOSAcceptedHistoryEntry,
        rhs: IOSAcceptedHistoryEntry
    ) -> Bool {
        lhs.hasSameImmutableBytes(as: rhs)
            && IOSAcceptedOutputDeliveryValidation.optionalBytesEqual(
                lhs.cachedAudioRelativeIdentifier,
                rhs.cachedAudioRelativeIdentifier
            )
    }
}

extension IOSAcceptedHistoryEntry: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String { "IOSAcceptedHistoryEntry(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

public struct IOSAcceptedHistoryEnvelope: Equatable, Sendable {
    public let revision: Int64
    public let entries: [IOSAcceptedHistoryEntry]

    init(
        revision: Int64,
        entries: [IOSAcceptedHistoryEntry]
    ) throws {
        guard revision >= 1,
              entries.count <= IOSAcceptedHistoryValidation.maximumEntryCount,
              entries == IOSAcceptedHistoryValidation.sorted(entries),
              Set(entries.map(\.deliveryID)).count == entries.count,
              Set(entries.map(\.transcriptID)).count == entries.count else {
            throw IOSAcceptedHistoryError.invalidRecord
        }
        self.revision = revision
        self.entries = entries
    }
}

extension IOSAcceptedHistoryEnvelope: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String { "IOSAcceptedHistoryEnvelope(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

public struct IOSAcceptedHistoryMaintenanceReport: Equatable, Sendable {
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

enum IOSAcceptedHistoryValidation {
    static let maximumEntryCount = 20
    static let maximumCacheIdentifierByteCount = 512

    static func sorted(
        _ entries: [IOSAcceptedHistoryEntry]
    ) -> [IOSAcceptedHistoryEntry] {
        entries.sorted { lhs, rhs in
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt > rhs.createdAt
            }
            return canonicalIdentifier(lhs.deliveryID)
                < canonicalIdentifier(rhs.deliveryID)
        }
    }

    static func canonicalIdentifier(_ identifier: UUID) -> String {
        identifier.uuidString.lowercased()
    }

    static func isValidCacheIdentifier(_ value: String?) -> Bool {
        guard let value else { return true }
        guard !value.isEmpty,
              value.utf8.count <= maximumCacheIdentifierByteCount,
              !value.hasPrefix("/"),
              !value.hasSuffix("/"),
              !value.contains("\\"),
              !value.unicodeScalars.contains(where: { $0.value == 0 }) else {
            return false
        }
        return value.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { component in
                !component.isEmpty && component != "." && component != ".."
            }
    }
}
