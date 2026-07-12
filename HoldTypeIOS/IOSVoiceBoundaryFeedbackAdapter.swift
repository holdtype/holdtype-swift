import AVFAudio
import Foundation
import UIKit

nonisolated struct IOSVoiceBoundaryFeedbackToken:
    Equatable,
    Hashable,
    Sendable
{
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

nonisolated struct IOSVoiceBoundaryFeedbackPreferences:
    Equatable,
    Sendable
{
    let audioCuesEnabled: Bool
    let hapticsEnabled: Bool
}

nonisolated enum IOSVoiceBoundaryCue: Equatable, Sendable {
    case start
    case successStop
}

nonisolated enum IOSVoiceBoundaryPlayerEvent: Equatable, Sendable {
    case completed
    case failed
}

nonisolated enum IOSVoiceBoundaryStartCancellation: Equatable, Sendable {
    case callerCancelled
    case interrupted
}

nonisolated enum IOSVoiceBoundaryStartResult:
    String,
    Equatable,
    Sendable
{
    case completed
    case cueUnavailable
    case cueFailed
    case timedOut
    case callerCancelled
    case interrupted
    case busy
}

nonisolated enum IOSVoiceBoundaryRecorderCloseDisposition:
    Equatable,
    Sendable
{
    case success
    case cancelled
    case interrupted
}

nonisolated enum IOSVoiceBoundaryStopResult:
    String,
    Equatable,
    Sendable
{
    case feedbackStarted
    case feedbackCompleted
    case feedbackSkipped
    case cueUnavailable
    case cueFailed
    case stale
    case busy
}

nonisolated enum IOSVoiceBoundaryFeedbackSystemError:
    Error,
    Equatable,
    Sendable
{
    case cueUnavailable
    case playerCreationFailed
}

nonisolated enum IOSVoiceBoundaryFeedbackDiagnostic:
    String,
    Equatable,
    Sendable
{
    case startBoundaryBegan = "start boundary began"
    case boundaryHapticDelivered = "boundary haptic delivered"
    case cueStarted = "boundary cue started"
    case cueStopped = "boundary cue stopped"
    case startBoundaryCompleted = "start boundary completed"
    case startBoundaryFailed = "start boundary failed"
    case startBoundaryCancelled = "start boundary cancelled"
    case startBoundaryTimedOut = "start boundary timed out"
    case retainedCaptureBegan = "retained capture began"
    case recorderCloseAccepted = "recorder close accepted"
    case successFeedbackSkipped = "success feedback skipped"
    case successFeedbackCompleted = "success feedback completed"
    case staleCallbackIgnored = "stale feedback callback ignored"
}

@MainActor
protocol IOSVoiceBoundaryAudioPlayer: AnyObject {
    func play() -> Bool
    func stop()
}

nonisolated struct IOSVoiceBoundaryFeedbackClient: Sendable {
    typealias PlayerEventHandler = @MainActor @Sendable (
        IOSVoiceBoundaryPlayerEvent
    ) -> Void
    typealias MakePlayer = @MainActor @Sendable (
        IOSVoiceBoundaryCue,
        @escaping PlayerEventHandler
    ) throws -> any IOSVoiceBoundaryAudioPlayer
    typealias PerformHaptic = @MainActor @Sendable () -> Void
    typealias Sleep = @MainActor @Sendable (Duration) async throws -> Void

    let makePlayer: MakePlayer
    let performHaptic: PerformHaptic
    let sleep: Sleep

    init(
        makePlayer: @escaping MakePlayer,
        performHaptic: @escaping PerformHaptic,
        sleep: @escaping Sleep
    ) {
        self.makePlayer = makePlayer
        self.performHaptic = performHaptic
        self.sleep = sleep
    }

    nonisolated static func live(
        startCueURL: URL?,
        successStopCueURL: URL?
    ) -> Self {
        Self(
            makePlayer: { cue, receive in
                let url: URL?
                switch cue {
                case .start:
                    url = startCueURL
                case .successStop:
                    url = successStopCueURL
                }
                guard let url else {
                    throw IOSVoiceBoundaryFeedbackSystemError.cueUnavailable
                }
                do {
                    return try IOSVoiceBoundaryAVAudioPlayer(
                        url: url,
                        receive: receive
                    )
                } catch {
                    throw IOSVoiceBoundaryFeedbackSystemError
                        .playerCreationFailed
                }
            },
            performHaptic: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.prepare()
                generator.impactOccurred()
            },
            sleep: { duration in
                try await ContinuousClock().sleep(for: duration)
            }
        )
    }
}

