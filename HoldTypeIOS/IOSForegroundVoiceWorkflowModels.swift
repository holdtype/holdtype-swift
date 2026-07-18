import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence

/// Explicit scene-bound input for Start. The shared controller/client seam does
/// not yet carry this value, so production integration must extend that seam;
/// this workflow never substitutes a process-global "last scene" slot.
nonisolated struct IOSForegroundVoiceWorkflowStartRequest: Sendable {
    let outputIntent: DictationOutputIntent
    let sceneLease: IOSVoiceSceneStartLease
    let forcesTextCorrection: Bool
    let clearsDraftOnStart: Bool
    let draftInsertionMode: IOSVoiceDraftInsertionMode

    init(
        outputIntent: DictationOutputIntent,
        sceneLease: IOSVoiceSceneStartLease,
        forcesTextCorrection: Bool = false,
        clearsDraftOnStart: Bool = false,
        draftInsertionMode: IOSVoiceDraftInsertionMode = .replace
    ) {
        self.outputIntent = outputIntent
        self.sceneLease = sceneLease
        self.forcesTextCorrection = forcesTextCorrection
        self.clearsDraftOnStart = clearsDraftOnStart
        self.draftInsertionMode = draftInsertionMode
    }
}

nonisolated struct IOSForegroundVoiceWorkflowAttemptToken:
    Equatable,
    Hashable,
    Sendable {
    fileprivate let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// One frozen local snapshot used by a provider-capable Voice operation.
nonisolated struct IOSForegroundVoiceWorkflowConfiguration: Sendable {
    let settings: IOSAppSettings
    let library: IOSLibraryContent
}

nonisolated struct IOSForegroundVoiceWorkflowCredentialProof:
    Equatable,
    Hashable,
    Sendable {
    fileprivate let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

nonisolated enum IOSForegroundVoiceWorkflowCredentialResolution: Sendable {
    case available(IOSForegroundVoiceWorkflowCredentialProof)
    case needsSetup
    case unavailable
}

nonisolated enum IOSForegroundVoiceWorkflowPermissionOutcome:
    Equatable,
    Sendable {
    case granted
    case denied
    case unavailable
    case timedOut
    case cancelled
}

nonisolated struct IOSForegroundVoiceWorkflowPermissionClient: Sendable {
    let read: @MainActor @Sendable () -> IOSMicrophonePermissionStatus
    let requestIfUndetermined: @MainActor @Sendable () async ->
        IOSForegroundVoiceWorkflowPermissionOutcome
}

nonisolated struct IOSForegroundVoiceWorkflowProcessingRequest: Sendable {
    let pendingRecording: IOSV1PendingRecording
    let mode: IOSForegroundVoiceProcessingMode
    let configuration: IOSForegroundVoiceWorkflowConfiguration
    let credential: IOSForegroundVoiceWorkflowCredentialProof?
    let consentObservation: IOSV1ProviderConsentObservation?
    let forcesTextCorrection: Bool
    let draftInsertionMode: IOSVoiceDraftInsertionMode
    let cancellationAuthority:
        IOSForegroundVoiceProcessingCancellationAuthority

    init(
        pendingRecording: IOSV1PendingRecording,
        mode: IOSForegroundVoiceProcessingMode,
        configuration: IOSForegroundVoiceWorkflowConfiguration,
        credential: IOSForegroundVoiceWorkflowCredentialProof?,
        consentObservation: IOSV1ProviderConsentObservation?,
        forcesTextCorrection: Bool = false,
        draftInsertionMode: IOSVoiceDraftInsertionMode = .replace,
        cancellationAuthority:
            IOSForegroundVoiceProcessingCancellationAuthority = .init()
    ) {
        self.pendingRecording = pendingRecording
        self.mode = mode
        self.configuration = configuration
        self.credential = credential
        self.consentObservation = consentObservation
        self.forcesTextCorrection = forcesTextCorrection
        self.draftInsertionMode = draftInsertionMode
        self.cancellationAuthority = cancellationAuthority
    }
}

nonisolated struct IOSForegroundVoiceWorkflowDurableObservation: Sendable {
    let capture: IOSV1ForegroundVoiceCaptureRecoveryObservation
    let pending: IOSV1PendingRecordingObservation?
}

nonisolated enum IOSKeyboardDictationWorkflowProgress: Equatable, Sendable {
    case listening(RecordingDurationLimit)
    case processing
}

nonisolated enum IOSKeyboardDictationWorkflowResolution: Equatable, Sendable {
    case accepted(String)
    case interruptedSaved
    case transcriptionUncertainSaved
    case cancelled
    case failed
}

nonisolated struct IOSKeyboardDictationWorkflowClient: Sendable {
    typealias Progress = @MainActor @Sendable (
        IOSKeyboardDictationWorkflowProgress
    ) -> Void

    let run: @Sendable (
        UUID,
        KeyboardVoiceAction,
        @escaping Progress
    ) async -> IOSKeyboardDictationWorkflowResolution
    let finish: @MainActor @Sendable (UUID) -> Bool
    let cancel: @MainActor @Sendable (UUID) -> Bool
    let interrupt: @MainActor @Sendable (UUID) -> Bool
    let stopSession: @MainActor @Sendable (UUID?) -> Void
    let ownsRetainedCapture: @MainActor @Sendable (UUID) -> Bool
    let endWarmSession: @MainActor @Sendable () -> Void
    let loadTranslationAvailability: @Sendable () async -> Bool

    init(
        run: @escaping @Sendable (
            UUID,
            KeyboardVoiceAction,
            @escaping Progress
        ) async -> IOSKeyboardDictationWorkflowResolution,
        finish: @escaping @MainActor @Sendable (UUID) -> Bool,
        cancel: @escaping @MainActor @Sendable (UUID) -> Bool,
        interrupt: @escaping @MainActor @Sendable (UUID) -> Bool = {
            _ in false
        },
        stopSession: @escaping @MainActor @Sendable (UUID?) -> Void = {
            _ in
        },
        ownsRetainedCapture: @escaping @MainActor @Sendable (UUID) -> Bool = {
            _ in false
        },
        endWarmSession: @escaping @MainActor @Sendable () -> Void = {},
        loadTranslationAvailability: @escaping @Sendable () async -> Bool = {
            false
        }
    ) {
        self.run = run
        self.finish = finish
        self.cancel = cancel
        self.interrupt = interrupt
        self.stopSession = stopSession
        self.ownsRetainedCapture = ownsRetainedCapture
        self.endWarmSession = endWarmSession
        self.loadTranslationAvailability = loadTranslationAvailability
    }
}

/// Provider-capable action used by Saved Recording surfaces. It reuses the
/// process-owned workflow and Pending exact-once machinery without publishing
/// recovery progress through the ordinary Voice controller.
nonisolated struct IOSSavedRecordingWorkflowClient: Sendable {
    typealias Retry = @Sendable (
        IOSV1SavedRecordingExpectation
    ) async -> Bool

    private let retryAction: Retry

    init(retry: @escaping Retry) {
        retryAction = retry
    }

    func retry(
        expected: IOSV1SavedRecordingExpectation
    ) async -> Bool {
        await retryAction(expected)
    }
}

nonisolated enum IOSForegroundVoiceWorkflowCaptureStopReason:
    Equatable,
    Sendable {
    case done
    case cancelled
    case interrupted
    case maximumDuration
}

extension IOSForegroundVoiceWorkflowStartRequest:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowStartRequest(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceWorkflowAttemptToken:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowAttemptToken(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceWorkflowConfiguration:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowConfiguration(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceWorkflowCredentialProof:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowCredentialProof(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceWorkflowProcessingRequest:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowProcessingRequest(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
