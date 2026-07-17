import Foundation
import HoldTypeDomain
import Observation
@_spi(HoldTypeIOSCore) import HoldTypePersistence

enum IOSPendingRecordingHistoryStatus: Equatable, Sendable {
    case ready
    case processing(IOSPendingRecordingHistoryProcessingStage)
    case failed
    case blocked

    var isProcessing: Bool {
        if case .processing = self { return true }
        return false
    }
}

enum IOSPendingRecordingHistoryProcessingStage: Equatable, Sendable {
    case transcribing
    case postProcessing
    case savingResult
}

enum IOSPendingRecordingHistoryBlockReason: Equatable, Sendable {
    case audioUnavailable
    case durationLimitExceeded
    case providerResultUnrecoverable
}

enum IOSPendingRecordingHistoryPrimaryAction: Equatable, Sendable {
    case transcribe
    case retry
}

struct IOSPendingRecordingHistorySnapshotToken: Equatable, Sendable {
    typealias Source = IOSV1SavedRecordingExpectation

    let attemptID: UUID
    let source: Source

    fileprivate init(recording: IOSV1PendingRecording) {
        attemptID = recording.attemptID
        source = .pending(
            IOSV1PendingRecordingExpectation(recording: recording)
        )
    }

    fileprivate init(
        recording: IOSV1CompletedCaptureRecoveryObservation
    ) {
        attemptID = recording.attemptID
        source = .completedCapture(
            IOSV1CompletedCaptureRecoveryExpectation(recording: recording)
        )
    }
}

struct IOSPendingRecordingHistoryCard: Equatable, Identifiable, Sendable {
    let id: UUID
    let status: IOSPendingRecordingHistoryStatus
    let durationMilliseconds: Int64?
    let isPlayable: Bool
    let blockedReason: IOSPendingRecordingHistoryBlockReason?
    let token: IOSPendingRecordingHistorySnapshotToken

    var primaryAction: IOSPendingRecordingHistoryPrimaryAction? {
        switch status {
        case .ready: .transcribe
        case .failed: .retry
        case .processing, .blocked: nil
        }
    }

    var durationText: String? {
        guard let durationMilliseconds else { return nil }
        let totalSeconds = max(
            0,
            Int((Double(durationMilliseconds) / 1_000).rounded())
        )
        return String(
            format: "%d:%02d",
            totalSeconds / 60,
            totalSeconds % 60
        )
    }
}

enum IOSPendingRecordingHistoryState: Equatable, Sendable {
    case notLoaded
    case absent
    case ready(IOSPendingRecordingHistoryCard)
    case loadFailed(lastConfirmed: IOSPendingRecordingHistoryCard?)

    var card: IOSPendingRecordingHistoryCard? {
        switch self {
        case .ready(let card), .loadFailed(.some(let card)):
            card
        case .notLoaded, .absent, .loadFailed(lastConfirmed: nil):
            nil
        }
    }

    var isStale: Bool {
        if case .loadFailed = self { return true }
        return false
    }

    /// A failed read cannot prove that recoverable audio is absent. Keep a
    /// visible, refreshable recovery surface until a successful load confirms
    /// either the exact recording or its absence.
    var shouldPresentSavedRecording: Bool {
        switch self {
        case .ready, .loadFailed:
            true
        case .notLoaded, .absent:
            false
        }
    }

    var isConfirmedAbsent: Bool {
        self == .absent
    }
}

enum IOSPendingRecordingHistoryOperation: Equatable, Sendable {
    case idle
    case refreshing
    case playing(UUID)
    case retrying(UUID)
    case discarding(UUID)
}

enum IOSPendingRecordingHistoryNotice: Equatable, Sendable {
    case recordingInterruptedAndSaved
    case playbackFailed
    case retryFailed
    case discardFailed
    case recordingChanged

    var message: String {
        switch self {
        case .recordingInterruptedAndSaved:
            "Recording interrupted — saved to History."
        case .playbackFailed:
            "HoldType couldn't play this saved recording."
        case .retryFailed:
            "Transcription couldn't start. The recording is still saved."
        case .discardFailed:
            "The saved recording couldn't be discarded. Nothing was removed."
        case .recordingChanged:
            "The saved recording changed. Review its current status and try again."
        }
    }
}

