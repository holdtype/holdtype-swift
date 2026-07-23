@_spi(HoldTypeIOSCore) import HoldTypeIOSCore

nonisolated extension IOSVoiceDraftTextActionFailure {
    var diagnosticOutcome: IOSDiagnosticTextFixOutcome {
        switch self {
        case .busy:
            .busy
        case .invalidText, .invalidConfiguration,
             .credentialUnavailable, .consentUnavailable:
            .blocked
        case .timedOut:
            .timedOut
        case .draftChanged:
            .stale
        case .cancelled:
            .cancelled
        case .networkUnavailable, .providerUnavailable,
             .invalidResponse, .sourceTooLarge, .saveFailed:
            .failed
        }
    }
}
