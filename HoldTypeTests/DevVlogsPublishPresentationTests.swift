import Foundation
import Testing
@testable import HoldType

struct DevVlogsPublishPresentationTests {
    @Test func releasePresentationIsTruthfulAndOffersOnlyRefresh() {
        let presentation = DevVlogsPublishPresentation.releaseEmpty

        #expect(presentation.state == .noRecordings)
        #expect(presentation.state.visibleSections == [.source])
        #expect(presentation.enabledActions == [.refresh])
    }

    @Test func emptyDayShowsPreparationHierarchyWithoutActions() {
        let presentation = DevVlogsPublishPresentation(
            state: .emptyDay(selection),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.state.visibleSections == [.source])
        #expect(presentation.enabledActions == [.openInFinder, .refresh])
    }

    @Test func readySelectionEnablesOnlyCreateVideo() {
        let presentation = DevVlogsPublishPresentation(
            state: .selectionReady(selection),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions == [.openInFinder, .refresh, .createVideo])
        #expect(presentation.state.visibleSections == [.source])
    }

    @Test func unavailableSelectionRejectsEveryAction() {
        let presentation = DevVlogsPublishPresentation(
            state: .selectionUnavailable(selection, message: "One source is missing."),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions == [.openInFinder, .refresh])
        #expect(presentation.state.visibleSections == [.source])
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
        #expect(presentation.state.visibleSections == [.source, .buildProgress])

        guard case .building(_, let progress) = presentation.state else {
            Issue.record("Expected building presentation")
            return
        }
        #expect(progress.boundedFraction == 1)
    }

    @Test func cancelledPresentationShowsResultWithRetryOnly() {
        assertRetryableResult(.cancelled(selection, message: "Cancelled"))
    }

    @Test func failedPresentationShowsResultWithRetryOnly() {
        assertRetryableResult(.failed(selection, message: "Failed"))
    }

    private func assertRetryableResult(_ state: DevVlogsPublishState) {
        let presentation = DevVlogsPublishPresentation(
            state: state,
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions == [.openInFinder, .refresh, .retry])
        #expect(presentation.state.visibleSections == [.source, .result])
    }

    @Test func completedArtifactEnablesOnlyLocalResultActions() {
        let presentation = DevVlogsPublishPresentation(
            state: .completed(
                selection,
                DevVlogsPublishArtifact(
                    buildID: UUID(),
                    name: "Daily Vlog.mov",
                    detail: "1m 13s · Original",
                    outputLocation: "Movies",
                    fileURL: URL(fileURLWithPath: "/Preview/Daily Vlog.mov")
                )
            ),
            enabledActions: Set(DevVlogsPublishAction.allTestActions)
        )

        #expect(presentation.enabledActions == [.openInFinder, .refresh, .play, .reveal, .share])
        #expect(presentation.state.visibleSections == [.source, .result])
    }

    private let day = DevVlogsPublishDay(
        id: "2026-08-11",
        title: "Monday, August 11",
        detail: "2 clips · 1m 13s"
    )

    private var selection: DevVlogsPublishSelection {
        DevVlogsPublishSelection(
            day: day,
            application: .all,
            applications: [
                .all,
                DevVlogsPublishApplication(id: "application:codex", title: "Codex", detail: "2 clips")
            ],
            summary: DevVlogsPublishSourceSummary(
                clipCount: 2,
                duration: 73,
                byteCount: 1_024,
                invalidCount: 0
            ),
            outputLocation: "Movies"
        )
    }
}

private extension DevVlogsPublishAction {
    static let allTestActions: [DevVlogsPublishAction] = [
        .openInFinder,
        .refresh,
        .createVideo,
        .retry,
        .cancel,
        .play,
        .reveal,
        .share
    ]
}
