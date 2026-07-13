import Foundation

public enum IOSAcceptedTextHistoryEntryError: Error, Equatable, Sendable {
    case invalidText
    case invalidCreationDate
}

public struct IOSAcceptedTextHistoryEntry: Equatable, Identifiable, Sendable {
    public let resultID: UUID
    public let text: String
    public let createdAt: Date

    public var id: UUID { resultID }

    public init(
        resultID: UUID,
        text: String,
        createdAt: Date
    ) throws {
        guard IOSAcceptedOutputDeliveryValidation.isStoredAcceptedText(text) else {
            throw IOSAcceptedTextHistoryEntryError.invalidText
        }

        let canonicalDate: Date
        do {
            canonicalDate = try IOSAcceptedOutputDeliveryTimestampCodec
                .canonicalDate(from: createdAt)
        } catch {
            throw IOSAcceptedTextHistoryEntryError.invalidCreationDate
        }

        self.resultID = resultID
        self.text = text
        self.createdAt = canonicalDate
    }

    public static func == (
        lhs: IOSAcceptedTextHistoryEntry,
        rhs: IOSAcceptedTextHistoryEntry
    ) -> Bool {
        lhs.resultID == rhs.resultID
            && IOSAcceptedOutputDeliveryValidation.bytesEqual(lhs.text, rhs.text)
            && lhs.createdAt == rhs.createdAt
    }
}

public struct IOSAcceptedTextHistoryRecord: Equatable, Sendable {
    public static let maximumEntryCount = 20
    public static let enabledEmpty = Self(isEnabled: true, entries: [])

    public let isEnabled: Bool
    public let entries: [IOSAcceptedTextHistoryEntry]

    init(isEnabled: Bool, entries: [IOSAcceptedTextHistoryEntry]) {
        self.isEnabled = isEnabled
        self.entries = entries
    }
}

public struct IOSAcceptedTextHistorySnapshotToken: Equatable, Sendable {
    private let isEnabled: Bool
    private let resultIDs: [UUID]

    public init(record: IOSAcceptedTextHistoryRecord) {
        isEnabled = record.isEnabled
        resultIDs = record.entries.map(\.resultID)
    }
}

public enum IOSAcceptedTextHistoryAppendResult: Equatable, Sendable {
    case inserted
    case duplicate
    case disabled
    case outsideRetentionWindow
}

public enum IOSAcceptedTextHistoryMutationResult: Equatable, Sendable {
    case confirmed(IOSAcceptedTextHistoryRecord)
    case stale(IOSAcceptedTextHistoryRecord)
}

extension IOSAcceptedTextHistoryEntry: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSAcceptedTextHistoryEntry(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSAcceptedTextHistoryRecord: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSAcceptedTextHistoryRecord(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
