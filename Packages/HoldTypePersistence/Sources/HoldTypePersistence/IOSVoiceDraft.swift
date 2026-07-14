import Foundation

public enum IOSVoiceDraftSegmentError: Error, Equatable, Sendable {
    case invalidText
}

public struct IOSVoiceDraftSegment: Equatable, Identifiable, Sendable {
    public let resultID: UUID
    public let text: String

    public var id: UUID { resultID }

    public init(resultID: UUID, text: String) throws {
        guard IOSAcceptedTextHistoryValidation.isStoredText(text) else {
            throw IOSVoiceDraftSegmentError.invalidText
        }
        self.resultID = resultID
        self.text = text
    }
}

public struct IOSVoiceDraftRecord: Equatable, Sendable {
    public static let maximumSegmentCount = 100
    public static let empty = Self(segments: [])

    public let segments: [IOSVoiceDraftSegment]

    public var text: String {
        segments.map(\.text).joined(separator: "\n\n")
    }

    public var isEmpty: Bool { segments.isEmpty }
    public var isFull: Bool { segments.count >= Self.maximumSegmentCount }

    @_spi(HoldTypeIOSCore)
    public init(segments: [IOSVoiceDraftSegment]) {
        self.segments = segments
    }
}

public struct IOSVoiceDraftSnapshotToken: Equatable, Sendable {
    private let segments: [IOSVoiceDraftSegment]

    public init(record: IOSVoiceDraftRecord) {
        segments = record.segments
    }
}

public enum IOSVoiceDraftAppendResult: Equatable, Sendable {
    case inserted(IOSVoiceDraftRecord)
    case duplicate(IOSVoiceDraftRecord)
    case full(IOSVoiceDraftRecord)
}

public enum IOSVoiceDraftMutationResult: Equatable, Sendable {
    case confirmed(IOSVoiceDraftRecord)
    case stale(IOSVoiceDraftRecord)
}

extension IOSVoiceDraftSegment: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSVoiceDraftSegment(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSVoiceDraftRecord: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSVoiceDraftRecord(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSVoiceDraftSnapshotToken: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSVoiceDraftSnapshotToken(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
