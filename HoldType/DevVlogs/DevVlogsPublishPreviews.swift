#if DEBUG
import SwiftUI

private enum DevVlogsPublishPreviewFixtures {
    static let day = DevVlogsPublishDay(
        id: "2026-08-11",
        title: "Monday, August 11",
        detail: "3 clips across Codex and Xcode · 1m 24s"
    )

    static let selection = DevVlogsPublishSelection(
        day: day,
        clips: [
            clip(id: "00000000-0000-0000-0000-000000000001", title: "10:14 · Codex"),
            clip(id: "00000000-0000-0000-0000-000000000002", title: "11:02 · Xcode"),
            clip(
                id: "00000000-0000-0000-0000-000000000003",
                title: "14:37 · Codex",
                selected: false
            )
        ],
        outputLocation: "Recorded day / Builds"
    )

    static let unavailableSelection = DevVlogsPublishSelection(
        day: day,
        clips: [
            DevVlogsPublishClip(
                id: "00000000-0000-0000-0000-000000000004",
                clipID: nil,
                title: "10:14 · Codex",
                detail: "Source file is no longer available",
                isSelected: true,
                health: .missing
            )
        ],
        outputLocation: "Recorded day / Builds"
    )

    private static func clip(id: String, title: String, selected: Bool = true) -> DevVlogsPublishClip {
        DevVlogsPublishClip(
            id: id,
            clipID: UUID(uuidString: id),
            title: title,
            detail: "32s · Ready",
            isSelected: selected,
            health: .ready
        )
    }
}

#Preview("No recordings") {
    DevVlogsPublishView().frame(width: 700, height: 520)
}

#Preview("Empty day") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(state: .emptyDay(DevVlogsPublishPreviewFixtures.day))
    ).frame(width: 700, height: 520)
}

#Preview("Selection ready") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .selectionReady(DevVlogsPublishPreviewFixtures.selection),
            enabledActions: [.createVideo]
        )
    ).frame(width: 700, height: 520)
}

#Preview("Missing source") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .selectionUnavailable(
                DevVlogsPublishPreviewFixtures.unavailableSelection,
                message: "Exclude missing clips before creating a video."
            )
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
