import Foundation

extension IOSForegroundVoiceWorkflowPermissionClient {
    @MainActor
    init(adapter: IOSMicrophonePermissionAdapter) {
        self = IOSForegroundVoiceWorkflowPermissionOwner(
            adapter: adapter
        ).client
    }
}

/// Adds a bounded workflow wait even when the underlying system permission
/// sheet remains user-controlled. A late callback may refresh passive system
/// truth, but it cannot resume the retired Voice attempt.
@MainActor
final class IOSForegroundVoiceWorkflowPermissionOwner {
    typealias Sleep = @MainActor @Sendable (Duration) async throws -> Void

    nonisolated static let requestTimeout = Duration.seconds(120)

    private final class RequestRace {
        var continuation: CheckedContinuation<
            IOSForegroundVoiceWorkflowPermissionOutcome,
            Never
        >?
        var requestTask: Task<Void, Never>?
        var timeoutTask: Task<Void, Never>?
        var result: IOSForegroundVoiceWorkflowPermissionOutcome?

        func resolve(
            _ result: IOSForegroundVoiceWorkflowPermissionOutcome
        ) {
            guard self.result == nil else { return }
            self.result = result
            timeoutTask?.cancel()
            timeoutTask = nil
            requestTask = nil
            let continuation = continuation
            self.continuation = nil
            continuation?.resume(returning: result)
        }
    }

    private let adapter: IOSMicrophonePermissionAdapter
    private let sleep: Sleep
    private let timeout: Duration

    init(
        adapter: IOSMicrophonePermissionAdapter,
        timeout: Duration = requestTimeout,
        sleep: @escaping Sleep = { duration in
            try await ContinuousClock().sleep(for: duration)
        }
    ) {
        self.adapter = adapter
        self.timeout = timeout
        self.sleep = sleep
    }

    convenience init() {
        self.init(adapter: IOSMicrophonePermissionAdapter())
    }

    var client: IOSForegroundVoiceWorkflowPermissionClient {
        IOSForegroundVoiceWorkflowPermissionClient(
            read: { [adapter] in adapter.currentStatus() },
            requestIfUndetermined: { [self] in
                await requestIfUndetermined()
            }
        )
    }

    private func requestIfUndetermined() async
        -> IOSForegroundVoiceWorkflowPermissionOutcome {
        switch adapter.currentStatus() {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .unavailable:
            return .unavailable
        case .undetermined:
            break
        }
        guard !Task.isCancelled else { return .cancelled }

        let race = RequestRace()
        let adapter = adapter
        let sleep = sleep
        let timeout = timeout
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                race.continuation = continuation
                race.requestTask = Task { @MainActor in
                    let status = await adapter.requestIfUndetermined()
                    race.resolve(Self.map(status))
                }
                race.timeoutTask = Task { @MainActor in
                    do {
                        try await sleep(timeout)
                    } catch {
                        return
                    }
                    race.resolve(.timedOut)
                }
            }
        } onCancel: {
            Task { @MainActor in race.resolve(.cancelled) }
        }
    }

    private static func map(
        _ status: IOSMicrophonePermissionStatus
    ) -> IOSForegroundVoiceWorkflowPermissionOutcome {
        switch status {
        case .granted: .granted
        case .denied: .denied
        case .undetermined, .unavailable: .unavailable
        }
    }
}

/// Converts the UIKit assertion owner into the workflow's exact local-
/// finalization lease. Expiration closes provider admission in the workflow;
/// finishing the lease always ends the system assertion exactly once.
@MainActor
final class IOSForegroundVoiceWorkflowFinalizationOwner {
    private let backgroundTask: IOSForegroundFinalizationBackgroundTask

    init(backgroundTask: IOSForegroundFinalizationBackgroundTask) {
        self.backgroundTask = backgroundTask
    }

    convenience init() {
        self.init(backgroundTask: IOSForegroundFinalizationBackgroundTask())
    }

    func begin(
        onExpiration: @escaping @MainActor @Sendable () -> Void
    ) -> IOSForegroundVoiceWorkflowFinalizationLease? {
        guard let lease = backgroundTask.begin(onExpiration: { _ in
            onExpiration()
        }) else {
            return nil
        }
        return IOSForegroundVoiceWorkflowFinalizationLease {
            [backgroundTask] in
            backgroundTask.finish(lease)
        }
    }
}

/// Owns one process AVAudioSession adapter and maps only validated, content-
/// free platform events into the workflow. Output-only changes continue when
/// the frozen input tuple and format remain exact.
@MainActor
final class IOSForegroundVoiceWorkflowAudioOwner {
    private final class AttemptState {
        var frozenInput: IOSAudioSessionFrozenInput?
        var subscription: IOSAudioSessionEventSubscription?
    }

    private let adapter: IOSAudioSessionAdapter

    init(adapter: IOSAudioSessionAdapter) {
        self.adapter = adapter
    }

    convenience init() {
        self.init(adapter: IOSAudioSessionAdapter())
    }

    func activate() throws -> IOSForegroundVoiceWorkflowAudioLease {
        let token = IOSAudioSessionAttemptToken()
        try adapter.configureAndActivate(for: token)
        let state = AttemptState()

        return IOSForegroundVoiceWorkflowAudioLease(
            freezeAndValidate: { [adapter] in
                let current = try adapter.freezeCurrentInput(for: token)
                if let frozen = state.frozenInput, frozen != current {
                    throw IOSAudioSessionAdapterError.invalidInputIdentity
                }
                state.frozenInput = current
            },
            observe: { [adapter] receive in
                let subscription = adapter.observeEvents(
                    for: token
                ) { envelope in
                    guard let event = Self.map(
                        envelope.event,
                        frozenInput: state.frozenInput
                    ) else {
                        return
                    }
                    receive(event)
                }
                state.subscription = subscription
                return IOSForegroundVoiceWorkflowObservation {
                    subscription.cancel()
                    if state.subscription === subscription {
                        state.subscription = nil
                    }
                }
            },
            deactivate: { [adapter] in
                state.subscription?.cancel()
                state.subscription = nil
                try? adapter.deactivate(for: token)
            }
        )
    }

    private static func map(
        _ event: IOSAudioSessionEvent,
        frozenInput: IOSAudioSessionFrozenInput?
    ) -> IOSForegroundVoiceWorkflowAudioEvent? {
        switch event {
        case .interruptionBegan:
            return .interruption
        case .interruptionEnded:
            // Never auto-resume and never manufacture a new attempt.
            return nil
        case .routeChanged(_, let currentState),
             .inputMuteChanged(let currentState):
            return inputIsStillExact(currentState, frozenInput: frozenInput)
                ? nil
                : .routeInvalid
        case .mediaServicesLost:
            return .mediaServicesLost
        case .mediaServicesReset:
            return .mediaServicesReset
        }
    }

    private static func inputIsStillExact(
        _ state: IOSAudioSessionCurrentState,
        frozenInput: IOSAudioSessionFrozenInput?
    ) -> Bool {
        guard let frozenInput,
              state.isInputAvailable,
              !state.isInputMuted,
              state.sampleRate == frozenInput.sampleRate,
              state.inputNumberOfChannels
                == frozenInput.inputNumberOfChannels,
              state.inputPorts.count == 1,
              let input = state.inputPorts.first else {
            return false
        }
        return input.uid == frozenInput.uid
            && input.portType == frozenInput.portType
            && input.selectedDataSourceID
                == frozenInput.selectedDataSourceID
    }
}

extension IOSForegroundVoiceWorkflowFinalizationOwner:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowFinalizationOwner(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceWorkflowAudioOwner:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceWorkflowAudioOwner(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
