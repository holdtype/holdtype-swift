import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence

/// Cancels one process observation without exposing its platform identity.
@MainActor
final class IOSForegroundVoiceWorkflowObservation {
    private var cancelAction: (@MainActor @Sendable () -> Void)?

    init(cancel: @escaping @MainActor @Sendable () -> Void) {
        cancelAction = cancel
    }

    func cancel() {
        let action = cancelAction
        cancelAction = nil
        action?()
    }

    deinit {
        MainActor.assumeIsolated {
            cancelAction?()
            cancelAction = nil
        }
    }
}

/// Explicit scene-bound input for Start. The shared controller/client seam does
/// not yet carry this value, so production integration must extend that seam;
/// this workflow never substitutes a process-global "last scene" slot.
nonisolated struct IOSForegroundVoiceWorkflowStartRequest: Sendable {
    let outputIntent: DictationOutputIntent
    let sceneLease: IOSVoiceSceneStartLease
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
    let sessionID: UUID
    let pendingRecording: IOSPendingRecording
    let mode: IOSForegroundVoiceProcessingMode
    let configuration: IOSForegroundVoiceWorkflowConfiguration
    let credential: IOSForegroundVoiceWorkflowCredentialProof
    let consentObservation: IOSProviderConsentObservation
}

nonisolated struct IOSForegroundVoiceWorkflowDurableObservation: Sendable {
    let capture: IOSForegroundVoiceCaptureRecoveryObservation
    let pending: IOSPendingRecordingObservation?
    let latest: IOSForegroundVoiceLatestResultObservation
}

nonisolated enum IOSForegroundVoiceWorkflowCaptureStopReason: Sendable {
    case done
    case cancelled
    case interrupted
    case maximumDuration
}

/// Single-use descriptor-bound handoff produced only after recorder close.
/// It exposes no URL, path, descriptor, or reusable capture capability.
@MainActor
final class IOSForegroundVoiceWorkflowCaptureHandoff {
    private let prepareAction: @MainActor @Sendable (
        TranscriptionConfiguration
    ) async throws -> IOSPendingRecording
    private var releaseAction: (@MainActor @Sendable () -> Void)?

    init(
        prepare: @escaping @MainActor @Sendable (
            TranscriptionConfiguration
        ) async throws -> IOSPendingRecording,
        release: @escaping @MainActor @Sendable () -> Void
    ) {
        prepareAction = prepare
        releaseAction = release
    }

    func preparePending(
        transcriptionConfiguration: TranscriptionConfiguration
    ) async throws -> IOSPendingRecording {
        let result = try await prepareAction(transcriptionConfiguration)
        releaseAction = nil
        return result
    }

    func release() {
        let action = releaseAction
        releaseAction = nil
        action?()
    }

    deinit {
        MainActor.assumeIsolated { release() }
    }
}

/// One bounded UIKit background assertion covering only recorder close,
/// descriptor validation, protected copy, and Pending publication.
@MainActor
final class IOSForegroundVoiceWorkflowFinalizationLease {
    private let finishAction: @MainActor @Sendable () -> Void
    private var wasFinished = false

    init(finish: @escaping @MainActor @Sendable () -> Void) {
        finishAction = finish
    }

    func finish() {
        guard !wasFinished else { return }
        wasFinished = true
        finishAction()
    }

    deinit {
        MainActor.assumeIsolated { finish() }
    }
}

nonisolated enum IOSForegroundVoiceWorkflowCaptureStopResult: Sendable {
    case completed(IOSForegroundVoiceWorkflowCaptureHandoff)
    case discarded(IOSForegroundVoiceCaptureInvalidReason)
    case preserved
    case stale
}

/// One live recorder owner. Implementations may wrap AVAudioRecorder, but the
/// workflow sees only descriptor-bound capture truth.
@MainActor
final class IOSForegroundVoiceWorkflowRecording {
    private let startAction: @MainActor @Sendable () async -> Bool
    private let stopAction: @MainActor @Sendable (
        IOSForegroundVoiceWorkflowCaptureStopReason
    ) async -> IOSForegroundVoiceWorkflowCaptureStopResult
    private let isActiveAction: @MainActor @Sendable () -> Bool
    private let observeTerminalAction: @MainActor @Sendable (
        @escaping @MainActor @Sendable (
            IOSForegroundVoiceWorkflowCaptureStopReason
        ) -> Void
    ) -> IOSForegroundVoiceWorkflowObservation

    init(
        start: @escaping @MainActor @Sendable () async -> Bool,
        stop: @escaping @MainActor @Sendable (
            IOSForegroundVoiceWorkflowCaptureStopReason
        ) async -> IOSForegroundVoiceWorkflowCaptureStopResult,
        isActive: @escaping @MainActor @Sendable () -> Bool,
        observeTerminal: @escaping @MainActor @Sendable (
            @escaping @MainActor @Sendable (
                IOSForegroundVoiceWorkflowCaptureStopReason
            ) -> Void
        ) -> IOSForegroundVoiceWorkflowObservation
    ) {
        startAction = start
        stopAction = stop
        isActiveAction = isActive
        observeTerminalAction = observeTerminal
    }

    func start() async -> Bool { await startAction() }

    func stop(
        _ reason: IOSForegroundVoiceWorkflowCaptureStopReason
    ) async -> IOSForegroundVoiceWorkflowCaptureStopResult {
        await stopAction(reason)
    }

    var isActive: Bool { isActiveAction() }

    func observeTerminal(
        _ receive: @escaping @MainActor @Sendable (
            IOSForegroundVoiceWorkflowCaptureStopReason
        ) -> Void
    ) -> IOSForegroundVoiceWorkflowObservation {
        observeTerminalAction(receive)
    }
}

nonisolated enum IOSForegroundVoiceWorkflowAudioEvent: Equatable, Sendable {
    case interruption
    case routeInvalid
    case mediaServicesLost
    case mediaServicesReset
    case ended
}

/// Audio ownership is deliberately opaque here. P4D-3's platform bridge maps
/// AVAudioSession generations and frozen-input checks into these events.
@MainActor
final class IOSForegroundVoiceWorkflowAudioLease {
    private let freezeAndValidateAction: @MainActor @Sendable () throws -> Void
    private let observeAction: @MainActor @Sendable (
        @escaping @MainActor @Sendable (
            IOSForegroundVoiceWorkflowAudioEvent
        ) -> Void
    ) -> IOSForegroundVoiceWorkflowObservation
    private let deactivateAction: @MainActor @Sendable () -> Void
    private var wasDeactivated = false

