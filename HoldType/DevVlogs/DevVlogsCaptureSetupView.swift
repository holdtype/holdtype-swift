import SwiftUI

struct DevVlogsCaptureSetupView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var settingsStore: DevVlogsSettingsStore
    @ObservedObject var cameraSetupStore: DevVlogsCameraSetupStore
    @StateObject private var previewStore: DevVlogsCameraPreviewStore

    init(
        settingsStore: DevVlogsSettingsStore,
        cameraSetupStore: DevVlogsCameraSetupStore,
        previewStore: DevVlogsCameraPreviewStore? = nil
    ) {
        self.settingsStore = settingsStore
        self.cameraSetupStore = cameraSetupStore
        _previewStore = StateObject(wrappedValue: previewStore ?? DevVlogsCameraPreviewStore())
    }

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
            previewSection
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
                Task { await previewStore.stopPreview() }
                return
            }

            cameraSetupStore.refreshAfterApplicationActivation()
        }
        .onChange(of: settingsStore.isEnabled) { _, _ in reconcilePreview() }
        .onChange(of: settingsStore.preferredCamera?.id) { _, _ in reconcilePreview() }
        .onChange(of: cameraSetupStore.permissionStatus) { _, _ in reconcilePreview() }
        .onChange(of: cameraSetupStore.cameras.map(\.id)) { _, _ in reconcilePreview() }
        .onDisappear {
            Task { await previewStore.stopPreview() }
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

    private var previewSection: some View {
        Section {
            previewSurface

            switch previewStore.state {
            case .idle:
                Button("Start Preview") {
                    Task {
                        await previewStore.startPreview(
                            isEnabled: settingsStore.isEnabled,
                            permissionStatus: cameraSetupStore.permissionStatus,
                            preferredCamera: settingsStore.preferredCamera,
                            availableCameras: cameraSetupStore.cameras
                        )
                    }
                }
                .disabled(!canStartPreview)
            case .starting:
                Button("Stop Preview") {
                    Task { await previewStore.stopPreview() }
                }
            case .previewing:
                Button("Stop Preview") {
                    Task { await previewStore.stopPreview() }
                }
            case .failed(let message):
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.footnote)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Start Preview") {
                    Task {
                        await previewStore.startPreview(
                            isEnabled: settingsStore.isEnabled,
                            permissionStatus: cameraSetupStore.permissionStatus,
                            preferredCamera: settingsStore.preferredCamera,
                            availableCameras: cameraSetupStore.cameras
                        )
                    }
                }
                .disabled(!canStartPreview)
            }
        } header: {
            Text("Preview")
        } footer: {
            Text("Preview starts only when you ask, is mirrored for framing, and never records video or opens a microphone.")
        }
    }

    @ViewBuilder
    private var previewSurface: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.black)

            if let frame = previewStore.frame {
                Image(decorative: frame, scale: 1)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(x: -1, y: 1)
            } else if previewStore.state == .starting {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Starting preferred camera…")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                }
            } else {
                Label("Preview is off", systemImage: "video.slash")
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel(previewStore.state == .previewing ? "Live camera preview" : "Camera preview off")
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

    private var canStartPreview: Bool {
        guard settingsStore.isEnabled,
              cameraSetupStore.permissionStatus == .allowed,
              let preferredCamera = settingsStore.preferredCamera else { return false }
        return cameraSetupStore.cameras.contains { $0.id == preferredCamera.id }
    }

    private func reconcilePreview() {
        Task {
            await previewStore.reconcile(
                isEnabled: settingsStore.isEnabled,
                permissionStatus: cameraSetupStore.permissionStatus,
                preferredCamera: settingsStore.preferredCamera,
                availableCameras: cameraSetupStore.cameras
            )
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
