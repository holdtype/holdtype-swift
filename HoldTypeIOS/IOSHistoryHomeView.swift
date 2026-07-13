import HoldTypePersistence
import SwiftUI
import UIKit

struct IOSHistoryHomeView: View {
    @Environment(IOSAcceptedTextHistoryStateOwner.self)
    private var stateOwner
    @State private var pendingClearToken:
        IOSAcceptedTextHistorySnapshotToken?
    @State private var pendingDisableToken:
        IOSAcceptedTextHistorySnapshotToken?

    var body: some View {
        Group {
            switch IOSAcceptedTextHistoryHomePresentation.resolve(
                stateOwner.state
            ) {
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
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                refreshToolbarItem
            }
        }
        .task {
            await stateOwner.refresh()
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
            Text("This permanently removes every saved History entry on this device.")
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
        .accessibilityIdentifier(
            IOSContainingAppDestination.history.accessibilityIdentifier
        )
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

    @ViewBuilder
    private var refreshToolbarItem: some View {
        if stateOwner.isBusy {
            ProgressView()
                .accessibilityLabel("Updating History")
        } else {
            Button {
                Task { await stateOwner.refresh() }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .accessibilityIdentifier("ios.history.refresh")
        }
    }

    private func historyList(
        _ record: IOSAcceptedTextHistoryRecord,
        content: IOSAcceptedTextHistoryHomePresentation.Content,
        isStale: Bool
    ) -> some View {
        List {
            saveHistorySection(record)

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
                    if notice == .keyboardProjectionUpdateFailed {
                        Button("Retry Keyboard Update") {
                            Task {
                                await stateOwner.retryKeyboardProjection()
                            }
                        }
                        .disabled(stateOwner.isBusy)
                        .accessibilityIdentifier(
                            "ios.history.retry-keyboard-update"
                        )
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
                Section("Recent Results") {
                    ForEach(record.entries) { entry in
                        historyRow(entry)
                    }
                }

                Section {
                    Button("Clear All History", role: .destructive) {
                        pendingClearToken = IOSAcceptedTextHistorySnapshotToken(
                            record: record
                        )
                    }
                    .disabled(stateOwner.isBusy)
                    .accessibilityIdentifier("ios.history.clear-all")
                }
            }

            Section {
                Text(
                    "History stores only the 20 newest successful texts "
                        + "locally on this device. It never stores audio, API "
                        + "keys, prompts, or failed attempts."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .refreshable {
            guard !stateOwner.isBusy else { return }
            await stateOwner.refresh()
        }
    }

    private func saveHistorySection(
        _ record: IOSAcceptedTextHistoryRecord
    ) -> some View {
        Section {
            Toggle(
                "Save History",
                isOn: Binding(
                    get: { record.isEnabled },
                    set: { requestedValue in
                        guard requestedValue != record.isEnabled else {
                            return
                        }
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
            )
            .disabled(stateOwner.isBusy)
            .accessibilityIdentifier("ios.history.save-history")
        } footer: {
            Text("When on, successful texts are saved locally after Latest Result is ready.")
        }
    }

    private func historyRow(
        _ entry: IOSAcceptedTextHistoryEntry
    ) -> some View {
        NavigationLink {
            IOSHistoryDetailView(resultID: entry.resultID)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.text)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(entry.createdAt, format: .dateTime.day().month().year().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                Task { await stateOwner.delete(resultID: entry.resultID) }
            }
            .disabled(stateOwner.isBusy)
        }
        .contextMenu {
            Button("Copy") {
                UIPasteboard.general.string = entry.text
            }
            ShareLink(item: entry.text)
            Button("Delete", role: .destructive) {
                Task { await stateOwner.delete(resultID: entry.resultID) }
            }
        }
        .accessibilityIdentifier("ios.history.entry.\(entry.resultID.uuidString)")
    }
}

private struct IOSHistoryDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(IOSAcceptedTextHistoryStateOwner.self)
    private var stateOwner

    let resultID: UUID

    var body: some View {
        Group {
            if let entry = currentEntry {
                List {
                    Section("Text") {
                        Text(entry.text)
                            .textSelection(.enabled)
                    }
                    Section("Saved") {
                        Text(
                            entry.createdAt,
                            format: .dateTime
                                .day()
                                .month()
                                .year()
                                .hour()
                                .minute()
                                .second()
                        )
                    }
                    Section {
                        Button("Copy") {
                            UIPasteboard.general.string = entry.text
                        }
                        ShareLink("Share", item: entry.text)
                        Button("Delete", role: .destructive) {
                            Task {
                                if await stateOwner.delete(
                                    resultID: resultID
                                ) {
                                    dismiss()
                                }
                            }
                        }
                        .disabled(stateOwner.isBusy)
                    }
                }
            } else {
                ContentUnavailableView {
                    Label(
                        "History Result Removed",
                        systemImage: "trash"
                    )
                } description: {
                    Text(
                        "This result is no longer in the confirmed History."
                    )
                } actions: {
                    Button("Back") {
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle("History Result")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.history.detail")
    }

    private var currentEntry: IOSAcceptedTextHistoryEntry? {
        stateOwner.confirmedRecord?.entries.first {
            $0.resultID == resultID
        }
    }
}