    init(
        freezeAndValidate: @escaping @MainActor @Sendable () throws -> Void,
        observe: @escaping @MainActor @Sendable (
            @escaping @MainActor @Sendable (
                IOSForegroundVoiceWorkflowAudioEvent
            ) -> Void
        ) -> IOSForegroundVoiceWorkflowObservation,
        deactivate: @escaping @MainActor @Sendable () -> Void
    ) {
        freezeAndValidateAction = freezeAndValidate
        observeAction = observe
        deactivateAction = deactivate
    }

    func freezeAndValidateInput() throws {
        try freezeAndValidateAction()
    }

    func observe(
        _ receive: @escaping @MainActor @Sendable (
            IOSForegroundVoiceWorkflowAudioEvent
        ) -> Void
    ) -> IOSForegroundVoiceWorkflowObservation {
        observeAction(receive)
    }

    func deactivate() {
        guard !wasDeactivated else { return }
        wasDeactivated = true
        deactivateAction()
    }

    deinit {
        MainActor.assumeIsolated {
            guard !wasDeactivated else { return }
            wasDeactivated = true
            deactivateAction()
        }
    }
}

/// All effects used by the process Voice owner. No closure has a permissive
/// default: production composition must deliberately supply every boundary.
struct IOSForegroundVoiceWorkflowDependencies {
    typealias ObserveCapture = @Sendable () async ->
        IOSForegroundVoiceCaptureRecoveryObservation
    typealias RecoverLifecycle = @Sendable () async -> Bool
    typealias LoadPending = @Sendable () async throws ->
        IOSPendingRecordingObservation?
    typealias LoadLatest = @Sendable () async throws ->
        IOSForegroundVoiceLatestResultObservation
    typealias LoadSettings = @Sendable () async throws -> IOSAppSettings
    typealias LoadLibrary = @Sendable () async throws -> IOSLibraryContent
    typealias ObserveConsent = @Sendable () async ->
        IOSProviderConsentObservation
    typealias ContinueConsent = @MainActor @Sendable (
        IOSVoiceSceneStartLease,
        IOSProviderConsentObservation
    ) async -> IOSProviderConsentObservation?
    typealias RevalidateConsent = @Sendable (
        IOSProviderConsentObservation
    ) async -> Bool
    typealias ResolveCredential = @Sendable () async ->
        IOSForegroundVoiceWorkflowCredentialResolution
    typealias RevalidateCredential = @Sendable (
        IOSForegroundVoiceWorkflowCredentialProof
    ) async -> Bool
    typealias StopHistoryPlayback = @Sendable () async -> Bool
    typealias ActivateAudio = @MainActor @Sendable () throws ->
        IOSForegroundVoiceWorkflowAudioLease
    typealias PlayStartBoundary = @MainActor @Sendable (
        Bool
    ) async -> Bool
    typealias PlayStopBoundary = @MainActor @Sendable (Bool) async -> Void
    typealias MakeRecording = @MainActor @Sendable (
        UUID,
        DictationOutputIntent
    ) async throws -> IOSForegroundVoiceWorkflowRecording
    typealias BeginFinalization = @MainActor @Sendable (
        @escaping @MainActor @Sendable () -> Void
    ) -> IOSForegroundVoiceWorkflowFinalizationLease?
    typealias Process = @Sendable (
        IOSForegroundVoiceWorkflowProcessingRequest,
        @escaping IOSForegroundVoiceProcessingProgressHandler
    ) async -> IOSForegroundVoiceProcessingResolution
    typealias RetryLocal = @Sendable (
        @escaping IOSForegroundVoiceProcessingProgressHandler
    ) async -> IOSForegroundVoiceProcessingResolution
    typealias RecoverCapture = @Sendable (
        IOSForegroundVoiceCaptureRecoveryCapability,
        TranscriptionConfiguration
    ) async throws -> IOSForegroundVoiceCaptureRecoveryResult
    typealias DiscardCapture = @Sendable (
        IOSForegroundVoiceCaptureRecoveryCapability
    ) async throws -> Void
    typealias DiscardPending = @Sendable (
        IOSPendingRecordingCASExpectation
    ) async throws -> IOSPendingRecordingDiscardResult
    typealias RetrySaving = @Sendable (
        IOSForegroundVoiceSavingResultExpectation
    ) async throws -> IOSForegroundVoiceAcceptanceResult
    typealias Sleep = @Sendable (Duration) async throws -> Void

    let sceneRegistry: IOSVoiceSceneRegistry
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
    let activateAudio: ActivateAudio
    let playStartBoundary: PlayStartBoundary
    let cancelStartBoundary: @MainActor @Sendable () -> Void
    let playStopBoundary: PlayStopBoundary
    let makeRecording: MakeRecording
    let beginFinalization: BeginFinalization
    let process: Process
    let retryLocalRecovery: RetryLocal
    let recoverCapture: RecoverCapture
    let discardCapture: DiscardCapture
    let discardPending: DiscardPending
    let retrySavingResult: RetrySaving
    let sleep: Sleep
    let makeUUID: @Sendable () -> UUID
}

/// Process-owned imperative shell behind `IOSForegroundVoiceController`.
/// Construction is passive. All provider-capable paths require an explicit,
/// currently active scene proof and sequentially execute the frozen P4 order.
@MainActor
final class IOSForegroundVoiceWorkflow {
    private enum StopTrigger: Equatable {
        case done
        case cancelled
        case interrupted
        case maximumDuration
    }

