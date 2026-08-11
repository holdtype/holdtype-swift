import SwiftUI

struct DevVlogsLibraryView: View {
    @ObservedObject var store: DevVlogsLibraryStore
    let fileActions: any DevVlogsFileActionPerforming

    @State private var selectedDayID: String?
    @State private var playingURL: URL?
    @State private var pendingDelete: DevVlogsDeleteConfirmation?
    @State private var actionError: String?

    init(
        store: DevVlogsLibraryStore
    ) {
        self.init(store: store, fileActions: SystemDevVlogsFileActions())
    }

    init(
        store: DevVlogsLibraryStore,
        fileActions: any DevVlogsFileActionPerforming
    ) {
        self.store = store
        self.fileActions = fileActions
    }

    var body: some View {
        Form {
            sourceDaySection
            contentSections
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 18, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(HoldTypeWindowTitle.titled("Dev Vlogs"))
        .task {
            await store.refresh()
            selectNewestDayIfNeeded()
        }
        .onChange(of: store.snapshot.days) { _, _ in
            selectNewestDayIfNeeded()
        }
        .sheet(isPresented: playingBinding) {
            if let playingURL {
                DevVlogsPlayerView(url: playingURL)
            }
        }
        .confirmationDialog(
            pendingDelete?.title ?? "Delete this vlog clip?",
            isPresented: deleteConfirmationBinding,
            titleVisibility: .visible
        ) {
            Button("Delete Clip", role: .destructive) {
                guard let pendingDelete else { return }
                Task {
                    do {
                        try await store.delete(pendingDelete)
                    } catch {
                        actionError = error.localizedDescription
                    }
                    self.pendingDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(pendingDelete?.scope ?? "")
        }
        .alert("Library action failed", isPresented: actionErrorBinding) {
            Button("OK") { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    private var sourceDaySection: some View {
        Section {
            switch store.loadState {
            case .loading:
                ProgressView("Loading local recordings…")
            case .failed(let message):
                Label(message, systemImage: "externaldrive.badge.exclamationmark")
                    .foregroundStyle(.orange)
            case .ready where store.snapshot.days.isEmpty:
                emptyLibrary
            case .ready:
                Picker("Recorded day", selection: selectedDayBinding) {
                    ForEach(store.snapshot.days) { day in
                        Text(day.date.formatted(date: .long, time: .omitted))
                            .tag(Optional(day.id))
                    }
                }
                if let day = selectedDay {
                    LabeledContent("Clips", value: "\(day.clipCount)")
                    LabeledContent("Duration", value: DevVlogsFormatting.duration(day.duration))
                    LabeledContent("Size", value: DevVlogsFormatting.byteCount(day.byteCount))
                }
            }
        } header: {
            Text("Recorded Days")
        } footer: {
            Text("Days are shown newest first. Clips remain grouped by the app that triggered their dictation.")
        }
    }

    @ViewBuilder
    private var contentSections: some View {
        if let day = selectedDay {
            ForEach(day.appGroups) { group in
                Section {
                    ForEach(group.clips) { clip in
                        clipRow(clip)
                    }
                } header: {
                    Text(group.displayName)
                } footer: {
                    Text("\(group.clips.count) clips · \(DevVlogsFormatting.duration(group.duration)) · \(DevVlogsFormatting.byteCount(group.byteCount))")
                }
            }
        }
    }

    private func clipRow(_ clip: DevVlogsLibraryClip) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: icon(for: clip.health))
                    .foregroundStyle(color(for: clip.health))
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(clipTitle(clip))
                    Text("\(DevVlogsFormatting.duration(clip.duration)) · \(DevVlogsFormatting.byteCount(clip.byteCount)) · \(clip.health.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack {
                Toggle("Include in Publish", isOn: inclusionBinding(for: clip))
                    .disabled(clip.health != .ready)
                Spacer()
                if let mediaURL = clip.mediaURL, clip.health == .ready {
                    Button("Play") { playingURL = mediaURL }
                    Button("Reveal") { fileActions.reveal(mediaURL) }
                }
                Button("Delete", role: .destructive) {
                    pendingDelete = DevVlogsDeleteConfirmation(clip: clip)
                }
                .disabled(!store.canDelete(clip))
            }
            .controlSize(.small)
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .contain)
    }

    private var emptyLibrary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("No recordings yet", systemImage: "film.stack")
                .foregroundStyle(.secondary)
            Text("Ready Dev Vlogs clips will appear here after an eligible dictation saves one.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var selectedDay: DevVlogsLibraryDay? {
        store.snapshot.days.first { $0.id == selectedDayID }
    }

    private var selectedDayBinding: Binding<String?> {
        Binding(get: { selectedDayID }, set: { selectedDayID = $0 })
    }

    private func inclusionBinding(for clip: DevVlogsLibraryClip) -> Binding<Bool> {
        Binding(
            get: { !clip.isExcluded },
            set: { isIncluded in
                Task {
                    do {
                        try await store.setExcluded(!isIncluded, clip: clip)
                    } catch {
                        actionError = error.localizedDescription
                    }
                }
            }
        )
    }

    private func selectNewestDayIfNeeded() {
        guard !store.snapshot.days.contains(where: { $0.id == selectedDayID }) else { return }
        selectedDayID = store.snapshot.days.first?.id
    }

    private func clipTitle(_ clip: DevVlogsLibraryClip) -> String {
        guard let createdAt = clip.createdAt else { return "Unreadable clip metadata" }
        return createdAt.formatted(date: .omitted, time: .shortened)
    }

    private func icon(for health: DevVlogsLibraryHealth) -> String {
        switch health {
        case .ready: return "checkmark.circle.fill"
        case .missing: return "questionmark.circle"
        case .invalid: return "exclamationmark.triangle"
        }
    }

    private func color(for health: DevVlogsLibraryHealth) -> Color {
        health == .ready ? .green : .orange
    }

    private var playingBinding: Binding<Bool> {
        Binding(
            get: { playingURL != nil },
            set: { if !$0 { playingURL = nil } }
        )
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        )
    }

    private var actionErrorBinding: Binding<Bool> {
        Binding(
            get: { actionError != nil },
            set: { if !$0 { actionError = nil } }
        )
    }
}

#if DEBUG
#Preview("Populated Library") {
    let clipID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 9))
    let clip = DevVlogsLibraryClip(
        id: clipID.uuidString,
        clipID: clipID,
        createdAt: Date(timeIntervalSince1970: 1_754_900_400),
        triggerBundleIdentifier: "app.openai.codex",
        triggerApplicationName: "Codex",
        duration: 18,
        byteCount: 2_400_000,
        health: .ready,
        isExcluded: false,
        mediaURL: URL(fileURLWithPath: "/Preview/clip.mov"),
        relativeDirectory: "2026/2026-08-11/apps/Codex/clips/clip",
        resourceIdentity: nil
    )
    DevVlogsLibraryView(
        store: DevVlogsLibraryStore(
            previewSnapshot: DevVlogsLibrarySnapshot(
                days: [
                    DevVlogsLibraryDay(
                        id: "2026-08-11",
                        date: Date(timeIntervalSince1970: 1_754_870_400),
                        appGroups: [
                            DevVlogsLibraryAppGroup(
                                id: "codex",
                                displayName: "Codex",
                                bundleIdentifier: "app.openai.codex",
                                clips: [clip]
                            )
                        ]
                    )
                ]
            )
        )
    )
    .frame(width: 700, height: 560)
}
#endif
