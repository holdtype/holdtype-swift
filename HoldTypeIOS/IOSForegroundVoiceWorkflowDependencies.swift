import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence

/// All effects used by the process Voice owner. No closure has a permissive
/// default: production composition must deliberately supply every boundary.
struct IOSForegroundVoiceWorkflowDependencies {
    typealias ObserveCapture = @Sendable () async ->
        IOSV1ForegroundVoiceCaptureRecoveryObservation
    typealias RepairOrphanedCapture = @Sendable () async ->
        IOSV1ForegroundVoiceCaptureRecoveryObservation?
    typealias RepairInterruptedCapture = @Sendable () async ->
        IOSV1ForegroundVoiceCaptureRecoveryObservation?
    typealias RecoverLifecycle = @Sendable (
        IOSV1ContainingAppRecoveryOpportunity
    ) async -> IOSV1ContainingAppRecoveryDisposition
    typealias LoadPending = @Sendable () async throws ->
        IOSV1PendingRecordingObservation?
    typealias LoadLatest = @Sendable () async throws ->
        IOSV1ForegroundVoiceLatestResultObservation
    typealias LoadSettings = @Sendable () async throws -> IOSAppSettings
    typealias LoadLibrary = @Sendable () async throws -> IOSLibraryContent
    typealias ObserveConsent = @Sendable () async ->
        IOSV1ProviderConsentObservation
    typealias ContinueConsent = @MainActor @Sendable (
        IOSVoiceSceneStartLease,
        IOSV1ProviderConsentObservation
    ) async -> IOSV1ProviderConsentObservation?
    typealias RevalidateConsent = @Sendable (
        IOSV1ProviderConsentObservation
    ) async -> Bool
    typealias ResolveCredential = @Sendable () async ->
        IOSForegroundVoiceWorkflowCredentialResolution
    typealias RevalidateCredential = @Sendable (
        IOSForegroundVoiceWorkflowCredentialProof
    ) async -> Bool
    typealias StopHistoryPlayback = @Sendable () async -> Bool
    typealias PrepareDraftForNewDictation = @MainActor @Sendable () async -> Bool
    typealias ActivateAudio = @MainActor @Sendable () throws ->
        IOSForegroundVoiceWorkflowAudioLease
    typealias PlayStartBoundary = @MainActor @Sendable (
        Bool
    ) async -> Bool
    typealias PlayStopBoundary = @MainActor @Sendable (Bool) async -> Void
    typealias BeginKeyboardWarmInput = @MainActor @Sendable () throws -> Void
    typealias EndKeyboardWarmInput = @MainActor @Sendable () -> Void
    typealias MakeRecording = @MainActor @Sendable (
        UUID,
        DictationOutputIntent,
        IOSVoiceDraftInsertionMode,
        Bool,
        RecordingDurationLimit
    ) async throws -> IOSForegroundVoiceWorkflowRecording
    typealias BeginFinalization = @MainActor @Sendable (
        @escaping @MainActor @Sendable () -> Void
    ) -> IOSForegroundVoiceWorkflowFinalizationLease?
    typealias Process = @Sendable (
        IOSForegroundVoiceWorkflowProcessingRequest,
        @escaping IOSForegroundVoiceProcessingProgressHandler
    ) async -> IOSForegroundVoiceProcessingResolution
    typealias RecoverCapture = @Sendable (
        UUID,
        TranscriptionConfiguration
    ) async throws -> IOSV1PendingRecording
    typealias RecoverCompletedCapture = @Sendable (
        IOSV1CompletedCaptureRecoveryExpectation,
        TranscriptionConfiguration
    ) async throws -> IOSV1PendingRecording
    typealias DiscardCapture = @Sendable (UUID) async throws -> Void
    typealias DiscardPending = @Sendable (
        IOSV1PendingRecordingExpectation
    ) async throws -> IOSV1PendingRecordingDiscardResult
    typealias Sleep = @Sendable (Duration) async throws -> Void
    typealias RecordDiagnostic = @Sendable (
        IOSRuntimeDiagnosticEvent
    ) -> Void

    let sceneRegistry: IOSVoiceSceneRegistry
    let repairOrphanedCaptureAtProcessLaunch: RepairOrphanedCapture
    let repairInterruptedCaptureAfterRecorderStops:
        RepairInterruptedCapture
    let reconcileCaptureSources: ObserveCapture
    let recoverContainingAppLifecycle: RecoverLifecycle
    let loadPending: LoadPending
    let loadLatest: LoadLatest
    let loadSettings: LoadSettings
    let loadLibrary: LoadLibrary
    let observeConsent: ObserveConsent
    let continueConsent: ContinueConsent
    let revalidateConsent: RevalidateConsent
    let resolveCredential: ResolveCredential
    let revalidateCredential: RevalidateCredential
    let permission: IOSForegroundVoiceWorkflowPermissionClient
    let stopHistoryPlayback: StopHistoryPlayback
    let prepareDraftForNewDictation: PrepareDraftForNewDictation
    let activateAudio: ActivateAudio
    let playStartBoundary: PlayStartBoundary
    let cancelStartBoundary: @MainActor @Sendable () -> Void
    let playStopBoundary: PlayStopBoundary
    let beginKeyboardWarmInput: BeginKeyboardWarmInput
    let endKeyboardWarmInput: EndKeyboardWarmInput
    let makeRecording: MakeRecording
    let beginFinalization: BeginFinalization
    let process: Process
    let recoverCapture: RecoverCapture
    let recoverCompletedCapture: RecoverCompletedCapture
    let discardCapture: DiscardCapture
    let discardPending: DiscardPending
    let sleep: Sleep
    let makeUUID: @Sendable () -> UUID
    let recordDiagnostic: RecordDiagnostic
}
extension IOSForegroundVoiceWorkflowDependencies:
    IOSForegroundVoiceRedactedValue {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowDependencies(<redacted>)"
    }
}