    private final class Attempt {
        let token: IOSForegroundVoiceWorkflowAttemptToken
        let sceneLease: IOSVoiceSceneStartLease
        var stopContinuation: CheckedContinuation<StopTrigger, Never>?
        var tailContinuation:
            CheckedContinuation<StopTrigger?, Never>?
        var pendingTrigger: StopTrigger?
        var forcedTrigger: StopTrigger?
        var sceneObservation: IOSVoiceSceneEventSubscription?
        var audioObservation: IOSForegroundVoiceWorkflowObservation?
        var recordingObservation: IOSForegroundVoiceWorkflowObservation?
        var audio: IOSForegroundVoiceWorkflowAudioLease?
        var recording: IOSForegroundVoiceWorkflowRecording?
        var maximumDurationTask: Task<Void, Never>?
        var tailTask: Task<Void, Never>?
        var providerTask:
            Task<IOSForegroundVoiceProcessingResolution, Never>?
        var finalizationLease: IOSForegroundVoiceWorkflowFinalizationLease?
        var finalizationExpired = false
        var isListening = false

        init(
            token: IOSForegroundVoiceWorkflowAttemptToken,
            sceneLease: IOSVoiceSceneStartLease
        ) {
            self.token = token
            self.sceneLease = sceneLease
        }
    }

    private let dependencies: IOSForegroundVoiceWorkflowDependencies
    private var activeAttempt: Attempt?
    private var captureRecoveryCapability:
        IOSForegroundVoiceCaptureRecoveryCapability?
    private var pendingObservation: IOSPendingRecordingObservation?
    private var savingResultExpectation:
        IOSForegroundVoiceSavingResultExpectation?
    private var latestAvailability = IOSForegroundVoiceLatestAvailability.unknown
    private var lastConfiguration: IOSForegroundVoiceWorkflowConfiguration?
    private var didCompleteLaunchRecovery = false
    private var activeControllerAuthority: IOSForegroundVoiceAuthority?
    private var activeControllerToken: IOSForegroundVoiceWorkflowAttemptToken?

    init(dependencies: IOSForegroundVoiceWorkflowDependencies) {
        self.dependencies = dependencies
    }

    var client: IOSForegroundVoiceClient {
        IOSForegroundVoiceClient(
            observe: { [weak self] in
                guard let self else {
                    return await MainActor.run {
                        Self.unavailableObservation
                    }
                }
                return await self.observe()
            },
            runStart: { [weak self] intent, lease, authority, progress in
                guard let self else {
                    return await MainActor.run {
                        Self.unavailableResolution
                    }
                }
                return await self.runControllerStart(
                    intent,
                    sceneLease: lease,
                    authority: authority,
                    progress: progress
                )
            },
            run: { [weak self] operation, authority, progress in
                guard let self else {
                    return await MainActor.run {
                        Self.unavailableResolution
                    }
                }
                return await self.run(
                    operation,
                    authority: authority,
                    progress: progress
                )
            },
            finishUtterance: { [weak self] authority in
                self?.finishControllerUtterance(authority)
                    ?? .unavailable
            }
        )
    }

    private func runControllerStart(
        _ intent: DictationOutputIntent,
        sceneLease: IOSVoiceSceneStartLease,
        authority: IOSForegroundVoiceAuthority,
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        guard activeControllerAuthority == nil,
              activeControllerToken == nil else {
            return Self.busyResolution
        }
        let token = IOSForegroundVoiceWorkflowAttemptToken()
        activeControllerAuthority = authority
        activeControllerToken = token
        defer {
            if activeControllerAuthority == authority,
               activeControllerToken == token {
                activeControllerAuthority = nil
                activeControllerToken = nil
            }
        }
        return await start(
            IOSForegroundVoiceWorkflowStartRequest(
                outputIntent: intent,
                sceneLease: sceneLease
            ),
            token: token,
            progress: progress
        )
    }

    private func finishControllerUtterance(
        _ authority: IOSForegroundVoiceAuthority
    ) -> IOSForegroundVoiceControlDisposition {
        guard activeControllerAuthority == authority,
              let token = activeControllerToken else {
            return .unavailable
        }
        return finishUtterance(token)
    }

    /// Runs the exact scene-bound Start path. The returned token is also the
    /// only authority accepted by `finishUtterance(_:)`.
    func start(
        _ request: IOSForegroundVoiceWorkflowStartRequest,
        token: IOSForegroundVoiceWorkflowAttemptToken,
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        guard activeAttempt == nil else { return Self.busyResolution }
        return await runStart(
            request.outputIntent,
            sceneLease: request.sceneLease,
            token: token,
            progress: progress
        )
    }

    func finishUtterance(
        _ token: IOSForegroundVoiceWorkflowAttemptToken
    ) -> IOSForegroundVoiceControlDisposition {
        guard let attempt = activeAttempt,
              attempt.token == token,
              attempt.isListening,
              attempt.pendingTrigger == nil else {
            return .unavailable
        }
        requestStop(.done, for: attempt)
        return .accepted
    }

    private func observe() async -> IOSForegroundVoiceObservation {
        let capture = await dependencies.reconcileCaptureSources()
        if !didCompleteLaunchRecovery {
            guard await dependencies.recoverContainingAppLifecycle() else {
                return applyDurableFailure(capture: capture)
            }
            didCompleteLaunchRecovery = true
        }
        do {
            let pending = try await dependencies.loadPending()
            let latest = try await dependencies.loadLatest()
            let durable = IOSForegroundVoiceWorkflowDurableObservation(
                capture: capture,
                pending: pending,
                latest: latest
            )
            if mapRecovery(
                capture: capture,
                pending: pending,
                latest: latest
            ) == .none {
                let settings = try await dependencies.loadSettings()
                let library = try await dependencies.loadLibrary()
                lastConfiguration = IOSForegroundVoiceWorkflowConfiguration(
                    settings: settings,
                    library: library
                )
            }
            return apply(durable)
        } catch {
            return applyDurableFailure(capture: capture)
        }
    }

    private func run(
        _ operation: IOSForegroundVoiceOperation,
        authority _: IOSForegroundVoiceAuthority,
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        guard activeAttempt == nil else { return Self.busyResolution }

        switch operation {
        case .start:
            return IOSForegroundVoiceResolution(
                observation: IOSForegroundVoiceObservation(
                    setup: .unavailable,
                    recovery: .none,
                    latestAvailability: latestAvailability,
                    translationAvailable: translationIsAvailable
                ),
                failure: .unavailable
            )
        case .retryPending:
            return await runRetryPending(progress: progress)
        case .recoverRecording:
            return await runRecoverRecording()
        case .discard:
            return await runDiscard()
        case .retrySavingResult:
            return await runRetrySavingResult()
        case .retryLocalCheckpoint:
            return await mapProcessing(
                await dependencies.retryLocalRecovery { stage in
                    progress(.processing(stage))
                }
            )
        }
    }

