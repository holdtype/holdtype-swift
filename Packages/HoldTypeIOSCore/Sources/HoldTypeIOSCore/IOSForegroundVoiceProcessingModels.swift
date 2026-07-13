import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence

@_spi(HoldTypeIOSCore)
public enum IOSForegroundVoiceProcessingMode: Equatable, Sendable {
    case initial
    case retry
}

/// One frozen provider-processing input assembled by the process-owned voice
/// preflight. It is runtime-only and deliberately redacts its credential,
/// Library content, Pending owner, and consent observation.
@_spi(HoldTypeIOSCore)
public struct IOSForegroundVoiceProcessingRequest: Sendable {
    let sessionID: UUID
    let pendingRecording: IOSPendingRecording
    let mode: IOSForegroundVoiceProcessingMode
    let settings: IOSAppSettings
    let library: IOSLibraryContent
    let credential: IOSResolvedOpenAICredential
    let consentObservation: IOSProviderConsentObservation
    let historyMode: IOSForegroundVoiceHistoryMode

    public init(
        sessionID: UUID,
        pendingRecording: IOSPendingRecording,
        mode: IOSForegroundVoiceProcessingMode,
        settings: IOSAppSettings,
        library: IOSLibraryContent,
        credential: IOSResolvedOpenAICredential,
        consentObservation: IOSProviderConsentObservation
    ) {
        self.init(
            sessionID: sessionID,
            pendingRecording: pendingRecording,
            mode: mode,
            settings: settings,
            library: library,
            credential: credential,
            consentObservation: consentObservation,
            historyMode: .appOnly
        )
    }

    public init(
        sessionID: UUID,
        pendingRecording: IOSPendingRecording,
        mode: IOSForegroundVoiceProcessingMode,
        settings: IOSAppSettings,
        library: IOSLibraryContent,
        credential: IOSResolvedOpenAICredential,
        consentObservation: IOSProviderConsentObservation,
        historyMode: IOSForegroundVoiceHistoryMode
    ) {
        self.sessionID = sessionID
        self.pendingRecording = pendingRecording
        self.mode = mode
        self.settings = settings
        self.library = library
        self.credential = credential
        self.consentObservation = consentObservation
        self.historyMode = historyMode
    }
}

/// Fresh provider authority supplied only by an explicit retry. The value is
/// runtime-only and deliberately redacts both the credential and consent
/// observation.
@_spi(HoldTypeIOSCore)
public struct IOSForegroundVoiceProviderRetryAuthorization: Sendable {
    let credential: IOSResolvedOpenAICredential
    let consentObservation: IOSProviderConsentObservation

    public init(
        credential: IOSResolvedOpenAICredential,
        consentObservation: IOSProviderConsentObservation
    ) {
        self.credential = credential
        self.consentObservation = consentObservation
    }
}

@_spi(HoldTypeIOSCore)
public enum IOSForegroundVoiceProcessingFailure: Equatable, Sendable {
    case invalidConfiguration
    case providerConsentUnavailable
    case credentialRejected
    case networkUnavailable
    case networkFailure
    case timedOut
    case providerUnavailable
    case invalidRecording
    case invalidResponse
    case cancelled
    case localPersistence
}

/// Ordered, payload-free foreground progress. The callback always runs on the
/// main actor so UI owners can consume it without introducing another hop.
@_spi(HoldTypeIOSCore)
public typealias IOSForegroundVoiceProcessingProgressHandler =
    @MainActor @Sendable (VoiceAttemptStage) -> Void

/// Payload-free guidance for a local-only retry surface.
@_spi(HoldTypeIOSCore)
public enum IOSForegroundVoiceLocalRecoveryDisposition:
    Equatable,
    Sendable {
    case processingCheckpoint
    case savingResult
}

/// Payload-free authority requirement for one retained local checkpoint.
@_spi(HoldTypeIOSCore)
public enum IOSForegroundVoiceLocalRecoveryRequirement:
    Equatable,
    Sendable {
    case currentProviderAuthority
    case providerFree
}

/// Redacted orchestration result. Provider text and credentials never cross
/// this boundary; accepted text appears only through the existing P4B record.
@_spi(HoldTypeIOSCore)
public enum IOSForegroundVoiceProcessingResolution: Equatable, Sendable {
    case notStarted(IOSForegroundVoiceProcessingFailure)
    case acceptance(IOSForegroundVoiceAcceptanceResult)
    case awaitingRecovery(
        IOSPendingRecording,
        failure: IOSForegroundVoiceProcessingFailure,
        stage: VoiceAttemptStage
    )
    case localRecoveryPending(
        failure: IOSForegroundVoiceProcessingFailure,
        stage: VoiceAttemptStage,
        disposition: IOSForegroundVoiceLocalRecoveryDisposition,
        requirement: IOSForegroundVoiceLocalRecoveryRequirement
    )
    case busy
}

extension IOSForegroundVoiceProcessingMode:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceProcessingMode(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceProcessingRequest:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceProcessingRequest(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceProviderRetryAuthorization:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceProviderRetryAuthorization(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceProcessingFailure:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceProcessingFailure(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceLocalRecoveryDisposition:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceLocalRecoveryDisposition(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceLocalRecoveryRequirement:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceLocalRecoveryRequirement(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceProcessingResolution:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSForegroundVoiceProcessingResolution(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
