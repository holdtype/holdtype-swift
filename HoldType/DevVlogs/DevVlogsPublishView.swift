import SwiftUI

@MainActor
struct DevVlogsPublishView: View {
    let presentation: DevVlogsPublishPresentation
    let availableDays: [DevVlogsPublishDay]
    let selectedDayID: String?
    let selectedApplicationID: String
    let lastRefreshAt: Date?
    let isRefreshing: Bool
    let refreshFailureMessage: String?
    let onAction: (DevVlogsPublishAction) -> Void
    let onSelectDay: (String) -> Void
    let onSelectApplication: (String) -> Void
    let fileActions: any DevVlogsFileActionPerforming

    @State private var playingURL: URL?

    init(
        presentation: DevVlogsPublishPresentation = .releaseEmpty,
        availableDays: [DevVlogsPublishDay] = [],
        selectedDayID: String? = nil,
        selectedApplicationID: String = DevVlogsPublishApplication.all.id,
        lastRefreshAt: Date? = nil,
        isRefreshing: Bool = false,
        refreshFailureMessage: String? = nil,
        onAction: @escaping (DevVlogsPublishAction) -> Void = { _ in },
        onSelectDay: @escaping (String) -> Void = { _ in },
        onSelectApplication: @escaping (String) -> Void = { _ in }
    ) {
        self.init(
            presentation: presentation,
            availableDays: availableDays,
            selectedDayID: selectedDayID,
            selectedApplicationID: selectedApplicationID,
            lastRefreshAt: lastRefreshAt,
            isRefreshing: isRefreshing,
            refreshFailureMessage: refreshFailureMessage,
            onAction: onAction,
            onSelectDay: onSelectDay,
            onSelectApplication: onSelectApplication,
            fileActions: SystemDevVlogsFileActions()
        )
    }

    init(
        presentation: DevVlogsPublishPresentation,
        availableDays: [DevVlogsPublishDay],
        selectedDayID: String?,
        selectedApplicationID: String,
        lastRefreshAt: Date?,
        isRefreshing: Bool,
        refreshFailureMessage: String?,
        onAction: @escaping (DevVlogsPublishAction) -> Void,
        onSelectDay: @escaping (String) -> Void,
        onSelectApplication: @escaping (String) -> Void,
        fileActions: any DevVlogsFileActionPerforming
    ) {
        self.presentation = presentation
        self.availableDays = availableDays
        self.selectedDayID = selectedDayID
        self.selectedApplicationID = selectedApplicationID
        self.lastRefreshAt = lastRefreshAt
        self.isRefreshing = isRefreshing
        self.refreshFailureMessage = refreshFailureMessage
        self.onAction = onAction
        self.onSelectDay = onSelectDay
        self.onSelectApplication = onSelectApplication
        self.fileActions = fileActions
    }

    var body: some View {
        Form {
            sourceSection

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
            if let playingURL { DevVlogsPlayerView(url: playingURL) }
        }
    }

