#if DEBUG
import AppKit
import Foundation

enum DevVlogsPhase0BTerminationOutcome: Equatable { case cleanupCompleted, cleanupTimedOut }
enum DevVlogsPhase0BTerminationState: Equatable { case active, harnessCompleted, cleanupPending, terminal }

@MainActor
final class DevVlogsPhase0BTerminationCoordinator {
    typealias Sleep = @MainActor (Duration) async throws -> Void
    private let timeout: Duration
    private let sleep: Sleep
    private var raceContinuation: CheckedContinuation<DevVlogsPhase0BTerminationOutcome, Never>?
    private var cleanupWorker: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private(set) var state = DevVlogsPhase0BTerminationState.active
    private(set) var outcome: DevVlogsPhase0BTerminationOutcome?
    var permitsNaturalTermination: Bool { state == .harnessCompleted }

    init(timeout: Duration, sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
        self.timeout = timeout
        self.sleep = sleep
    }

    func harnessDidComplete() -> Bool {
        guard state == .active else { return false }
        state = .harnessCompleted
        return true
    }

    func begin(
        cancelActive: () -> Void,
        cleanup: @escaping @MainActor () async -> Void,
        completion: @escaping @MainActor (DevVlogsPhase0BTerminationOutcome) -> Void
    ) -> NSApplication.TerminateReply {
        switch state {
        case .harnessCompleted:
            state = .terminal
            return .terminateNow
        case .cleanupPending:
            return .terminateLater
        case .terminal:
            return .terminateNow
        case .active:
            state = .cleanupPending
        }
        cancelActive()
        completionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.raceCleanup(cleanup)
            completion(outcome)
        }
        return .terminateLater
    }

    private func raceCleanup(_ cleanup: @escaping @MainActor () async -> Void)
        async -> DevVlogsPhase0BTerminationOutcome {
        await withCheckedContinuation { continuation in
            raceContinuation = continuation
            cleanupWorker = Task { @MainActor [weak self] in
                await cleanup()
                self?.finish(.cleanupCompleted)
            }
            timeoutTask = Task { @MainActor [weak self, timeout, sleep] in
                do { try await sleep(timeout) } catch { return }
                self?.finish(.cleanupTimedOut)
            }
        }
    }

    private func finish(_ outcome: DevVlogsPhase0BTerminationOutcome) {
        guard state == .cleanupPending, let continuation = raceContinuation else { return }
        raceContinuation = nil
        state = .terminal
        self.outcome = outcome
        cleanupWorker?.cancel()
        timeoutTask?.cancel()
        cleanupWorker = nil
        timeoutTask = nil
        continuation.resume(returning: outcome)
    }
}

@MainActor
final class DevVlogsPhase0BNaturalTerminationScheduler {
    private let enqueue: (@escaping @MainActor () -> Void) -> Void
    private var didSchedule = false

    init(enqueue: @escaping (@escaping @MainActor () -> Void) -> Void = { action in
        DispatchQueue.main.async { action() }
    }) {
        self.enqueue = enqueue
    }

    func schedule(_ action: @escaping @MainActor () -> Void) {
        guard !didSchedule else { return }
        didSchedule = true
        enqueue(action)
    }
}
#endif
