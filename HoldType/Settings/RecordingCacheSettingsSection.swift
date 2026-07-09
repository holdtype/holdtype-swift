//
//  RecordingCacheSettingsSection.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import HoldTypeDomain
import SwiftUI

struct RecordingCacheSettingsSection: View {
    @Binding var settings: AppSettings

    let summary: RecordingCacheSummary
    let errorMessage: String?
    let onRevealCache: () -> Void
    let onRefresh: () -> Void
    let onRevealRecording: (RecordingCacheItem) -> Void
    let onDeleteRecording: (RecordingCacheItem) -> Void
    let onClearCache: () -> Void

    @State private var itemPendingDeletion: RecordingCacheItem?
    @State private var isShowingClearConfirmation = false

    var body: some View {
        Section("Recording Cache") {
            Toggle("Keep completed recordings", isOn: keepCacheBinding)

            Text(cachePolicyDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            RecordingCacheSummaryRows(summary: summary, errorMessage: errorMessage)

            HStack {
                Button(action: onRevealCache) {
                    Label("Reveal Cache", systemImage: "folder")
                }

                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    isShowingClearConfirmation = true
                } label: {
                    Label("Clear Cache", systemImage: "trash")
                }
                .disabled(summary.isEmpty)
            }

            if settings.recordingCachePolicy.keepsRecordings {
                RecordingCacheRetentionControls(settings: $settings)
                RecordingCacheList(
                    items: summary.items,
                    onRevealRecording: onRevealRecording,
                    onRequestDelete: { item in
                        itemPendingDeletion = item
                    }
                )
            } else {
                Label(
                    "Recording cache is off. New completed recordings are deleted after each attempt finishes.",
                    systemImage: "checkmark.shield"
                )
                .foregroundStyle(.secondary)
            }
        }
        .confirmationDialog(
            "Delete cached recording?",
            isPresented: itemDeletionConfirmationBinding,
            presenting: itemPendingDeletion
        ) { item in
            Button("Delete Recording", role: .destructive) {
                onDeleteRecording(item)
                itemPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                itemPendingDeletion = nil
            }
        } message: { item in
            Text(item.fileName)
        }
        .confirmationDialog(
            "Clear recording cache?",
            isPresented: $isShowingClearConfirmation
        ) {
            Button("Clear Cache", role: .destructive, action: onClearCache)
            Button("Cancel", role: .cancel) {}
        }
    }

    private var keepCacheBinding: Binding<Bool> {
        Binding(
            get: {
                settings.recordingCachePolicy.keepsRecordings
            },
            set: { keepCache in
                if keepCache {
                    settings.recordingCachePolicy = .keepLast(
                        RecordingCachePolicy.defaultRetainedRecordingLimit
                    )
                } else {
                    settings.recordingCachePolicy = .deleteImmediately
                }
            }
        )
    }

    private var itemDeletionConfirmationBinding: Binding<Bool> {
        Binding(
            get: {
                itemPendingDeletion != nil
            },
            set: { isPresented in
                if !isPresented {
                    itemPendingDeletion = nil
                }
            }
        )
    }

    private var cachePolicyDescription: String {
        switch settings.recordingCachePolicy.normalized {
        case .deleteImmediately:
            return "HoldType still creates a temporary recording while transcribing, then deletes it after the attempt finishes."
        case .keepLast(let count):
            return "HoldType keeps the last \(count) completed recordings so you can reveal or save them from Finder."
        case .unlimited:
            return "HoldType keeps completed recordings until you delete them. Watch the cache size and clear it when needed."
        }
    }
}

private struct RecordingCacheSummaryRows: View {
    let summary: RecordingCacheSummary
    let errorMessage: String?

    var body: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }

        LabeledContent("Cache size", value: RecordingCacheFormatters.size(summary.totalByteCount))
        LabeledContent("Cached recordings", value: "\(summary.fileCount)")
        LabeledContent("Location", value: summary.directoryURL.path)
    }
}

