import SwiftUI

private enum DevVlogsNavigationItem: String {
    case overview
}

@MainActor
struct DevVlogsWindowRoot: View {
    @SceneStorage("holdtype.dev-vlogs.selected-section") private var selectedSection = DevVlogsNavigationItem.overview.rawValue
    @StateObject private var settingsStore: DevVlogsSettingsStore

    init(settingsStore: DevVlogsSettingsStore = DevVlogsSettingsStore()) {
        _settingsStore = StateObject(wrappedValue: settingsStore)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedSection) {
                Label("Overview", systemImage: "rectangle.grid.1x2")
                    .tag(DevVlogsNavigationItem.overview.rawValue)
            }
            .listStyle(.sidebar)
            .navigationTitle("Dev Vlogs")
        } detail: {
            DevVlogsOverviewView(settingsStore: settingsStore)
        }
        .frame(minWidth: 620, minHeight: 400)
    }
}

#Preview("Off") {
    DevVlogsWindowRoot(settingsStore: DevVlogsSettingsStore(isEnabled: false))
}

#Preview("Setup required") {
    DevVlogsWindowRoot(settingsStore: DevVlogsSettingsStore(isEnabled: true))
}