@MainActor
struct IOSPendingRecordingHistoryActions {
    typealias Load = () async throws
        -> IOSV1SavedRecordingObservation?
    typealias Play = (IOSPendingRecordingHistorySnapshotToken) async
        -> IOSHistoryPlaybackAttempt
    typealias Mutation = (IOSPendingRecordingHistorySnapshotToken) async
        -> Bool

    let supportsPlayback: Bool
    private let loadAction: Load
    private let playAction: Play
    private let retryAction: Mutation
    private let discardAction: Mutation
    private let stopAction: () async -> Void

    init(
        persistenceOwner: IOSV1ForegroundVoicePersistenceOwner,
        savedRecordingClient: IOSSavedRecordingWorkflowClient,
        player: IOSHistoryAudioPlaybackOwner?
    ) {
        supportsPlayback = player != nil
        loadAction = { try await persistenceOwner.loadSavedRecording() }
        playAction = { token in
            guard let player,
                  let current = try? await persistenceOwner
                    .loadSavedRecording() else {
                return .unavailable
            }
            do {
                let audio: IOSV1PendingRecordingPlaybackAudio
                switch (token.source, current) {
                case let (.pending(expected), .pending(observation))
                    where observation.expectation == expected
                        && observation.availability == .available:
                    audio = try await persistenceOwner
                        .preparePendingPlaybackAudio(expected: expected)
                case let (
                    .completedCapture(expected),
                    .completedCapture(observation)
                ) where IOSV1CompletedCaptureRecoveryExpectation(
                    recording: observation
                ) == expected && observation.availability == .available:
                    audio = try await persistenceOwner
                        .prepareCompletedCapturePlaybackAudio(
                            expected: expected
                        )
                default:
                    return .unavailable
                }
                return player.playPendingAudio(audio)
                    ? .played : .failed
            } catch {
                return .unavailable
            }
        }
        retryAction = { token in
            guard let current = try? await persistenceOwner
                .loadSavedRecording(),
                  Self.matches(token, current),
                  Self.isAvailable(current) else {
                return false
            }
            return await savedRecordingClient.retry(expected: token.source)
        }
        discardAction = { token in
            guard let current = try? await persistenceOwner
                .loadSavedRecording(),
                  Self.matches(token, current) else {
                return false
            }
            do {
                switch token.source {
                case .pending(let expected):
                    _ = try await persistenceOwner.discard(expected: expected)
                case .completedCapture(let expected):
                    try await persistenceOwner.discardCapture(
                        expected: expected
                    )
                }
                return true
            } catch {
                return false
            }
        }
        stopAction = {
            guard let player else { return }
            _ = await player.stopAndDeactivate()
        }
    }

    init(
        supportsPlayback: Bool = true,
        load: @escaping Load,
        play: @escaping Play = { _ in .unavailable },
        retry: @escaping Mutation = { _ in false },
        discard: @escaping Mutation = { _ in false },
        stop: @escaping () async -> Void = {}
    ) {
        self.supportsPlayback = supportsPlayback
        loadAction = load
        playAction = play
        retryAction = retry
        discardAction = discard
        stopAction = stop
    }

    func load() async throws -> IOSV1SavedRecordingObservation? {
        try await loadAction()
    }

    func play(
        token: IOSPendingRecordingHistorySnapshotToken
    ) async -> IOSHistoryPlaybackAttempt {
        await playAction(token)
    }

    func retry(
        token: IOSPendingRecordingHistorySnapshotToken
    ) async -> Bool {
        await retryAction(token)
    }

    func discard(
        token: IOSPendingRecordingHistorySnapshotToken
    ) async -> Bool {
        await discardAction(token)
    }

    func stop() async {
        await stopAction()
    }

    private static func matches(
        _ token: IOSPendingRecordingHistorySnapshotToken,
        _ observation: IOSV1SavedRecordingObservation
    ) -> Bool {
        switch (token.source, observation) {
        case let (.pending(expected), .pending(current)):
            current.expectation == expected
        case let (
            .completedCapture(expected),
            .completedCapture(current)
        ):
            IOSV1CompletedCaptureRecoveryExpectation(recording: current)
                == expected
        default:
            false
        }
    }

