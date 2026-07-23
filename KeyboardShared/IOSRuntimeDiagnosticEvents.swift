import Foundation

nonisolated enum IOSDiagnosticProcess: String, Sendable {
    case app
    case keyboard
}

nonisolated enum IOSDiagnosticSeverity: String, Sendable {
    case info
    case error
}

nonisolated enum IOSDiagnosticScenePhase: String, Sendable {
    case active
    case inactive
    case background
}

nonisolated enum IOSDiagnosticVoiceOrigin: String, Sendable {
    case foreground
    case keyboard
}

nonisolated enum IOSDiagnosticVoiceAction: String, Sendable {
    case standard
    case translate
    case improve
    case translateAndImprove = "translate_and_improve"
}

nonisolated enum IOSDiagnosticVoiceStopReason: String, Sendable {
    case done
    case cancelled
    case interrupted
    case maximumDuration = "maximum_duration"
}

nonisolated enum IOSDiagnosticVoiceDurability: String, Sendable {
    case none
    case recoverableCapture = "recoverable_capture"
    case discardOnlyCapture = "discard_only_capture"
    case pendingRecording = "pending_recording"
    case blocked
}

nonisolated enum IOSDiagnosticProviderAuthority: String, Sendable {
    case granted
    case absent
}

nonisolated enum IOSDiagnosticProviderMode: String, Sendable {
    case initial
    case retry
}

nonisolated enum IOSDiagnosticOutcome: String, Sendable {
    case succeeded
    case failed
    case unavailable
    case cancelled
    case timedOut = "timed_out"
    case stale
}

nonisolated enum IOSDiagnosticAudioEvent: String, Sendable {
    case activationStarted = "activation_started"
    case activated
    case activationFailed = "activation_failed"
    case inputValidated = "input_validated"
    case inputInvalid = "input_invalid"
    case interrupted
    case deactivated
}

nonisolated enum IOSDiagnosticKeyboardState: String, Sendable {
    case opened
    case closed
    case noSharedAccess = "no_shared_access"
    case sessionReady = "session_ready"
    case sessionUnavailable = "session_unavailable"
    case listening
    case processing
    case resultReady = "result_ready"
    case failed
    case expired
}

nonisolated enum IOSDiagnosticKeyboardCommand: String, Sendable {
    case start
    case finish
    case cancel
    case claimDelivery = "claim_delivery"
    case acknowledgeDelivery = "acknowledge_delivery"
}

nonisolated enum IOSDiagnosticInsertionKind: String, Sendable {
    case latest
    case dictation
}

nonisolated enum IOSDiagnosticKeyboardDeliveryStage: String, Sendable {
    case resultObserved = "result_observed"
    case requestRejected = "request_rejected"
    case documentMissing = "document_missing"
    case documentMismatch = "document_mismatch"
    case documentMatched = "document_matched"
    case controllerInactive = "controller_inactive"
    case controllerLifetimeLost = "controller_lifetime_lost"
    case deliveryPreviouslyDisqualified = "delivery_previously_disqualified"
    case claimRequested = "claim_requested"
    case grantAccepted = "grant_accepted"
    case grantRejected = "grant_rejected"
    case insertInvoked = "insert_invoked"
    case insertReturned = "insert_returned"
    case textWillChange = "text_will_change"
    case textDidChange = "text_did_change"
    case textChangeNotObserved = "text_change_not_observed"
    case acknowledgementRequested = "acknowledgement_requested"
}

nonisolated enum IOSDiagnosticTextFixStage: String, Sendable {
    case eligibility
    case request
    case processing
    case provider
    case result
    case target
    case output
    case launch
    case cancellation
}

nonisolated enum IOSDiagnosticTextFixOutcome: String, Sendable {
    case started
    case succeeded
    case failed
    case blocked
    case busy
    case unavailable
    case timedOut = "timed_out"
    case cancelled
    case stale
    case expired
    case bridgeUnavailable = "bridge_unavailable"
    case acknowledged
}

/// A stable, content-free tag that correlates one opaque bridge UUID across
/// the app and keyboard logs without exporting the UUID itself.
nonisolated struct IOSDiagnosticCorrelationTag: Equatable, Sendable {
    let value: UInt32

    init(_ identifier: UUID) {
        value = iosDiagnosticStableTag(identifier.uuidString)
    }

    var formatted: String {
        String(value, radix: 16, uppercase: false)
    }
}

/// A stable, content-free projection of a built-in or custom Fix identifier.
/// The source identifier is never retained by the diagnostic value.
nonisolated struct IOSDiagnosticActionTag: Equatable, Sendable {
    let value: UInt32

    init(_ identifier: String) {
        value = iosDiagnosticStableTag(identifier)
    }

    var formatted: String {
        String(value, radix: 16, uppercase: false)
    }
}

nonisolated enum IOSDiagnosticMetricKind: String, Sendable {
    case crash
    case hang
    case cpuException = "cpu_exception"
    case diskWrite = "disk_write"
}

/// Closed, content-free event vocabulary shared by the iOS app and keyboard.
/// Callers cannot attach arbitrary strings, paths, text, prompts, or payloads.
nonisolated enum IOSRuntimeDiagnosticEvent: Sendable {
    case appLaunched
    case scenePhase(IOSDiagnosticScenePhase)
    case voiceStartRequested(
        origin: IOSDiagnosticVoiceOrigin,
        action: IOSDiagnosticVoiceAction
    )
    case voiceRecordingStarted(origin: IOSDiagnosticVoiceOrigin)
    case voiceStopRequested(IOSDiagnosticVoiceStopReason)
    case voiceStopResolved(
        reason: IOSDiagnosticVoiceStopReason,
        durability: IOSDiagnosticVoiceDurability,
        providerAuthority: IOSDiagnosticProviderAuthority,
        attempt: IOSDiagnosticCorrelationTag?
    )
    case voiceCompleted(IOSDiagnosticOutcome)
    case audio(IOSDiagnosticAudioEvent)
    case providerStarted(IOSDiagnosticProviderMode)
    case providerCompleted(IOSDiagnosticOutcome)
    case keyboardState(IOSDiagnosticKeyboardState)
    case keyboardCommand(
        IOSDiagnosticKeyboardCommand,
        action: IOSDiagnosticVoiceAction,
        outcome: IOSDiagnosticOutcome
    )
    case keyboardInsertInvoked(IOSDiagnosticInsertionKind)
    case keyboardDelivery(
        IOSDiagnosticKeyboardDeliveryStage,
        request: IOSDiagnosticCorrelationTag?,
        claim: IOSDiagnosticCorrelationTag?,
        sourceDocument: IOSDiagnosticCorrelationTag?,
        currentDocument: IOSDiagnosticCorrelationTag?,
        controllerLifetime: IOSDiagnosticCorrelationTag?
    )
    case textFix(
        IOSDiagnosticTextFixStage,
        action: IOSDiagnosticActionTag?,
        request: IOSDiagnosticCorrelationTag?,
        outcome: IOSDiagnosticTextFixOutcome
    )
    case diagnosticsExported(IOSDiagnosticOutcome)
    case metricDiagnosticsReceived(IOSDiagnosticMetricKind, count: Int)
}

private nonisolated func iosDiagnosticStableTag(_ value: String) -> UInt32 {
    var hash: UInt32 = 2_166_136_261
    for byte in value.utf8 {
        hash ^= UInt32(byte)
        hash &*= 16_777_619
    }
    return hash
}
