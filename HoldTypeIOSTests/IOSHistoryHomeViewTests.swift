import Foundation
import HoldTypeDomain
import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSHistoryHomeViewTests {
    @Test func copyWritesTheExactSelectedTextOnce() {
        var copiedTexts: [String] = []
        let actions = IOSHistoryRowActions(
            copyText: { copiedTexts.append($0) }
        )
        let text = "  Exact text\nwith emoji 🫡 and punctuation!?  "

        actions.copy(text)

        #expect(copiedTexts == [text])
    }

    @Test func asyncPlaybackBoundaryUsesOnlyResolvedCacheEntries() async {
        let playableID = UUID()
        let missingID = UUID()
        var resolvedIDs: [[UUID]] = []
        var playedIDs: [UUID] = []
        let actions = IOSHistoryPlaybackActions(
            resolvePlayableResultIDs: { resultIDs in
                resolvedIDs.append(resultIDs)
                return [playableID]
            },
            playRecording: { resultID in
                playedIDs.append(resultID)
                return resultID == playableID ? .played : .unavailable
            }
        )

        let playable = await actions.playableResultIDs([
            playableID,
            missingID,
        ])
        let played = await actions.play(resultID: playableID)
        let unavailable = await actions.play(resultID: missingID)

        #expect(resolvedIDs == [[playableID, missingID]])
        #expect(playable == [playableID])
        #expect(played == .played)
        #expect(unavailable == .unavailable)
        #expect(playedIDs == [playableID, missingID])
    }

    @Test func cacheLifecycleNormalizesPolicyAndStopsPlaybackBeforeDisabling()
        async {
        var reconciledPolicies: [RecordingCachePolicy] = []
        var stopCount = 0
        let actions = IOSRecordingCacheLifecycleActions(
            stopPlayback: { stopCount += 1 },
            reconcileCache: { policy in
                reconciledPolicies.append(policy)
                return true
            }
        )

        #expect(await actions.reconcile(policy: .keepLast(0)))
        #expect(stopCount == 0)
        #expect(await actions.reconcile(policy: .deleteImmediately))

        #expect(reconciledPolicies == [.keepLast(1), .deleteImmediately])
        #expect(stopCount == 1)
    }

    @Test func savedRecordingActionsStayBoundToTheExactRowSnapshot() async {
        let recording = IOSSavedAcceptedRecording(
            resultID: UUID(),
            createdAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        var played: [IOSSavedAcceptedRecording] = []
        var discarded: [IOSSavedAcceptedRecording] = []
        let actions = IOSHistoryPlaybackActions(
            resolvePlayableResultIDs: { _ in [] },
            playRecording: { _ in .unavailable },
            loadSavedRecordings: { .loaded([recording]) },
            playSavedRecording: { expected in
                played.append(expected)
                return .played
            },
            discardSavedRecording: { expected in
                discarded.append(expected)
                return .discarded
            }
        )

        #expect(await actions.savedRecordings() == .loaded([recording]))
        #expect(await actions.playSaved(recording) == .played)
        #expect(await actions.discardSaved(recording) == .discarded)
        #expect(played == [recording])
        #expect(discarded == [recording])
        #expect(
            IOSSavedRecordingHistoryPresentationState.ready([recording])
                .shouldPresent
        )

        let returnedActive = IOSSavedRecordingHistoryPresentationState
            .resolving(
                previous: .ready([]),
                result: await actions.savedRecordings()
            )
        #expect(returnedActive == .ready([recording]))
        #expect(returnedActive.shouldPresent)
    }
}
