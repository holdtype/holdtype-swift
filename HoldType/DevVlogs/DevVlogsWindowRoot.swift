import SwiftUI

private enum DevVlogsNavigationItem: String {
    case overview
    case capture
    case applications
    case storage
}

@MainActor
struct DevVlogsWindowRoot: View {
    @SceneStorage("holdtype.dev-vlogs.selected-section") private var selectedSection = DevVlogsNavigationItem.overview.rawValue
    @StateObject private var settingsStore: DevVlogsSettingsStore
    @StateObject private var cameraSetupStore: DevVlogsCameraSetupStore
    @StateObject private var destinationStore: DevVlogsDestinationSetupStore

    init() {
        _settingsStore = StateObject(wrappedValue: DevVlogsSettingsStore())
        _cameraSetupStore = StateObject(wrappedValue: DevVlogsCameraSetupStore())
        _destinationStore = StateObject(wrappedValue: DevVlogsDestinationSetupStore())
    }

    init(
        settingsStore: DevVlogsSettingsStore,
        cameraSetupStore: DevVlogsCameraSetupStore,
        destinationStore: DevVlogsDestinationSetupStore
    ) {
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _cameraSetupStore = StateObject(wrappedValue: cameraSetupStore)
        _destinationStore = StateObject(wrappedValue: destinationStore)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Label("Overview", systemImage: "rectangle.grid.1x2")
                    .tag(DevVlogsNavigationItem.overview.rawValue)
                Label("Capture", systemImage: "video")
                    .tag(DevVlogsNavigationItem.capture.rawValue)
                Label("Applications", systemImage: "app.badge")
                    .tag(DevVlogsNavigationItem.applications.rawValue)
                Label("Storage", systemImage: "externaldrive")
                    .tag(DevVlogsNavigationItem.storage.rawValue)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dev Vlogs")
        } detail: {
            switch DevVlogsNavigationItem(rawValue: selectedSection) ?? .overview {
            case .overview:
                DevVlogsOverviewView(readiness: readiness, settingsStore: settingsStore)
            case .capture:
                DevVlogsCaptureSetupView(
                    settingsStore: settingsStore,
                    cameraSetupStore: cameraSetupStore
                )
            case .applications:
                DevVlogsApplicationsView(settingsStore: settingsStore)
            case .storage:
                DevVlogsStorageView(settingsStore: settingsStore, destinationStore: destinationStore)
            }
        }
        .frame(minWidth: 620, minHeight: 400)
    }

    private var readiness: DevVlogsReadiness {
        DevVlogsReadinessReducer.reduce(
            DevVlogsReadinessInput(
                isEnabled: settingsStore.isEnabled,
                preferredCamera: settingsStore.preferredCamera,
                cameraPermissionStatus: cameraSetupStore.permissionStatus,
                availableCameras: cameraSetupStore.cameras,
                applicationPolicy: settingsStore.applicationPolicy,
                destination: destinationStore.status
            )
        )
    }
}

#Preview("Off") {
    DevVlogsWindowRoot(
        settingsStore: DevVlogsSettingsStore(isEnabled: false),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(status: .notDetermined)
        ),
        destinationStore: .preview(
            selection: .proposedDefault(path: "/Preview/Movies/HoldType Dev Vlogs"),
            availability: .needsSetup
        )
    )
}

#Preview("Allowed with cameras") {
    DevVlogsWindowRoot(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(status: .allowed)
        ),
        destinationStore: .preview(
            selection: .custom(displayName: "Dev Vlogs", pathSnapshot: "/Preview/Dev Vlogs"),
            availability: .available
        )
    )
}
