//
//  DictationEventLogger.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

import Foundation
import HoldTypeDomain
import OSLog

enum RecordingTerminalCause: String, Equatable {
    case userFinished = "user_finished"
    case configuredLimit = "configured_limit"
    case platformInterrupted = "platform_interrupted"
    case internalFailure = "internal_failure"
    case ownerTeardown = "owner_teardown"
    case explicitUserDiscard = "explicit_user_discard"
}

enum RecordingDurabilityOutcome: String, Equatable {
    case historyCheckpoint = "history_checkpoint"
    case emergencyFallback = "emergency_fallback"
    case protectedCapture = "protected_capture"
    case emptyOrMissingDiscarded = "empty_or_missing_discarded"
    case explicitlyDiscarded = "explicitly_discarded"
    case discardFailed = "discard_failed"
}

enum DictationLogEvent: Equatable {
    case hotkeyEvent(action: GlobalHotkeyAction, intent: DictationOutputIntent)
    case hotkeyStopDeferred
    case hotkeyStopReplayed
    case recordingStartRequested
    case recordingStarted
    case recordingStartFailed(category: String)
    case recordingStopRequested
    case recordingStopTailStarted(duration: TimeInterval)
    case recordingStopTailFinished(duration: TimeInterval)
    case recordingLimitReached
    case recordingEndedUnexpectedly(recorderReportedSuccess: Bool)
    case recordingStopped(duration: TimeInterval, byteCount: Int64)
    case recordingStopFailed(category: String)
    case transcriptionStarted
    case transcriptionSucceeded
    case transcriptionFailed(category: String)
    case postProcessingFailed(category: String)
    case outputDeliveryFailed(category: String)
    case recordingCacheHandled(policy: RecordingCachePolicy)
    case recordingCacheFailed(category: String)
    case recordingTerminal(
        cause: RecordingTerminalCause,
        attemptID: UUID,
        durability: RecordingDurabilityOutcome,
        providerAuthorized: Bool
    )
}

protocol DictationEventLogging {
    func record(_ event: DictationLogEvent)
}

struct OSLogDictationEventLogger: DictationEventLogging {
    private let logger: Logger
    private let runtimeLogRecorder: any RuntimeDiagnosticLogRecording

    init(
        logger: Logger = Logger(
            subsystem: Bundle.main.bundleIdentifier ?? "app.holdtype.HoldType",
            category: "Dictation"
        ),
        runtimeLogRecorder: any RuntimeDiagnosticLogRecording = RuntimeDiagnosticsLogStore.shared
    ) {
        self.logger = logger
        self.runtimeLogRecorder = runtimeLogRecorder
    }

    func record(_ event: DictationLogEvent) {
        switch event {
        case .hotkeyEvent(let action, let intent):
            logger.info(
                "Hotkey event: \(action.logName, privacy: .public), intent: \(intent.logName, privacy: .public)"
            )
        case .hotkeyStopDeferred:
            logger.info("Hotkey stop deferred until recording start completes")
        case .hotkeyStopReplayed:
            logger.info("Hotkey deferred stop replayed")
        case .recordingStartRequested:
            logger.info("Recording start requested")
        case .recordingStarted:
            logger.info("Recording started")
        case .recordingStartFailed(let category):
            logger.error("Recording start failed: \(category, privacy: .public)")
        case .recordingStopRequested:
            logger.info("Recording stop requested")
        case .recordingStopTailStarted(let duration):
            logger.info("Recording stop tail started: duration \(duration, privacy: .public)")
        case .recordingStopTailFinished(let duration):
            logger.info("Recording stop tail finished: duration \(duration, privacy: .public)")
        case .recordingLimitReached:
            logger.info("Recording limit reached; automatic finish started")
        case .recordingEndedUnexpectedly(let recorderReportedSuccess):
            logger.error(
                "Recorder ended unexpectedly: success \(recorderReportedSuccess, privacy: .public)"
            )
        case .recordingStopped(let duration, let byteCount):
            logger.info(
                "Recording stopped: duration \(duration, privacy: .public), bytes \(byteCount, privacy: .public)"
            )
        case .recordingStopFailed(let category):
            logger.error("Recording stop failed: \(category, privacy: .public)")
        case .transcriptionStarted:
            logger.info("Transcription started")
        case .transcriptionSucceeded:
            logger.info("Transcription succeeded")
        case .transcriptionFailed(let category):
            logger.error("Transcription failed: \(category, privacy: .public)")
        case .postProcessingFailed(let category):
            logger.error("Dictation post-processing failed: \(category, privacy: .public)")
        case .outputDeliveryFailed(let category):
            logger.error("Output delivery failed: \(category, privacy: .public)")
        case .recordingCacheHandled(let policy):
            logger.info("Recording cache handled: \(policy.logName, privacy: .public)")
        case .recordingCacheFailed(let category):
            logger.error("Recording cache failed: \(category, privacy: .public)")
        case .recordingTerminal(let cause, let attemptID, let durability, let providerAuthorized):
            logger.info(
                "Recording terminal: cause \(cause.rawValue, privacy: .public), attempt \(compactRecordingAttemptID(attemptID), privacy: .public), durability \(durability.rawValue, privacy: .public), provider authorized \(providerAuthorized, privacy: .public)"
            )
        }

        runtimeLogRecorder.record(event.runtimeDiagnosticEvent)
    }
}

