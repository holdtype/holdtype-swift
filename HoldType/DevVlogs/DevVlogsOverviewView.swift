import SwiftUI

struct DevVlogsOverviewView: View {
    @ObservedObject var settingsStore: DevVlogsSettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Dev Vlogs")
                    .font(.largeTitle)

                VStack(alignment: .leading, spacing: 8) {
                    Text(settingsStore.readiness.title)
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
        switch settingsStore.readiness {
        case .off:
            return "Dev Vlogs is off. Enable it to set up your camera, destination, and app scope."
        case .setupRequired:
            return "Choose a camera, destination, and app scope before Dev Vlogs can become ready."
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
