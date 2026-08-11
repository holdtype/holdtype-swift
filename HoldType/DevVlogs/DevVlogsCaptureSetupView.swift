import SwiftUI

struct DevVlogsCaptureSetupView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var settingsStore: DevVlogsSettingsStore
    @ObservedObject var cameraSetupStore: DevVlogsCameraSetupStore

    var body: some View {
        Form {
            if !settingsStore.isEnabled {
                Section {
                    Label("Enable Dev Vlogs to configure capture.", systemImage: "pause.circle")
                        .foregroundStyle(.secondary)
                }
            }

            permissionSection
            cameraSection
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 18, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Label(
                    cameraSetupStore.permissionStatus.title,
                    systemImage: cameraSetupStore.permissionStatus.systemImage
                )
                .foregroundStyle(permissionColor)

                Text(cameraSetupStore.permissionStatus.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

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
        } header: {
            Text("Camera Access")
        } footer: {
            Text("Access is requested only when you choose the camera action above. Opening this page never starts preview or capture.")
        }
    }

    private var cameraSection: some View {
        Section {
            if let preferredCamera = settingsStore.preferredCamera,
               !cameraSetupStore.cameras.contains(where: { $0.hasSameIdentity(as: preferredCamera) }) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Camera unavailable", systemImage: "video.slash")
                        .foregroundStyle(.orange)

                    Text("\(preferredCamera.label) is still remembered. Dev Vlogs will wait for this camera to return and will not substitute another device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if cameraSetupStore.cameras.isEmpty {
                Label("No cameras are currently available.", systemImage: "video.slash")
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
        } header: {
            Text("Preferred Camera")
        } footer: {
            Text("Dev Vlogs remembers this camera by its stable device identity and never switches silently.")
        }
    }

    private var permissionColor: Color {
        switch cameraSetupStore.permissionStatus {
        case .allowed:
            return .green
        case .denied, .notDetermined:
            return .orange
        case .unavailable:
            return .secondary
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
