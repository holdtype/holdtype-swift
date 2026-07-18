import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
@_spi(HoldTypeIOSCore) import HoldTypePersistence

/// Exact-once cleanup storage whose last-reference path is safe on any
/// executor. Explicit owners run it synchronously on MainActor; deinit hops
/// the still-armed action to MainActor without assuming executor affinity.
nonisolated final class IOSForegroundVoiceMainActorCleanup:
    @unchecked Sendable {
    private let lock = NSLock()
    private var action: (@MainActor @Sendable () -> Void)?

    init(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    @MainActor
    func run() {
        take()?()
    }

    @MainActor
    func disarm() {
        _ = take()
    }

    private func take() -> (@MainActor @Sendable () -> Void)? {
        lock.withLock {
            let action = self.action
            self.action = nil
            return action
        }
    }

    deinit {
        guard let action = take() else { return }
        Task { @MainActor in action() }
    }
}

/// Cancels one process observation without exposing its platform identity.
@MainActor
final class IOSForegroundVoiceWorkflowObservation {
    private let cleanup: IOSForegroundVoiceMainActorCleanup

    init(cancel: @escaping @MainActor @Sendable () -> Void) {
        cleanup = IOSForegroundVoiceMainActorCleanup(cancel)
    }

    func cancel() {
        cleanup.run()
    }
}

/// Single-use descriptor-bound handoff produced only after recorder close.
/// It exposes no URL, path, descriptor, or reusable capture capability.
@MainActor
final class IOSForegroundVoiceWorkflowCaptureHandoff {
    private enum State {
        case available
        case preparing
        case consumed
        case released
    }

    private enum UseError: Error {
        case unavailable
    }

    private let prepareAction: @MainActor @Sendable (
        TranscriptionConfiguration,
        IOSAcceptedAudioRetention
    ) async throws -> IOSV1PendingRecording
    private let cleanup: IOSForegroundVoiceMainActorCleanup
    private var state = State.available
    let durationMilliseconds: Int64

    init(
        durationMilliseconds: Int64 = 0,
        prepare: @escaping @MainActor @Sendable (
            TranscriptionConfiguration,
            IOSAcceptedAudioRetention
        ) async throws -> IOSV1PendingRecording,
        release: @escaping @MainActor @Sendable () -> Void
    ) {
        self.durationMilliseconds = durationMilliseconds
        prepareAction = prepare
        cleanup = IOSForegroundVoiceMainActorCleanup(release)
    }

    func preparePending(
        transcriptionConfiguration: TranscriptionConfiguration,
        acceptedAudioRetention: IOSAcceptedAudioRetention =
            .recordingCachePolicy
    ) async throws -> IOSV1PendingRecording {
        guard state == .available else { throw UseError.unavailable }
        state = .preparing
        do {
            let result = try await prepareAction(
                transcriptionConfiguration,
                acceptedAudioRetention
            )
            guard state == .preparing else { throw UseError.unavailable }
            state = .consumed
            cleanup.disarm()
            return result
        } catch {
            guard state == .preparing else { throw error }
            state = .released
            cleanup.run()
            throw error
        }
    }

    func release() {
        if state == .preparing {
            return
        }
        guard state == .available else { return }
        state = .released
        cleanup.run()
    }
}

/// One bounded UIKit background assertion covering only recorder close,
/// descriptor validation, protected copy, and Pending publication.
@MainActor
final class IOSForegroundVoiceWorkflowFinalizationLease {
    private let cleanup: IOSForegroundVoiceMainActorCleanup

    init(finish: @escaping @MainActor @Sendable () -> Void) {
        cleanup = IOSForegroundVoiceMainActorCleanup(finish)
    }

    func finish() {
        cleanup.run()
    }
}

nonisolated enum IOSForegroundVoiceWorkflowCaptureStopResult: Sendable {
    case completed(IOSForegroundVoiceWorkflowCaptureHandoff)
    case discarded
    case invalid(IOSV1ForegroundVoiceCaptureInvalidReason)
    case preserved
    case stale
}

nonisolated enum IOSForegroundVoiceWorkflowRecordingStartResult:
    Equatable,
    Sendable {
    case started
    case cancelled
    case failed
}

/// One live recorder owner. Implementations may wrap AVAudioRecorder, but the
/// workflow sees only descriptor-bound capture truth.
@MainActor
final class IOSForegroundVoiceWorkflowRecording {
    private let startAction: @MainActor @Sendable () async ->
        IOSForegroundVoiceWorkflowRecordingStartResult
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
        start: @escaping @MainActor @Sendable () async ->
            IOSForegroundVoiceWorkflowRecordingStartResult,
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

    func start() async -> IOSForegroundVoiceWorkflowRecordingStartResult {
        await startAction()
    }

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

/// Monotonic authority shared by one aggregate-foreground retry and its exact
/// child task. Aggregate loss and parent cancellation are terminal even if a
/// scene later reactivates or a cancellation-hostile dependency returns late.
nonisolated final class IOSForegroundVoiceRetryAuthority:
    @unchecked Sendable {
    private let lock = NSLock()
    private var isTerminal = false
    private var child:
        Task<IOSForegroundVoiceProcessingResolution, Never>?
    let processingCancellationAuthority =
        IOSForegroundVoiceProcessingCancellationAuthority()

    var canContinue: Bool {
        lock.withLock { !isTerminal }
    }

    func terminate() {
        let child = lock.withLock {
            isTerminal = true
            let child = self.child
            self.child = nil
            return child
        }
        child?.cancel()
    }

    func cancelProcessingExplicitly() {
        processingCancellationAuthority.cancelExplicitly()
        terminate()
    }

    func install(
        _ child: Task<IOSForegroundVoiceProcessingResolution, Never>
    ) -> Bool {
        let accepted = lock.withLock {
            guard !isTerminal else { return false }
            self.child = child
            return true
        }
        if !accepted { child.cancel() }
        return accepted
    }

    func clearChild() {
        lock.withLock { child = nil }
    }
}

nonisolated enum IOSForegroundVoiceWorkflowAudioEvent: Equatable, Sendable {
    case interruption
    case routeInvalid
    case routeNeedsRevalidation
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
    private let cleanup: IOSForegroundVoiceMainActorCleanup

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
        cleanup = IOSForegroundVoiceMainActorCleanup(deactivate)
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
        cleanup.run()
    }
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