/// Coordinates only the audible and haptic boundaries around retained audio.
/// Recorder ownership and all permission, route, and persistence decisions stay
/// outside this adapter.
@MainActor
final class IOSVoiceBoundaryFeedbackAdapter {
    typealias DiagnosticHandler = @MainActor @Sendable (
        IOSVoiceBoundaryFeedbackDiagnostic
    ) -> Void

    nonisolated static let startCueWatchdogDuration: Duration = .seconds(2)

    private enum Phase {
        case idle
        case starting(ActiveStart)
        case readyForCapture(IOSVoiceBoundaryFeedbackToken)
        case capturing(IOSVoiceBoundaryFeedbackToken)
    }

    private final class ActiveStart {
        let token: IOSVoiceBoundaryFeedbackToken
        let generation: UInt64
        var player: (any IOSVoiceBoundaryAudioPlayer)?
        var watchdogTask: Task<Void, Never>?
        var continuation:
            CheckedContinuation<IOSVoiceBoundaryStartResult, Never>?
        var deferredPlayerEvent: IOSVoiceBoundaryPlayerEvent?
        var resolution: IOSVoiceBoundaryStartResult?
        private var playerWasStopped = false

        init(token: IOSVoiceBoundaryFeedbackToken, generation: UInt64) {
            self.token = token
            self.generation = generation
        }

        func stopPlayerOnce() -> Bool {
            guard !playerWasStopped, let player else { return false }
            playerWasStopped = true
            player.stop()
            return true
        }
    }

    private final class ActiveStop {
        let token: IOSVoiceBoundaryFeedbackToken
        let generation: UInt64
        var player: (any IOSVoiceBoundaryAudioPlayer)?
        var deferredPlayerEvent: IOSVoiceBoundaryPlayerEvent?
        var resolution: IOSVoiceBoundaryStopResult?
        private var playerWasStopped = false

        init(
            token: IOSVoiceBoundaryFeedbackToken,
            generation: UInt64
        ) {
            self.token = token
            self.generation = generation
        }

        func stopPlayerOnce() -> Bool {
            guard !playerWasStopped, let player else { return false }
            playerWasStopped = true
            player.stop()
            return true
        }
    }

    private let client: IOSVoiceBoundaryFeedbackClient
    private let diagnose: DiagnosticHandler
    private var phase = Phase.idle
    private var activeStop: ActiveStop?
    private var nextGeneration: UInt64 = 0

    init(
        client: IOSVoiceBoundaryFeedbackClient,
        diagnose: @escaping DiagnosticHandler = { _ in }
    ) {
        self.client = client
        self.diagnose = diagnose
    }