    private static func isAvailable(
        _ observation: IOSV1SavedRecordingObservation
    ) -> Bool {
        switch observation {
        case .pending(let pending):
            pending.availability == .available
        case .completedCapture(let capture):
            capture.availability == .available
        }
    }
}

@MainActor
@Observable
final class IOSPendingRecordingHistoryStateOwner {
    private(set) var state = IOSPendingRecordingHistoryState.notLoaded
    private(set) var operation = IOSPendingRecordingHistoryOperation.idle
    private(set) var notice: IOSPendingRecordingHistoryNotice?

    @ObservationIgnored
    private let actions: IOSPendingRecordingHistoryActions
    @ObservationIgnored
    private var interruptionRefreshIsPending = false

    init(actions: IOSPendingRecordingHistoryActions) {
        self.actions = actions
    }

    var card: IOSPendingRecordingHistoryCard? { state.card }
    var isBusy: Bool { operation != .idle }
    var shouldPresentSavedRecording: Bool {
        state.shouldPresentSavedRecording
    }
    var isConfirmedAbsent: Bool { state.isConfirmedAbsent }

    @discardableResult
    func refresh() async -> Bool {
        guard begin(.refreshing) else { return false }
        let result = await reload(clearNoticeOnSuccess: true)
        complete()
        return result
    }

    /// Reloads the exact durable recording after an involuntary stop. The
    /// success notice is published only after the canonical owner confirms a
    /// locally playable source, so UI never claims that uncertain audio was
    /// saved. A concurrent History action coalesces the request and performs
    /// one refresh when that action completes.
    @discardableResult
    func refreshAfterInterruption() async -> Bool {
        guard begin(.refreshing) else {
            interruptionRefreshIsPending = true
            return false
        }
        let loaded = await reload(clearNoticeOnSuccess: false)
        let confirmedPlayable = loaded && state.card?.isPlayable == true
        if confirmedPlayable {
            notice = .recordingInterruptedAndSaved
        } else if notice == .recordingInterruptedAndSaved {
            notice = nil
        }
        complete()
        return confirmedPlayable
    }

    func dismissNotice() {
        notice = nil
    }

    func play(
        ifCurrent token: IOSPendingRecordingHistorySnapshotToken
    ) async {
        guard let card = currentCard(matching: token),
              card.isPlayable,
              begin(.playing(token.attemptID)) else {
            notice = .recordingChanged
            return
        }
        switch await actions.play(token: token) {
        case .played:
            notice = nil
        case .unavailable:
            notice = .recordingChanged
            _ = await reload(clearNoticeOnSuccess: false)
        case .failed:
            notice = .playbackFailed
        }
        complete()
    }

    func retry(
        ifCurrent token: IOSPendingRecordingHistorySnapshotToken
    ) async {
        guard let card = currentCard(matching: token),
              card.primaryAction != nil,
              begin(.retrying(token.attemptID)) else {
            notice = .recordingChanged
            return
        }
        guard await actions.retry(token: token) else {
            notice = .retryFailed
            _ = await reload(clearNoticeOnSuccess: false)
            complete()
            return
        }
        notice = nil
        await waitForCanonicalMutation(from: token)
        complete()
    }

    func discard(
        ifCurrent token: IOSPendingRecordingHistorySnapshotToken
    ) async {
        guard let card = currentCard(matching: token),
              !card.status.isProcessing,
              begin(.discarding(token.attemptID)) else {
            notice = .recordingChanged
            return
        }
        guard await actions.discard(token: token) else {
            notice = .discardFailed
            _ = await reload(clearNoticeOnSuccess: false)
            complete()
            return
        }
        notice = nil
        await waitForCanonicalMutation(from: token)
        complete()
    }

    func stopPlayback() async {
        await actions.stop()
    }

    private func currentCard(
        matching token: IOSPendingRecordingHistorySnapshotToken
    ) -> IOSPendingRecordingHistoryCard? {
        guard let card, card.token == token else { return nil }
        return card
    }

