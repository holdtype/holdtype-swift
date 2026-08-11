import SwiftUI

private enum DevVlogsNavigationItem: String {
    case overview
    case capture
    case applications
    case storage
}

@MainActor
struct DevVlogsWindowRoot: View {
    @Environment(\.scenePhase) private var scenePhase
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
                sidebarRow(title: "Overview", systemImage: "rectangle.grid.1x2")
                    .tag(DevVlogsNavigationItem.overview.rawValue)
                sidebarRow(title: "Capture", systemImage: "video")
                    .tag(DevVlogsNavigationItem.capture.rawValue)
                sidebarRow(title: "Applications", systemImage: "app.badge")
                    .tag(DevVlogsNavigationItem.applications.rawValue)
                sidebarRow(title: "Storage", systemImage: "externaldrive")
                    .tag(DevVlogsNavigationItem.storage.rawValue)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dev Vlogs")
            .navigationSplitViewColumnWidth(min: 210, ideal: 240, max: 300)
        } detail: {
            switch DevVlogsNavigationItem(rawValue: selectedSection) ?? .overview {
            case .overview:
                DevVlogsOverviewView(
                    readiness: readiness,
                    settingsStore: settingsStore,
                    cameraStatus: cameraSetupStore.permissionStatus,
                    availableCameras: cameraSetupStore.cameras,
                    destinationStatus: destinationStore.status,
                    onNavigate: navigate(to:)
                )
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
        .frame(minWidth: 760, minHeight: 520)
        .task {
            refreshReadinessInputs()
        }
        .onReceive(cameraSetupStore.cameraDeviceChangePublisher()) { _ in
            refreshReadinessInputs()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            refreshReadinessInputs()
        }
    }

    private func sidebarRow(title: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            Text(title)
                .lineLimit(1)
        }
    }

    private func navigate(to destination: DevVlogsOverviewDestination) {
        switch destination {
        case .capture:
            selectedSection = DevVlogsNavigationItem.capture.rawValue
        case .applications:
            selectedSection = DevVlogsNavigationItem.applications.rawValue
        case .storage:
            selectedSection = DevVlogsNavigationItem.storage.rawValue
        }
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

    private func refreshReadinessInputs() {
        DevVlogsReadinessCoordinator.refresh(
            cameraSetupStore: cameraSetupStore,
            destinationStore: destinationStore
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
