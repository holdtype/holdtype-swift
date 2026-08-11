import SwiftUI

struct DevVlogsPublishView: View {
    let presentation: DevVlogsPublishPresentation
    let availableDays: [DevVlogsPublishDay]
    let selectedDayID: String?
    let onAction: (DevVlogsPublishAction) -> Void
    let onSelectDay: (String) -> Void
    let onSetIncluded: (Bool, UUID) -> Void
    let onMove: (UUID, Int) -> Void
    let fileActions: any DevVlogsFileActionPerforming

    @State private var playingURL: URL?

    init(
        presentation: DevVlogsPublishPresentation = .releaseEmpty,
        availableDays: [DevVlogsPublishDay] = [],
        selectedDayID: String? = nil,
        onAction: @escaping (DevVlogsPublishAction) -> Void = { _ in },
        onSelectDay: @escaping (String) -> Void = { _ in },
        onSetIncluded: @escaping (Bool, UUID) -> Void = { _, _ in },
        onMove: @escaping (UUID, Int) -> Void = { _, _ in }
    ) {
        self.init(
            presentation: presentation,
            availableDays: availableDays,
            selectedDayID: selectedDayID,
            onAction: onAction,
            onSelectDay: onSelectDay,
            onSetIncluded: onSetIncluded,
            onMove: onMove,
            fileActions: SystemDevVlogsFileActions()
        )
    }

    init(
        presentation: DevVlogsPublishPresentation,
        availableDays: [DevVlogsPublishDay],
        selectedDayID: String?,
        onAction: @escaping (DevVlogsPublishAction) -> Void,
        onSelectDay: @escaping (String) -> Void,
        onSetIncluded: @escaping (Bool, UUID) -> Void,
        onMove: @escaping (UUID, Int) -> Void,
        fileActions: any DevVlogsFileActionPerforming
    ) {
        self.presentation = presentation
        self.availableDays = availableDays
        self.selectedDayID = selectedDayID
        self.onAction = onAction
        self.onSelectDay = onSelectDay
        self.onSetIncluded = onSetIncluded
        self.onMove = onMove
        self.fileActions = fileActions
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
        .sheet(isPresented: playingBinding) {
            if let playingURL {
                DevVlogsPlayerView(url: playingURL)
            }
        }
    }

    private var sourceDaySection: some View {
        Section {
            if let day = presentation.state.day {
                if availableDays.count > 1 {
                    Picker("Recorded day", selection: daySelectionBinding) {
                        ForEach(availableDays) { candidate in
                            Text(candidate.title).tag(Optional(candidate.id))
                        }
                    }
                }
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
                color: .secondary,
                offersRetry: presentation.enables(.retry)
            )
        case .failed(_, let message):
            statusResult(
                title: "Video not created",
                detail: message,
                systemImage: "exclamationmark.triangle",
                color: .orange,
                offersRetry: presentation.enables(.retry)
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
        color: Color,
        offersRetry: Bool = false
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

            if offersRetry {
                Button("Retry") { onAction(.retry) }
                    .buttonStyle(.borderedProminent)
            }
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
                if presentation.enables(.play) {
                    Button("Play") { playingURL = artifact.fileURL }
                        .buttonStyle(.borderedProminent)
                }
                if presentation.enables(.reveal) {
                    Button("Reveal in Finder") { fileActions.reveal(artifact.fileURL) }
                        .buttonStyle(.bordered)
                }
                if presentation.enables(.share) {
                    ShareLink(item: artifact.fileURL) {
                        Text("Share…")
                    }
                    .buttonStyle(.bordered)
                }
            }
        } header: {
            Text("Result")
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
            if let clipID = UUID(uuidString: clip.id), clip.health == .ready {
                Toggle(
                    "Include",
                    isOn: Binding(
                        get: { clip.isSelected },
                        set: { onSetIncluded($0, clipID) }
                    )
                )
                .toggleStyle(.checkbox)
                .disabled(presentation.state.isBuilding)
                Button {
                    onMove(clipID, -1)
                } label: {
                    Image(systemName: "arrow.up")
                }
                .help("Move earlier")
                .disabled(presentation.state.isBuilding)
                Button {
                    onMove(clipID, 1)
                } label: {
                    Image(systemName: "arrow.down")
                }
                .help("Move later")
                .disabled(presentation.state.isBuilding)
            } else {
                Text(clipStatus(clip))
                    .font(.footnote)
                    .foregroundStyle(clipColor(clip))
            }
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

    private var daySelectionBinding: Binding<String?> {
        Binding(
            get: { selectedDayID },
            set: { if let value = $0 { onSelectDay(value) } }
        )
    }

    private var playingBinding: Binding<Bool> {
        Binding(
            get: { playingURL != nil },
            set: { if !$0 { playingURL = nil } }
        )
    }
}

#Preview("No recordings") {
    DevVlogsPublishView()
        .frame(width: 700, height: 520)
}
