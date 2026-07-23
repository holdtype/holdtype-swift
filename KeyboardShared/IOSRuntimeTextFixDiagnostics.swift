import Foundation

/// Typed adapter for Fix diagnostics. Raw action identifiers are projected to
/// content-free tags before the event reaches any logger or persistent store.
nonisolated struct IOSRuntimeTextFixDiagnosticClient: Sendable {
    private let recordEvent:
        @Sendable (IOSRuntimeDiagnosticEvent) -> Void

    init(
        recordEvent: @escaping @Sendable (
            IOSRuntimeDiagnosticEvent
        ) -> Void
    ) {
        self.recordEvent = recordEvent
    }

    func record(
        _ stage: IOSDiagnosticTextFixStage,
        actionIdentifier: String? = nil,
        requestID: UUID? = nil,
        outcome: IOSDiagnosticTextFixOutcome
    ) {
        recordEvent(
            .textFix(
                stage,
                action: actionIdentifier.map(IOSDiagnosticActionTag.init),
                request: requestID.map(IOSDiagnosticCorrelationTag.init),
                outcome: outcome
            )
        )
    }

    static var silent: IOSRuntimeTextFixDiagnosticClient {
        IOSRuntimeTextFixDiagnosticClient(recordEvent: { _ in })
    }
}

nonisolated extension KeyboardFixFailureCode {
    var diagnosticOutcome: IOSDiagnosticTextFixOutcome {
        switch self {
        case .actionUnavailable, .translationUnavailable:
            .unavailable
        case .consentRequired, .credentialUnavailable:
            .blocked
        case .timedOut:
            .timedOut
        case .cancelled:
            .cancelled
        case .requestInvalid:
            .stale
        case .persistenceFailed:
            .bridgeUnavailable
        case .providerFailed, .invalidOutput, .sourceTooLarge:
            .failed
        }
    }
}
