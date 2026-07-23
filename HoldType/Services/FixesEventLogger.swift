import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import OSLog

struct FixesActionIdentity: Equatable {
    let value: UInt32

    init(action: TextFixAction) {
        value = fixesDiagnosticStableTag(action.id)
    }

    var formatted: String {
        String(value, radix: 16, uppercase: false)
    }
}

enum FixesCaptureOutcome: String, Equatable {
    case succeeded
    case blockedAccessibility = "blocked_accessibility"
    case blockedUnavailable = "blocked_unavailable"
    case blockedHoldTypeFocus = "blocked_holdtype_focus"
    case blockedSecureField = "blocked_secure_field"
    case blockedInvalidRange = "blocked_invalid_range"
    case blockedBlankSource = "blocked_blank_source"
    case blockedSourceTooLarge = "blocked_source_too_large"
    case blockedStale = "blocked_stale"
    case blockedUnknown = "blocked_unknown"
}

enum FixesAvailabilityOutcome: String, Equatable {
    case ready
    case blockedBusy = "blocked_busy"
    case blockedCatalogUnavailable = "blocked_catalog_unavailable"
    case blockedConsentRequired = "blocked_consent_required"
    case blockedTargetUnavailable = "blocked_target_unavailable"
    case blockedActionUnavailable = "blocked_action_unavailable"
}

enum FixesActionOutcome: String, Equatable {
    case started
    case succeeded
    case blockedBusy = "blocked_busy"
    case blockedTargetUnavailable = "blocked_target_unavailable"
    case blockedConsentRequired = "blocked_consent_required"
    case blockedCredentialUnavailable = "blocked_credential_unavailable"
    case failedProvider = "failed_provider"
    case failedReplacement = "failed_replacement"
    case timedOutProvider = "timed_out_provider"
    case timedOutReplacement = "timed_out_replacement"
    case cancelled
    case stale
}

enum FixesActionStage {
    case provider
    case replacement
}

enum FixesLogEvent: Equatable {
    case capture(outcome: FixesCaptureOutcome)
    case availability(outcome: FixesAvailabilityOutcome)
    case action(identity: FixesActionIdentity, outcome: FixesActionOutcome)
}

protocol FixesEventLogging {
    func record(_ event: FixesLogEvent)
}

struct OSLogFixesEventLogger: FixesEventLogging {
    private let logger: Logger
    private let runtimeLogRecorder: any RuntimeDiagnosticLogRecording

    init(
        logger: Logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "app.holdtype.HoldType",
            category: "Fixes"
        ),
        runtimeLogRecorder: any RuntimeDiagnosticLogRecording =
            RuntimeDiagnosticsLogStore.shared
    ) {
        self.logger = logger
        self.runtimeLogRecorder = runtimeLogRecorder
    }

    func record(_ event: FixesLogEvent) {
        switch event {
        case .capture(let outcome):
            recordCapture(outcome)
        case .availability(let outcome):
            recordAvailability(outcome)
        case .action(let identity, let outcome):
            recordAction(identity: identity, outcome: outcome)
        }

        runtimeLogRecorder.record(event.runtimeDiagnosticEvent)
    }

    private func recordCapture(_ outcome: FixesCaptureOutcome) {
        if outcome == .succeeded {
            logger.info(
                "Fixes capture: outcome \(outcome.rawValue, privacy: .public)"
            )
        } else {
            logger.error(
                "Fixes capture: outcome \(outcome.rawValue, privacy: .public)"
            )
        }
    }

    private func recordAvailability(_ outcome: FixesAvailabilityOutcome) {
        if outcome == .ready {
            logger.info(
                "Fixes availability: outcome \(outcome.rawValue, privacy: .public)"
            )
        } else {
            logger.error(
                "Fixes availability: outcome \(outcome.rawValue, privacy: .public)"
            )
        }
    }

    private func recordAction(
        identity: FixesActionIdentity,
        outcome: FixesActionOutcome
    ) {
        switch outcome {
        case .failedProvider,
             .failedReplacement,
             .timedOutProvider,
             .timedOutReplacement:
            logger.error(
                "Fixes action: tag \(identity.formatted, privacy: .public), outcome \(outcome.rawValue, privacy: .public)"
            )
        case .started,
             .succeeded,
             .blockedBusy,
             .blockedTargetUnavailable,
             .blockedConsentRequired,
             .blockedCredentialUnavailable,
             .cancelled,
             .stale:
            logger.info(
                "Fixes action: tag \(identity.formatted, privacy: .public), outcome \(outcome.rawValue, privacy: .public)"
            )
        }
    }
}

