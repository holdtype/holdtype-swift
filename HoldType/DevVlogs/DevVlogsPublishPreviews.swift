#if DEBUG
import SwiftUI

private enum DevVlogsPublishPreviewFixtures {
    static let days = [
        DevVlogsPublishDay(
            id: "2026-08-11",
            title: "Monday, August 11",
            detail: "12 clips across 3 apps"
        ),
        DevVlogsPublishDay(
            id: "2026-08-10",
            title: "Sunday, August 10",
            detail: "8 clips across 3 apps"
        ),
        DevVlogsPublishDay(
            id: "2026-08-09",
            title: "Saturday, August 9",
            detail: "15 clips across 3 apps"
        )
    ]

    static let day = days[0]

    static let applications: [DevVlogsPublishApplication] = [
        .all,
        .init(id: "application:codex", title: "Codex", detail: "5 clips"),
        .init(id: "application:xcode", title: "Xcode", detail: "4 clips"),
        .init(id: "application:safari", title: "Safari", detail: "3 clips")
    ]

    static let selection = DevVlogsPublishSelection(
        day: day,
        application: .all,
        applications: applications,
        summary: .init(
            clipCount: 12,
            duration: 702,
            byteCount: 1_842_000_000,
            invalidCount: 0
        ),
        outputLocation: "Recorded day / Builds"
    )

    static let unavailableSelection = DevVlogsPublishSelection(
        day: day,
        application: applications[3],
        applications: applications,
        summary: .init(clipCount: 3, duration: 185, byteCount: 486_000_000, invalidCount: 1),
        outputLocation: "Recorded day / Builds"
    )

    static let refreshedAt = Date(timeIntervalSince1970: 1_754_916_600)
}

#Preview("No recordings") {
    DevVlogsPublishView().frame(width: 700, height: 520)
}

#Preview("Empty day") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(state: .emptyDay(DevVlogsPublishPreviewFixtures.selection))
    ).frame(width: 700, height: 520)
}

#Preview("Populated — All Applications") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .selectionReady(DevVlogsPublishPreviewFixtures.selection),
            enabledActions: [.openInFinder, .refresh, .createVideo]
        ),
        availableDays: DevVlogsPublishPreviewFixtures.days,
        selectedDayID: DevVlogsPublishPreviewFixtures.day.id,
        selectedApplicationID: DevVlogsPublishApplication.all.id,
        lastRefreshAt: DevVlogsPublishPreviewFixtures.refreshedAt
    )
    .frame(width: 760, height: 560)
}

#Preview("Unavailable source — Safari") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .selectionUnavailable(
                DevVlogsPublishPreviewFixtures.unavailableSelection,
                message: "Review unavailable source files in Finder, then refresh."
            ),
            enabledActions: [.openInFinder, .refresh]
        ),
        availableDays: DevVlogsPublishPreviewFixtures.days,
        selectedDayID: DevVlogsPublishPreviewFixtures.day.id,
        selectedApplicationID: DevVlogsPublishPreviewFixtures.applications[3].id,
        lastRefreshAt: DevVlogsPublishPreviewFixtures.refreshedAt
    )
    .frame(width: 760, height: 560)
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
                    detail: "1m 13s · 128 MB",
                    outputLocation: "Recorded day / Builds",
                    fileURL: URL(fileURLWithPath: "/Preview/Dev Vlog.mov")
                )
            ),
            enabledActions: [.play, .reveal, .share]
        )
    ).frame(width: 700, height: 520)
}
#endif
