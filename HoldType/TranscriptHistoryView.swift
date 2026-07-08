//
//  TranscriptHistoryView.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import AppKit
import SwiftUI

struct TranscriptHistoryView: View {
    @ObservedObject private var historyStore: TranscriptRecoveryHistoryStore
    @ObservedObject private var failureRecoveryStore: TranscriptionFailureRecoveryStore
    @State private var appSettings: AppSettings
    @State private var actionStatusText: String?
    @State private var recordingCacheRevision = 0

    private let appSettingsStore: AppSettingsStore
    private let copyHistoryEntryAction: TranscriptHistoryClipboardCopyAction
    private let playHistoryAudioAction: TranscriptHistoryAudioPlaybackAction
    private let retryFailedTranscription: @MainActor (FailedTranscriptionAttempt.ID) async -> Void
    private let openSettings: @MainActor (SettingsNavigationItem) -> Void
    private let calendar: Calendar

    @MainActor
    init(
        historyStore: TranscriptRecoveryHistoryStore? = nil,
        failureRecoveryStore: TranscriptionFailureRecoveryStore? = nil,
        appSettingsStore: AppSettingsStore = AppSettingsStore(),
        systemClipboardWriter: any SystemClipboardWriting = SystemClipboardWriter(),
        audioPlayer: any TranscriptHistoryAudioPlaying = TranscriptHistoryAudioPlayer(),
        retryFailedTranscription: @escaping @MainActor (FailedTranscriptionAttempt.ID) async -> Void = { id in
            await DictationRuntime.shared.retryFailedTranscription(id: id)
        },
        openSettings: @escaping @MainActor (SettingsNavigationItem) -> Void = { item in
            SettingsWindowPresenter.shared.show(focusing: item)
        },
        calendar: Calendar = .current
    ) {
        self.historyStore = historyStore ?? TranscriptRecoveryHistoryStore.shared
        self.failureRecoveryStore = failureRecoveryStore ?? TranscriptionFailureRecoveryStore.shared
        self.appSettingsStore = appSettingsStore
        copyHistoryEntryAction = TranscriptHistoryClipboardCopyAction(
            systemClipboardWriter: systemClipboardWriter
        )
        playHistoryAudioAction = TranscriptHistoryAudioPlaybackAction(audioPlayer: audioPlayer)
        self.retryFailedTranscription = retryFailedTranscription
        self.openSettings = openSettings
        self.calendar = calendar
        _appSettings = State(initialValue: appSettingsStore.load())
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            content

            if let actionStatusText {
                Divider()

                Text(actionStatusText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
            }
        }
        .frame(minWidth: 620, minHeight: 420)
        .onAppear(perform: reloadAppSettings)
        .onReceive(NotificationCenter.default.publisher(for: .appSettingsDidChange)) { _ in
            reloadAppSettings()
        }
        .onReceive(NotificationCenter.default.publisher(for: .recordingCacheDidChange)) { _ in
            recordingCacheRevision += 1
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Transcript History")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(headerSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button("Clear History", role: .destructive) {
                clearHistory()
            }
            .disabled(historyRows.isEmpty)
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if !appSettings.saveTranscriptHistory {
            TranscriptHistoryEmptyStateView(
                systemImage: "clock.badge.xmark",
                title: "Transcript history is off",
                message: "Enable recovery history in Settings to keep accepted transcripts and failed attempts until you quit."
            )
        } else if historyRows.isEmpty {
            TranscriptHistoryEmptyStateView(
                systemImage: "text.bubble",
                title: "No transcripts yet",
                message: "Accepted dictations and recoverable failed attempts will appear here until you clear history or quit HoldType."
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(groupedRows) { group in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(group.title)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)

                            VStack(spacing: 8) {
                                ForEach(group.rows) { row in
                                    switch row {
                                    case .transcript(let entry):
                                        TranscriptHistoryRowView(
                                            entry: entry,
                                            canPlayAudio: canPlayAudio(for: entry),
                                            onPlayAudio: {
                                                playCachedAudio(for: entry)
                                            },
                                            onCopy: {
                                                copyToSystemClipboard(entry)
                                            },
                                            onDelete: {
                                                deleteEntry(entry)
                                            }
                                        )
                                    case .failed(let attempt):
                                        FailedTranscriptionHistoryRowView(
                                            attempt: attempt,
                                            onRetry: {
                                                retryAttempt(attempt)
                                            },
                                            onOpenSettings: { item in
                                                openSettings(item)
                                            },
                                            onDelete: {
                                                deleteFailedAttempt(attempt)
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
    }

    private var headerSubtitle: String {
        if appSettings.saveTranscriptHistory {
            let count = historyRows.count
            return "\(count) session \(count == 1 ? "entry" : "entries")"
        }

        return "Session recovery is disabled"
    }

    private var historyRows: [TranscriptHistoryRow] {
        let transcriptRows = historyStore.entries.map(TranscriptHistoryRow.transcript)
        let failedRows = failureRecoveryStore.failedAttempts.map(TranscriptHistoryRow.failed)

        return (transcriptRows + failedRows).sorted { lhs, rhs in
            lhs.createdAt > rhs.createdAt
        }
    }

    private var groupedRows: [TranscriptHistoryGroup] {
        let grouped = Dictionary(grouping: historyRows) { row in
            calendar.startOfDay(for: row.createdAt)
        }

        return grouped.keys.sorted(by: >).map { day in
            TranscriptHistoryGroup(
                day: day,
                title: title(for: day),
                rows: (grouped[day] ?? []).sorted { lhs, rhs in
                    lhs.createdAt > rhs.createdAt
                }
            )
        }
    }

    private func reloadAppSettings() {
        appSettings = appSettingsStore.load()

        if !appSettings.saveTranscriptHistory {
            historyStore.clear()
            failureRecoveryStore.clear()
        }
    }

    private func clearHistory() {
        historyStore.clear()
        failureRecoveryStore.clear()
        actionStatusText = "Transcript history cleared."
    }

    private func copyToSystemClipboard(_ entry: TranscriptHistoryEntry) {
        actionStatusText = copyHistoryEntryAction.copy(entry).statusText
    }

    private func canPlayAudio(for entry: TranscriptHistoryEntry) -> Bool {
        _ = recordingCacheRevision
        return playHistoryAudioAction.canPlay(entry, settings: appSettings)
    }

    private func playCachedAudio(for entry: TranscriptHistoryEntry) {
        actionStatusText = playHistoryAudioAction.play(entry, settings: appSettings).statusText
    }

    private func deleteEntry(_ entry: TranscriptHistoryEntry) {
        let didDelete = historyStore.deleteEntry(id: entry.id)
        actionStatusText = didDelete
            ? "Deleted history row."
            : "History row was already gone."
    }

    private func retryAttempt(_ attempt: FailedTranscriptionAttempt) {
        guard attempt.reason.canRetry else {
            actionStatusText = attempt.reason.message
            return
        }

        actionStatusText = "Retrying failed transcription..."
        Task {
            await retryFailedTranscription(attempt.id)
            await MainActor.run {
                actionStatusText = "Retry finished. Check the latest status in the menu."
            }
        }
    }

    private func deleteFailedAttempt(_ attempt: FailedTranscriptionAttempt) {
        failureRecoveryStore.removeFailedAttempt(id: attempt.id)
        actionStatusText = "Deleted failed transcription row."
    }

    private func title(for day: Date) -> String {
        if calendar.isDateInToday(day) {
            return "Today"
        }

        if calendar.isDateInYesterday(day) {
            return "Yesterday"
        }

        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

private struct TranscriptHistoryGroup: Identifiable {
    let day: Date
    let title: String
    let rows: [TranscriptHistoryRow]

    var id: Date {
        day
    }
}

private enum TranscriptHistoryRow: Identifiable {
    case transcript(TranscriptHistoryEntry)
    case failed(FailedTranscriptionAttempt)

    var id: String {
        switch self {
        case .transcript(let entry):
            return "transcript-\(entry.id.uuidString)"
        case .failed(let attempt):
            return "failed-\(attempt.id.uuidString)"
        }
    }

    var createdAt: Date {
        switch self {
        case .transcript(let entry):
            return entry.createdAt
        case .failed(let attempt):
            return attempt.updatedAt
        }
    }
}

private struct TranscriptHistoryRowView: View {
    let entry: TranscriptHistoryEntry
    let canPlayAudio: Bool
    let onPlayAudio: () -> Void
    let onCopy: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 58, alignment: .leading)

            Text(entry.transcriptText)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if canPlayAudio {
                    Button(action: onPlayAudio) {
                        Label("Play", systemImage: "play.circle")
                    }
                    .help("Play Cached Recording")
                    .accessibilityLabel("Play Cached Recording")
                }

                Button(action: onCopy) {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .help("Copy to Clipboard")
                .accessibilityLabel("Copy Transcript to Clipboard")

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete History Row")
                .accessibilityLabel("Delete Transcript")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .controlSize(.small)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct FailedTranscriptionHistoryRowView: View {
    let attempt: FailedTranscriptionAttempt
    let onRetry: () -> Void
    let onOpenSettings: (SettingsNavigationItem) -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(attempt.updatedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)

                    Text("Not transcribed")
                        .font(.body)
                        .fontWeight(.semibold)
                }

                Text(attempt.reason.message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if let settingsTarget = attempt.reason.settingsTarget {
                    Button {
                        onOpenSettings(settingsTarget)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .help("Open Settings")
                    .controlSize(.small)
                }

                if attempt.reason.canRetry {
                    Button(action: onRetry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .help("Retry Transcription")
                    .controlSize(.small)
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete Failed Attempt")
                .accessibilityLabel("Delete Failed Attempt")
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }

    private var metadataText: String {
        var parts = [attempt.reason.title]

        if !attempt.transcriptionModel.isEmpty {
            parts.append(attempt.transcriptionModel)
        }

        parts.append(attempt.languageCode ?? "Auto")

        if let audioDuration = attempt.audioDuration {
            parts.append(Self.durationFormatter.string(from: audioDuration) ?? "\(Int(audioDuration.rounded()))s")
        }

        if attempt.retryCount > 0 {
            parts.append("Retries: \(attempt.retryCount)")
        }

        return parts.joined(separator: " · ")
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter
    }()
}

private struct TranscriptHistoryEmptyStateView: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 34))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
    }
}

protocol SystemClipboardWriting {
    @discardableResult
    func copyPlainText(_ text: String) -> Bool
}

struct SystemClipboardWriter: SystemClipboardWriting {
    @discardableResult
    func copyPlainText(_ text: String) -> Bool {
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }
}

struct TranscriptHistoryClipboardCopyAction {
    private let systemClipboardWriter: any SystemClipboardWriting

    init(systemClipboardWriter: any SystemClipboardWriting = SystemClipboardWriter()) {
        self.systemClipboardWriter = systemClipboardWriter
    }

    func copy(_ entry: TranscriptHistoryEntry) -> TranscriptHistoryClipboardCopyResult {
        if systemClipboardWriter.copyPlainText(entry.transcriptText) {
            return .copied
        }

        return .failed
    }
}

enum TranscriptHistoryClipboardCopyResult: Equatable {
    case copied
    case failed

    var statusText: String {
        switch self {
        case .copied:
            return "Copied history row to system clipboard."
        case .failed:
            return "Could not copy history row to system clipboard."
        }
    }
}

#Preview {
    TranscriptHistoryView(historyStore: TranscriptRecoveryHistoryStore())
}