    func prepareStartBoundary(
        for token: IOSVoiceBoundaryFeedbackToken,
        preferences: IOSVoiceBoundaryFeedbackPreferences
    ) async -> IOSVoiceBoundaryStartResult {
        guard case .idle = phase, activeStop == nil else {
            return .busy
        }
        guard !Task.isCancelled else {
            return .callerCancelled
        }

        let generation = makeGeneration()
        let active = ActiveStart(token: token, generation: generation)
        phase = .starting(active)
        diagnose(.startBoundaryBegan)

        if preferences.hapticsEnabled {
            client.performHaptic()
            diagnose(.boundaryHapticDelivered)
            guard isCurrent(active) else {
                return active.resolution ?? .cueFailed
            }
        }
        guard preferences.audioCuesEnabled else {
            completeStart(active, with: .completed)
            return .completed
        }

        do {
            let player = try client.makePlayer(.start) {
                [weak self] event in
                self?.receiveStartPlayerEvent(
                    event,
                    token: token,
                    generation: generation
                )
            }
            active.player = player
            guard isCurrent(active) else {
                _ = active.stopPlayerOnce()
                return active.resolution ?? .cueFailed
            }
        } catch let error as IOSVoiceBoundaryFeedbackSystemError {
            guard isCurrent(active) else {
                return active.resolution ?? .cueFailed
            }
            let result: IOSVoiceBoundaryStartResult
            switch error {
            case .cueUnavailable:
                result = .cueUnavailable
            case .playerCreationFailed:
                result = .cueFailed
            }
            completeStart(active, with: result)
            return result
        } catch {
            guard isCurrent(active) else {
                return active.resolution ?? .cueFailed
            }
            completeStart(active, with: .cueFailed)
            return .cueFailed
        }

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                active.continuation = continuation
                if let event = active.deferredPlayerEvent {
                    active.deferredPlayerEvent = nil
                    receiveStartPlayerEvent(
                        event,
                        token: token,
                        generation: generation
                    )
                    return
                }
                guard isCurrent(active) else {
                    continuation.resume(
                        returning: active.resolution ?? .cueFailed
                    )
                    active.continuation = nil
                    return
                }
                let sleep = client.sleep
                active.watchdogTask = Task { @MainActor [weak self] in
                    do {
                        try await sleep(Self.startCueWatchdogDuration)
                    } catch {
                        return
                    }
                    self?.completeStartIfCurrent(
                        token: token,
                        generation: generation,
                        result: .timedOut
                    )
                }

                let didStart = active.player?.play() == true
                guard isCurrent(active) else { return }
                guard didStart else {
                    completeStart(active, with: .cueFailed)
                    return
                }
                diagnose(.cueStarted)
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.cancelStart(
                    for: token,
                    reason: .callerCancelled
                )
            }
        }
    }

    func cancelStart(
        for token: IOSVoiceBoundaryFeedbackToken,
        reason: IOSVoiceBoundaryStartCancellation
    ) {
        guard case let .starting(active) = phase,
              active.token == token else {
            diagnose(.staleCallbackIgnored)
            return
        }
        switch reason {
        case .callerCancelled:
            completeStart(active, with: .callerCancelled)
        case .interrupted:
            completeStart(active, with: .interrupted)
        }
    }

    @discardableResult
    func retainedCaptureDidBegin(
        for token: IOSVoiceBoundaryFeedbackToken
    ) -> Bool {
        guard case .readyForCapture(token) = phase else { return false }
        phase = .capturing(token)
        diagnose(.retainedCaptureBegan)
        return true
    }

    @discardableResult
    func abandonReadyBoundary(
        for token: IOSVoiceBoundaryFeedbackToken
    ) -> Bool {
        guard case .readyForCapture(token) = phase else { return false }
        phase = .idle
        return true
    }

    func recorderDidClose(
        for token: IOSVoiceBoundaryFeedbackToken,
        disposition: IOSVoiceBoundaryRecorderCloseDisposition,
        preferences: IOSVoiceBoundaryFeedbackPreferences
    ) -> IOSVoiceBoundaryStopResult {
        guard activeStop == nil else { return .busy }
        guard case .capturing(token) = phase else { return .stale }

        // The caller's recorder-close signal retires the capture phase before
        // either feedback surface can run.
        phase = .idle
        diagnose(.recorderCloseAccepted)

        guard disposition == .success else {
            diagnose(.successFeedbackSkipped)
            return .feedbackSkipped
        }

        if preferences.hapticsEnabled {
            client.performHaptic()
            diagnose(.boundaryHapticDelivered)
        }
        guard preferences.audioCuesEnabled else {
            if preferences.hapticsEnabled {
                diagnose(.successFeedbackCompleted)
                return .feedbackCompleted
            }
            diagnose(.successFeedbackSkipped)
            return .feedbackSkipped
        }

        let generation = makeGeneration()
        let active = ActiveStop(
            token: token,
            generation: generation
        )
        activeStop = active
        let player: any IOSVoiceBoundaryAudioPlayer
        do {
            player = try client.makePlayer(.successStop) {
                [weak self] event in
                self?.receiveStopPlayerEvent(
                    event,
                    token: token,
                    generation: generation
                )
            }
            active.player = player
            guard activeStop === active else {
                _ = active.stopPlayerOnce()
                return active.resolution ?? .stale
            }
        } catch let error as IOSVoiceBoundaryFeedbackSystemError {
            guard activeStop === active else {
                return active.resolution ?? .stale
            }
            let result: IOSVoiceBoundaryStopResult = switch error {
            case .cueUnavailable:
                .cueUnavailable
            case .playerCreationFailed:
                .cueFailed
            }
            active.resolution = result
            activeStop = nil
            return result
        } catch {
            guard activeStop === active else {
                return active.resolution ?? .stale
            }
            active.resolution = .cueFailed
            activeStop = nil
            return .cueFailed
        }

        if let event = active.deferredPlayerEvent {
            active.deferredPlayerEvent = nil
            resolveStopPlayerEvent(active, event: event)
            return active.resolution ?? .cueFailed
        }

        let didStart = player.play()
        guard activeStop === active else {
            return active.resolution ?? .stale
        }
        guard didStart else {
            resolveStopPlayerEvent(active, event: .failed)
            return .cueFailed
        }
        diagnose(.cueStarted)
        return .feedbackStarted
    }

    func cancelSuccessFeedback(
        for token: IOSVoiceBoundaryFeedbackToken
    ) {
        guard let activeStop, activeStop.token == token else {
            diagnose(.staleCallbackIgnored)
            return
        }
        activeStop.resolution = .feedbackSkipped
        stopActiveStop(activeStop)
    }

    private func receiveStartPlayerEvent(
        _ event: IOSVoiceBoundaryPlayerEvent,
        token: IOSVoiceBoundaryFeedbackToken,
        generation: UInt64
    ) {
        guard case let .starting(active) = phase,
              active.token == token,
              active.generation == generation else {
            diagnose(.staleCallbackIgnored)
            return
        }
        guard active.player != nil,
              active.continuation != nil else {
            guard active.deferredPlayerEvent == nil else {
                diagnose(.staleCallbackIgnored)
                return
            }
            active.deferredPlayerEvent = event
            return
        }

        let result: IOSVoiceBoundaryStartResult
        switch event {
        case .completed:
            result = .completed
        case .failed:
            result = .cueFailed
        }
        completeStartIfCurrent(
            token: token,
            generation: generation,
            result: result
        )
    }

    private func isCurrent(_ active: ActiveStart) -> Bool {
        guard case let .starting(current) = phase else { return false }
        return current === active
    }

    private func completeStartIfCurrent(
        token: IOSVoiceBoundaryFeedbackToken,
        generation: UInt64,
        result: IOSVoiceBoundaryStartResult
    ) {
        guard case let .starting(active) = phase,
              active.token == token,
              active.generation == generation else {
            diagnose(.staleCallbackIgnored)
            return
        }
        completeStart(active, with: result)
    }

    private func completeStart(
        _ active: ActiveStart,
        with result: IOSVoiceBoundaryStartResult
    ) {
        guard case let .starting(current) = phase,
              current === active,
              active.resolution == nil else {
            diagnose(.staleCallbackIgnored)
            return
        }

        active.resolution = result

        active.watchdogTask?.cancel()
        active.watchdogTask = nil
        if active.stopPlayerOnce() {
            diagnose(.cueStopped)
        }

        switch result {
        case .completed, .cueUnavailable, .cueFailed, .timedOut:
            phase = .readyForCapture(active.token)
        case .callerCancelled, .interrupted, .busy:
            phase = .idle
        }

        switch result {
        case .completed:
            diagnose(.startBoundaryCompleted)
        case .timedOut:
            diagnose(.startBoundaryTimedOut)
        case .callerCancelled, .interrupted:
            diagnose(.startBoundaryCancelled)
        case .cueUnavailable, .cueFailed, .busy:
            diagnose(.startBoundaryFailed)
        }

        let continuation = active.continuation
        active.continuation = nil
        continuation?.resume(returning: result)
    }

    private func receiveStopPlayerEvent(
        _ event: IOSVoiceBoundaryPlayerEvent,
        token: IOSVoiceBoundaryFeedbackToken,
        generation: UInt64
    ) {
        guard let activeStop,
              activeStop.token == token,
              activeStop.generation == generation else {
            diagnose(.staleCallbackIgnored)
            return
        }
        guard activeStop.player != nil else {
            guard activeStop.deferredPlayerEvent == nil else {
                diagnose(.staleCallbackIgnored)
                return
            }
            activeStop.deferredPlayerEvent = event
            return
        }
        resolveStopPlayerEvent(activeStop, event: event)
    }

    private func resolveStopPlayerEvent(
        _ active: ActiveStop,
        event: IOSVoiceBoundaryPlayerEvent
    ) {
        guard activeStop === active, active.resolution == nil else {
            diagnose(.staleCallbackIgnored)
            return
        }
        active.resolution = event == .completed
            ? .feedbackCompleted
            : .cueFailed
        stopActiveStop(active)
        if event == .completed { diagnose(.successFeedbackCompleted) }
    }

    private func stopActiveStop(_ active: ActiveStop) {
        guard activeStop === active else {
            diagnose(.staleCallbackIgnored)
            return
        }
        if active.stopPlayerOnce() {
            diagnose(.cueStopped)
        }
        activeStop = nil
    }

    private func makeGeneration() -> UInt64 {
        nextGeneration &+= 1
        if nextGeneration == 0 { nextGeneration = 1 }
        return nextGeneration
    }
}