    private var sourceSection: some View {
        Section {
            if let selection = presentation.state.selection {
                Picker("Recorded day", selection: daySelectionBinding) {
                    ForEach(availableDays) { day in
                        Text(day.title).tag(Optional(day.id))
                    }
                }
                .disabled(presentation.state.isBuilding)

                Picker("Application", selection: applicationSelectionBinding) {
                    ForEach(selection.applications) { application in
                        Text(application.title).tag(application.id)
                    }
                }
                .disabled(presentation.state.isBuilding)

                sourceSummary(selection)

                HStack {
                    if presentation.enables(.openInFinder) {
                        Button("Open in Finder") { onAction(.openInFinder) }
                    }
                    if presentation.enables(.refresh) {
                        refreshButton
                        Spacer()
                        Text(refreshStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if case .selectionUnavailable(_, let message) = presentation.state {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }

                if presentation.enables(.createVideo) {
                    Button("Create Video") { onAction(.createVideo) }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: [.command])
                }
            } else {
                emptyMessage(
                    title: "No recordings yet",
                    detail: "Recorded days will appear here after Dev Vlogs saves its first clip.",
                    systemImage: "calendar.badge.clock"
                )
                if presentation.enables(.refresh) {
                    refreshButton
                }
                if let refreshFailureMessage {
                    Label(refreshFailureMessage, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        } header: {
            Text("Source")
        } footer: {
            Text("Review clips with Finder and Quick Look. Publish uses every remaining clip in the selected scope.")
        }
    }

    private func sourceSummary(_ selection: DevVlogsPublishSelection) -> some View {
        let summary = selection.summary
        return VStack(alignment: .leading, spacing: 7) {
            Label(selection.application.title, systemImage: "folder")
                .font(.headline)
            LabeledContent("Clips", value: "\(summary.clipCount)")
            LabeledContent("Final video duration", value: DevVlogsFormatting.duration(summary.duration))
            LabeledContent("Source size", value: DevVlogsFormatting.byteCount(summary.byteCount))
            LabeledContent("Availability", value: summary.invalidCount == 0 ? "Ready" : "\(summary.invalidCount) unavailable")
        }
        .padding(.vertical, 2)
    }

    private func buildProgressSection(_ progress: DevVlogsPublishBuildProgress) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Label("Creating video", systemImage: "film.stack").font(.headline)
                ProgressView(value: progress.boundedFraction)
                Text(progress.detail).font(.footnote).foregroundStyle(.secondary)
            }
            if presentation.enables(.cancel) {
                Button("Cancel") { onAction(.cancel) }
            }
        } header: {
            Text("Build Progress")
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        switch presentation.state {
        case .cancelled(_, let message):
            statusResult(title: "Video creation cancelled", detail: message, color: .secondary)
        case .failed(_, let message):
            statusResult(title: "Video not created", detail: message, color: .orange)
        case .completed(_, let artifact):
            completedResult(artifact)
        default:
            EmptyView()
        }
    }

    private func statusResult(title: String, detail: String, color: Color) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label(title, systemImage: "exclamationmark.triangle")
                    .font(.headline)
                    .foregroundStyle(color)
                Text(detail).font(.footnote).foregroundStyle(.secondary)
            }
            if presentation.enables(.retry) {
                Button("Retry") { onAction(.retry) }.buttonStyle(.borderedProminent)
            }
        } header: { Text("Result") }
    }

    private func completedResult(_ artifact: DevVlogsPublishArtifact) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label("Video ready", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                Text(artifact.name)
                Text(artifact.detail).font(.footnote).foregroundStyle(.secondary)
            }
            HStack {
                if presentation.enables(.play) {
                    Button("Play") { playingURL = artifact.fileURL }.buttonStyle(.borderedProminent)
                }
                if presentation.enables(.reveal) {
                    Button("Reveal in Finder") { fileActions.reveal(artifact.fileURL) }
                }
                if presentation.enables(.share) {
                    ShareLink(item: artifact.fileURL) { Text("Share…") }
                }
            }
        } header: { Text("Result") }
    }

    private func emptyMessage(title: String, detail: String, systemImage: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: systemImage).foregroundStyle(.secondary)
            Text(detail).font(.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var daySelectionBinding: Binding<String?> {
        Binding(get: { selectedDayID }, set: { if let id = $0 { onSelectDay(id) } })
    }

    private var applicationSelectionBinding: Binding<String> {
        Binding(get: { selectedApplicationID }, set: { onSelectApplication($0) })
    }

    private var refreshStatus: String {
        if isRefreshing { return "Refreshing source…" }
        if refreshFailureMessage != nil { return "Refresh unavailable" }
        guard let lastRefreshAt else { return "Not refreshed yet" }
        return "Updated \(lastRefreshAt.formatted(date: .omitted, time: .shortened))"
    }

    private var refreshButton: some View {
        Button {
            onAction(.refresh)
        } label: {
            if isRefreshing {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("Refreshing…")
                }
            } else {
                Text("Refresh")
            }
        }
        .disabled(isRefreshing)
    }

    private var playingBinding: Binding<Bool> {
        Binding(get: { playingURL != nil }, set: { if !$0 { playingURL = nil } })
    }
}

#Preview("No recordings") {
    DevVlogsPublishView().frame(width: 700, height: 520)
}
