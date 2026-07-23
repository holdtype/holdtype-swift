import Foundation
import HoldTypeDomain

/// Containing-app owner for the single replaceable Keyboard Fix request.
/// Calls are serialized, but async dependency work remains cancellable.
actor IOSKeyboardFixProcessor {
    private struct ActiveRun {
        let id: UUID
        let task: Task<IOSKeyboardFixProcessorOutcome, Never>
    }

    private let bridge: IOSKeyboardFixBridgeClient
    private let catalog: IOSKeyboardFixCatalogClient
    private let settings: IOSKeyboardFixSettingsClient
    private let consent: IOSKeyboardFixConsentV4Client
    private let credential: IOSKeyboardFixCredentialClient
    private let executor: IOSKeyboardFixExecutionClient
    private let backgroundTask: IOSKeyboardFixBackgroundTaskClient
    private let clock: IOSKeyboardFixProcessorClock
    private let signals: IOSKeyboardFixSignalClient
    private var activeRun: ActiveRun?

    init(
        bridge: IOSKeyboardFixBridgeClient,
        catalog: IOSKeyboardFixCatalogClient,
        settings: IOSKeyboardFixSettingsClient,
        consent: IOSKeyboardFixConsentV4Client,
        credential: IOSKeyboardFixCredentialClient,
        executor: IOSKeyboardFixExecutionClient,
        backgroundTask: IOSKeyboardFixBackgroundTaskClient,
        clock: IOSKeyboardFixProcessorClock = .live,
        signals: IOSKeyboardFixSignalClient = .silent
    ) {
        self.bridge = bridge
        self.catalog = catalog
        self.settings = settings
        self.consent = consent
        self.credential = credential
        self.executor = executor
        self.backgroundTask = backgroundTask
        self.clock = clock
        self.signals = signals
    }

    deinit {
        activeRun?.task.cancel()
    }

    /// Consumes at most one request. A reentrant signal is rejected instead of
    /// being retained as an internal queue.
    func processPendingRequest() async -> IOSKeyboardFixProcessorOutcome {
        guard activeRun == nil else {
            signals.emit(.rejectedWhileBusy)
            return .busy
        }

        let observedAt = clock.now()
        let request: KeyboardFixRequestRecord
        do {
            guard let consumed = try bridge.consumeRequest(observedAt) else {
                return .noRequest
            }
            request = consumed
        } catch {
            signals.emit(.bridgeUnavailable)
            return .bridgeUnavailable
        }

        guard request.isValid(at: observedAt) else {
            signals.emit(
                .expired(
                    requestID: request.requestID,
                    actionIdentifier: request.actionIdentifier
                )
            )
            return .expired
        }

        let runID = UUID()
        let dependencies = IOSKeyboardFixProcessorRunDependencies(
            bridge: bridge,
            catalog: catalog,
            settings: settings,
            consent: consent,
            credential: credential,
            executor: executor,
            backgroundTask: backgroundTask,
            clock: clock,
            signals: signals
        )
        let task = Task {
            await IOSKeyboardFixProcessorRunEngine.run(
                request: request,
                dependencies: dependencies
            )
        }
        activeRun = ActiveRun(id: runID, task: task)

        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
        if activeRun?.id == runID {
            activeRun = nil
        }
        return outcome
    }

    func cancelActiveRequest() {
        activeRun?.task.cancel()
    }
}

nonisolated extension IOSKeyboardFixProcessor:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSKeyboardFixProcessor(redacted)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
