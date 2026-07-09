public enum RecordingCachePolicy: Equatable, Sendable {
    public static let defaultRetainedRecordingLimit = 10
    public static let maximumRetainedRecordingLimit = 999

    case deleteImmediately
    case keepLast(Int)
    case unlimited

    public var keepsRecordings: Bool {
        self != .deleteImmediately
    }

    public var retainedRecordingLimit: Int {
        switch normalized {
        case .keepLast(let count):
            return count
        case .deleteImmediately, .unlimited:
            return Self.defaultRetainedRecordingLimit
        }
    }

    public var normalized: RecordingCachePolicy {
        switch self {
        case .keepLast(let count):
            return .keepLast(Self.normalizedRetainedRecordingLimit(count))
        case .deleteImmediately, .unlimited:
            return self
        }
    }

    public static func normalizedRetainedRecordingLimit(_ count: Int) -> Int {
        min(max(1, count), maximumRetainedRecordingLimit)
    }
}

public struct RetentionConfiguration: Equatable, Sendable {
    public static let acceptedHistoryEntryLimit = 20
    public static let failedHistoryEntryLimit = 5
    public static let defaults = RetentionConfiguration()

    public var historyEnabled: Bool
    public var recordingCachePolicy: RecordingCachePolicy

    public init(
        historyEnabled: Bool = true,
        recordingCachePolicy: RecordingCachePolicy = .deleteImmediately
    ) {
        self.historyEnabled = historyEnabled
        self.recordingCachePolicy = recordingCachePolicy
    }
}
