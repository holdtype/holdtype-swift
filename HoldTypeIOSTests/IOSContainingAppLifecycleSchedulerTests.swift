import HoldTypePersistence
import SwiftUI
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSContainingAppLifecycleSchedulerTests {
    @Test func launchInitialActivationAndConcurrentSignalsCoalesce()
        async throws {
        let firstPass = LifecycleRecoveryLatch()
        let recorder = LifecycleRecoveryRecorder(
            results: [.pendingLocalRecovery, .complete, .complete],
            firstPass: firstPass
        )
        let scheduler = IOSContainingAppLifecycleScheduler { opportunity in
            await recorder.recover(opportunity)
        }

        scheduler.scheduleProcessLaunch()
        try await lifecycleEventually {
            await recorder.opportunities().count == 1
        }
        scheduler.scheduleForeground()
        scheduler.scheduleForeground()
        scheduler.observeScenePhase(.inactive, isInitialObservation: true)
        scheduler.observeScenePhase(.active, isInitialObservation: false)
        #expect(await recorder.opportunities() == [.processLaunch])

        await firstPass.open()
        await scheduler.waitUntilIdle()
        #expect(scheduler.latestDisposition == .pendingLocalRecovery)

        scheduler.observeScenePhase(.background, isInitialObservation: false)
        scheduler.observeScenePhase(.active, isInitialObservation: false)
        await scheduler.waitUntilIdle()
        #expect(
            await recorder.opportunities()
                == [.processLaunch, .processLaunch]
        )
        #expect(scheduler.latestDisposition == .complete)

        scheduler.observeScenePhase(.inactive, isInitialObservation: false)
        scheduler.observeScenePhase(.active, isInitialObservation: false)
        await scheduler.waitUntilIdle()
        #expect(
            await recorder.opportunities()
                == [.processLaunch, .processLaunch, .foreground]
        )
    }

    @Test func laterSceneInitialObservationCannotResetProcessActivation()
        async {
        let recorder = LifecycleRecoveryRecorder(
            results: [.complete, .complete]
        )
        let scheduler = IOSContainingAppLifecycleScheduler { opportunity in
            await recorder.recover(opportunity)
        }

        scheduler.scheduleProcessLaunch()
        scheduler.observeScenePhase(.active, isInitialObservation: true)
        await scheduler.waitUntilIdle()
        scheduler.observeScenePhase(.inactive, isInitialObservation: true)
        scheduler.observeScenePhase(.background, isInitialObservation: false)
        scheduler.observeScenePhase(.active, isInitialObservation: false)
        await scheduler.waitUntilIdle()

        #expect(
            await recorder.opportunities()
                == [.processLaunch, .foreground]
        )
    }
}

private actor LifecycleRecoveryRecorder {
    private let results: [IOSContainingAppRecoveryDisposition]
    private let firstPass: LifecycleRecoveryLatch?
    private var calls: [IOSContainingAppRecoveryOpportunity] = []

    init(
        results: [IOSContainingAppRecoveryDisposition],
        firstPass: LifecycleRecoveryLatch? = nil
    ) {
        self.results = results
        self.firstPass = firstPass
    }

    func recover(
        _ opportunity: IOSContainingAppRecoveryOpportunity
    ) async -> IOSContainingAppRecoveryDisposition {
        let index = calls.count
        calls.append(opportunity)
        if index == 0, let firstPass {
            await firstPass.wait()
        }
        guard results.indices.contains(index) else {
            return .pendingLocalRecovery
        }
        return results[index]
    }

    func opportunities() -> [IOSContainingAppRecoveryOpportunity] {
        calls
    }
}

private actor LifecycleRecoveryLatch {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            if isOpen {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let waiters = waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private func lifecycleEventually(
    _ predicate: @escaping @Sendable () async -> Bool
) async throws {
    for _ in 0..<100 {
        if await predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for containing-app lifecycle recovery.")
}
