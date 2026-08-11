import SwiftUI
import UniformTypeIdentifiers

struct DevVlogsStorageView: View {
    @ObservedObject var settingsStore: DevVlogsSettingsStore
    @ObservedObject var destinationStore: DevVlogsDestinationSetupStore
    @State private var isFolderImporterPresented = false
    @State private var feedback: String?

    var body: some View {
        Form {
            if !settingsStore.isEnabled {
                Section {
                    Label("Enable Dev Vlogs to choose a destination.", systemImage: "pause.circle")
                        .foregroundStyle(.secondary)
                }
            }

            destinationSection

            if let feedback {
                Section {
                    Label(feedback, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 18, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(HoldTypeWindowTitle.titled("Dev Vlogs"))
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: handleFolderSelection
        )
    }

    private var destinationSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 5) {
                Label(destinationStore.status.displayName, systemImage: destinationSystemImage)
                    .font(.headline)

                Text(destinationKindDescription)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Text(destinationStore.status.displayPath)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 2)

            switch destinationStore.status.availability {
            case .needsSetup:
                Label("Destination setup required", systemImage: "exclamationmark.circle")
                    .foregroundStyle(.orange)
            case .available:
                Label("Destination available", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .unavailable(let reason):
                VStack(alignment: .leading, spacing: 4) {
                    Label("Destination unavailable", systemImage: "externaldrive.badge.exclamationmark")
                        .foregroundStyle(.orange)
                    Text(reason.message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if needsReselection,
               !destinationStore.status.isAvailable {
                Button("Reselect Folder…") {
                    isFolderImporterPresented = true
                }
                .disabled(!settingsStore.isEnabled)
                .buttonStyle(.borderedProminent)
            } else {
                Button(destinationStore.status.isConfigured ? "Choose Different Folder…" : "Choose Folder…") {
                    isFolderImporterPresented = true
                }
                .disabled(!settingsStore.isEnabled)
            }

            Button("Use Default Movies Folder") {
                destinationStore.useOrCreateDefaultFolder()
            }
            .disabled(!settingsStore.isEnabled)
        } header: {
            Text("Destination")
        } footer: {
            Text("Setup does not create clips or inspect folder contents. HoldType never falls back to another location silently.")
        }
    }

    private var destinationSystemImage: String {
        switch destinationStore.status.selection {
        case .proposedDefault, .defaultFolder:
            return "folder"
        case .custom:
            return "externaldrive"
        case .persistedRecordUnavailable:
            return "externaldrive.badge.questionmark"
        }
    }

    private var destinationKindDescription: String {
        switch destinationStore.status.selection {
        case .proposedDefault:
            return "Default Movies destination, not yet created"
        case .defaultFolder:
            return "Default Movies destination"
        case .custom:
            return "Custom folder"
        case .persistedRecordUnavailable:
            return "Saved folder record needs recovery"
        }
    }

    private var needsReselection: Bool {
        switch destinationStore.status.selection {
        case .custom, .persistedRecordUnavailable:
            return true
        case .proposedDefault, .defaultFolder:
            return false
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            feedback = "Folder selection was cancelled or could not be completed."
        case .success(let urls):
            guard let url = urls.first else {
                feedback = "Choose one folder for Dev Vlogs."
                return
            }

            let startedSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if startedSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            destinationStore.selectCustomFolder(url)
            feedback = destinationStore.status.isAvailable ? nil : "The selected folder is not available for Dev Vlogs."
        }
    }
}

#Preview("Default folder absent") {
    DevVlogsStorageView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        destinationStore: DevVlogsDestinationSetupStore.preview(
            selection: .proposedDefault(path: "/Preview/Movies/HoldType Dev Vlogs"),
            availability: .needsSetup
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("Custom folder unavailable") {
    DevVlogsStorageView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        destinationStore: DevVlogsDestinationSetupStore.preview(
            selection: .custom(displayName: "Dev Vlogs SSD", pathSnapshot: "/Volumes/Dev Vlogs/Clips"),
            availability: .unavailable(.bookmarkUnavailable)
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("Default folder available") {
    DevVlogsStorageView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        destinationStore: DevVlogsDestinationSetupStore.preview(
            selection: .defaultFolder(path: "/Preview/Movies/HoldType Dev Vlogs"),
            availability: .available
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("Custom folder available") {
    DevVlogsStorageView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        destinationStore: DevVlogsDestinationSetupStore.preview(
            selection: .custom(displayName: "Dev Vlogs SSD", pathSnapshot: "/Preview/Dev Vlogs SSD"),
            availability: .available
        )
    )
    .frame(width: 700, height: 500)
}

extension DevVlogsDestinationSetupStore {
    static func preview(
        selection: DevVlogsDestinationSelection,
        availability: DevVlogsDestinationAvailability
    ) -> DevVlogsDestinationSetupStore {
        DevVlogsDestinationSetupStore(
            status: DevVlogsDestinationStatus(selection: selection, availability: availability),
            bookmarkResolver: PreviewBookmarkResolver(),
            fileAccess: PreviewFileAccess(),
            defaultDestinationURL: URL(fileURLWithPath: "/Preview/Movies/HoldType Dev Vlogs")
        )
    }

    private struct PreviewBookmarkResolver: DevVlogsDestinationBookmarkResolving {
        func bookmarkData(for url: URL) throws -> Data { Data() }
        func resolveBookmarkData(_ data: Data) throws -> DevVlogsBookmarkResolution {
            DevVlogsBookmarkResolution(url: URL(fileURLWithPath: "/Preview/Folder"), isStale: false)
        }
        func startAccessingSecurityScopedResource(at url: URL) -> Bool { true }
        func stopAccessingSecurityScopedResource(at url: URL) {}
    }

    private struct PreviewFileAccess: DevVlogsDestinationFileAccessing {
        func directoryState(at url: URL) -> DevVlogsDestinationDirectoryState { .directory(isWritable: true) }
        func createDirectory(at url: URL) throws {}
    }
}