private struct RecordingCacheRetentionControls: View {
    @Binding var settings: AppSettings

    var body: some View {
        Picker("Retention", selection: retentionModeBinding) {
            ForEach(RecordingCacheRetentionMode.allCases) { mode in
                Text(mode.title).tag(mode)
            }
        }
        .pickerStyle(.segmented)

        switch settings.recordingCachePolicy.normalized {
        case .keepLast:
            Stepper(
                "Keep last \(settings.recordingCachePolicy.retainedRecordingLimit) recordings",
                value: retainedRecordingLimitBinding,
                in: 1...RecordingCachePolicy.maximumRetainedRecordingLimit
            )
        case .unlimited:
            Label(
                "Unlimited cache can grow until you clear it.",
                systemImage: "exclamationmark.triangle"
            )
            .foregroundStyle(.orange)
        case .deleteImmediately:
            EmptyView()
        }
    }

    private var retentionModeBinding: Binding<RecordingCacheRetentionMode> {
        Binding(
            get: {
                settings.recordingCachePolicy == .unlimited ? .unlimited : .keepLast
            },
            set: { mode in
                switch mode {
                case .keepLast:
                    settings.recordingCachePolicy = .keepLast(
                        settings.recordingCachePolicy.retainedRecordingLimit
                    )
                case .unlimited:
                    settings.recordingCachePolicy = .unlimited
                }
            }
        )
    }

    private var retainedRecordingLimitBinding: Binding<Int> {
        Binding(
            get: {
                settings.recordingCachePolicy.retainedRecordingLimit
            },
            set: { count in
                settings.recordingCachePolicy = .keepLast(count)
            }
        )
    }
}

private struct RecordingCacheList: View {
    let items: [RecordingCacheItem]
    let onRevealRecording: (RecordingCacheItem) -> Void
    let onRequestDelete: (RecordingCacheItem) -> Void

    var body: some View {
        if items.isEmpty {
            Label("No cached recordings.", systemImage: "waveform")
                .foregroundStyle(.secondary)
        } else {
            ForEach(items) { item in
                RecordingCacheRow(
                    item: item,
                    onRevealRecording: onRevealRecording,
                    onRequestDelete: onRequestDelete
                )
            }
        }
    }
}

private struct RecordingCacheRow: View {
    let item: RecordingCacheItem
    let onRevealRecording: (RecordingCacheItem) -> Void
    let onRequestDelete: (RecordingCacheItem) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .lineLimit(1)

                Text(
                    "\(RecordingCacheFormatters.date(item.createdAt)) · \(RecordingCacheFormatters.size(item.byteCount))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                onRevealRecording(item)
            } label: {
                Label("Reveal", systemImage: "folder")
            }

            Button(role: .destructive) {
                onRequestDelete(item)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

private enum RecordingCacheRetentionMode: String, CaseIterable, Identifiable {
    case keepLast
    case unlimited

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .keepLast:
            return "Keep Last"
        case .unlimited:
            return "Unlimited"
        }
    }
}

private enum RecordingCacheFormatters {
    static func size(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview("Recording Cache") {
    Form {
        RecordingCacheSettingsSection(
            settings: .constant({
                var settings = AppSettings.defaults
                settings.recordingCachePolicy = .keepLast(10)
                return settings
            }()),
            summary: RecordingCacheSummary(
                directoryURL: URL(fileURLWithPath: "/Users/example/Library/Caches/HoldType/Recordings"),
                items: [
                    RecordingCacheItem(
                        fileURL: URL(fileURLWithPath: "/tmp/HoldType-20260706-120000.m4a"),
                        byteCount: 1_245_000,
                        createdAt: Date()
                    )
                ]
            ),
            errorMessage: nil,
            onRevealCache: {},
            onRefresh: {},
            onRevealRecording: { _ in },
            onDeleteRecording: { _ in },
            onClearCache: {}
        )
    }
    .formStyle(.grouped)
    .padding()
}
