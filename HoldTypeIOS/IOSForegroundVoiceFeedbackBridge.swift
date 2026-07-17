import Foundation
import HoldTypeDomain

nonisolated struct IOSForegroundVoiceFeedbackAttemptHandle:
    Equatable,
    Hashable,
    Sendable {
    fileprivate let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

/// Narrow, fakeable surface over the single process boundary-feedback adapter.
nonisolated struct IOSForegroundVoiceFeedbackBridgeDriver: Sendable {
    let prepareStartBoundary: @MainActor @Sendable (
        IOSVoiceBoundaryFeedbackToken,
        IOSVoiceBoundaryFeedbackPreferences
    ) async -> IOSVoiceBoundaryStartResult
    let cancelStart: @MainActor @Sendable (
        IOSVoiceBoundaryFeedbackToken,
        IOSVoiceBoundaryStartCancellation
    ) -> Void
    let retainedCaptureDidBegin: @MainActor @Sendable (
        IOSVoiceBoundaryFeedbackToken
    ) -> Bool
    let abandonReadyBoundary: @MainActor @Sendable (
        IOSVoiceBoundaryFeedbackToken
    ) -> Bool
    let recorderDidClose: @MainActor @Sendable (
        IOSVoiceBoundaryFeedbackToken,
        IOSVoiceBoundaryRecorderCloseDisposition,
        IOSVoiceBoundaryFeedbackPreferences
    ) async -> IOSVoiceBoundaryStopResult
    let cancelSuccessFeedback: @MainActor @Sendable (
        IOSVoiceBoundaryFeedbackToken
    ) -> Void

    @MainActor
    init(adapter: IOSVoiceBoundaryFeedbackAdapter) {
        prepareStartBoundary = { [adapter] token, preferences in
            await adapter.prepareStartBoundary(
                for: token,
                preferences: preferences
            )
        }
        cancelStart = { [adapter] token, reason in
            adapter.cancelStart(for: token, reason: reason)
        }
        retainedCaptureDidBegin = { [adapter] token in
            adapter.retainedCaptureDidBegin(for: token)
        }
        abandonReadyBoundary = { [adapter] token in
            adapter.abandonReadyBoundary(for: token)
        }
        recorderDidClose = { [adapter] token, disposition, preferences in
            await adapter.recorderDidClose(
                for: token,
                disposition: disposition,
                preferences: preferences
            )
        }
        cancelSuccessFeedback = { [adapter] token in
            adapter.cancelSuccessFeedback(for: token)
        }
    }

    init(
        prepareStartBoundary: @escaping @MainActor @Sendable (
            IOSVoiceBoundaryFeedbackToken,
            IOSVoiceBoundaryFeedbackPreferences
        ) async -> IOSVoiceBoundaryStartResult,
        cancelStart: @escaping @MainActor @Sendable (
            IOSVoiceBoundaryFeedbackToken,
            IOSVoiceBoundaryStartCancellation
        ) -> Void,
        retainedCaptureDidBegin: @escaping @MainActor @Sendable (
            IOSVoiceBoundaryFeedbackToken
        ) -> Bool,
        abandonReadyBoundary: @escaping @MainActor @Sendable (
            IOSVoiceBoundaryFeedbackToken
        ) -> Bool,
        recorderDidClose: @escaping @MainActor @Sendable (
            IOSVoiceBoundaryFeedbackToken,
            IOSVoiceBoundaryRecorderCloseDisposition,
            IOSVoiceBoundaryFeedbackPreferences
        ) async -> IOSVoiceBoundaryStopResult,
        cancelSuccessFeedback: @escaping @MainActor @Sendable (
            IOSVoiceBoundaryFeedbackToken
        ) -> Void
    ) {
        self.prepareStartBoundary = prepareStartBoundary
        self.cancelStart = cancelStart
        self.retainedCaptureDidBegin = retainedCaptureDidBegin
        self.abandonReadyBoundary = abandonReadyBoundary
        self.recorderDidClose = recorderDidClose
        self.cancelSuccessFeedback = cancelSuccessFeedback
    }
}

/// Owns one feedback token from the start boundary through recorder close and
/// the optional Done-only success boundary.
@MainActor
final class IOSForegroundVoiceFeedbackBridge {
    typealias PlayLimitWarning = @MainActor @Sendable (
        VoiceSessionWarning,
        Bool
    ) -> Void

    private struct Attempt {
        let handle: IOSForegroundVoiceFeedbackAttemptHandle
        let token: IOSVoiceBoundaryFeedbackToken
        let preferences: IOSVoiceBoundaryFeedbackPreferences
    }

    private enum State {
        case starting(Attempt)
        case ready(Attempt)
        case capturing(Attempt)
        case closedForDone(Attempt)
        case closing(Attempt)
    }

    private let driver: IOSForegroundVoiceFeedbackBridgeDriver
    private let makeToken: @MainActor @Sendable () ->
        IOSVoiceBoundaryFeedbackToken
    private let playLimitWarningFeedback: PlayLimitWarning
    private var state: State?

    convenience init(
        client: IOSVoiceBoundaryFeedbackClient = .live(),
        diagnose: @escaping IOSVoiceBoundaryFeedbackAdapter
            .DiagnosticHandler = { _ in }
    ) {
        self.init(
            driver: IOSForegroundVoiceFeedbackBridgeDriver(
                adapter: IOSVoiceBoundaryFeedbackAdapter(
                    client: client,
                    diagnose: diagnose
                )
            )
        )
    }

    init(
        driver: IOSForegroundVoiceFeedbackBridgeDriver,
        makeToken: @escaping @MainActor @Sendable () ->
            IOSVoiceBoundaryFeedbackToken = {
                IOSVoiceBoundaryFeedbackToken()
            },
        playLimitWarningFeedback: @escaping PlayLimitWarning = {
            warning,
            audioCuesEnabled in
            IOSRecordingLimitWarningFeedback.shared.play(
                warning,
                audioCuesEnabled: audioCuesEnabled
            )
        }
    ) {
        self.driver = driver
        self.makeToken = makeToken
        self.playLimitWarningFeedback = playLimitWarningFeedback
    }

    /// Workflow start-boundary seam. Cue failure and the two-second watchdog
    /// remain fail-open only for the later frozen preflight revalidation.
    func playStartBoundary(audioCuesEnabled: Bool) async -> Bool {
        if case .closedForDone(let staleAttempt) = state {
            state = .closing(staleAttempt)
            _ = await driver.recorderDidClose(
                staleAttempt.token,
                .interrupted,
                staleAttempt.preferences
            )
            clearClosing(staleAttempt.token)
        }
        guard state == nil else { return false }
        let attempt = Attempt(
            handle: IOSForegroundVoiceFeedbackAttemptHandle(),
            token: makeToken(),
            preferences: .p4(audioCuesEnabled: audioCuesEnabled)
        )
        state = .starting(attempt)
        let result = await driver.prepareStartBoundary(
            attempt.token,
            attempt.preferences
        )
        guard isCurrent(attempt.token, phase: .starting) else {
            return false
        }
        switch result {
        case .completed, .cueUnavailable, .cueFailed, .timedOut:
            state = .ready(attempt)
            return true
        case .callerCancelled, .interrupted, .busy:
            state = nil
            return false
        }
    }

    /// Synchronous workflow cancellation seam used while the start boundary is
    /// still arming or waiting for recorder construction.
    func cancelStartBoundary() {
        switch state {
        case .starting(let attempt):
            state = nil
            driver.cancelStart(attempt.token, .callerCancelled)
        case .ready(let attempt):
            state = nil
            _ = driver.abandonReadyBoundary(attempt.token)
        case .capturing, .closedForDone, .closing, nil:
            break
        }
    }

    @discardableResult
    func retainedCaptureDidBegin(
        for handle: IOSForegroundVoiceFeedbackAttemptHandle
    ) -> Bool {
        guard case .ready(let attempt) = state,
              attempt.handle == handle else {
            return false
        }
        guard driver.retainedCaptureDidBegin(attempt.token) else {
            state = nil
            _ = driver.abandonReadyBoundary(attempt.token)
            return false
        }
        state = .capturing(attempt)
        return true
    }

    func retainedCaptureDidNotBegin(
        for handle: IOSForegroundVoiceFeedbackAttemptHandle
    ) {
        switch state {
        case .starting(let attempt) where attempt.handle == handle:
            state = nil
            driver.cancelStart(attempt.token, .callerCancelled)
        case .ready(let attempt) where attempt.handle == handle:
            state = nil
            _ = driver.abandonReadyBoundary(attempt.token)
        case .starting, .ready, .capturing, .closedForDone, .closing, nil:
            break
        }
    }

    func playLimitWarning(
        _ warning: VoiceSessionWarning,
        for handle: IOSForegroundVoiceFeedbackAttemptHandle
    ) {
        guard case .capturing(let attempt) = state,
              attempt.handle == handle else {
            return
        }
        playLimitWarningFeedback(
            warning,
            attempt.preferences.audioCuesEnabled
        )
    }

    /// Called only after the recorder adapter has closed or preserved its
    /// descriptor-bound source. Done retains the token until the workflow's
    /// explicit success-boundary seam; every other reason clears it now.
    func recorderDidClose(
        _ reason: IOSForegroundVoiceWorkflowCaptureStopReason,
        for handle: IOSForegroundVoiceFeedbackAttemptHandle
    ) async {
        guard case .capturing(let attempt) = state,
              attempt.handle == handle else {
            return
        }
        if reason == .done {
            state = .closedForDone(attempt)
            return
        }
        state = .closing(attempt)
        _ = await driver.recorderDidClose(
            attempt.token,
            Self.disposition(for: reason),
            attempt.preferences
        )
        clearClosing(attempt.token)
    }

    /// Workflow stop-boundary seam. Only an exact recorder-closed Done token
    /// can produce the success haptic/cue.
    func playStopBoundary(audioCuesEnabled: Bool) async {
        guard case .closedForDone(let attempt) = state else { return }
        state = .closing(attempt)
        _ = await driver.recorderDidClose(
            attempt.token,
            .success,
            .p4(audioCuesEnabled: audioCuesEnabled)
        )
        clearClosing(attempt.token)
    }

    /// Clears adapter and bridge state for interruption/media reset without a
    /// success cue. Repeated or stale resets are idempotent.
    func resetAfterInterruption() async {
        switch state {
        case .starting(let attempt):
            state = nil
            driver.cancelStart(attempt.token, .interrupted)
        case .ready(let attempt):
            state = nil
            _ = driver.abandonReadyBoundary(attempt.token)
        case .capturing(let attempt), .closedForDone(let attempt):
            state = .closing(attempt)
            _ = await driver.recorderDidClose(
                attempt.token,
                .interrupted,
                attempt.preferences
            )
            clearClosing(attempt.token)
        case .closing(let attempt):
            state = nil
            driver.cancelSuccessFeedback(attempt.token)
        case nil:
            break
        }
    }

    var hasActiveAttempt: Bool { state != nil }

    var recorderAttemptHandle: IOSForegroundVoiceFeedbackAttemptHandle? {
        switch state {
        case .ready(let attempt):
            attempt.handle
        case .starting, .capturing, .closedForDone, .closing, nil:
            nil
        }
    }

    private enum Phase {
        case starting
    }

    private func isCurrent(
        _ token: IOSVoiceBoundaryFeedbackToken,
        phase: Phase
    ) -> Bool {
        switch (phase, state) {
        case (.starting, .starting(let attempt)):
            attempt.token == token
        default:
            false
        }
    }

    private func clearClosing(_ token: IOSVoiceBoundaryFeedbackToken) {
        guard case .closing(let attempt) = state,
              attempt.token == token else {
            return
        }
        state = nil
    }

    private static func disposition(
        for reason: IOSForegroundVoiceWorkflowCaptureStopReason
    ) -> IOSVoiceBoundaryRecorderCloseDisposition {
        switch reason {
        case .done, .maximumDuration:
            .success
        case .cancelled:
            .cancelled
        case .interrupted:
            .interrupted
        }
    }
}

extension IOSForegroundVoiceFeedbackBridge:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundVoiceFeedbackBridge(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceFeedbackBridgeDriver:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoiceFeedbackBridgeDriver(<redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceFeedbackAttemptHandle:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoiceFeedbackAttemptHandle(<redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
