import SwiftUI

private enum DevVlogsNavigationItem: String {
    case overview
    case capture
}

@MainActor
struct DevVlogsWindowRoot: View {
    @SceneStorage("holdtype.dev-vlogs.selected-section") private var selectedSection = DevVlogsNavigationItem.overview.rawValue
    @StateObject private var settingsStore: DevVlogsSettingsStore
    @StateObject private var cameraSetupStore: DevVlogsCameraSetupStore

    init() {
        _settingsStore = StateObject(wrappedValue: DevVlogsSettingsStore())
        _cameraSetupStore = StateObject(wrappedValue: DevVlogsCameraSetupStore())
    }

    init(
        settingsStore: DevVlogsSettingsStore,
        cameraSetupStore: DevVlogsCameraSetupStore
    ) {
        _settingsStore = StateObject(wrappedValue: settingsStore)
        _cameraSetupStore = StateObject(wrappedValue: cameraSetupStore)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Label("Overview", systemImage: "rectangle.grid.1x2")
                    .tag(DevVlogsNavigationItem.overview.rawValue)
                Label("Capture", systemImage: "video")
                    .tag(DevVlogsNavigationItem.capture.rawValue)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dev Vlogs")
        } detail: {
            switch DevVlogsNavigationItem(rawValue: selectedSection) ?? .overview {
            case .overview:
                DevVlogsOverviewView(settingsStore: settingsStore)
            case .capture:
                DevVlogsCaptureSetupView(
                    settingsStore: settingsStore,
                    cameraSetupStore: cameraSetupStore
                )
            }
        }
        .frame(minWidth: 620, minHeight: 400)
    }
}

#Preview("Off") {
    DevVlogsWindowRoot(
        settingsStore: DevVlogsSettingsStore(isEnabled: false),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(status: .notDetermined)
        )
    )
}

#Preview("Allowed with cameras") {
    DevVlogsWindowRoot(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(status: .allowed)
        )
    )
}
