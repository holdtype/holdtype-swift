//
//  TranscriptHistoryView.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import AppKit
import HoldTypeDomain
import SwiftUI

struct TranscriptHistoryView: View {
    @ObservedObject private var historyStore: TranscriptRecoveryHistoryStore
    @ObservedObject private var failureRecoveryStore: TranscriptionFailureRecoveryStore
    @ObservedObject private var dictationRuntime: DictationRuntime
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
        dictationRuntime: DictationRuntime? = nil,
        appSettingsStore: AppSettingsStore = AppSettingsStore(),
        systemClipboardWriter: any SystemClipboardWriting = SystemClipboardWriter(),
        audioPlayer: any TranscriptHistoryAudioPlaying = TranscriptHistoryAudioPlayer.shared,
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
        self.dictationRuntime = dictationRuntime ?? .shared
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

            Button("Clear Accepted History", role: .destructive) {
                clearHistory()
            }
            .disabled(historyStore.entries.isEmpty)
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if historyRows.isEmpty {
            TranscriptHistoryEmptyStateView(
                systemImage: appSettings.saveTranscriptHistory ? "text.bubble" : "clock.badge.xmark",
                title: appSettings.saveTranscriptHistory ? "No transcripts yet" : "Transcript history is off",
                message: appSettings.saveTranscriptHistory
                    ? "Accepted dictations and saved recordings will appear here."
                    : "Accepted transcripts are not retained. Recordings saved for processing or retry will still appear here."
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
                                            canPlayAudio: canPlayAudio(for: attempt),
                                            savedRecordingActionsEnabled:
                                                savedRecordingActionsEnabled,
                                            onPlayAudio: {
                                                playCachedAudio(for: attempt)
                                            },
                                            onRetry: {
                                                retryAttempt(attempt)
                                            },
                                            onRetrySave: {
                                                retrySavingAttempt(attempt)
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
        let count = historyRows.count
        if !appSettings.saveTranscriptHistory {
            let savedCount = failureRecoveryStore.failedAttempts.count
            guard savedCount > 0 else {
                return "Accepted transcript history is disabled"
            }
            return "Accepted history off · \(savedCount) saved \(savedCount == 1 ? "recording" : "recordings")"
        }

        return "\(count) session \(count == 1 ? "entry" : "entries")"
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
        }
    }

    private func clearHistory() {
        historyStore.clear()
        actionStatusText = "Accepted transcript history cleared. Saved recordings were kept."
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

    private func canPlayAudio(for attempt: FailedTranscriptionAttempt) -> Bool {
        _ = recordingCacheRevision
        return playHistoryAudioAction.canPlay(attempt)
    }

    private func playCachedAudio(for attempt: FailedTranscriptionAttempt) {
        guard savedRecordingActionsEnabled else {
            actionStatusText =
                DictationSessionController.savedRecordingActionsUnavailableMessage
            return
        }
        actionStatusText = playHistoryAudioAction.play(attempt).statusText
    }

    private func deleteEntry(_ entry: TranscriptHistoryEntry) {
        let didDelete = historyStore.deleteEntry(id: entry.id)
        actionStatusText = didDelete
            ? "Deleted history row."
            : "History row was already gone."
    }

    private func retryAttempt(_ attempt: FailedTranscriptionAttempt) {
        guard savedRecordingActionsEnabled else {
            actionStatusText =
                DictationSessionController.savedRecordingActionsUnavailableMessage
            return
        }

        guard attempt.canRetry else {
            if attempt.state == .processing {
                actionStatusText = "Transcription is already in progress."
                return
            }
            if attempt.state == .saved {
                actionStatusText = "This saved recording is already transcribed."
                return
            }
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
        guard savedRecordingActionsEnabled, attempt.canDelete else {
            actionStatusText = attempt.state == .processing
                ? "This saved recording is still being processed."
                : DictationSessionController.savedRecordingActionsUnavailableMessage
            return
        }
        do {
            let didDelete = try failureRecoveryStore.removeFailedAttempt(id: attempt.id)
            actionStatusText = didDelete
                ? "Deleted saved recording."
                : "Saved recording was already gone."
        } catch {
            actionStatusText = TranscriptionFailureRecoveryError.deleteFailed.localizedDescription
        }
    }

    private func retrySavingAttempt(_ attempt: FailedTranscriptionAttempt) {
        guard savedRecordingActionsEnabled else {
            actionStatusText = DictationSessionController.savedRecordingActionsUnavailableMessage
            return
        }
        do {
            switch attempt.reason {
            case .savedStatePersistenceFailed:
                guard let acceptedTranscriptText = attempt.acceptedTranscriptText else {
                    throw TranscriptionFailureRecoveryError.attemptUnavailable
                }
                try failureRecoveryStore.markSaved(
                    id: attempt.id,
                    acceptedTranscriptText: acceptedTranscriptText
                )
                actionStatusText = "Saved recording updated."
            case .recoveryOwnershipPersistenceFailed:
                try failureRecoveryStore.repairLocalRecovery(id: attempt.id)
                actionStatusText = "Recording saved locally. Transcription can now be retried."
            case .providerDispatchPersistenceFailed:
                try failureRecoveryStore.repairLocalRecovery(id: attempt.id)
                actionStatusText = "Retry preparation updated. Transcription can now be retried."
            case .postProcessingFailedAfterProviderAcceptance:
                guard let acceptedTranscriptText = attempt.acceptedTranscriptText else {
                    throw TranscriptionFailureRecoveryError.attemptUnavailable
                }
                try failureRecoveryStore.markSaved(
                    id: attempt.id,
                    acceptedTranscriptText: acceptedTranscriptText
                )
                actionStatusText = "Raw transcription saved."
            default:
                throw TranscriptionFailureRecoveryError.attemptUnavailable
            }
        } catch {
            actionStatusText = "The saved recording still could not be updated."
        }
    }

    private var savedRecordingActionsEnabled: Bool {
        dictationRuntime.status.voiceWorkPhase == .inactive
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
    let canPlayAudio: Bool
    let savedRecordingActionsEnabled: Bool
    let onPlayAudio: () -> Void
    let onRetry: () -> Void
    let onRetrySave: () -> Void
    let onOpenSettings: (SettingsNavigationItem) -> Void
    let onDelete: () -> Void

    private var presentation: TranscriptionRecoveryHistoryRowPresentation {
        TranscriptionRecoveryHistoryRowPresentation(attempt: attempt)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(attempt.updatedAt.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    if presentation.showsProgress {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: presentation.systemImage)
                            .foregroundStyle(
                                attempt.state == .saved ? Color.green : Color.orange
                            )
                    }

                    Text(presentation.title)
                        .font(.body)
                        .fontWeight(.semibold)
                }

                Text(presentation.message)
                    .font(.body)
                    .foregroundStyle(attempt.state == .saved ? .primary : .secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(metadataText)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                if canPlayAudio {
                    Button(action: onPlayAudio) {
                        Label("Play", systemImage: "play.circle")
                    }
                    .help("Play Saved Recording")
                    .accessibilityLabel("Play Saved Recording")
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(!savedRecordingActionsEnabled)
                }

                if presentation.showsSettings,
                   let settingsTarget = attempt.reason.settingsTarget {
                    Button {
                        onOpenSettings(settingsTarget)
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                    .help("Open Settings")
                    .controlSize(.small)
                }

                if presentation.showsRetry {
                    Button(action: onRetry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    .help("Retry Transcription")
                    .controlSize(.small)
                    .disabled(!savedRecordingActionsEnabled)
                }

                if presentation.showsSaveRetry {
                    Button(action: onRetrySave) {
                        Label(
                            presentation.saveRetryTitle,
                            systemImage: "externaldrive.badge.checkmark"
                        )
                    }
                    .help(presentation.saveRetryTitle)
                    .controlSize(.small)
                    .disabled(!savedRecordingActionsEnabled)
                }

                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
                .help("Delete Saved Recording")
                .accessibilityLabel("Delete Saved Recording")
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .controlSize(.small)
                .disabled(
                    !savedRecordingActionsEnabled
                        || !attempt.canDelete
                )
            }
        }
        .padding(12)
        .background(
            backgroundColor,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    private var backgroundColor: Color {
        switch attempt.state {
        case .processing:
            return Color.accentColor.opacity(0.08)
        case .failed:
            return Color.orange.opacity(0.10)
        case .saved:
            return Color.green.opacity(0.08)
        }
    }

    private var metadataText: String {
        var parts: [String] = []

        if attempt.state == .failed {
            parts.append(attempt.reason.title)
        } else if attempt.state == .saved {
            parts.append("Saved")
        }

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

struct TranscriptionRecoveryHistoryRowPresentation: Equatable {
    let title: String
    let message: String
    let systemImage: String
    let showsProgress: Bool
    let showsSettings: Bool
    let showsRetry: Bool
    let showsSaveRetry: Bool
    let saveRetryTitle: String

    init(attempt: FailedTranscriptionAttempt) {
        switch attempt.state {
        case .processing:
            title = "Processing"
            message = "Recording saved. Transcription is in progress."
            systemImage = "waveform"
            showsProgress = true
            showsSettings = false
            showsRetry = false
            showsSaveRetry = false
            saveRetryTitle = "Retry Save"
        case .failed:
            if attempt.reason == .savedStatePersistenceFailed {
                title = "Transcribed — save incomplete"
                message = attempt.acceptedTranscriptText ?? attempt.reason.message
            } else if attempt.reason == .postProcessingFailedAfterProviderAcceptance {
                title = "Raw transcription recovered — post-processing failed"
                message = attempt.acceptedTranscriptText ?? attempt.reason.message
            } else if attempt.reason == .recoveryOwnershipPersistenceFailed
                        || attempt.reason == .providerDispatchPersistenceFailed {
                title = "Recording — save incomplete"
                message = attempt.reason.message
            } else {
                title = "Not transcribed"
                message = attempt.reason.message
            }
            systemImage = "exclamationmark.triangle"
            showsProgress = false
            showsSettings = attempt.reason.settingsTarget != nil
            showsRetry = attempt.canRetry
            showsSaveRetry = (
                attempt.reason == .savedStatePersistenceFailed
                    && attempt.acceptedTranscriptText != nil
            ) || attempt.reason == .recoveryOwnershipPersistenceFailed
                || attempt.reason == .providerDispatchPersistenceFailed
                || (
                    attempt.reason == .postProcessingFailedAfterProviderAcceptance
                        && attempt.acceptedTranscriptText != nil
                )
            saveRetryTitle = attempt.reason
                == .postProcessingFailedAfterProviderAcceptance
                ? "Save Raw Transcription"
                : "Retry Save"
        case .saved:
            title = attempt.reason == .postProcessingFailedAfterProviderAcceptance
                ? "Raw transcription saved — post-processing failed"
                : "Saved and transcribed"
            message = attempt.acceptedTranscriptText ?? "Transcription completed."
            systemImage = "checkmark.circle.fill"
            showsProgress = false
            showsSettings = false
            showsRetry = false
            showsSaveRetry = false
            saveRetryTitle = "Retry Save"
        }
    }
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
