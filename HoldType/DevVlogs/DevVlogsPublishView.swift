import SwiftUI

struct DevVlogsPublishView: View {
    let presentation: DevVlogsPublishPresentation
    let onAction: (DevVlogsPublishAction) -> Void

    init(
        presentation: DevVlogsPublishPresentation = .releaseEmpty,
        onAction: @escaping (DevVlogsPublishAction) -> Void = { _ in }
    ) {
        self.presentation = presentation
        self.onAction = onAction
    }

    var body: some View {
        Form {
            sourceDaySection
            clipsSection
            outputSection

            if case .building(_, let progress) = presentation.state {
                buildProgressSection(progress)
            }

            resultSection
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 18, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(HoldTypeWindowTitle.titled("Dev Vlogs"))
    }

    private var sourceDaySection: some View {
        Section {
            if let day = presentation.state.day {
                VStack(alignment: .leading, spacing: 4) {
                    Label(day.title, systemImage: "calendar")
                        .font(.headline)
                    Text(day.detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } else {
                emptyMessage(
                    title: "No recordings yet",
                    detail: "Recorded days will appear here after Dev Vlogs saves its first clip.",
                    systemImage: "calendar.badge.clock"
                )
            }
        } header: {
            Text("Source Day")
        } footer: {
            Text("Publish prepares one local video from clips recorded on a single day.")
        }
    }

    private var clipsSection: some View {
        Section {
            if let selection = presentation.state.selection {
                ForEach(selection.clips) { clip in
                    clipRow(clip)
                }

                if case .selectionUnavailable(_, let message) = presentation.state {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            } else {
                emptyMessage(
                    title: emptyClipsTitle,
                    detail: emptyClipsDetail,
                    systemImage: "film.stack"
                )
            }
        } header: {
            Text("Clips")
        } footer: {
            if let selection = presentation.state.selection {
                Text("\(selection.selectedClipCount) of \(selection.clips.count) clips selected in chronological order.")
            } else {
                Text("Clip selection becomes available when the Library has a recorded day.")
            }
        }
    }

    private var outputSection: some View {
        Section {
            LabeledContent("Quality", value: "Original")

            LabeledContent("Location") {
                Text(presentation.state.selection?.outputLocation ?? "Choose after selecting a day")
                    .foregroundStyle(presentation.state.selection == nil ? .secondary : .primary)
            }

            if presentation.enables(.createVideo) {
                Button("Create Video") {
                    onAction(.createVideo)
                }
                .buttonStyle(.borderedProminent)
            }
        } header: {
            Text("Output")
        } footer: {
            Text("Original keeps source dimensions and nominal frame rate. Publish creates a local artifact; it does not upload or post to a social service.")
        }
    }

    private func buildProgressSection(_ progress: DevVlogsPublishBuildProgress) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Creating video", systemImage: "film.stack")
                    .font(.headline)
                ProgressView(value: progress.boundedFraction)
                Text(progress.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)

            if presentation.enables(.cancel) {
                Button("Cancel") {
                    onAction(.cancel)
                }
            }
        } header: {
            Text("Build Progress")
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch presentation.state {
        case .cancelled(_, let message):
            statusResult(
                title: "Video creation cancelled",
                detail: message,
                systemImage: "xmark.circle",
                color: .secondary
            )
        case .failed(_, let message):
            statusResult(
                title: "Video not created",
                detail: message,
                systemImage: "exclamationmark.triangle",
                color: .orange
            )
        case .completed(_, let artifact):
            completedResult(artifact)
        case .noRecordings, .emptyDay, .selectionReady, .selectionUnavailable, .building:
            EmptyView()
        }
    }

    private func statusResult(
        title: String,
        detail: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                    .foregroundStyle(color)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 2)
        } header: {
            Text("Result")
        }
    }

    private func completedResult(_ artifact: DevVlogsPublishArtifact) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("Video ready", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(artifact.name)
                Text(artifact.detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text(artifact.outputLocation)
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 2)

            HStack {
                actionButton("Play", action: .play, prominent: true)
                actionButton("Reveal in Finder", action: .reveal)
                actionButton("Share…", action: .share)
            }
        } header: {
            Text("Result")
        }
    }

