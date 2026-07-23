nonisolated extension IOSRuntimeDiagnosticEvent {
    var category: String {
        switch self {
        case .appLaunched, .scenePhase:
            "lifecycle"
        case .voiceStartRequested, .voiceRecordingStarted,
             .voiceStopRequested, .voiceStopResolved, .voiceCompleted:
            "voice"
        case .audio:
            "audio"
        case .providerStarted, .providerCompleted:
            "provider"
        case .keyboardState, .keyboardCommand, .keyboardInsertInvoked,
             .keyboardDelivery:
            "keyboard"
        case .textFix:
            "text_fix"
        case .diagnosticsExported, .metricDiagnosticsReceived:
            "diagnostics"
        }
    }

    var name: String {
        switch self {
        case .appLaunched:
            "app_launched"
        case .scenePhase:
            "scene_phase_changed"
        case .voiceStartRequested:
            "voice_start_requested"
        case .voiceRecordingStarted:
            "voice_recording_started"
        case .voiceStopRequested:
            "voice_stop_requested"
        case .voiceStopResolved:
            "voice_stop_resolved"
        case .voiceCompleted:
            "voice_completed"
        case .audio:
            "audio_session_event"
        case .providerStarted:
            "provider_started"
        case .providerCompleted:
            "provider_completed"
        case .keyboardState:
            "keyboard_state_changed"
        case .keyboardCommand:
            "keyboard_command"
        case .keyboardInsertInvoked:
            "keyboard_insert_invoked"
        case .keyboardDelivery:
            "keyboard_delivery"
        case .textFix:
            "text_fix"
        case .diagnosticsExported:
            "diagnostic_export"
        case .metricDiagnosticsReceived:
            "metric_diagnostics_received"
        }
    }

    var severity: IOSDiagnosticSeverity {
        switch self {
        case .voiceCompleted(.failed), .voiceCompleted(.unavailable),
             .audio(.activationFailed), .audio(.inputInvalid),
             .providerCompleted(.failed), .providerCompleted(.unavailable),
             .keyboardState(.failed),
             .keyboardCommand(_, _, .failed),
             .keyboardCommand(_, _, .unavailable),
             .textFix(_, _, _, .failed),
             .textFix(_, _, _, .blocked),
             .textFix(_, _, _, .busy),
             .textFix(_, _, _, .unavailable),
             .textFix(_, _, _, .timedOut),
             .textFix(_, _, _, .stale),
             .textFix(_, _, _, .expired),
             .textFix(_, _, _, .bridgeUnavailable),
             .diagnosticsExported(.failed):
            .error
        default:
            .info
        }
    }

    var fields: [String] {
        switch self {
        case .appLaunched:
            []
        case .scenePhase(let phase):
            ["phase=\(phase.rawValue)"]
        case .voiceStartRequested(let origin, let action):
            ["origin=\(origin.rawValue)", "action=\(action.rawValue)"]
        case .voiceRecordingStarted(let origin):
            ["origin=\(origin.rawValue)"]
        case .voiceStopRequested(let reason):
            ["reason=\(reason.rawValue)"]
        case .voiceStopResolved(
            let reason,
            let durability,
            let providerAuthority,
            let attempt
        ):
            [
                "reason=\(reason.rawValue)",
                "durability=\(durability.rawValue)",
                "provider_authority=\(providerAuthority.rawValue)",
            ] + (attempt.map { ["attempt_tag=\($0.formatted)"] } ?? [])
        case .voiceCompleted(let outcome),
             .providerCompleted(let outcome),
             .diagnosticsExported(let outcome):
            ["outcome=\(outcome.rawValue)"]
        case .audio(let event):
            ["state=\(event.rawValue)"]
        case .providerStarted(let mode):
            ["mode=\(mode.rawValue)"]
        case .keyboardState(let state):
            ["state=\(state.rawValue)"]
        case .keyboardCommand(let command, let action, let outcome):
            [
                "command=\(command.rawValue)",
                "action=\(action.rawValue)",
                "outcome=\(outcome.rawValue)",
            ]
        case .keyboardInsertInvoked(let kind):
            ["kind=\(kind.rawValue)"]
        case .keyboardDelivery(
            let stage,
            let request,
            let claim,
            let sourceDocument,
            let currentDocument,
            let controllerLifetime
        ):
            ["stage=\(stage.rawValue)"]
                + (request.map { ["request_tag=\($0.formatted)"] } ?? [])
                + (claim.map { ["claim_tag=\($0.formatted)"] } ?? [])
                + (sourceDocument.map {
                    ["source_document_tag=\($0.formatted)"]
                } ?? [])
                + (currentDocument.map {
                    ["current_document_tag=\($0.formatted)"]
                } ?? [])
                + (controllerLifetime.map {
                    ["controller_lifetime_tag=\($0.formatted)"]
                } ?? [])
        case .textFix(let stage, let action, let request, let outcome):
            [
                "stage=\(stage.rawValue)",
                "outcome=\(outcome.rawValue)",
            ]
                + (action.map { ["action_tag=\($0.formatted)"] } ?? [])
                + (request.map { ["request_tag=\($0.formatted)"] } ?? [])
        case .metricDiagnosticsReceived(let kind, let count):
            ["kind=\(kind.rawValue)", "count=\(max(0, count))"]
        }
    }
}