    private func runStart(
        _ intent: DictationOutputIntent,
        sceneLease: IOSVoiceSceneStartLease,
        token: IOSForegroundVoiceWorkflowAttemptToken,
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        guard dependencies.sceneRegistry.validateContinuation(sceneLease)
                == .ready else {
            return await blockedPreflight(failure: .unavailable)
        }

        let attempt = Attempt(token: token, sceneLease: sceneLease)
        activeAttempt = attempt
        attempt.sceneObservation = dependencies.sceneRegistry.observeEvents {
            [weak self, weak attempt] event in
            guard let self, let attempt, self.activeAttempt === attempt else {
                return
            }
            guard self.dependencies.sceneRegistry.validate(event) else {
                return
            }
            switch event.kind {
            case .lastActiveSceneLost(.expectedMicrophonePermissionPrompt),
                 .aggregateBecameActive,
                 .initiatingSceneReactivatedAfterPermission:
                break
            case .lastActiveSceneLost(.voiceWorkMustStop),
                 .initiatingSceneBecameUnavailable:
                self.dependencies.cancelStartBoundary()
                self.requestStop(.interrupted, for: attempt)
            }
        }

        return await withTaskCancellationHandler {
            await performStart(
                intent,
                attempt: attempt,
                progress: progress
            )
        } onCancel: {
            Task { @MainActor [weak self, weak attempt] in
                guard let self, let attempt else { return }
                self.requestStop(.cancelled, for: attempt)
            }
        }
    }

    private func performStart(
        _ intent: DictationOutputIntent,
        attempt: Attempt,
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        defer { retire(attempt) }
        defer {
            attempt.sceneLease.finish()
        }

        guard await hasNoDurableRecoveryOwner() else {
            return await blockedPreflight(failure: .localRecovery)
        }
        guard let configuration = await loadValidatedConfiguration(intent) else {
            return await configurationFailure(for: intent)
        }
        lastConfiguration = configuration

        guard let consent = await resolveConsent(for: attempt) else {
            return await blockedPreflight(
                setup: .needsSetup(.microphoneAndPrivacy),
                failure: nil
            )
        }
        guard let credential = await resolveCredential() else {
            return await blockedPreflight(
                setup: .needsSetup(.openAI),
                failure: nil
            )
        }

        guard await resolvePermission(for: attempt) else {
            return await blockedPreflight(
                setup: .needsSetup(.microphoneAndPrivacy),
                failure: nil
            )
        }
        guard await revalidate(
            attempt: attempt,
            intent: intent,
            configuration: configuration,
            consent: consent,
            credential: credential,
            requireGrantedPermission: true
        ) else {
            return await blockedPreflight(failure: .unavailable)
        }
        guard await dependencies.stopHistoryPlayback() else {
            return await blockedPreflight(failure: .operationFailed)
        }

        do {
            attempt.audio = try dependencies.activateAudio()
        } catch {
            return await blockedPreflight(failure: .operationFailed)
        }
        attempt.audioObservation = attempt.audio?.observe {
            [weak self, weak attempt] event in
            guard let self, let attempt, self.activeAttempt === attempt else {
                return
            }
            switch event {
            case .interruption, .routeInvalid, .mediaServicesLost,
                 .mediaServicesReset, .ended:
                self.requestStop(.interrupted, for: attempt)
            }
        }

        let cuesEnabled = configuration.settings
            .voiceSessionPreferences.audioCuesEnabled
        guard await dependencies.playStartBoundary(cuesEnabled) else {
            return await blockedPreflight(failure: .operationFailed)
        }
        guard await revalidate(
            attempt: attempt,
            intent: intent,
            configuration: configuration,
            consent: consent,
            credential: credential,
            requireGrantedPermission: true
        ) else {
            return await blockedPreflight(failure: .unavailable)
        }
        do {
            try attempt.audio?.freezeAndValidateInput()
        } catch {
            return await blockedPreflight(failure: .unavailable)
        }

        do {
            attempt.recording = try await dependencies.makeRecording(
                dependencies.makeUUID(),
                intent
            )
        } catch {
            return await blockedPreflight(failure: .localRecovery)
        }
        guard await attempt.recording?.start() == true else {
            return await resolveStoppedAttempt(
                .cancelled,
                attempt: attempt,
                configuration: configuration,
                consent: consent,
                credential: credential,
                progress: progress
            )
        }

        guard attempt.recording?.isActive == true,
              await revalidate(
                attempt: attempt,
                intent: intent,
                configuration: configuration,
                consent: consent,
                credential: credential,
                requireGrantedPermission: true,
                requireNoDurableOwner: false
              ) else {
            return await resolveStoppedAttempt(
                .cancelled,
                attempt: attempt,
                configuration: configuration,
                consent: consent,
                credential: credential,
                progress: progress
            )
        }

        attempt.recordingObservation = attempt.recording?.observeTerminal {
            [weak self, weak attempt] reason in
            guard let self, let attempt, self.activeAttempt === attempt else {
                return
            }
            switch reason {
            case .done, .cancelled:
                break
            case .interrupted:
                self.requestStop(.interrupted, for: attempt)
            case .maximumDuration:
                self.requestStop(.maximumDuration, for: attempt)
            }
        }
        do {
            try attempt.audio?.freezeAndValidateInput()
        } catch {
            return await resolveStoppedAttempt(
                .interrupted,
                attempt: attempt,
                configuration: configuration,
                consent: consent,
                credential: credential,
                progress: progress
            )
        }

        attempt.isListening = true
        progress(.listening)
        scheduleMaximumDuration(for: attempt)
        let trigger = await waitForStop(on: attempt)
        return await resolveStoppedAttempt(
            trigger,
            attempt: attempt,
            configuration: configuration,
            consent: consent,
            credential: credential,
            progress: progress
        )
    }

