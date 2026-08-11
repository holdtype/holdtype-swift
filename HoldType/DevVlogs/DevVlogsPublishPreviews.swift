#if DEBUG
import SwiftUI

private enum DevVlogsPublishPreviewFixtures {
    static let day = DevVlogsPublishDay(
        id: "2026-08-11",
        title: "Monday, August 11",
        detail: "3 clips across 2 apps"
    )

    static let applications: [DevVlogsPublishApplication] = [
        .all,
        .init(id: "application:codex", title: "Codex", detail: "2 clips"),
        .init(id: "application:xcode", title: "Xcode", detail: "1 clip")
    ]

    static let selection = DevVlogsPublishSelection(
        day: day,
        application: .all,
        applications: applications,
        summary: .init(clipCount: 3, duration: 84, byteCount: 128_000_000, invalidCount: 0),
        outputLocation: "Recorded day / Builds"
    )

    static let unavailableSelection = DevVlogsPublishSelection(
        day: day,
        application: applications[1],
        applications: applications,
        summary: .init(clipCount: 2, duration: 42, byteCount: 64_000_000, invalidCount: 1),
        outputLocation: "Recorded day / Builds"
    )
}

#Preview("No recordings") {
    DevVlogsPublishView().frame(width: 700, height: 520)
}

#Preview("Empty day") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(state: .emptyDay(DevVlogsPublishPreviewFixtures.selection))
    ).frame(width: 700, height: 520)
}

#Preview("Selection ready") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .selectionReady(DevVlogsPublishPreviewFixtures.selection),
            enabledActions: [.openInFinder, .refresh, .createVideo]
        )
    ).frame(width: 700, height: 520)
}

#Preview("Missing source") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .selectionUnavailable(
                DevVlogsPublishPreviewFixtures.unavailableSelection,
                message: "Review unavailable source files in Finder, then refresh."
            ),
            enabledActions: [.openInFinder, .refresh]
        )
    ).frame(width: 700, height: 520)
}

#Preview("Building") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .building(
                DevVlogsPublishPreviewFixtures.selection,
                DevVlogsPublishBuildProgress(completedFraction: 0.58, detail: "Combining 2 clips…")
            ),
            enabledActions: [.cancel]
        )
    ).frame(width: 700, height: 520)
}

#Preview("Completed") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .completed(
                DevVlogsPublishPreviewFixtures.selection,
                DevVlogsPublishArtifact(
                    buildID: UUID(),
                    name: "Dev Vlog — August 11.mov",
                    detail: "1m 13s · Original",
                    outputLocation: "Recorded day / Builds",
                    fileURL: URL(fileURLWithPath: "/Preview/Dev Vlog.mov")
                )
            ),
            enabledActions: [.play, .reveal, .share]
        )
    ).frame(width: 700, height: 520)
}
#endif
