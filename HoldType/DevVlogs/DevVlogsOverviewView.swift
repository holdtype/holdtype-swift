import SwiftUI

struct DevVlogsOverviewView: View {
    let readiness: DevVlogsReadiness
    @ObservedObject var settingsStore: DevVlogsSettingsStore

    init(readiness: DevVlogsReadiness? = nil, settingsStore: DevVlogsSettingsStore) {
        self.readiness = readiness ?? settingsStore.readiness
        self.settingsStore = settingsStore
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Dev Vlogs")
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 8) {
                    Text(readiness.title)
                        .font(.title2.weight(.semibold))

                    Text(statusDescription)
                        .foregroundStyle(.secondary)
                }

                Button(actionTitle) {
                    settingsStore.setEnabled(!settingsStore.isEnabled)
                }
                .accessibilityHint(actionHint)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(32)
        }
        .navigationTitle(HoldTypeWindowTitle.titled("Dev Vlogs"))
    }

    private var statusDescription: String {
        switch readiness {
        case .off:
            return "Dev Vlogs is off. Enable it to set up your camera, destination, and app scope."
        case .setupRequired:
            return "Choose a camera, destination, and app scope before Dev Vlogs can become ready."
        case .ready:
            return "Dev Vlogs is configured and ready for a future eligible dictation attempt."
        case .degradedCameraUnavailable:
            return "Your preferred camera is unavailable. Dev Vlogs will wait for it to return."
        case .degradedDestinationUnavailable:
            return "Your selected destination is unavailable. Reconnect it or choose another folder."
        }
    }

    private var actionTitle: String {
        settingsStore.isEnabled ? "Turn Off" : "Enable Dev Vlogs"
    }

    private var actionHint: String {
        settingsStore.isEnabled
            ? "Turns Dev Vlogs off for future dictation attempts."
            : "Enables Dev Vlogs without starting camera or microphone capture."
    }
}

#Preview("Off") {
    DevVlogsOverviewView(settingsStore: DevVlogsSettingsStore(isEnabled: false))
        .frame(width: 700, height: 500)
}

#Preview("Setup required") {
    DevVlogsOverviewView(settingsStore: DevVlogsSettingsStore(isEnabled: true))
        .frame(width: 700, height: 500)
}

#Preview("Ready") {
    DevVlogsOverviewView(
        readiness: .ready,
        settingsStore: DevVlogsSettingsStore(isEnabled: true)
    )
    .frame(width: 700, height: 500)
}

#Preview("Camera unavailable") {
    DevVlogsOverviewView(
        readiness: .degradedCameraUnavailable,
        settingsStore: DevVlogsSettingsStore(isEnabled: true)
    )
    .frame(width: 700, height: 500)
}

#Preview("Destination unavailable") {
    DevVlogsOverviewView(
        readiness: .degradedDestinationUnavailable,
        settingsStore: DevVlogsSettingsStore(isEnabled: true)
    )
    .frame(width: 700, height: 500)
}
