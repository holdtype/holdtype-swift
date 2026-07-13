import HoldTypePersistence
import SwiftUI

@MainActor
final class IOSContainingAppLifecycleScheduler {
    typealias Recovery = @Sendable (
        IOSContainingAppRecoveryOpportunity
    ) async -> IOSContainingAppRecoveryDisposition

    private let recover: Recovery
    private var activeTask: Task<Void, Never>?
    // Signals may request one bounded follow-up pass, but a disposition never
    // creates an automatic retry loop.
    private var pendingOpportunity:
        IOSContainingAppRecoveryOpportunity?
    private var processLaunchRecoveryCompleted = false
    private var observedInitialScenePhase = false
    private var initialActivationCoveredByLaunch = false

    private(set) var latestDisposition:
        IOSContainingAppRecoveryDisposition = .pendingLocalRecovery

    init(recover: @escaping Recovery) {
        self.recover = recover
    }

    func scheduleProcessLaunch() {
        enqueue(.processLaunch)
    }

    func scheduleForeground() {
        enqueue(.foreground)
    }

    func observeScenePhase(
        _ phase: ScenePhase,
        isInitialObservation: Bool
    ) {
        if !observedInitialScenePhase {
            observedInitialScenePhase = true
            initialActivationCoveredByLaunch = phase == .active
            return
        }
        if isInitialObservation {
            if phase == .active {
                initialActivationCoveredByLaunch = true
            }
            return
        }
        guard phase == .active else { return }
        guard initialActivationCoveredByLaunch else {
            initialActivationCoveredByLaunch = true
            return
        }
        scheduleForeground()
    }

    func waitUntilIdle() async {
        while let task = activeTask {
            await task.value
        }
    }

    private func enqueue(
        _ signal: IOSContainingAppRecoveryOpportunity
    ) {
        pendingOpportunity = merged(
            pendingOpportunity,
            with: signal
        )
        startNextIfNeeded()
    }

    private func startNextIfNeeded() {
        guard activeTask == nil,
              let opportunity = takeNextOpportunity() else {
            return
        }
        let recover = recover
        activeTask = Task { [weak self] in
            let disposition = await recover(opportunity)
            guard let self else { return }
            finish(
                opportunity,
                disposition: disposition
            )
        }
    }

    private func takeNextOpportunity()
        -> IOSContainingAppRecoveryOpportunity? {
        guard let pendingOpportunity else { return nil }
        self.pendingOpportunity = nil
        if pendingOpportunity == .foreground,
           !processLaunchRecoveryCompleted {
            return .processLaunch
        }
        return pendingOpportunity
    }

    private func merged(
        _ pending: IOSContainingAppRecoveryOpportunity?,
        with signal: IOSContainingAppRecoveryOpportunity
    ) -> IOSContainingAppRecoveryOpportunity {
        guard let pending else { return signal }
        // Launch recovery is the stronger opportunity and covers coalesced
        // foreground work while preserving launch-before-foreground ordering.
        return switch (pending, signal) {
        case (.processLaunch, _), (_, .processLaunch):
            .processLaunch
        case (.foreground, .foreground):
            .foreground
        }
    }

    private func finish(
        _ opportunity: IOSContainingAppRecoveryOpportunity,
        disposition: IOSContainingAppRecoveryDisposition
    ) {
        latestDisposition = disposition
        if opportunity == .processLaunch,
           disposition == .complete {
            processLaunchRecoveryCompleted = true
        }
        activeTask = nil
        startNextIfNeeded()
    }

    deinit {
        activeTask?.cancel()
    }
}
