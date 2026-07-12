import HoldTypePersistence
import SwiftUI

@MainActor
final class IOSContainingAppLifecycleScheduler {
    typealias Recovery = @Sendable (
        IOSContainingAppRecoveryOpportunity
    ) async -> IOSContainingAppRecoveryDisposition

    private let recover: Recovery
    private var activeTask: Task<Void, Never>?
    private var processLaunchRecoveryCompleted = false
    private var observedInitialScenePhase = false
    private var initialActivationCoveredByLaunch = false

    private(set) var latestDisposition:
        IOSContainingAppRecoveryDisposition = .pendingLocalRecovery

    init(recover: @escaping Recovery) {
        self.recover = recover
    }

    func scheduleProcessLaunch() {
        schedule(.processLaunch)
    }

    func scheduleForeground() {
        schedule(
            processLaunchRecoveryCompleted ? .foreground : .processLaunch
        )
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
        let task = activeTask
        await task?.value
    }

    private func schedule(
        _ opportunity: IOSContainingAppRecoveryOpportunity
    ) {
        guard activeTask == nil else { return }
        let recover = recover
        activeTask = Task { [weak self] in
            let disposition = await recover(opportunity)
            guard let self else { return }
            latestDisposition = disposition
            if opportunity == .processLaunch,
               disposition == .complete {
                processLaunchRecoveryCompleted = true
            }
            activeTask = nil
        }
    }
}
