import HoldTypePersistence
import SwiftUI
import UIKit

@MainActor
struct IOSHistoryRowActions {
    private let copyText: (String) -> Void

    init(copyText: @escaping (String) -> Void) {
        self.copyText = copyText
    }

    func copy(_ text: String) {
        copyText(text)
    }

}

enum IOSHistoryHomeLayout: Equatable, Sendable {
    case acceptedHistoryOnly(IOSAcceptedTextHistoryHomePresentation)
    case savedRecordingFirst(IOSAcceptedTextHistoryHomePresentation)

    static func resolve(
        acceptedHistory: IOSAcceptedTextHistoryHomePresentation,
        hasSavedRecording: Bool
    ) -> Self {
        if hasSavedRecording {
            return .savedRecordingFirst(acceptedHistory)
        }
        return .acceptedHistoryOnly(acceptedHistory)
    }
}

enum IOSSavedRecordingHistoryPresentationState: Equatable, Sendable {
    case loading
    case ready([IOSSavedAcceptedRecording])
    case stale([IOSSavedAcceptedRecording])
    case unavailable

    var recordings: [IOSSavedAcceptedRecording] {
        switch self {
        case .ready(let recordings), .stale(let recordings):
            recordings
        case .loading, .unavailable:
            []
        }
    }

    var shouldPresent: Bool {
        switch self {
        case .ready(let recordings):
            !recordings.isEmpty
        case .stale, .unavailable:
            true
        case .loading:
            false
        }
    }

    static func resolving(
        previous: Self,
        result: IOSSavedRecordingHistoryLoadResult
    ) -> Self {
        switch result {
        case .loaded(let recordings):
            return .ready(recordings)
        case .failed:
            let recordings = previous.recordings
            return recordings.isEmpty ? .unavailable : .stale(recordings)
        }
    }
}

