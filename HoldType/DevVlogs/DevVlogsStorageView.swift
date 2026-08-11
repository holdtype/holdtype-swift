import SwiftUI
import UniformTypeIdentifiers

struct DevVlogsStorageView: View {
    @ObservedObject var settingsStore: DevVlogsSettingsStore
    @ObservedObject var destinationStore: DevVlogsDestinationSetupStore
    @State private var isFolderImporterPresented = false
    @State private var feedback: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Storage")
                    .font(.largeTitle)

                Text("Choose where future Dev Vlogs clips will be stored. Setup does not create clips or inspect the folder’s contents.")
                    .foregroundStyle(.secondary)

                if !settingsStore.isEnabled {
                    Text("Enable Dev Vlogs to choose a destination.")
                        .foregroundStyle(.secondary)
                }

                destinationSection

                if let feedback {
                    Text(feedback)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(32)
        }
        .navigationTitle(HoldTypeWindowTitle.titled("Dev Vlogs"))
        .fileImporter(
            isPresented: $isFolderImporterPresented,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false,
            onCompletion: handleFolderSelection
        )
    }

    private var destinationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(destinationStore.status.displayName)
                .font(.title2.weight(.semibold))
            Text(destinationStore.status.displayPath)
                .font(.callout.monospaced())
                .textSelection(.enabled)
                .foregroundStyle(.secondary)

            switch destinationStore.status.availability {
            case .needsSetup:
                Text("Use the default folder or choose an existing writable folder.")
                    .foregroundStyle(.secondary)
            case .available:
                Label("Destination available", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            case .unavailable(let reason):
                Text(reason.message)
                    .foregroundStyle(.orange)
            }

            HStack {
                Button("Use/Create Default Folder") {
                    destinationStore.useOrCreateDefaultFolder()
                }
                .disabled(!settingsStore.isEnabled)

                Button(destinationStore.status.isConfigured ? "Choose Different Folder…" : "Choose Folder…") {
                    isFolderImporterPresented = true
                }
                .disabled(!settingsStore.isEnabled)
            }

            if needsReselection,
               !destinationStore.status.isAvailable {
                Button("Reselect Folder…") {
                    isFolderImporterPresented = true
                }
                .disabled(!settingsStore.isEnabled)
            }
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