@MainActor
private final class IOSVoiceBoundaryAVAudioPlayer:
    NSObject,
    AVAudioPlayerDelegate,
    IOSVoiceBoundaryAudioPlayer
{
    private let player: AVAudioPlayer
    private let receive:
        IOSVoiceBoundaryFeedbackClient.PlayerEventHandler

    init(
        url: URL,
        receive: @escaping IOSVoiceBoundaryFeedbackClient.PlayerEventHandler
    ) throws {
        player = try AVAudioPlayer(contentsOf: url)
        self.receive = receive
        super.init()
        player.delegate = self
        guard player.prepareToPlay() else {
            throw IOSVoiceBoundaryFeedbackSystemError.playerCreationFailed
        }
    }

    func play() -> Bool {
        player.play()
    }

    func stop() {
        player.stop()
    }

    func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool
    ) {
        receive(flag ? .completed : .failed)
    }

    func audioPlayerDecodeErrorDidOccur(
        _ player: AVAudioPlayer,
        error: Error?
    ) {
        receive(.failed)
    }
}

extension IOSVoiceBoundaryFeedbackToken:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    var description: String {
        "IOSVoiceBoundaryFeedbackToken(<redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSVoiceBoundaryFeedbackClient:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    var description: String {
        "IOSVoiceBoundaryFeedbackClient(<redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSVoiceBoundaryFeedbackAdapter:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    nonisolated var description: String {
        "IOSVoiceBoundaryFeedbackAdapter(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