struct IOSHistoryHomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(IOSAcceptedTextHistoryStateOwner.self)
    private var stateOwner
    @State private var pendingClearToken:
        IOSAcceptedTextHistorySnapshotToken?
    @State private var pendingDisableToken:
        IOSAcceptedTextHistorySnapshotToken?
    @State private var pendingRecordingDiscardToken:
        IOSPendingRecordingHistorySnapshotToken?
    @State private var pendingSavedAcceptedRecordingDiscard:
        IOSSavedAcceptedRecording?
    @State private var playableResultIDs = Set<UUID>()
    @State private var showsPlaybackFailure = false
    @State private var savedRecordingState:
        IOSSavedRecordingHistoryPresentationState = .loading
    @State private var savedRecordingActionID: UUID?
    @State private var showsSavedRecordingActionFailure = false

    private let rowActions: IOSHistoryRowActions
    private let playbackActions: IOSHistoryPlaybackActions?
    private let pendingRecordingOwner:
        IOSPendingRecordingHistoryStateOwner?

    private var resolvedLayout: IOSHistoryHomeLayout {
        let acceptedHistory = IOSAcceptedTextHistoryHomePresentation.resolve(
            stateOwner.state
        )
        let hasSavedRecording =
            pendingRecordingOwner?.shouldPresentSavedRecording == true
                || savedRecordingState.shouldPresent
        return IOSHistoryHomeLayout.resolve(
            acceptedHistory: acceptedHistory,
            hasSavedRecording: hasSavedRecording
        )
    }

    init(
        playbackActions: IOSHistoryPlaybackActions? = nil,
        pendingRecordingOwner:
            IOSPendingRecordingHistoryStateOwner? = nil
    ) {
        rowActions = IOSHistoryRowActions(
            copyText: { UIPasteboard.general.string = $0 }
        )
        self.playbackActions = playbackActions
        self.pendingRecordingOwner = pendingRecordingOwner
    }

    init(
        rowActions: IOSHistoryRowActions,
        playbackActions: IOSHistoryPlaybackActions? = nil,
        pendingRecordingOwner:
            IOSPendingRecordingHistoryStateOwner? = nil
    ) {
        self.rowActions = rowActions
        self.playbackActions = playbackActions
        self.pendingRecordingOwner = pendingRecordingOwner
    }

    var body: some View {
        historyContent(for: resolvedLayout)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                historyManagementMenu
            }
        }
        .task {
            await stateOwner.refresh()
            await pendingRecordingOwner?.refresh()
        }
        .task(id: pendingRecordingPollingToken) {
            guard let pendingRecordingOwner,
                  pendingRecordingOwner.card?.status.isProcessing == true
            else { return }
            while !Task.isCancelled,
                  pendingRecordingOwner.card?.status.isProcessing == true {
                do {
                    try await Task.sleep(for: .milliseconds(500))
                } catch {
                    return
                }
                _ = await pendingRecordingOwner.refresh()
            }
        }
        .task(id: playbackRefreshToken) {
            await refreshPlaybackAvailability()
            await refreshSavedRecordings()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await refreshSavedRecordings()
                await refreshPlaybackAvailability()
                await pendingRecordingOwner?.refresh()
            }
        }
        .onDisappear {
            Task {
                await playbackActions?.stop()
                await pendingRecordingOwner?.stopPlayback()
            }
        }
        .alert(
            "Recording Unavailable",
            isPresented: $showsPlaybackFailure
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("HoldType couldn’t play this cached recording.")
        }
        .alert(
            "Saved Recording Unavailable",
            isPresented: $showsSavedRecordingActionFailure
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(
                "HoldType couldn’t complete that saved-recording action. "
                    + "The last confirmed list remains visible."
            )
        }
        .confirmationDialog(
            "Clear All History?",
            isPresented: Binding(
                get: { pendingClearToken != nil },
                set: { if !$0 { pendingClearToken = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Clear All History", role: .destructive) {
                guard let token = pendingClearToken else { return }
                pendingClearToken = nil
                Task { await stateOwner.clearAll(ifCurrent: token) }
            }
            .disabled(stateOwner.isBusy)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This permanently removes accepted text History on this device. Saved Recordings remain available until you discard them separately."
            )
        }
        .confirmationDialog(
            "Turn Off Save History?",
            isPresented: Binding(
                get: { pendingDisableToken != nil },
                set: { if !$0 { pendingDisableToken = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Turn Off and Delete History", role: .destructive) {
                guard let token = pendingDisableToken else { return }
                pendingDisableToken = nil
                Task {
                    await stateOwner.setEnabled(
                        false,
                        ifCurrent: token
                    )
                }
            }
            .disabled(stateOwner.isBusy)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "HoldType will stop saving successful texts and permanently "
                    + "delete the current History on this device."
            )
        }
        .confirmationDialog(
            "Discard Saved Recording?",
            isPresented: Binding(
                get: { pendingRecordingDiscardToken != nil },
                set: {
                    if !$0 { pendingRecordingDiscardToken = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard Recording", role: .destructive) {
                guard let token = pendingRecordingDiscardToken else { return }
                pendingRecordingDiscardToken = nil
                Task {
                    await pendingRecordingOwner?.discard(
                        ifCurrent: token
                    )
                }
            }
            .disabled(pendingRecordingOwner?.isBusy != false)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This permanently removes the saved audio. It does not "
                    + "remove accepted text from History."
            )
        }
        .confirmationDialog(
            "Discard Transcribed Recording?",
            isPresented: Binding(
                get: { pendingSavedAcceptedRecordingDiscard != nil },
                set: {
                    if !$0 { pendingSavedAcceptedRecordingDiscard = nil }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Discard Recording", role: .destructive) {
                guard let recording =
                        pendingSavedAcceptedRecordingDiscard else {
                    return
                }
                pendingSavedAcceptedRecordingDiscard = nil
                discardSavedRecording(recording)
            }
            .disabled(savedRecordingActionID != nil)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This permanently removes the five-minute audio. Accepted "
                    + "text and Latest Result are not changed."
            )
        }
        .accessibilityIdentifier(
            IOSContainingAppDestination.history.accessibilityIdentifier
        )
    }

    @ViewBuilder
    private func historyContent(for layout: IOSHistoryHomeLayout) -> some View {
        switch layout {
        case .savedRecordingFirst(let acceptedHistory):
            recoveryFirstHistoryList(acceptedHistory)
        case .acceptedHistoryOnly(let acceptedHistory):
            acceptedHistoryContent(acceptedHistory)
        }
    }

    @ViewBuilder
    private func acceptedHistoryContent(
        _ presentation: IOSAcceptedTextHistoryHomePresentation
    ) -> some View {
        switch presentation {
        case .loading:
            IOSDestinationLoadingView(title: "Loading History")
        case .unavailable:
            unavailableContent
        case .history(let record, let content, let isStale):
            historyList(
                record,
                content: content,
                isStale: isStale
            )
        }
    }

    private var unavailableContent: some View {
        IOSDestinationLoadFailureView(
            title: "History Unavailable",
            description:
                "HoldType couldn't read device-local History. Stored data was "
                    + "preserved and was not replaced with an empty list.",
            isRetrying: stateOwner.isBusy,
            retry: { Task { await stateOwner.refresh() } }
        )
    }

    private var historyManagementMenu: some View {
        Menu {
            Button {
                Task { await stateOwner.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("ios.history.refresh")

            if let record = stateOwner.confirmedRecord {
                Divider()

                Toggle(
                    "Save History",
                    isOn: saveHistoryBinding(record)
                )
                .accessibilityIdentifier("ios.history.save-history")

                Button("Clear All History", role: .destructive) {
                    pendingClearToken = IOSAcceptedTextHistorySnapshotToken(
                        record: record
                    )
                }
                .disabled(record.entries.isEmpty)
                .accessibilityIdentifier("ios.history.clear-all")
            }
        } label: {
            Label("History Options", systemImage: "ellipsis.circle")
        }
        .disabled(stateOwner.isBusy)
        .accessibilityIdentifier("ios.history.menu")
    }

    private func saveHistoryBinding(
        _ record: IOSAcceptedTextHistoryRecord
    ) -> Binding<Bool> {
        Binding(
            get: { record.isEnabled },
            set: { requestedValue in
                guard requestedValue != record.isEnabled else { return }

                let token = IOSAcceptedTextHistorySnapshotToken(
                    record: record
                )
                if requestedValue {
                    Task {
                        await stateOwner.setEnabled(
                            true,
                            ifCurrent: token
                        )
                    }
                } else {
                    pendingDisableToken = token
                }
            }
        )
    }

    private func historyList(
        _ record: IOSAcceptedTextHistoryRecord,
        content: IOSAcceptedTextHistoryHomePresentation.Content,
        isStale: Bool
    ) -> some View {
        List {
            pendingRecordingSection
            savedAcceptedRecordingsSection

            acceptedHistorySections(
                record,
                content: content,
                isStale: isStale
            )
        }
        .refreshable {
            guard !stateOwner.isBusy else { return }
            await stateOwner.refresh()
            await pendingRecordingOwner?.refresh()
            await refreshPlaybackAvailability()
            await refreshSavedRecordings()
        }
    }

    private func recoveryFirstHistoryList(
        _ presentation: IOSAcceptedTextHistoryHomePresentation
    ) -> some View {
        List {
            pendingRecordingSection
            savedAcceptedRecordingsSection

            switch presentation {
            case .loading:
                Section("Accepted Text History") {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading accepted text History…")
                            .foregroundStyle(.secondary)
                    }
                }
            case .unavailable:
                Section("Accepted Text History") {
                    unavailableContent
                }
            case .history(let record, let content, let isStale):
                acceptedHistorySections(
                    record,
                    content: content,
                    isStale: isStale
                )
            }
        }
        .refreshable {
            await pendingRecordingOwner?.refresh()
            if !stateOwner.isBusy {
                await stateOwner.refresh()
            }
            await refreshPlaybackAvailability()
            await refreshSavedRecordings()
        }
    }

    @ViewBuilder
    private func acceptedHistorySections(
        _ record: IOSAcceptedTextHistoryRecord,
        content: IOSAcceptedTextHistoryHomePresentation.Content,
        isStale: Bool
    ) -> some View {
        if let notice = stateOwner.notice {
            Section {
                Label {
                    Text(notice.message)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                Button("Dismiss") {
                    stateOwner.dismissNotice()
                }
            }
            .accessibilityIdentifier("ios.history.warning")
        }

        if isStale {
            Section {
                Label(
                    "History couldn't be refreshed. The last confirmed list remains visible.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.secondary)
            }
        }

        switch content {
        case .disabled:
            Section {
                ContentUnavailableView {
                    Label("History Is Off", systemImage: "clock.badge.xmark")
                } description: {
                    Text("Turn on Save History to keep future successful texts on this device.")
                }
            }
            .accessibilityIdentifier("ios.history.disabled")
        case .empty:
            Section {
                ContentUnavailableView {
                    Label("No History Yet", systemImage: "clock")
                } description: {
                    Text("Successful texts will appear here after you finish a dictation.")
                }
            }
            .accessibilityIdentifier("ios.history.empty")
        case .entries:
            ForEach(record.entries) { entry in
                historyRow(entry)
            }
        }
    }

    @ViewBuilder
    private var savedAcceptedRecordingsSection: some View {
        switch savedRecordingState {
        case .loading:
            if playbackActions != nil {
                Section("Saved Recordings") {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Loading saved recordings…")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        case .ready(let recordings):
            if !recordings.isEmpty {
                savedAcceptedRecordingsContent(
                    recordings,
                    showsStaleWarning: false
                )
            }
        case .stale(let recordings):
            savedAcceptedRecordingsContent(
                recordings,
                showsStaleWarning: true
            )
        case .unavailable:
            Section("Saved Recordings") {
                Label(
                    "Saved Recordings Need Attention",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
                Text(
                    "HoldType couldn't confirm saved five-minute audio. "
                        + "Nothing was removed."
                )
                .foregroundStyle(.secondary)
                Button {
                    Task { await refreshSavedRecordings() }
                } label: {
                    Label("Retry Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(savedRecordingActionID != nil)
            }
            .accessibilityIdentifier(
                "ios.history.transcribed-recordings.unavailable"
            )
        }
    }

    private func savedAcceptedRecordingsContent(
        _ recordings: [IOSSavedAcceptedRecording],
        showsStaleWarning: Bool
    ) -> some View {
        Section("Saved Recordings") {
            if showsStaleWarning {
                Label(
                    "The last confirmed saved recordings remain visible.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .foregroundStyle(.orange)
            }

            ForEach(recordings) { recording in
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Five-minute recording")
                            .font(.headline)
                        Text(
                            recording.createdAt.formatted(
                                date: .abbreviated,
                                time: .shortened
                            )
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        playSavedRecording(recording)
                    } label: {
                        Label("Play", systemImage: "play.fill")
                    }
                    .disabled(savedRecordingActionID != nil)
                    .accessibilityIdentifier(
                        "ios.history.transcribed-recording.play."
                            + recording.resultID.uuidString
                    )

                    Button("Discard", role: .destructive) {
                        pendingSavedAcceptedRecordingDiscard = recording
                    }
                    .disabled(savedRecordingActionID != nil)
                    .accessibilityIdentifier(
                        "ios.history.transcribed-recording.discard."
                            + recording.resultID.uuidString
                    )
                }
            }
        }
        .accessibilityIdentifier("ios.history.transcribed-recordings")
    }

    @ViewBuilder
    private var pendingRecordingSection: some View {
        if let pendingRecordingOwner,
           let card = pendingRecordingOwner.card {
            Section("Saved Recording") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Label(
                            pendingStatusTitle(card.status),
                            systemImage: pendingStatusImage(card.status)
                        )
                        .font(.headline)
                        .foregroundStyle(
                            pendingStatusColor(card.status)
                        )

                        Spacer()

                        if let durationText = card.durationText {
                            Text(durationText)
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .accessibilityLabel(
                                    "Recording duration " + durationText
                                )
                        }
                    }

                    Text(pendingStatusDescription(card))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        if card.isPlayable {
                            Button {
                                Task {
                                    await pendingRecordingOwner.play(
                                        ifCurrent: card.token
                                    )
                                }
                            } label: {
                                Label("Play", systemImage: "play.fill")
                            }
                            .disabled(pendingRecordingOwner.isBusy)
                            .accessibilityIdentifier(
                                "ios.history.saved-recording.play"
                            )
                        }

                        if let primaryAction = card.primaryAction {
                            Button {
                                Task {
                                    await pendingRecordingOwner.retry(
                                        ifCurrent: card.token
                                    )
                                }
                            } label: {
                                Label(
                                    primaryAction == .transcribe
                                        ? "Transcribe" : "Retry",
                                    systemImage: "text.badge.plus"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(pendingRecordingOwner.isBusy)
                            .accessibilityIdentifier(
                                primaryAction == .transcribe
                                    ? "ios.history.saved-recording.transcribe"
                                    : "ios.history.saved-recording.retry"
                            )
                        }

                        Spacer()

                        Button("Discard", role: .destructive) {
                            pendingRecordingDiscardToken = card.token
                        }
                        .disabled(
                            pendingRecordingOwner.isBusy
                                || card.status.isProcessing
                        )
                        .accessibilityIdentifier(
                            "ios.history.saved-recording.discard"
                        )
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.vertical, 4)

                if let notice = pendingRecordingOwner.notice {
                    Label {
                        Text(notice.message)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }
                    Button("Dismiss") {
                        pendingRecordingOwner.dismissNotice()
                    }
                }

                if pendingRecordingOwner.state.isStale {
                    Label(
                        "The last confirmed saved recording remains visible.",
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .accessibilityIdentifier("ios.history.saved-recording")
        } else if let pendingRecordingOwner,
                  pendingRecordingOwner.state.isStale {
            Section("Saved Recording") {
                Label(
                    "Saved Recording Needs Attention",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.headline)
                .foregroundStyle(.orange)

                Text(
                    "HoldType couldn't confirm the saved audio. Nothing was "
                        + "removed, and a new dictation will not replace it."
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button {
                    Task { _ = await pendingRecordingOwner.refresh() }
                } label: {
                    Label("Retry Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
                .disabled(pendingRecordingOwner.isBusy)
                .accessibilityIdentifier(
                    "ios.history.saved-recording.refresh"
                )
            }
            .accessibilityIdentifier("ios.history.saved-recording")
        }
    }

    private func pendingStatusTitle(
        _ status: IOSPendingRecordingHistoryStatus
    ) -> String {
        switch status {
        case .ready:
            "Ready to Transcribe"
        case .processing(.transcribing):
            "Transcribing"
        case .processing(.postProcessing):
            "Finishing Text"
        case .processing(.savingResult):
            "Saving Result"
        case .failed:
            "Not Transcribed"
        case .blocked:
            "Recording Needs Attention"
        }
    }

    private func pendingStatusDescription(
        _ card: IOSPendingRecordingHistoryCard
    ) -> String {
        switch card.status {
        case .ready:
            "The audio is saved on this device and has not been uploaded."
        case .processing:
            "The audio stays saved until transcription finishes."
        case .failed:
            "Your audio is still saved. Retry when you're ready."
        case .blocked:
            switch card.blockedReason {
            case .providerResultUnrecoverable:
                "HoldType couldn't safely recover the processing result. "
                    + "Your audio is still saved; you can play or discard it."
            case .durationLimitExceeded:
                "This recording exceeds the five-minute transcription limit. "
                    + "The audio is still saved; you can play or discard it."
            case .audioUnavailable, nil:
                "HoldType preserved this recording, but its audio isn't "
                    + "currently available for transcription."
            }
        }
    }

    private func pendingStatusImage(
        _ status: IOSPendingRecordingHistoryStatus
    ) -> String {
        switch status {
        case .ready: "waveform.badge.checkmark"
        case .processing: "waveform.badge.magnifyingglass"
        case .failed: "arrow.clockwise.circle.fill"
        case .blocked: "exclamationmark.triangle.fill"
        }
    }

    private func pendingStatusColor(
        _ status: IOSPendingRecordingHistoryStatus
    ) -> Color {
        switch status {
        case .ready: .blue
        case .processing: .orange
        case .failed, .blocked: .red
        }
    }

    private func historyRow(
        _ entry: IOSAcceptedTextHistoryEntry
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(entry.text)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 0) {
                if playableResultIDs.contains(entry.resultID) {
                    historyActionButton(
                        title: "Play Recording",
                        systemImage: "play.fill"
                    ) {
                        beginPlayback(resultID: entry.resultID)
                    }
                    .accessibilityIdentifier(
                        "ios.history.play.\(entry.resultID.uuidString)"
                    )
                }

                historyActionButton(
                    title: "Copy Text",
                    systemImage: "doc.on.doc"
                ) {
                    rowActions.copy(entry.text)
                }
                .accessibilityHint("Copies this text to the clipboard")
                .accessibilityIdentifier(
                    "ios.history.copy.\(entry.resultID.uuidString)"
                )
            }
        }
        .padding(.vertical, 4)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                Task { await stateOwner.delete(resultID: entry.resultID) }
            }
            .disabled(stateOwner.isBusy)
        }
    }

    private func historyActionButton(
        title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private var playbackRefreshToken: String {
        stateOwner.confirmedRecord?.entries
            .map(\.resultID.uuidString)
            .joined(separator: "|") ?? ""
    }

    private var pendingRecordingPollingToken: String {
        guard let pendingRecordingOwner else { return "unavailable" }
        guard let card = pendingRecordingOwner.card else { return "absent" }
        return "\(card.id.uuidString)|\(String(describing: card.status))"
    }

    private func refreshPlaybackAvailability() async {
        guard let playbackActions,
              let record = stateOwner.confirmedRecord else {
            playableResultIDs = []
            return
        }
        let resolved = await playbackActions.playableResultIDs(
            record.entries.map(\.resultID)
        )
        guard !Task.isCancelled else { return }
        playableResultIDs = resolved
    }

    private func refreshSavedRecordings() async {
        guard let playbackActions else {
            savedRecordingState = .ready([])
            return
        }
        let result = await playbackActions.savedRecordings()
        guard !Task.isCancelled else { return }
        savedRecordingState = .resolving(
            previous: savedRecordingState,
            result: result
        )
    }

    private func playSavedRecording(
        _ recording: IOSSavedAcceptedRecording
    ) {
        guard let playbackActions, savedRecordingActionID == nil else {
            return
        }
        savedRecordingActionID = recording.resultID
        Task {
            let result = await playbackActions.playSaved(recording)
            guard savedRecordingActionID == recording.resultID else { return }
            savedRecordingActionID = nil
            switch result {
            case .played:
                break
            case .unavailable, .failed:
                showsSavedRecordingActionFailure = true
                await refreshSavedRecordings()
            }
        }
    }

    private func discardSavedRecording(
        _ recording: IOSSavedAcceptedRecording
    ) {
        guard let playbackActions, savedRecordingActionID == nil else {
            return
        }
        savedRecordingActionID = recording.resultID
        Task {
            let result = await playbackActions.discardSaved(recording)
            guard savedRecordingActionID == recording.resultID else { return }
            savedRecordingActionID = nil
            switch result {
            case .discarded, .alreadyAbsent:
                await refreshSavedRecordings()
                await refreshPlaybackAvailability()
            case .stale:
                await refreshSavedRecordings()
                showsSavedRecordingActionFailure = true
            case .failed:
                showsSavedRecordingActionFailure = true
            }
        }
    }

    private func beginPlayback(resultID: UUID) {
        guard let playbackActions else { return }

        Task {
            switch await playbackActions.play(resultID: resultID) {
            case .played:
                break
            case .unavailable:
                playableResultIDs.remove(resultID)
            case .failed:
                playableResultIDs.remove(resultID)
                showsPlaybackFailure = true
            }
        }
    }
}
