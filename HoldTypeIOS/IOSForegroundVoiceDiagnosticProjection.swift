import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore

@MainActor
enum IOSForegroundVoiceDiagnosticProjection {
    static func action(
        intent: DictationOutputIntent,
        forcesTextCorrection: Bool
    ) -> IOSDiagnosticVoiceAction {
        if forcesTextCorrection && intent == .translate {
            return .translateAndImprove
        }
        if forcesTextCorrection { return .improve }
        return intent == .translate ? .translate : .standard
    }

    static func providerMode(
        _ mode: IOSForegroundVoiceProcessingMode
    ) -> IOSDiagnosticProviderMode {
        switch mode {
        case .initial:
            .initial
        case .retry:
            .retry
        }
    }

    static func durability(
        _ recovery: IOSForegroundVoiceRecovery
    ) -> IOSDiagnosticVoiceDurability {
        switch recovery {
        case .none:
            .none
        case .captureRecoverOrDiscard:
            .recoverableCapture
        case .captureDiscardOnly:
            .discardOnlyCapture
        case .pendingRetryOrDiscard:
            .pendingRecording
        case .blocked:
            .blocked
        }
    }

    static func outcome(
        _ resolution: IOSForegroundVoiceProcessingResolution
    ) -> IOSDiagnosticOutcome {
        switch resolution {
        case .acceptance:
            .succeeded
        case .notStarted(.cancelled):
            .cancelled
        case .notStarted(.timedOut):
            .timedOut
        case .notStarted, .retryAvailable:
            .failed
        case .busy:
            .unavailable
        }
    }

    static func outcome(
        _ resolution: IOSForegroundVoiceResolution
    ) -> IOSDiagnosticOutcome {
        if resolution.failure == .microphonePermissionTimedOut {
            return .timedOut
        }
        if resolution.failure != nil { return .failed }
        return switch resolution.outcome {
        case .resultReady:
            .succeeded
        case .interrupted:
            .cancelled
        case .recoverableFailure:
            .failed
        case nil:
            .unavailable
        }
    }
}
