import SwiftUI

struct DevVlogsCaptureSetupView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var settingsStore: DevVlogsSettingsStore
    @ObservedObject var cameraSetupStore: DevVlogsCameraSetupStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Capture")
                    .font(.largeTitle)

                if !settingsStore.isEnabled {
                    Text("Enable Dev Vlogs before requesting camera access or choosing a preferred camera.")
                        .foregroundStyle(.secondary)
                }

                permissionSection
                cameraSection
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(32)
        }
        .navigationTitle(HoldTypeWindowTitle.titled("Dev Vlogs"))
        .task {
            cameraSetupStore.refresh()
        }
        .onReceive(cameraSetupStore.cameraDeviceChangePublisher()) { _ in
            cameraSetupStore.refreshAfterCameraDeviceChange()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }

            cameraSetupStore.refreshAfterApplicationActivation()
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(cameraSetupStore.permissionStatus.title, systemImage: cameraSetupStore.permissionStatus.systemImage)
                .font(.title2.weight(.semibold))

            Text(cameraSetupStore.permissionStatus.description)
                .foregroundStyle(.secondary)

            switch cameraSetupStore.permissionStatus {
            case .notDetermined:
                Button("Request Camera Access") {
                    cameraSetupStore.requestAccessIfNeeded(isEnabled: settingsStore.isEnabled)
                }
                .disabled(!settingsStore.isEnabled)
            case .denied:
                Button("Open Camera Settings") {
                    cameraSetupStore.openCameraSettingsIfNeeded(isEnabled: settingsStore.isEnabled)
                }
                .disabled(!settingsStore.isEnabled)
            case .allowed, .unavailable:
                EmptyView()
            }
        }
    }

    private var cameraSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preferred camera")
                .font(.title2.weight(.semibold))

            if let preferredCamera = settingsStore.preferredCamera,
               !cameraSetupStore.cameras.contains(where: { $0.hasSameIdentity(as: preferredCamera) }) {
                Text("\(preferredCamera.label) is unavailable. Dev Vlogs will wait for this camera to return.")
                    .foregroundStyle(.secondary)
            }

            if cameraSetupStore.cameras.isEmpty {
                Text("No cameras are currently available.")
                    .foregroundStyle(.secondary)
            } else {
                Picker("Preferred camera", selection: preferredCameraSelection) {
                    Text("Choose a camera")
                        .tag(Optional<DevVlogsCamera.ID>.none)

                    ForEach(cameraSetupStore.cameras) { camera in
                        Text(camera.label)
                            .tag(Optional(camera.id))
                    }
                }
                .disabled(!settingsStore.isEnabled)
            }
        }
    }

    private var preferredCameraSelection: Binding<DevVlogsCamera.ID?> {
        Binding(
            get: { settingsStore.preferredCamera?.id },
            set: { selectedID in
                guard settingsStore.isEnabled,
                      let selectedID,
                      let camera = cameraSetupStore.cameras.first(where: { $0.id == selectedID }) else {
                    return
                }

                settingsStore.setPreferredCamera(camera)
            }
        )
    }
}

#Preview("Off") {
    DevVlogsCaptureSetupView(
        settingsStore: DevVlogsSettingsStore(isEnabled: false),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(status: .notDetermined)
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("Not determined") {
    DevVlogsCaptureSetupView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(status: .notDetermined)
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("Denied") {
    DevVlogsCaptureSetupView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(status: .denied)
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("Allowed with remembered unavailable camera") {
    DevVlogsCaptureSetupView(
        settingsStore: DevVlogsSettingsStore(
            isEnabled: true,
            preferredCamera: DevVlogsCamera(id: "disconnected", label: "Desk Camera")
        ),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(status: .allowed)
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("Unavailable") {
    DevVlogsCaptureSetupView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        cameraSetupStore: DevVlogsCameraSetupStore(
            client: DevVlogsCameraSetupPreviewClient(
                status: .denied,
                discoveryFails: true
            )
        )
    )
    .frame(width: 700, height: 500)
}
