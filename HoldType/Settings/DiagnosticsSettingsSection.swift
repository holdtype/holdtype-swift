//
//  DiagnosticsSettingsSection.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import SwiftUI

struct DiagnosticsSettingsSection: View {
    let summary: DiagnosticReportSummary
    let runtimeLogSummary: DiagnosticRuntimeLogSummary
    let errorMessage: String?
    let runtimeLogErrorMessage: String?
    let bundleResult: DiagnosticBundleResult?
    let bundleErrorMessage: String?
    let onRevealReportsDirectory: () -> Void
    let onCopyReportsDirectoryPath: () -> Void
    let onRefresh: () -> Void
    let onRevealReport: (DiagnosticReportItem) -> Void
    let onCopyReportPath: (DiagnosticReportItem) -> Void
    let onRevealRuntimeLogsDirectory: () -> Void
    let onCopyRuntimeLogs: () -> Void
    let onExportBundle: () -> Void

    var body: some View {
        Section("Diagnostics") {
            Text("Crash reports are stored by macOS outside HoldType. Exported diagnostic bundles stay local until you send them.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            DiagnosticSummaryRows(summary: summary, errorMessage: errorMessage)

            HStack {
                Button(action: onRevealReportsDirectory) {
                    Label("Reveal Reports", systemImage: "folder")
                }

                Button(action: onCopyReportsDirectoryPath) {
                    Label("Copy Path", systemImage: "doc.on.doc")
                }

                Button(action: onRefresh) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }

            Button(action: onExportBundle) {
                Label("Export Diagnostic Bundle", systemImage: "square.and.arrow.up")
            }

            if let bundleResult {
                Label(
                    "Exported \(bundleResult.bundleURL.lastPathComponent)",
                    systemImage: "checkmark.circle"
                )
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .truncationMode(.middle)
            }

            if let bundleErrorMessage {
                Label(bundleErrorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }
        }

        Section("Runtime Logs") {
            if let runtimeLogErrorMessage {
                Label(runtimeLogErrorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            LabeledContent("Recent events", value: "\(runtimeLogSummary.lineCount)")
            LabeledContent("Location") {
                Text(runtimeLogSummary.directoryURL.path)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }

            HStack {
                Button(action: onRevealRuntimeLogsDirectory) {
                    Label("Reveal Logs", systemImage: "folder")
                }

                Button(action: onCopyRuntimeLogs) {
                    Label("Copy Recent Events", systemImage: "doc.on.doc")
                }
                .disabled(runtimeLogSummary.isEmpty)
            }

            if runtimeLogSummary.isEmpty {
                Label("No runtime events recorded yet.", systemImage: "text.badge.checkmark")
                    .foregroundStyle(.secondary)
            } else {
                RuntimeLogLinesView(lines: runtimeLogSummary.recentLines)
            }
        }

        Section("Crash Reports") {
            if summary.items.isEmpty {
                Label(emptyStateMessage, systemImage: "checkmark.shield")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(summary.items) { item in
                    DiagnosticReportRow(
                        item: item,
                        onRevealReport: onRevealReport,
                        onCopyReportPath: onCopyReportPath
                    )
                }
            }
        }
    }

    private var emptyStateMessage: String {
        switch summary.directoryStatus {
        case .available:
            return "No HoldType crash reports found."
        case .missing:
            return "Diagnostic Reports folder has not been created yet."
        }
    }
}

private struct RuntimeLogLinesView: View {
    let lines: [String]

    var body: some View {
        let previewLines = Array(lines.suffix(8))

        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(previewLines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        }
    }
}

private struct DiagnosticSummaryRows: View {
    let summary: DiagnosticReportSummary
    let errorMessage: String?

    var body: some View {
        if let errorMessage {
            Label(errorMessage, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }

        LabeledContent("Crash reports", value: "\(summary.fileCount)")
        LabeledContent("Folder status", value: folderStatus)
        LabeledContent("Location") {
            Text(summary.directoryURL.path)
                .lineLimit(2)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
    }

    private var folderStatus: String {
        switch summary.directoryStatus {
        case .available:
            return "Available"
        case .missing:
            return "Not created yet"
        }
    }
}

private struct DiagnosticReportRow: View {
    let item: DiagnosticReportItem
    let onRevealReport: (DiagnosticReportItem) -> Void
    let onCopyReportPath: (DiagnosticReportItem) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.fileName)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(
                    "\(DiagnosticReportFormatters.date(item.createdAt)) · \(DiagnosticReportFormatters.size(item.byteCount))"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button {
                onCopyReportPath(item)
            } label: {
                Label("Copy Path", systemImage: "doc.on.doc")
            }

            Button {
                onRevealReport(item)
            } label: {
                Label("Reveal", systemImage: "folder")
            }
        }
    }
}

private enum DiagnosticReportFormatters {
    static func size(_ byteCount: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: byteCount, countStyle: .file)
    }

    static func date(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview("Diagnostics") {
    Form {
        DiagnosticsSettingsSection(
            summary: DiagnosticReportSummary(
                directoryURL: URL(fileURLWithPath: "/Users/example/Library/Logs/DiagnosticReports"),
                directoryStatus: .available,
                items: [
                    DiagnosticReportItem(
                        fileURL: URL(fileURLWithPath: "/Users/example/Library/Logs/DiagnosticReports/HoldType-2026-07-06-132424.ips"),
                        byteCount: 54_000,
                        createdAt: Date()
                    )
                ]
            ),
            runtimeLogSummary: DiagnosticRuntimeLogSummary(
                directoryURL: URL(fileURLWithPath: "/Users/example/Library/Caches/HoldType/Diagnostics/RuntimeLogs"),
                recentLines: [
                    "2026-07-07T12:00:00Z category=dictation event=recording_started severity=info",
                    "2026-07-07T12:00:02Z category=dictation event=transcription_succeeded severity=info",
                ]
            ),
            errorMessage: nil,
            runtimeLogErrorMessage: nil,
            bundleResult: nil,
            bundleErrorMessage: nil,
            onRevealReportsDirectory: {},
            onCopyReportsDirectoryPath: {},
            onRefresh: {},
            onRevealReport: { _ in },
            onCopyReportPath: { _ in },
            onRevealRuntimeLogsDirectory: {},
            onCopyRuntimeLogs: {},
            onExportBundle: {}
        )
    }
    .formStyle(.grouped)
}