private extension FixesLogEvent {
    var runtimeDiagnosticEvent: RuntimeDiagnosticEvent {
        switch self {
        case .capture(let outcome):
            return RuntimeDiagnosticEvent(
                category: "fixes",
                name: "capture",
                severity: outcome == .succeeded ? .info : .error,
                fields: ["outcome": outcome.rawValue]
            )
        case .availability(let outcome):
            return RuntimeDiagnosticEvent(
                category: "fixes",
                name: "availability",
                severity: outcome == .ready ? .info : .error,
                fields: ["outcome": outcome.rawValue]
            )
        case .action(let identity, let outcome):
            return RuntimeDiagnosticEvent(
                category: "fixes",
                name: "action",
                severity: outcome.runtimeSeverity,
                fields: [
                    "action_tag": identity.formatted,
                    "outcome": outcome.rawValue,
                ]
            )
        }
    }
}

private func fixesDiagnosticStableTag(_ value: String) -> UInt32 {
    var hash: UInt32 = 2_166_136_261
    for byte in value.utf8 {
        hash ^= UInt32(byte)
        hash &*= 16_777_619
    }
    return hash
}

private extension FixesActionOutcome {
    var runtimeSeverity: RuntimeDiagnosticSeverity {
        switch self {
        case .failedProvider,
             .failedReplacement,
             .timedOutProvider,
             .timedOutReplacement:
            return .error
        case .started,
             .succeeded,
             .blockedBusy,
             .blockedTargetUnavailable,
             .blockedConsentRequired,
             .blockedCredentialUnavailable,
             .cancelled,
             .stale:
            return .info
        }
    }
}

extension FixesCaptureOutcome {
    static func closedCategory(for error: Error) -> FixesCaptureOutcome {
        guard let error = error as? FocusedTextTargetError else {
            return .blockedUnknown
        }

        switch error {
        case .accessibilityNotTrusted:
            return .blockedAccessibility
        case .unavailable:
            return .blockedUnavailable
        case .holdTypeOwnsFocus:
            return .blockedHoldTypeFocus
        case .secureField:
            return .blockedSecureField
        case .invalidRange:
            return .blockedInvalidRange
        case .blankSource:
            return .blockedBlankSource
        case .sourceTooLarge:
            return .blockedSourceTooLarge
        case .stale,
             .focusRestorationFailed,
             .cancelled,
             .replacementTimedOut,
             .replacementFailed:
            return .blockedStale
        }
    }
}

extension FixesActionOutcome {
    static func terminal(
        for error: Error,
        stage: FixesActionStage
    ) -> FixesActionOutcome {
        if error is CancellationError || isProviderCancellation(error) {
            return .cancelled
        }
        if let targetError = error as? FocusedTextTargetError {
            switch targetError {
            case .stale:
                return .stale
            case .cancelled:
                return .cancelled
            case .replacementTimedOut:
                return .timedOutReplacement
            case .accessibilityNotTrusted,
                 .unavailable,
                 .holdTypeOwnsFocus,
                 .secureField,
                 .invalidRange,
                 .blankSource,
                 .sourceTooLarge,
                 .focusRestorationFailed,
                 .replacementFailed:
                break
            }
        }
        if isProviderTimeout(error) {
            return .timedOutProvider
        }

        switch stage {
        case .provider:
            return .failedProvider
        case .replacement:
            return .failedReplacement
        }
    }

    private static func isProviderCancellation(_ error: Error) -> Bool {
        if let error = error as? OpenAITextTranslationServiceError,
           case .cancelled = error {
            return true
        }
        if let error = error as? OpenAITextCorrectionServiceError,
           case .cancelled = error {
            return true
        }
        if let error = error as? OpenAITextTransformationServiceError,
           case .cancelled = error {
            return true
        }
        return false
    }

    private static func isProviderTimeout(_ error: Error) -> Bool {
        if let error = error as? OpenAITextTranslationServiceError,
           case .timedOut = error {
            return true
        }
        if let error = error as? OpenAITextCorrectionServiceError,
           case .timedOut = error {
            return true
        }
        if let error = error as? OpenAITextTransformationServiceError,
           case .timedOut = error {
            return true
        }
        if let error = error as? URLError, error.code == .timedOut {
            return true
        }
        return false
    }
}
