import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence

@_spi(HoldTypeIOSCore)
public enum IOSForegroundVoiceProcessingMode: Equatable, Sendable {
    case initial
    case retry
}

/// One exact provider chain's explicit user-cancellation signal. Generic task
/// cancellation deliberately does not set this bit: only an admitted
/// `Cancel Processing` action may revoke late-result authority. Dispatch
/// evidence still decides whether the retained audio is ordinarily retryable.
@_spi(HoldTypeIOSCore)
public final class IOSForegroundVoiceProcessingCancellationAuthority:
    @unchecked Sendable {
    private let lock = NSLock()
    private var explicitlyCancelled = false

    public init() {}

    public var isExplicitlyCancelled: Bool {
        lock.withLock { explicitlyCancelled }
    }

    public func cancelExplicitly() {
        lock.withLock { explicitlyCancelled = true }
    }
}

/// One frozen provider-processing input assembled by the process-owned voice
/// preflight. It is runtime-only and deliberately redacts its credential,
/// Library content, Pending owner, and consent observation.
@_spi(HoldTypeIOSCore)
public struct IOSForegroundVoiceProcessingRequest: Sendable {
    let pendingRecording: IOSV1PendingRecording
    let mode: IOSForegroundVoiceProcessingMode
    let settings: IOSAppSettings
    let library: IOSLibraryContent
    let credential: IOSResolvedOpenAICredential?
    let consentObservation: IOSV1ProviderConsentObservation?
    let forcesTextCorrection: Bool
    let cancellationAuthority:
        IOSForegroundVoiceProcessingCancellationAuthority

    public init(
        pendingRecording: IOSV1PendingRecording,
        mode: IOSForegroundVoiceProcessingMode,
        settings: IOSAppSettings,
        library: IOSLibraryContent,
        credential: IOSResolvedOpenAICredential?,
        consentObservation: IOSV1ProviderConsentObservation?,
        forcesTextCorrection: Bool = false,
        cancellationAuthority:
            IOSForegroundVoiceProcessingCancellationAuthority = .init()
    ) {
        self.pendingRecording = pendingRecording
        self.mode = mode
        self.settings = settings
        self.library = library
        self.credential = credential
        self.consentObservation = consentObservation
        self.forcesTextCorrection = forcesTextCorrection
        self.cancellationAuthority = cancellationAuthority
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

/// Redacted orchestration result. Provider text and credentials never cross
/// this boundary; accepted text appears only through Latest Result.
@_spi(HoldTypeIOSCore)
public enum IOSForegroundVoiceProcessingResolution: Equatable, Sendable {
    case notStarted(IOSForegroundVoiceProcessingFailure)
    case acceptance(IOSV1ForegroundVoiceAcceptanceResult)
    case retryAvailable(
        IOSV1PendingRecording,
        failure: IOSForegroundVoiceProcessingFailure,
        stage: VoiceAttemptStage
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

@_spi(HoldTypeIOSCore)
public enum IOSVoiceDraftTextAction: Equatable, Sendable {
    case translate
    case correct
}

@_spi(HoldTypeIOSCore)
public enum IOSVoiceDraftTextActionFailure: Equatable, Sendable {
    case busy
    case invalidText
    case sourceTooLarge
    case invalidConfiguration
    case credentialUnavailable
    case consentUnavailable
    case networkUnavailable
    case timedOut
    case providerUnavailable
    case invalidResponse
    case draftChanged
    case saveFailed
    case cancelled
}

@_spi(HoldTypeIOSCore)
public enum IOSVoiceDraftTextActionResolution: Equatable, Sendable {
    case success(String)
    case failure(IOSVoiceDraftTextActionFailure)
}

@_spi(HoldTypeIOSCore)
public struct IOSVoiceDraftTextActionRequest: Sendable {
    public let action: IOSVoiceDraftTextAction
    public let text: String
    public let settings: IOSAppSettings
    public let credential: IOSResolvedOpenAICredential
    public let consentObservation: IOSV1ProviderConsentObservation

    public init(
        action: IOSVoiceDraftTextAction,
        text: String,
        settings: IOSAppSettings,
        credential: IOSResolvedOpenAICredential,
        consentObservation: IOSV1ProviderConsentObservation
    ) {
        self.action = action
        self.text = text
        self.settings = settings
        self.credential = credential
        self.consentObservation = consentObservation
    }
}

extension IOSVoiceDraftTextActionRequest:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSVoiceDraftTextActionRequest(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// One validated catalog action applied to an existing app-private Voice Draft.
@_spi(HoldTypeIOSCore)
public struct IOSVoiceDraftTextFixRequest: Sendable {
    public let action: TextFixAction
    public let text: String
    public let settings: IOSAppSettings
    public let credential: IOSResolvedOpenAICredential
    public let consentObservation: IOSV1ProviderConsentObservation

    public init(
        action: TextFixAction,
        text: String,
        settings: IOSAppSettings,
        credential: IOSResolvedOpenAICredential,
        consentObservation: IOSV1ProviderConsentObservation
    ) {
        self.action = action
        self.text = text
        self.settings = settings
        self.credential = credential
        self.consentObservation = consentObservation
    }
}

extension IOSVoiceDraftTextFixRequest:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "IOSVoiceDraftTextFixRequest(redacted)"
    }

    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
