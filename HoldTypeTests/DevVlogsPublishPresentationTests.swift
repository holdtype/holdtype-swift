import Testing
@testable import HoldType

struct DevVlogsPublishPresentationTests {
    @Test func releasePresentationIsTruthfulAndActionless() {
        let presentation = DevVlogsPublishPresentation.releaseEmpty

        #expect(presentation.state == .noRecordings)
        #expect(presentation.state.visibleSections == [.sourceDay, .clips, .output])
        #expect(presentation.enabledActions.isEmpty)
    }

    @Test func emptyDayShowsPreparationHierarchyWithoutActions() {
        let presentation = DevVlogsPublishPresentation(
            state: .emptyDay(day),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.state.visibleSections == [.sourceDay, .clips, .output])
        #expect(presentation.enabledActions.isEmpty)
    }

    @Test func readySelectionEnablesOnlyCreateVideo() {
        let presentation = DevVlogsPublishPresentation(
            state: .selectionReady(selection),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions == [.createVideo])
        #expect(presentation.state.visibleSections == [.sourceDay, .clips, .output])
    }

    @Test func unavailableSelectionRejectsEveryAction() {
        let presentation = DevVlogsPublishPresentation(
            state: .selectionUnavailable(selection, message: "One source is missing."),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions.isEmpty)
        #expect(presentation.state.visibleSections == [.sourceDay, .clips, .output])
    }

    @Test func buildingShowsProgressAndEnablesOnlyCancel() {
        let presentation = DevVlogsPublishPresentation(
            state: .building(
                selection,
                DevVlogsPublishBuildProgress(completedFraction: 1.4, detail: "Finalizing")
            ),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions == [.cancel])
        #expect(presentation.state.visibleSections == [.sourceDay, .clips, .output, .buildProgress])

        guard case .building(_, let progress) = presentation.state else {
            Issue.record("Expected building presentation")
            return
        }
        #expect(progress.boundedFraction == 1)
    }

    @Test func cancelledPresentationShowsResultWithoutActions() {
        assertTerminalResult(.cancelled(selection, message: "Cancelled"))
    }

    @Test func failedPresentationShowsResultWithoutActions() {
        assertTerminalResult(.failed(selection, message: "Failed"))
    }

    private func assertTerminalResult(_ state: DevVlogsPublishState) {
        let presentation = DevVlogsPublishPresentation(
            state: state,
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions.isEmpty)
        #expect(presentation.state.visibleSections == [.sourceDay, .clips, .output, .result])
    }

    @Test func completedArtifactEnablesOnlyLocalResultActions() {
        let presentation = DevVlogsPublishPresentation(
            state: .completed(
                selection,
                DevVlogsPublishArtifact(
                    name: "Daily Vlog.mov",
                    detail: "1m 13s · Original",
                    outputLocation: "Movies"
                )
            ),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions == [.play, .reveal, .share])
        #expect(presentation.state.visibleSections == [.sourceDay, .clips, .output, .result])
    }

    private let day = DevVlogsPublishDay(
        title: "Monday, August 11",
        detail: "2 clips · 1m 13s"
    )

    private var selection: DevVlogsPublishSelection {
        DevVlogsPublishSelection(
            day: day,
            clips: [
                DevVlogsPublishClip(
                    id: "clip-1",
                    title: "10:14 · Codex",
                    detail: "32s · Ready",
                    isSelected: true,
                    health: .ready
                ),
                DevVlogsPublishClip(
                    id: "clip-2",
                    title: "11:02 · Xcode",
                    detail: "41s · Ready",
                    isSelected: true,
                    health: .ready
                )
            ],
            outputLocation: "Movies"
        )
    }
}

private extension DevVlogsPublishAction {
    static let allTestActions: [DevVlogsPublishAction] = [
        .createVideo,
        .cancel,
        .play,
        .reveal,
        .share
    ]
}