    @ViewBuilder
    private func actionButton(
        _ title: String,
        action: DevVlogsPublishAction,
        prominent: Bool = false
    ) -> some View {
        if presentation.enables(action) {
            if prominent {
                Button(title) {
                    onAction(action)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(title) {
                    onAction(action)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func clipRow(_ clip: DevVlogsPublishClip) -> some View {
        HStack(spacing: 12) {
            Image(systemName: clipSystemImage(clip))
                .foregroundStyle(clipColor(clip))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(clip.title)
                Text(clip.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Text(clipStatus(clip))
                .font(.footnote)
                .foregroundStyle(clipColor(clip))
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }

    private func emptyMessage(title: String, detail: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Text(detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private var emptyClipsTitle: String {
        presentation.state.day == nil ? "No clips available" : "No clips recorded"
    }

    private var emptyClipsDetail: String {
        presentation.state.day == nil
            ? "There are no local recordings to prepare yet."
            : "This day has no clips that can be included in a video."
    }

    private func clipSystemImage(_ clip: DevVlogsPublishClip) -> String {
        switch clip.health {
        case .ready:
            return clip.isSelected ? "checkmark.circle.fill" : "circle"
        case .missing:
            return "questionmark.circle"
        case .invalid:
            return "exclamationmark.circle"
        }
    }

    private func clipColor(_ clip: DevVlogsPublishClip) -> Color {
        switch clip.health {
        case .ready:
            return clip.isSelected ? .accentColor : .secondary
        case .missing, .invalid:
            return .orange
        }
    }

    private func clipStatus(_ clip: DevVlogsPublishClip) -> String {
        switch clip.health {
        case .ready:
            return clip.isSelected ? "Included" : "Excluded"
        case .missing:
            return "Missing"
        case .invalid:
            return "Unavailable"
        }
    }
}

#if DEBUG
private enum DevVlogsPublishPreviewFixtures {
    static let day = DevVlogsPublishDay(
        title: "Monday, August 11",
        detail: "3 clips across Codex and Xcode · 1m 24s"
    )

    static let selection = DevVlogsPublishSelection(
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
            ),
            DevVlogsPublishClip(
                id: "clip-3",
                title: "14:37 · Codex",
                detail: "11s · Excluded",
                isSelected: false,
                health: .ready
            )
        ],
        outputLocation: "Movies"
    )

    static let unavailableSelection = DevVlogsPublishSelection(
        day: day,
        clips: [
            DevVlogsPublishClip(
                id: "clip-missing",
                title: "10:14 · Codex",
                detail: "Source file is no longer available",
                isSelected: true,
                health: .missing
            )
        ],
        outputLocation: "Movies"
    )
}

#Preview("No recordings") {
    DevVlogsPublishView()
        .frame(width: 700, height: 520)
}

#Preview("Empty day") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .emptyDay(DevVlogsPublishPreviewFixtures.day)
        )
    )
    .frame(width: 700, height: 520)
}

#Preview("Selection ready") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .selectionReady(DevVlogsPublishPreviewFixtures.selection),
            enabledActions: [.createVideo]
        )
    )
    .frame(width: 700, height: 520)
}

#Preview("Missing source") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .selectionUnavailable(
                DevVlogsPublishPreviewFixtures.unavailableSelection,
                message: "Replace or exclude missing clips before creating a video."
            )
        )
    )
    .frame(width: 700, height: 520)
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
    )
    .frame(width: 700, height: 520)
}

#Preview("Cancelled") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .cancelled(
                DevVlogsPublishPreviewFixtures.selection,
                message: "Source clips are unchanged."
            )
        )
    )
    .frame(width: 700, height: 520)
}

#Preview("Failed") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .failed(
                DevVlogsPublishPreviewFixtures.selection,
                message: "The selected clips could not be combined without changing the source video."
            )
        )
    )
    .frame(width: 700, height: 520)
}

#Preview("Completed") {
    DevVlogsPublishView(
        presentation: DevVlogsPublishPresentation(
            state: .completed(
                DevVlogsPublishPreviewFixtures.selection,
                DevVlogsPublishArtifact(
                    name: "Dev Vlog — August 11.mov",
                    detail: "1m 13s · Original",
                    outputLocation: "/Preview/Movies/Dev Vlog — August 11.mov"
                )
            ),
            enabledActions: [.play, .reveal, .share]
        )
    )
    .frame(width: 700, height: 520)
}
#endif
