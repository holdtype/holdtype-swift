import HoldTypeDomain

/// Opaque process-local ordering for usage write attempts and Reset fences.
/// It carries no transcription, model, duration, price, or storage identity.
public struct IOSTranscriptionUsageWriteToken:
    Equatable,
    Comparable,
    Sendable {
    fileprivate let revision: UInt64

    init(revision: UInt64) {
        self.revision = revision
    }

    public static func < (
        lhs: Self,
        rhs: Self
    ) -> Bool {
        lhs.revision < rhs.revision
    }

    /// A fail-closed sentinel after the process-local ordering counter can no
    /// longer advance. Consumers must treat every such failure as fresh.
    @_spi(HoldTypeIOSCore)
    public var isOrderingExhausted: Bool {
        revision == UInt64.max
    }
}

public enum IOSTranscriptionUsageObservedRecordResult:
    Equatable,
    Sendable {
    case inserted(IOSTranscriptionUsageWriteToken)
    case duplicate(IOSTranscriptionUsageWriteToken)
    case failed(IOSTranscriptionUsageWriteToken)
}

/// Mandatory production recording path shared by foreground Voice and
/// failed-History Retry. A write error is reported with only its opaque token.
public struct IOSTranscriptionUsageRecordingClient: Sendable {
    public typealias FailureReporter = @Sendable (
        IOSTranscriptionUsageWriteToken
    ) async -> Void

    private let repository: IOSTranscriptionUsageRepository
    private let reportFailure: FailureReporter

    public init(
        repository: IOSTranscriptionUsageRepository,
        reportFailure: @escaping FailureReporter
    ) {
        self.repository = repository
        self.reportFailure = reportFailure
    }

    public func record(_ usage: SuccessfulTranscriptionUsage) async {
        guard case .failed(let token) = await repository.recordObserved(usage)
        else {
            return
        }
        await reportFailure(token)
    }
}

extension IOSTranscriptionUsageWriteToken:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSTranscriptionUsageWriteToken(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSTranscriptionUsageRecordingClient:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSTranscriptionUsageRecordingClient(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
