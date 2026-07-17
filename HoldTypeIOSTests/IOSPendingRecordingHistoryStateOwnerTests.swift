import Foundation
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSPendingRecordingHistoryStateOwnerTests {
    @Test func presentationMapsCanonicalPendingWithoutExposingAPath()
        throws {
        let ready = try pendingObservation(
            phase: .readyForTranscription
        )
        let readyState = IOSPendingRecordingHistoryStateOwner.resolve(
            .pending(ready),
            supportsPlayback: true
        )
        let readyCard = try #require(readyState.card)
        #expect(readyCard.status == .ready)
        #expect(readyCard.primaryAction == .transcribe)
        #expect(readyCard.durationMilliseconds == 30_250)
        #expect(readyCard.durationText == "0:30")
        #expect(readyCard.isPlayable)

        let failedState = IOSPendingRecordingHistoryStateOwner.resolve(
            .pending(try pendingObservation(phase: .failed)),
            supportsPlayback: true
        )
        #expect(failedState.card?.status == .failed)
        #expect(failedState.card?.primaryAction == .retry)

        let processingState = IOSPendingRecordingHistoryStateOwner.resolve(
            .pending(
                try pendingObservation(
                    phase: .transcribing,
                    transcriptionID: UUID()
                )
            ),
            supportsPlayback: true
        )
        #expect(
            processingState.card?.status == .processing(.transcribing)
        )
        #expect(processingState.card?.primaryAction == nil)

        let blockedState = IOSPendingRecordingHistoryStateOwner.resolve(
            .pending(
                try pendingObservation(
                    phase: .failed,
                    availability: .temporarilyUnavailable
                )
            ),
            supportsPlayback: true
        )
        #expect(blockedState.card?.status == .blocked)
        #expect(blockedState.card?.isPlayable == false)

        let overrunState = IOSPendingRecordingHistoryStateOwner.resolve(
            .pending(
                try pendingObservation(
                    phase: .failed,
                    durationMilliseconds: 902_001
                )
            ),
            supportsPlayback: true
        )
        #expect(overrunState.card?.status == .blocked)
        #expect(overrunState.card?.primaryAction == nil)
        #expect(overrunState.card?.isPlayable == true)
        #expect(overrunState.card?.blockedReason == .durationLimitExceeded)

        let replayBlockedState = IOSPendingRecordingHistoryStateOwner.resolve(
            .pending(
                try pendingObservation(
                    phase: .failed,
                    transcriptionReplayBlocked: true
                )
            ),
            supportsPlayback: true
        )
        #expect(replayBlockedState.card?.status == .blocked)
        #expect(replayBlockedState.card?.primaryAction == nil)
        #expect(replayBlockedState.card?.isPlayable == true)
        #expect(
            replayBlockedState.card?.blockedReason
                == .providerResultUnrecoverable
        )

        let translationUnknownState =
            IOSPendingRecordingHistoryStateOwner.resolve(
                .pending(
                    try pendingObservation(
                        phase: .failed,
                        textCheckpointStage: .translationInFlight
                    )
                ),
                supportsPlayback: true
            )
        #expect(translationUnknownState.card?.status == .blocked)
        #expect(translationUnknownState.card?.primaryAction == nil)
        #expect(translationUnknownState.card?.isPlayable == true)
        #expect(
            translationUnknownState.card?.blockedReason
                == .providerResultUnrecoverable
        )

        let liveTranslationState =
            IOSPendingRecordingHistoryStateOwner.resolve(
                .pending(
                    try pendingObservation(
                        phase: .postProcessing,
                        transcriptionID: UUID(),
                        textCheckpointStage: .translationInFlight
                    )
                ),
                supportsPlayback: true
            )
        #expect(
            liveTranslationState.card?.status == .processing(.postProcessing)
        )
        #expect(liveTranslationState.card?.primaryAction == nil)
        #expect(liveTranslationState.card?.status.isProcessing == true)
        #expect(liveTranslationState.card?.blockedReason == nil)
    }

    @Test func refreshNeverStartsProviderAndExplicitRetryUsesExactPending()
        async throws {
        var current: IOSV1PendingRecordingObservation? = try pendingObservation(
            phase: .readyForTranscription
        )
        var retryCount = 0
        var receivedExpectation: IOSV1PendingRecordingExpectation?
        let actions = IOSPendingRecordingHistoryActions(
            load: { current.map(IOSV1SavedRecordingObservation.pending) },
            retry: { token in
                retryCount += 1
                guard case .pending(let expected) = token.source else {
                    return false
                }
                receivedExpectation = expected
                current = try? pendingObservation(
                    phase: .transcribing,
                    transcriptionID: UUID()
                )
                return current != nil
            }
        )
        let owner = IOSPendingRecordingHistoryStateOwner(actions: actions)

        #expect(await owner.refresh())
        #expect(retryCount == 0)
        let card = try #require(owner.card)

        await owner.retry(ifCurrent: card.token)

        #expect(retryCount == 1)
        guard case .pending(let cardExpectation) = card.token.source else {
            Issue.record("Expected Pending token")
            return
        }
        #expect(receivedExpectation == cardExpectation)
        #expect(owner.card?.status == .processing(.transcribing))
        #expect(
            owner.operation == IOSPendingRecordingHistoryOperation.idle
        )
    }

    @Test func processingDisablesDiscardAndExactDiscardRemovesOnlyCard()
        async throws {
        var current: IOSV1PendingRecordingObservation? =
            try pendingObservation(phase: .failed)
        var discardCount = 0
        let actions = IOSPendingRecordingHistoryActions(
            load: { current.map(IOSV1SavedRecordingObservation.pending) },
            discard: { token in
                guard case .pending(let expected) = token.source else {
                    return false
                }
                guard current?.expectation == expected else { return false }
                discardCount += 1
                current = nil
                return true
            }
        )
        let owner = IOSPendingRecordingHistoryStateOwner(actions: actions)
        #expect(await owner.refresh())
        let failed = try #require(owner.card)

        await owner.discard(ifCurrent: failed.token)

        #expect(discardCount == 1)
        #expect(owner.state == IOSPendingRecordingHistoryState.absent)

        current = try pendingObservation(
            phase: .postProcessing,
            transcriptionID: UUID()
        )
        #expect(await owner.refresh())
        let processing = try #require(owner.card)

        await owner.discard(ifCurrent: processing.token)

        #expect(discardCount == 1)
        #expect(
            owner.notice
                == IOSPendingRecordingHistoryNotice.recordingChanged
        )
        #expect(owner.card?.status == .processing(.postProcessing))
    }

    @Test func playbackUsesExactTokenAndNeverNeedsAFileURL() async throws {
        let current = try pendingObservation(phase: .failed)
        var playedExpectation: IOSV1PendingRecordingExpectation?
        let actions = IOSPendingRecordingHistoryActions(
            load: { .pending(current) },
            play: { token in
                guard case .pending(let expected) = token.source else {
                    return .unavailable
                }
                playedExpectation = expected
                return .played
            }
        )
        let owner = IOSPendingRecordingHistoryStateOwner(actions: actions)
        #expect(await owner.refresh())
        let card = try #require(owner.card)

        await owner.play(ifCurrent: card.token)

        guard case .pending(let cardExpectation) = card.token.source else {
            Issue.record("Expected Pending token")
            return
        }
        #expect(playedExpectation == cardExpectation)
        #expect(owner.notice == nil)
    }

    @Test func completedCaptureIsPlayableRetryableAndDiscardable()
        async throws {
        var current: IOSV1SavedRecordingObservation? = .completedCapture(
            try IOSV1CompletedCaptureRecoveryObservation
                .qualificationFixture(
                    durationMilliseconds: 30_250,
                    byteCount: 4_096
                )
        )
        var retrySource: IOSV1SavedRecordingExpectation?
        var discardSource: IOSV1SavedRecordingExpectation?
        let actions = IOSPendingRecordingHistoryActions(
            load: { current },
            play: { _ in .played },
            retry: { token in
                retrySource = token.source
                return false
            },
            discard: { token in
                discardSource = token.source
                current = nil
                return true
            }
        )
        let owner = IOSPendingRecordingHistoryStateOwner(actions: actions)

        #expect(await owner.refresh())
        let card = try #require(owner.card)
        #expect(card.status == .ready)
        #expect(card.primaryAction == .transcribe)
        #expect(card.isPlayable)
        #expect(card.durationText == "0:30")

        let blocked = IOSPendingRecordingHistoryStateOwner.resolve(
            .completedCapture(
                try IOSV1CompletedCaptureRecoveryObservation
                    .qualificationFixture(
                        availability: .temporarilyUnavailable
                    )
            ),
            supportsPlayback: true
        ).card
        #expect(blocked?.status == .blocked)
        #expect(blocked?.primaryAction == nil)
        #expect(blocked?.isPlayable == false)

        await owner.retry(ifCurrent: card.token)
        #expect(retrySource == card.token.source)
        #expect(owner.notice == .retryFailed)

        owner.dismissNotice()
        await owner.discard(ifCurrent: card.token)
        #expect(discardSource == card.token.source)
        #expect(owner.state == .absent)
    }

    @Test func interruptionNoticeRequiresCanonicalPlayableRecovery()
        async throws {
        var current: IOSV1SavedRecordingObservation? = .completedCapture(
            try IOSV1CompletedCaptureRecoveryObservation
                .qualificationFixture(
                    byteCount: 4_096,
                    availability: .available
                )
        )
        let owner = IOSPendingRecordingHistoryStateOwner(
            actions: IOSPendingRecordingHistoryActions(
                load: { current }
            )
        )

        #expect(await owner.refreshAfterInterruption())
        #expect(owner.card?.isPlayable == true)
        #expect(owner.notice == .recordingInterruptedAndSaved)
        #expect(
            owner.notice?.message
                == "Recording interrupted — saved to History."
        )

        current = .completedCapture(
            try IOSV1CompletedCaptureRecoveryObservation
                .qualificationFixture(
                    byteCount: 4_096,
                    availability: .temporarilyUnavailable
                )
        )
        #expect(!(await owner.refreshAfterInterruption()))
        #expect(owner.card?.status == .blocked)
        #expect(owner.notice == nil)
    }

    @Test func interruptionLoadFailureNeverClaimsThatAudioWasSaved() async {
        let owner = IOSPendingRecordingHistoryStateOwner(
            actions: IOSPendingRecordingHistoryActions(
                load: { throw PendingRecordingLoadFailure() }
            )
        )

        #expect(!(await owner.refreshAfterInterruption()))
        #expect(owner.state == .loadFailed(lastConfirmed: nil))
        #expect(owner.notice == nil)
    }

    @Test
    func firstLoadFailureStaysVisibleAndRefreshClosesOnlyAfterConfirmedAbsence()
        async {
        var loadFails = true
        let owner = IOSPendingRecordingHistoryStateOwner(
            actions: IOSPendingRecordingHistoryActions(
                load: {
                    if loadFails {
                        throw PendingRecordingLoadFailure()
                    }
                    return nil
                }
            )
        )

        #expect(!(await owner.refresh()))
        #expect(owner.state == .loadFailed(lastConfirmed: nil))
        #expect(owner.shouldPresentSavedRecording)
        #expect(!owner.isConfirmedAbsent)
        #expect(owner.card == nil)

        loadFails = false
        #expect(await owner.refresh())
        #expect(owner.state == .absent)
        #expect(!owner.shouldPresentSavedRecording)
        #expect(owner.isConfirmedAbsent)
    }
}

private struct PendingRecordingLoadFailure: Error {}

@MainActor
private func pendingObservation(
    phase: IOSV1PendingRecordingPhase,
    transcriptionID: UUID? = nil,
    availability: IOSV1PendingRecordingAvailability = .available,
    durationMilliseconds: Int64 = 30_250,
    transcriptionReplayBlocked: Bool = false,
    textCheckpointStage: IOSV1PendingTextCheckpointStage? = nil
) throws -> IOSV1PendingRecordingObservation {
    let acceptedTranscriptionID = textCheckpointStage.map { _ in UUID() }
    return IOSV1PendingRecordingObservation(
        recording: try IOSV1PendingRecording.qualificationFixture(
            phase: phase,
            transcriptionID: transcriptionID,
            transcriptionReplayBlocked: transcriptionReplayBlocked,
            acceptedTranscriptionID: acceptedTranscriptionID,
            acceptedTranscript: textCheckpointStage.map { _ in "Accepted" },
            textCheckpointStage: textCheckpointStage,
            textCheckpointText: textCheckpointStage.map { _ in "Current" },
            durationMilliseconds: durationMilliseconds,
            byteCount: 4_096
        ),
        availability: availability
    )
}
