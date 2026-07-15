import SwiftUI
import UIKit

struct IOSDiagnosticsView: View {
    @State private var snapshot: IOSDiagnosticsSnapshot?
    @State private var shareItem: IOSDiagnosticShareItem?
    @State private var isPreparingShare = false
    @State private var didCopy = false
    @State private var errorMessage: String?

    private let service = IOSDiagnosticsService()

    var body: some View {
        Form {
            if let snapshot {
                overview(snapshot)
                actions(snapshot)
                runtimeEvents(snapshot)
                crashDiagnostics(snapshot)
                privacy
            } else {
                Section {
                    ProgressView("Loading diagnostics…")
                }
            }
        }
        .navigationTitle("Diagnostics & Support")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.diagnostics")
        .task { reload() }
        .refreshable { reload() }
        .sheet(item: $shareItem) { item in
            IOSDiagnosticActivityView(activityItems: [item.url])
        }
        .alert(
            "Diagnostics Unavailable",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "HoldType could not prepare diagnostics.")
        }
    }

    private func overview(
        _ snapshot: IOSDiagnosticsSnapshot
    ) -> some View {
        Section("Overview") {
            LabeledContent(
                "App",
                value: snapshot.metadata.appVersion
                    + " ("
                    + snapshot.metadata.buildNumber
                    + ")"
            )
            LabeledContent(
                "System",
                value: snapshot.metadata.operatingSystem
            )
            LabeledContent(
                "Device",
                value: snapshot.metadata.deviceFamily
            )
            LabeledContent(
                "Runtime events",
                value: String(snapshot.runtimeEventCount)
            )
            if snapshot.runtimeReadFailed {
                Label(
                    "Some local diagnostic data could not be read.",
                    systemImage: "exclamationmark.triangle"
                )
                .foregroundStyle(.orange)
            }
        }
    }

    private func actions(
        _ snapshot: IOSDiagnosticsSnapshot
    ) -> some View {
        Section {
            Button {
                UIPasteboard.general.string = service.copyText(from: snapshot)
                didCopy = true
            } label: {
                Label(
                    didCopy ? "Recent Logs Copied" : "Copy Recent Logs",
                    systemImage: didCopy ? "checkmark" : "doc.on.doc"
                )
            }
            .accessibilityIdentifier("ios.diagnostics.copy")

            Button {
                prepareAndShare(snapshot)
            } label: {
                if isPreparingShare {
                    HStack {
                        ProgressView()
                        Text("Preparing Diagnostic File…")
                    }
                } else {
                    Label(
                        "Share Diagnostic File",
                        systemImage: "square.and.arrow.up"
                    )
                }
            }
            .disabled(isPreparingShare)
            .accessibilityIdentifier("ios.diagnostics.share")
        } header: {
            Text("Actions")
        } footer: {
            Text(
                "Sharing opens the system share sheet. HoldType does not "
                + "upload diagnostics automatically."
            )
        }
    }

    private func runtimeEvents(
        _ snapshot: IOSDiagnosticsSnapshot
    ) -> some View {
        Section("Recent Runtime Events") {
            if snapshot.recentLines.isEmpty {
                Text("No HoldType runtime events have been recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(
                    Array(snapshot.recentLines.suffix(8).enumerated()),
                    id: \.offset
                ) { _, line in
                    Text(line)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        }
    }

    private func crashDiagnostics(
        _ snapshot: IOSDiagnosticsSnapshot
    ) -> some View {
        Section {
            if snapshot.metricRecords.isEmpty {
                Text(
                    "No crash diagnostics have been delivered to HoldType. "
                    + "This does not prove that the app has never crashed."
                )
                .foregroundStyle(.secondary)
            } else {
                LabeledContent(
                    "Crash reports delivered",
                    value: String(snapshot.crashCount)
                )
                LabeledContent(
                    "Hang reports delivered",
                    value: String(snapshot.hangCount)
                )
                LabeledContent(
                    "Diagnostic deliveries",
                    value: String(snapshot.metricRecords.count)
                )
            }
        } header: {
            Text("Crash Diagnostics")
        } footer: {
            Text(
                "iOS delivers MetricKit diagnostics later, usually after the "
                + "affected launch. TestFlight and App Store crash reports "
                + "remain separate."
            )
        }
    }

    private var privacy: some View {
        Section("Privacy") {
            Text(
                "HoldType diagnostics exclude recordings, transcripts, "
                + "prompts, API keys, typed text, and provider payloads. "
                + "Runtime logs are kept locally for up to seven days."
            )
            .foregroundStyle(.secondary)
        }
    }

    private func reload() {
        let metadata = IOSDiagnosticsMetadata.current()
        snapshot = service.snapshot(metadata: metadata)
    }

    private func prepareAndShare(_ snapshot: IOSDiagnosticsSnapshot) {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        errorMessage = nil
        Task {
            defer { isPreparingShare = false }
            do {
                shareItem = IOSDiagnosticShareItem(
                    url: try service.makeDiagnosticFile(from: snapshot)
                )
            } catch {
                errorMessage =
                    "HoldType could not create the diagnostic file. Try again."
            }
        }
    }
}

private struct IOSDiagnosticShareItem: Identifiable {
    let id = UUID()
    let url: URL
}

private struct IOSDiagnosticActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(
        context: Context
    ) -> UIActivityViewController {
        UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}
}