private extension DictationLogEvent {
    var runtimeDiagnosticEvent: RuntimeDiagnosticEvent {
        switch self {
        case .hotkeyEvent(let action, let intent):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "hotkey_event",
                fields: [
                    "action": action.logName,
                    "intent": intent.logName,
                ]
            )
        case .hotkeyStopDeferred:
            return RuntimeDiagnosticEvent(category: "dictation", name: "hotkey_stop_deferred")
        case .hotkeyStopReplayed:
            return RuntimeDiagnosticEvent(category: "dictation", name: "hotkey_stop_replayed")
        case .recordingStartRequested:
            return RuntimeDiagnosticEvent(category: "dictation", name: "recording_start_requested")
        case .recordingStarted:
            return RuntimeDiagnosticEvent(category: "dictation", name: "recording_started")
        case .recordingStartFailed(let category):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_start_failed",
                severity: .error,
                fields: ["error_category": category]
            )
        case .recordingStopRequested:
            return RuntimeDiagnosticEvent(category: "dictation", name: "recording_stop_requested")
        case .recordingStopTailStarted(let duration):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_stop_tail_started",
                fields: ["duration_seconds": Self.durationLogValue(duration)]
            )
        case .recordingStopTailFinished(let duration):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_stop_tail_finished",
                fields: ["duration_seconds": Self.durationLogValue(duration)]
            )
        case .recordingLimitReached:
            return RuntimeDiagnosticEvent(category: "dictation", name: "recording_limit_reached")
        case .recordingEndedUnexpectedly(let recorderReportedSuccess):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_ended_unexpectedly",
                severity: .error,
                fields: ["recorder_reported_success": String(recorderReportedSuccess)]
            )
        case .recordingStopped(let duration, let byteCount):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_stopped",
                fields: [
                    "byte_count": String(byteCount),
                    "duration_seconds": Self.durationLogValue(duration),
                ]
            )
        case .recordingStopFailed(let category):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_stop_failed",
                severity: .error,
                fields: ["error_category": category]
            )
        case .transcriptionStarted:
            return RuntimeDiagnosticEvent(category: "dictation", name: "transcription_started")
        case .transcriptionSucceeded:
            return RuntimeDiagnosticEvent(category: "dictation", name: "transcription_succeeded")
        case .transcriptionFailed(let category):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "transcription_failed",
                severity: .error,
                fields: ["error_category": category]
            )
        case .postProcessingFailed(let category):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "post_processing_failed",
                severity: .error,
                fields: ["error_category": category]
            )
        case .outputDeliveryFailed(let category):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "output_delivery_failed",
                severity: .error,
                fields: ["error_category": category]
            )
        case .recordingCacheHandled(let policy):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_cache_handled",
                fields: ["policy": policy.logName]
            )
        case .recordingCacheFailed(let category):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_cache_failed",
                severity: .error,
                fields: ["error_category": category]
            )
        case .recordingTerminal(let cause, let attemptID, let durability, let providerAuthorized):
            return RuntimeDiagnosticEvent(
                category: "dictation",
                name: "recording_terminal",
                fields: [
                    "attempt_id": compactRecordingAttemptID(attemptID),
                    "durability": durability.rawValue,
                    "provider_authorized": String(providerAuthorized),
                    "terminal_cause": cause.rawValue,
                ]
            )
        }
    }

    private static func durationLogValue(_ duration: TimeInterval) -> String {
        String(format: "%.3f", locale: Locale(identifier: "en_US_POSIX"), duration)
    }
}

private func compactRecordingAttemptID(_ attemptID: UUID) -> String {
    String(attemptID.uuidString.lowercased().prefix(8))
}

private extension GlobalHotkeyAction {
    var logName: String {
        switch self {
        case .keyDown:
            return "key_down"
        case .keyUp:
            return "key_up"
        case .outputIntentChanged:
            return "output_intent_changed"
        }
    }
}

private extension DictationOutputIntent {
    var logName: String {
        switch self {
        case .standard:
            return "standard"
        case .translate:
            return "translate"
        }
    }
}

private extension RecordingCachePolicy {
    var logName: String {
        switch normalized {
        case .deleteImmediately:
            return "delete_immediately"
        case .keepLast(let count):
            return "keep_last_\(count)"
        case .unlimited:
            return "unlimited"
        }
    }
}