    @discardableResult
    private func reload(clearNoticeOnSuccess: Bool) async -> Bool {
        let previous = state.card
        do {
            let observation = try await actions.load()
            state = Self.resolve(
                observation,
                supportsPlayback: actions.supportsPlayback
            )
            if clearNoticeOnSuccess { notice = nil }
            return true
        } catch is CancellationError {
            return false
        } catch {
            state = .loadFailed(lastConfirmed: previous)
            return false
        }
    }

    private func waitForCanonicalMutation(
        from token: IOSPendingRecordingHistorySnapshotToken
    ) async {
        for attempt in 0..<20 {
            _ = await reload(clearNoticeOnSuccess: false)
            guard state.card?.token == token else { return }
            guard attempt < 19 else { return }
            do {
                try await Task.sleep(for: .milliseconds(50))
            } catch {
                return
            }
        }
    }

    private func begin(
        _ requested: IOSPendingRecordingHistoryOperation
    ) -> Bool {
        guard operation == .idle else { return false }
        operation = requested
        return true
    }

    private func complete() {
        operation = .idle
        guard interruptionRefreshIsPending else { return }
        interruptionRefreshIsPending = false
        Task { @MainActor [weak self] in
            await self?.refreshAfterInterruption()
        }
    }

    static func resolve(
        _ observation: IOSV1SavedRecordingObservation?,
        supportsPlayback: Bool
    ) -> IOSPendingRecordingHistoryState {
        switch observation {
        case nil:
            return .absent
        case .pending(let observation):
            guard observation.recording.phase != .acceptedCleanup else {
                return .absent
            }
            let recording = observation.recording
            let blockedReason: IOSPendingRecordingHistoryBlockReason? =
                if observation.availability != .available {
                    .audioUnavailable
                } else if recording.durationMilliseconds
                    > RecordingDurationLimit
                        .maximumSupportedFinalizedMediaDurationMilliseconds {
                    .durationLimitExceeded
                } else if recording.phase == .failed
                    && (recording.transcriptionReplayBlocked
                        || recording.textCheckpointStage
                            == .translationInFlight) {
                    .providerResultUnrecoverable
                } else {
                    nil
                }
            let status: IOSPendingRecordingHistoryStatus
            if blockedReason != nil {
                status = .blocked
            } else {
                status = switch recording.phase {
                case .readyForTranscription:
                    .ready
                case .failed:
                    .failed
                case .transcribing:
                    .processing(.transcribing)
                case .postProcessing:
                    .processing(.postProcessing)
                case .outputDelivery:
                    .processing(.savingResult)
                case .acceptedCleanup:
                    preconditionFailure("accepted cleanup is filtered above")
                }
            }
            return .ready(
                IOSPendingRecordingHistoryCard(
                    id: recording.attemptID,
                    status: status,
                    durationMilliseconds:
                        recording.durationMilliseconds > 0
                            ? recording.durationMilliseconds : nil,
                    isPlayable: supportsPlayback
                        && observation.availability == .available,
                    blockedReason: blockedReason,
                    token: IOSPendingRecordingHistorySnapshotToken(
                        recording: recording
                    )
                )
            )
        case .completedCapture(let recording):
            let blockedReason: IOSPendingRecordingHistoryBlockReason? =
                if recording.availability != .available {
                    .audioUnavailable
                } else if recording.durationMilliseconds
                    > RecordingDurationLimit
                        .maximumSupportedFinalizedMediaDurationMilliseconds {
                    .durationLimitExceeded
                } else {
                    nil
                }
            return .ready(
                IOSPendingRecordingHistoryCard(
                    id: recording.attemptID,
                    status: blockedReason == nil ? .ready : .blocked,
                    durationMilliseconds:
                        recording.durationMilliseconds > 0
                            ? recording.durationMilliseconds : nil,
                    isPlayable: supportsPlayback
                        && recording.availability == .available,
                    blockedReason: blockedReason,
                    token: IOSPendingRecordingHistorySnapshotToken(
                        recording: recording
                    )
                )
            )
        }
    }
}
