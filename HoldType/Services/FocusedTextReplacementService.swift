import AppKit
import Foundation

@MainActor
protocol ExternalApplicationActivating {
    func activate(processIdentifier: pid_t) -> Bool
}

@MainActor
struct NSWorkspaceExternalApplicationActivator:
    ExternalApplicationActivating {
    func activate(processIdentifier: pid_t) -> Bool {
        guard let application = NSRunningApplication(
            processIdentifier: processIdentifier
        ) else {
            return false
        }
        return application.activate(options: [.activateIgnoringOtherApps])
    }
}

protocol FocusedTextReplacementSleeping: Sendable {
    func sleep(seconds: TimeInterval) async throws
}

struct TaskFocusedTextReplacementSleeper:
    FocusedTextReplacementSleeping {
    func sleep(seconds: TimeInterval) async throws {
        guard seconds > 0 else {
            return
        }
        try await Task.sleep(
            nanoseconds: UInt64(seconds * 1_000_000_000)
        )
    }
}

@MainActor
struct FocusedTextReplacementService {
    static let defaultReplacementTimeout: TimeInterval = 5
    static let defaultFocusAttemptCount = 20
    static let defaultFocusRetryDelay: TimeInterval = 0.05

    private let targetService: FocusedTextTargetService
    private let applicationActivator: any ExternalApplicationActivating
    private let textEventPoster: any TextEventPosting
    private let sleeper: any FocusedTextReplacementSleeping
    private let replacementTimeout: TimeInterval
    private let focusAttemptCount: Int
    private let focusRetryDelay: TimeInterval

    init() {
        self.init(
            targetService: FocusedTextTargetService(),
            applicationActivator: NSWorkspaceExternalApplicationActivator(),
            textEventPoster: CGEventTextEventPoster(),
            sleeper: TaskFocusedTextReplacementSleeper(),
            replacementTimeout: Self.defaultReplacementTimeout,
            focusAttemptCount: Self.defaultFocusAttemptCount,
            focusRetryDelay: Self.defaultFocusRetryDelay
        )
    }

    init(
        targetService: FocusedTextTargetService,
        applicationActivator: any ExternalApplicationActivating,
        textEventPoster: any TextEventPosting,
        sleeper: any FocusedTextReplacementSleeping,
        replacementTimeout: TimeInterval,
        focusAttemptCount: Int,
        focusRetryDelay: TimeInterval
    ) {
        self.targetService = targetService
        self.applicationActivator = applicationActivator
        self.textEventPoster = textEventPoster
        self.sleeper = sleeper
        self.replacementTimeout = replacementTimeout > 0
            ? replacementTimeout
            : Self.defaultReplacementTimeout
        self.focusAttemptCount = max(1, focusAttemptCount)
        self.focusRetryDelay = max(0, focusRetryDelay)
    }

    func replace(
        snapshot: FocusedTextTargetSnapshot,
        with output: String
    ) async throws {
        guard !output.isEmpty else {
            throw FocusedTextTargetError.replacementFailed
        }
        try Task.checkCancellation()
        try targetService.validate(snapshot)

        guard applicationActivator.activate(
            processIdentifier: snapshot.processIdentifier
        ) else {
            throw FocusedTextTargetError.focusRestorationFailed
        }

        try await restoreAndValidateTarget(snapshot)
        try await postWithTimeout(output)
    }

    private func restoreAndValidateTarget(
        _ snapshot: FocusedTextTargetSnapshot
    ) async throws {
        for attempt in 0..<focusAttemptCount {
            try Task.checkCancellation()

            do {
                try targetService.restoreFocusAndReplacementRange(
                    for: snapshot
                )
                try targetService.validateFocusedReplacementRange(
                    snapshot
                )
                return
            } catch {
                guard attempt + 1 < focusAttemptCount else {
                    throw FocusedTextTargetError.focusRestorationFailed
                }
                try await sleeper.sleep(seconds: focusRetryDelay)
            }
        }
    }

    private func postWithTimeout(_ output: String) async throws {
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await textEventPoster.postText(output)
                }
                group.addTask {
                    try await sleeper.sleep(seconds: replacementTimeout)
                    throw FocusedTextTargetError.replacementTimedOut
                }

                defer {
                    group.cancelAll()
                }
                guard let _ = try await group.next() else {
                    throw FocusedTextTargetError.replacementFailed
                }
            }
        } catch let error as FocusedTextTargetError {
            throw error
        } catch is CancellationError {
            throw FocusedTextTargetError.cancelled
        } catch {
            throw FocusedTextTargetError.replacementFailed
        }
    }
}