    private func resolveStoppedAttempt(
        _ requestedTrigger: StopTrigger,
        attempt: Attempt,
        configuration: IOSForegroundVoiceWorkflowConfiguration,
        consent: IOSProviderConsentObservation,
        credential: IOSForegroundVoiceWorkflowCredentialProof,
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        var trigger = requestedTrigger
        if trigger == .done {
            let seconds = configuration.settings.voiceSessionPreferences
                .recordingStopTailDuration.duration
            if seconds > 0 {
                if let forced = await waitForTail(
                    .milliseconds(Int64(seconds * 1_000)),
                    attempt: attempt
                ) {
                    trigger = forced
                }
            }
            if let forced = attempt.forcedTrigger { trigger = forced }
        }

        attempt.maximumDurationTask?.cancel()
        attempt.maximumDurationTask = nil
        attempt.isListening = false
        let stopReason: IOSForegroundVoiceWorkflowCaptureStopReason = switch trigger {
        case .done: .done
        case .cancelled: .cancelled
        case .interrupted: .interrupted
        case .maximumDuration: .maximumDuration
        }
        if trigger != .cancelled { progress(.finalizing) }
        if trigger != .cancelled {
            attempt.finalizationLease = dependencies.beginFinalization {
                [weak self, weak attempt] in
                guard let self, let attempt else { return }
                attempt.finalizationExpired = true
                self.requestStop(.interrupted, for: attempt)
            }
        }
        let result = await attempt.recording?.stop(stopReason) ?? .stale
        if let forced = attempt.forcedTrigger {
            trigger = forced
        }
        attempt.audioObservation?.cancel()
        attempt.audioObservation = nil

        switch result {
        case .completed(let capture):
            if attempt.finalizationExpired {
                finishFinalization(for: attempt)
                deactivateAudio(for: attempt)
                capture.release()
                return IOSForegroundVoiceResolution(
                    observation: await observe(),
                    stage: .recordingFinalization,
                    outcome: trigger == .interrupted ? .interrupted : nil,
                    failure: .localRecovery
                )
            }
            if trigger == .maximumDuration {
                finishFinalization(for: attempt)
                deactivateAudio(for: attempt)
                capture.release()
                return IOSForegroundVoiceResolution(
                    observation: IOSForegroundVoiceObservation(
                        setup: .unavailable,
                        recovery: .blocked,
                        latestAvailability: latestAvailability,
                        translationAvailable: translationIsAvailable
                    ),
                    failure: .maximumDuration
                )
            }
            if trigger != .done {
                finishFinalization(for: attempt)
                deactivateAudio(for: attempt)
                capture.release()
                let observation = await observe()
                return IOSForegroundVoiceResolution(
                    observation: observation,
                    stage: .recordingFinalization,
                    outcome: trigger == .interrupted ? .interrupted : nil,
                    failure: trigger == .maximumDuration
                        ? .maximumDuration
                        : nil
                )
            }
            await dependencies.playStopBoundary(
                configuration.settings.voiceSessionPreferences
                    .audioCuesEnabled
            )
            deactivateAudio(for: attempt)
            let pending: IOSPendingRecording
            do {
                pending = try await capture.preparePending(
                    transcriptionConfiguration:
                        configuration.settings.transcriptionConfiguration
                )
            } catch {
                capture.release()
                finishFinalization(for: attempt)
                return IOSForegroundVoiceResolution(
                    observation: await observe(),
                    stage: .recordingFinalization,
                    failure: .localRecovery
                )
            }
            capture.release()
            let finalizationExpired = attempt.finalizationExpired
            finishFinalization(for: attempt)
            guard !finalizationExpired else {
                return IOSForegroundVoiceResolution(
                    observation: await observe(),
                    stage: .recordingFinalization,
                    outcome: .recoverableFailure,
                    failure: .localRecovery
                )
            }
            guard dependencies.sceneRegistry.validateContinuation(
                    attempt.sceneLease
                  ) == .ready,
                  await dependencies.revalidateConsent(consent),
                  await dependencies.revalidateCredential(credential) else {
                return IOSForegroundVoiceResolution(
                    observation: await observe(),
                    stage: .recordingFinalization,
                    outcome: .recoverableFailure,
                    failure: .localRecovery
                )
            }
            return await runProcessor(
                IOSForegroundVoiceWorkflowProcessingRequest(
                    sessionID: dependencies.makeUUID(),
                    pendingRecording: pending,
                    mode: .initial,
                    configuration: configuration,
                    credential: credential,
                    consentObservation: consent
                ),
                attempt: attempt,
                progress: progress
            )
        case .discarded(let reason):
            finishFinalization(for: attempt)
            deactivateAudio(for: attempt)
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: nil,
                outcome: trigger == .interrupted ? .interrupted : nil,
                failure: failure(for: reason)
            )
        case .preserved, .stale:
            finishFinalization(for: attempt)
            deactivateAudio(for: attempt)
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: .recordingFinalization,
                outcome: trigger == .interrupted ? .interrupted : nil,
                failure: .localRecovery
            )
        }
    }

    private func runRetryPending(
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        guard dependencies.sceneRegistry.snapshot.isForegroundActive,
              let pending = pendingObservation,
              pending.availability == .available,
              pending.recording.phase == .readyForTranscription
                || pending.recording.phase == .awaitingRecovery,
              let configuration = await loadValidatedConfiguration(
                pending.recording.outputIntent
              ),
              let consent = await resolveConsentWithoutPresentation(),
              let credential = await resolveCredential(),
              dependencies.sceneRegistry.snapshot.isForegroundActive,
              await dependencies.revalidateConsent(consent),
              await dependencies.revalidateCredential(credential) else {
            return await blockedPreflight(failure: .unavailable)
        }

        return await runAggregateProcessor(
            IOSForegroundVoiceWorkflowProcessingRequest(
                sessionID: dependencies.makeUUID(),
                pendingRecording: pending.recording,
                mode: .retry,
                configuration: configuration,
                credential: credential,
                consentObservation: consent
            ),
            progress: progress
        )
    }

    private func runRecoverRecording() async -> IOSForegroundVoiceResolution {
        guard let capability = captureRecoveryCapability,
              let settings = try? await dependencies.loadSettings(),
              !settings.transcriptionConfiguration
                .customLanguageCodeValidation.isInvalid else {
            return await blockedPreflight(failure: .localRecovery)
        }
        do {
            _ = try await dependencies.recoverCapture(
                capability,
                settings.transcriptionConfiguration
            )
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: .recordingFinalization
            )
        } catch {
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: .recordingFinalization,
                failure: .localRecovery
            )
        }
    }

    private func runDiscard() async -> IOSForegroundVoiceResolution {
        do {
            if let capability = captureRecoveryCapability {
                try await dependencies.discardCapture(capability)
            } else if let pending = pendingObservation {
                _ = try await dependencies.discardPending(
                    pending.expectation
                )
            } else {
                return await blockedPreflight(failure: .localRecovery)
            }
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: .recordingFinalization
            )
        } catch {
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: .recordingFinalization,
                failure: .localRecovery
            )
        }
    }

    private func runRetrySavingResult() async -> IOSForegroundVoiceResolution {
        guard let expectation = savingResultExpectation else {
            return await blockedPreflight(failure: .localRecovery)
        }
        do {
            return await mapAcceptance(
                try await dependencies.retrySavingResult(expectation)
            )
        } catch {
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: .outputDelivery,
                failure: .localRecovery
            )
        }
    }

    private func mapProcessing(
        _ resolution: IOSForegroundVoiceProcessingResolution
    ) async -> IOSForegroundVoiceResolution {
        switch resolution {
        case .acceptance(let acceptance):
            return await mapAcceptance(acceptance)
        case .awaitingRecovery(_, let failure, let stage):
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: stage,
                outcome: .recoverableFailure,
                failure: map(failure)
            )
        case .localRecoveryPending(let failure, let stage, let disposition):
            let recovery: IOSForegroundVoiceRecovery = switch disposition {
            case .processingCheckpoint: .localCheckpoint(stage)
            case .savingResult: .savingResult
            }
            return IOSForegroundVoiceResolution(
                observation: IOSForegroundVoiceObservation(
                    setup: .ready,
                    recovery: recovery,
                    stage: stage,
                    latestAvailability: latestAvailability,
                    translationAvailable: translationIsAvailable
                ),
                stage: stage,
                outcome: disposition == .processingCheckpoint
                    ? .recoverableFailure
                    : nil,
                failure: map(failure)
            )
        case .notStarted(let failure):
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                failure: map(failure)
            )
        case .busy:
            return Self.busyResolution
        }
    }

    private func runProcessor(
        _ request: IOSForegroundVoiceWorkflowProcessingRequest,
        attempt: Attempt,
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        guard dependencies.sceneRegistry.validateContinuation(
                attempt.sceneLease
              ) == .ready,
              attempt.forcedTrigger == nil else {
            return IOSForegroundVoiceResolution(
                observation: await observe(),
                stage: .recordingFinalization,
                outcome: .recoverableFailure,
                failure: .localRecovery
            )
        }
        let process = dependencies.process
        let task = Task {
            await process(request) { stage in
                progress(.processing(stage))
            }
        }
        attempt.providerTask = task
        let result = await task.value
        attempt.providerTask = nil
        return await mapProcessing(result)
    }

    private func runAggregateProcessor(
        _ request: IOSForegroundVoiceWorkflowProcessingRequest,
        progress: @escaping IOSForegroundVoiceClient.Progress
    ) async -> IOSForegroundVoiceResolution {
        guard dependencies.sceneRegistry.snapshot.isForegroundActive else {
            return await blockedPreflight(failure: .unavailable)
        }
        var task: Task<IOSForegroundVoiceProcessingResolution, Never>?
        let registry = dependencies.sceneRegistry
        let observation = registry.observeEvents { event in
            guard registry.validate(event) else { return }
            if event.kind == .lastActiveSceneLost(.voiceWorkMustStop) {
                task?.cancel()
            }
        }
        defer { observation.cancel() }
        guard registry.snapshot.isForegroundActive else {
            return await blockedPreflight(failure: .unavailable)
        }
        let process = dependencies.process
        let operation = Task {
            await process(request) { stage in
                progress(.processing(stage))
            }
        }
        task = operation
        let result = await operation.value
        task = nil
        return await mapProcessing(result)
    }

    private func mapAcceptance(
        _ acceptance: IOSForegroundVoiceAcceptanceResult
    ) async -> IOSForegroundVoiceResolution {
        let observation = await observe()
        switch acceptance {
        case .resultReady:
            return IOSForegroundVoiceResolution(
                observation: observation,
                outcome: .resultReady
            )
        case .savingResult(let expectation):
            savingResultExpectation = expectation
            return IOSForegroundVoiceResolution(
                observation: IOSForegroundVoiceObservation(
                    setup: observation.setup,
                    recovery: .savingResult,
                    stage: .outputDelivery,
                    latestAvailability:
                        observation.latestAvailability == .available
                            ? .priorAvailableWhileSaving
                            : observation.latestAvailability,
                    translationAvailable:
                        observation.translationAvailable
                ),
                stage: .outputDelivery,
                failure: .localRecovery
            )
        case .expired:
            return IOSForegroundVoiceResolution(observation: observation)
        case .clockRollbackAmbiguous:
            return IOSForegroundVoiceResolution(
                observation: observation,
                failure: .localRecovery
            )
        }
    }

    private func hasNoDurableRecoveryOwner() async -> Bool {
        let observation = await observe()
        return observation.recovery == .none
    }

    private func loadValidatedConfiguration(
        _ intent: DictationOutputIntent
    ) async -> IOSForegroundVoiceWorkflowConfiguration? {
        guard let settings = try? await dependencies.loadSettings(),
              let library = try? await dependencies.loadLibrary() else {
            return nil
        }
        guard !settings.transcriptionConfiguration
                .customLanguageCodeValidation.isInvalid else {
            return nil
        }
        if intent == .translate,
           !settings.translationConfiguration.canRunAction {
            return nil
        }
        return IOSForegroundVoiceWorkflowConfiguration(
            settings: settings,
            library: library
        )
    }

    private func resolveConsent(
        for attempt: Attempt
    ) async -> IOSProviderConsentObservation? {
        await resolveConsent(sceneLease: attempt.sceneLease)
    }

    private func resolveConsent(
        sceneLease: IOSVoiceSceneStartLease
    ) async -> IOSProviderConsentObservation? {
        let observed = await dependencies.observeConsent()
        if observed.status == .acceptedCurrentDisclosure,
           await dependencies.revalidateConsent(observed) {
            return observed
        }
        guard dependencies.sceneRegistry.validateContinuation(sceneLease)
                == .ready,
              let accepted = await dependencies.continueConsent(
                  sceneLease,
                  observed
              ),
              accepted.status == .acceptedCurrentDisclosure,
              dependencies.sceneRegistry.validateContinuation(sceneLease)
                == .ready,
              await dependencies.revalidateConsent(accepted) else {
            return nil
        }
        return accepted
    }

    private func resolveConsentWithoutPresentation() async
        -> IOSProviderConsentObservation? {
        let observed = await dependencies.observeConsent()
        guard observed.status == .acceptedCurrentDisclosure,
              await dependencies.revalidateConsent(observed) else {
            return nil
        }
        return observed
    }

    private func resolveCredential() async
        -> IOSForegroundVoiceWorkflowCredentialProof? {
        switch await dependencies.resolveCredential() {
        case .available(let credential): credential
        case .needsSetup, .unavailable: nil
        }
    }

    private func resolvePermission(for attempt: Attempt) async -> Bool {
        let status = dependencies.permission.read()
        switch status {
        case .granted:
            return true
        case .denied, .unavailable:
            return false
        case .undetermined:
            guard dependencies.sceneRegistry
                .beginExpectedMicrophonePermissionPrompt(
                    attempt.sceneLease
                ) else {
                return false
            }
            let outcome = await dependencies.permission
                .requestIfUndetermined()
            var validation = dependencies.sceneRegistry
                .microphonePermissionPromptDidReturn(attempt.sceneLease)
            if validation == .awaitingInitiatingSceneReactivation {
                validation = await dependencies.sceneRegistry
                    .waitUntilInitiatingSceneActive(attempt.sceneLease)
            }
            return validation == .ready && outcome == .granted
                && dependencies.permission.read() == .granted
        }
    }

    private func revalidate(
        attempt: Attempt,
        intent: DictationOutputIntent,
        configuration: IOSForegroundVoiceWorkflowConfiguration,
        consent: IOSProviderConsentObservation,
        credential: IOSForegroundVoiceWorkflowCredentialProof,
        requireGrantedPermission: Bool,
        requireNoDurableOwner: Bool = true
    ) async -> Bool {
        guard activeAttempt === attempt,
              !Task.isCancelled,
              dependencies.sceneRegistry.validateContinuation(
                attempt.sceneLease
              ) == .ready else {
            return false
        }
        if requireNoDurableOwner,
           !(await hasNoDurableRecoveryOwner()) {
            return false
        }
        guard let current = await loadValidatedConfiguration(intent),
              current.settings == configuration.settings,
              current.library == configuration.library,
              await dependencies.revalidateConsent(consent),
              await dependencies.revalidateCredential(credential) else {
            return false
        }
        return !requireGrantedPermission
            || dependencies.permission.read() == .granted
    }

    private func deactivateAudio(for attempt: Attempt) {
        attempt.audioObservation?.cancel()
        attempt.audioObservation = nil
        attempt.audio?.deactivate()
        attempt.audio = nil
    }

    private func finishFinalization(for attempt: Attempt) {
        attempt.finalizationLease?.finish()
        attempt.finalizationLease = nil
    }

    private func waitForStop(on attempt: Attempt) async -> StopTrigger {
        if let pending = attempt.pendingTrigger {
            attempt.pendingTrigger = nil
            return pending
        }
        return await withCheckedContinuation { continuation in
            attempt.stopContinuation = continuation
        }
    }

    private func requestStop(_ trigger: StopTrigger, for attempt: Attempt) {
        guard activeAttempt === attempt else { return }
        if trigger == .interrupted || trigger == .maximumDuration {
            attempt.forcedTrigger = trigger
        }
        if let continuation = attempt.tailContinuation,
           trigger != .done {
            attempt.tailContinuation = nil
            attempt.tailTask?.cancel()
            attempt.tailTask = nil
            continuation.resume(returning: trigger)
        } else if let continuation = attempt.stopContinuation {
            attempt.stopContinuation = nil
            continuation.resume(returning: trigger)
        } else if attempt.pendingTrigger == nil {
            attempt.pendingTrigger = trigger
        }
        if trigger != .done { attempt.providerTask?.cancel() }
    }

    private func waitForTail(
        _ duration: Duration,
        attempt: Attempt
    ) async -> StopTrigger? {
        if let forced = attempt.forcedTrigger { return forced }
        let sleep = dependencies.sleep
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                attempt.tailContinuation = continuation
                attempt.tailTask = Task { @MainActor [weak attempt] in
                    do {
                        try await sleep(duration)
                    } catch {
                        return
                    }
                    guard let attempt,
                          let continuation = attempt.tailContinuation else {
                        return
                    }
                    attempt.tailContinuation = nil
                    attempt.tailTask = nil
                    continuation.resume(returning: nil)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self, weak attempt] in
                guard let self, let attempt else { return }
                self.requestStop(.cancelled, for: attempt)
            }
        }
    }

    private func scheduleMaximumDuration(for attempt: Attempt) {
        let sleep = dependencies.sleep
        attempt.maximumDurationTask = Task { @MainActor [weak self, weak attempt] in
            do {
                try await sleep(.seconds(300))
            } catch {
                return
            }
            guard let self, let attempt else { return }
            self.requestStop(.maximumDuration, for: attempt)
        }
    }

    private func retire(_ attempt: Attempt) {
        guard activeAttempt === attempt else { return }
        attempt.maximumDurationTask?.cancel()
        attempt.maximumDurationTask = nil
        attempt.tailTask?.cancel()
        attempt.tailTask = nil
        attempt.tailContinuation?.resume(returning: .cancelled)
        attempt.tailContinuation = nil
        attempt.providerTask?.cancel()
        attempt.providerTask = nil
        finishFinalization(for: attempt)
        attempt.sceneObservation?.cancel()
        attempt.sceneObservation = nil
        attempt.audioObservation?.cancel()
        attempt.audioObservation = nil
        attempt.audio?.deactivate()
        attempt.audio = nil
        attempt.recordingObservation?.cancel()
        attempt.recordingObservation = nil
        activeAttempt = nil
    }

    private func apply(
        _ durable: IOSForegroundVoiceWorkflowDurableObservation
    ) -> IOSForegroundVoiceObservation {
        captureRecoveryCapability = durable.capture.recoveryCapability
        pendingObservation = durable.pending
        latestAvailability = map(durable.latest)
        if case .savingResult(let expectation, _) = durable.latest {
            savingResultExpectation = expectation
        } else {
            savingResultExpectation = nil
        }

        let recovery = mapRecovery(
            capture: durable.capture,
            pending: durable.pending,
            latest: durable.latest
        )
        return IOSForegroundVoiceObservation(
            setup: recovery == .blocked ? .unavailable : passiveSetup,
            recovery: recovery,
            stage: stage(for: durable.pending),
            latestAvailability: latestAvailability,
            translationAvailable: translationIsAvailable
        )
    }

    private func applyDurableFailure(
        capture: IOSForegroundVoiceCaptureRecoveryObservation
    ) -> IOSForegroundVoiceObservation {
        captureRecoveryCapability = capture.recoveryCapability
        pendingObservation = nil
        return IOSForegroundVoiceObservation(
            setup: .unavailable,
            recovery: capture.recoveryCapability == nil
                ? .blocked
                : .captureRecoverOrDiscard,
            latestAvailability: .unavailable
        )
    }

    private func mapRecovery(
        capture: IOSForegroundVoiceCaptureRecoveryObservation,
        pending: IOSPendingRecordingObservation?,
        latest: IOSForegroundVoiceLatestResultObservation
    ) -> IOSForegroundVoiceRecovery {
        switch capture.status {
        case .activeNeedsRecovery, .finalizingNeedsRecovery,
             .completedNeedsPendingHandoff:
            return .captureRecoverOrDiscard
        case .emptyActiveNeedsDiscard:
            return .captureDiscardOnly
        case .preparingPendingNeedsRecovery:
            return .captureRecoverOnly
        case .recordingInProgress, .transferredCleanupPending,
             .blockedUnknown:
            return .blocked
        case .empty, .cleanupPerformed:
            break
        }

        if case .savingResult = latest { return .savingResult }
        guard let pending else { return .none }
        guard pending.availability == .available else { return .blocked }
        switch pending.recording.phase {
        case .readyForTranscription, .awaitingRecovery:
            return .pendingRetryOrDiscard
        case .transcribing, .postProcessing, .outputDelivery:
            return .blocked
        }
    }

    private func stage(
        for pending: IOSPendingRecordingObservation?
    ) -> VoiceAttemptStage? {
        guard let pending else { return nil }
        switch pending.recording.phase {
        case .readyForTranscription, .awaitingRecovery:
            return .transcription
        case .transcribing:
            return .transcription
        case .postProcessing:
            return .postProcessing
        case .outputDelivery:
            return .outputDelivery
        }
    }

    private func map(
        _ latest: IOSForegroundVoiceLatestResultObservation
    ) -> IOSForegroundVoiceLatestAvailability {
        switch latest {
        case .absent: .absent
        case .resultReady: .available
        case .savingResult(_, let prior):
            prior == nil ? .unknown : .priorAvailableWhileSaving
        case .expired: .expired
        case .clockRollbackAmbiguous: .clockRollbackAmbiguous
        case .clearedCleanupPending: .cleanupPending
        }
    }

    private func failure(
        for reason: IOSForegroundVoiceCaptureInvalidReason
    ) -> IOSForegroundVoiceFailure {
        switch reason {
        case .tooShort, .empty: .tooShort
        case .maximumDurationReached: .maximumDuration
        case .invalidMedia: .operationFailed
        }
    }

    private func map(
        _ failure: IOSForegroundVoiceProcessingFailure
    ) -> IOSForegroundVoiceFailure {
        switch failure {
        case .localPersistence: .localRecovery
        case .invalidConfiguration, .providerConsentUnavailable,
             .credentialRejected, .networkUnavailable, .networkFailure,
             .timedOut, .providerUnavailable, .invalidRecording,
             .invalidResponse, .cancelled:
            .operationFailed
        }
    }

    private var translationIsAvailable: Bool {
        guard passiveSetup == .ready else { return false }
        return lastConfiguration?.settings.translationConfiguration
            .canRunAction ?? false
    }

    private var passiveSetup: IOSForegroundVoiceSetup {
        guard let settings = lastConfiguration?.settings else {
            return .unavailable
        }
        if settings.transcriptionConfiguration
            .customLanguageCodeValidation.isInvalid {
            return .needsSetup(.transcription)
        }
        return .ready
    }

    private func configurationFailure(
        for intent: DictationOutputIntent
    ) async -> IOSForegroundVoiceResolution {
        await blockedPreflight(
            setup: .needsSetup(
                intent == .translate ? .translation : .transcription
            ),
            failure: nil
        )
    }

    private func blockedPreflight(
        setup: IOSForegroundVoiceSetup = .unavailable,
        failure: IOSForegroundVoiceFailure?
    ) async -> IOSForegroundVoiceResolution {
        let current = await observe()
        return IOSForegroundVoiceResolution(
            observation: IOSForegroundVoiceObservation(
                setup: setup,
                recovery: current.recovery,
                stage: current.stage,
                latestAvailability: current.latestAvailability,
                translationAvailable: current.translationAvailable
            ),
            failure: failure
        )
    }

    private static let unavailableObservation = IOSForegroundVoiceObservation(
        setup: .unavailable,
        recovery: .blocked,
        latestAvailability: .unavailable
    )

    private static let unavailableResolution = IOSForegroundVoiceResolution(
        observation: unavailableObservation,
        failure: .unavailable
    )

    private static let busyResolution = IOSForegroundVoiceResolution(
        observation: IOSForegroundVoiceObservation(
            setup: .unavailable,
            recovery: .blocked,
            latestAvailability: .unknown
        )
    )
}

extension IOSForegroundVoiceWorkflow:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflow(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceWorkflowDependencies:
    IOSForegroundVoiceRedactedValue {
    var description: String {
        "IOSForegroundVoiceWorkflowDependencies(<redacted>)"
    }
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

extension IOSForegroundVoiceWorkflowCaptureHandoff:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowCaptureHandoff(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceWorkflowRecording:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowRecording(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
