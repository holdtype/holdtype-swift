import SwiftUI

enum DevVlogsOverviewDestination {
    case capture
    case applications
    case storage
}

struct DevVlogsOverviewView: View {
    let readiness: DevVlogsReadiness
    @ObservedObject var settingsStore: DevVlogsSettingsStore
    let cameraStatus: DevVlogsCameraPermissionStatus
    let availableCameras: [DevVlogsCamera]
    let destinationStatus: DevVlogsDestinationStatus
    let captureState: DevVlogsCaptureState
    let onNavigate: (DevVlogsOverviewDestination) -> Void

    init(
        readiness: DevVlogsReadiness? = nil,
        settingsStore: DevVlogsSettingsStore,
        cameraStatus: DevVlogsCameraPermissionStatus = .unavailable,
        availableCameras: [DevVlogsCamera] = [],
        destinationStatus: DevVlogsDestinationStatus = DevVlogsDestinationStatus(
            selection: .proposedDefault(path: "~/Movies/HoldType Dev Vlogs"),
            availability: .needsSetup
        ),
        captureState: DevVlogsCaptureState = .idle,
        onNavigate: @escaping (DevVlogsOverviewDestination) -> Void = { _ in }
    ) {
        self.readiness = readiness ?? settingsStore.readiness
        self.settingsStore = settingsStore
        self.cameraStatus = cameraStatus
        self.availableCameras = availableCameras
        self.destinationStatus = destinationStatus
        self.captureState = captureState
        self.onNavigate = onNavigate
    }

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Label(readiness.title, systemImage: readinessSystemImage)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(readinessColor)

                    Text(statusDescription)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)

                Toggle("Enable Dev Vlogs", isOn: enabledBinding)
                    .accessibilityHint(actionHint)
            } header: {
                Text("Dev Vlogs")
            } footer: {
                Text("Enabling setup never starts camera or microphone capture.")
            }

            Section {
                setupRow(
                    title: "Camera",
                    detail: cameraDetail,
                    systemImage: "video",
                    statusSystemImage: cameraStatusSystemImage,
                    statusColor: cameraStatusColor,
                    destination: .capture
                )

                setupRow(
                    title: "Applications",
                    detail: applicationDetail,
                    systemImage: "app.badge",
                    statusSystemImage: applicationStatusSystemImage,
                    statusColor: applicationStatusColor,
                    destination: .applications
                )

                setupRow(
                    title: "Storage",
                    detail: storageDetail,
                    systemImage: "externaldrive",
                    statusSystemImage: storageStatusSystemImage,
                    statusColor: storageStatusColor,
                    destination: .storage
                )
            } header: {
                Text("Setup")
            } footer: {
                Text(nextActionDescription)
            }

            Section("Latest Attempt") {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(captureState.title)
                        Text(captureState.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: captureStateSystemImage)
                        .foregroundStyle(captureStateColor)
                }
            }
        }
        .formStyle(.grouped)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .contentMargins(.top, 0, for: .scrollContent)
        .contentMargins(.bottom, 18, for: .scrollContent)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(HoldTypeWindowTitle.titled("Dev Vlogs"))
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.isEnabled },
            set: { settingsStore.setEnabled($0) }
        )
    }

    private func setupRow(
        title: String,
        detail: String,
        systemImage: String,
        statusSystemImage: String,
        statusColor: Color,
        destination: DevVlogsOverviewDestination
    ) -> some View {
        Button {
            onNavigate(destination)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(.primary)

                    Text(detail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 12)

                Image(systemName: statusSystemImage)
                    .foregroundStyle(statusColor)
                    .accessibilityHidden(true)

                Image(systemName: "chevron.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Open \(title) setup")
    }

    private var statusDescription: String {
        switch readiness {
        case .off:
            return "Turn on Dev Vlogs to finish camera, application, and storage setup."
        case .setupRequired:
            return "Setup is incomplete. Complete the next item below before Dev Vlogs can become ready."
        case .ready:
            return "Camera, applications, and storage are configured for future eligible dictations."
        case .degradedCameraUnavailable:
            return "Your preferred camera is unavailable. Dev Vlogs will wait for it to return."
        case .degradedDestinationUnavailable:
            return "Your selected destination is unavailable. Reconnect it or choose another folder."
        }
    }

    private var nextActionDescription: String {
        if !settingsStore.isEnabled {
            return "Next: enable Dev Vlogs, then complete the setup rows."
        }
        if settingsStore.preferredCamera == nil || cameraStatus != .allowed {
            return "Next: finish Camera setup."
        }
        if !settingsStore.applicationPolicy.hasEffectiveEligibility {
            return "Next: choose at least one eligible application."
        }
        if !destinationStatus.isConfigured || !destinationStatus.isAvailable {
            return "Next: choose an available storage destination."
        }
        return "Setup is complete."
    }

    private var readinessSystemImage: String {
        switch readiness {
        case .off:
            return "pause.circle"
        case .setupRequired:
            return "wrench.and.screwdriver"
        case .ready:
            return "checkmark.circle.fill"
        case .degradedCameraUnavailable:
            return "video.slash"
        case .degradedDestinationUnavailable:
            return "externaldrive.badge.exclamationmark"
        }
    }

    private var readinessColor: Color {
        switch readiness {
        case .ready:
            return .green
        case .setupRequired, .degradedCameraUnavailable, .degradedDestinationUnavailable:
            return .orange
        case .off:
            return .secondary
        }
    }

    private var captureStateSystemImage: String {
        switch captureState {
        case .idle:
            return "video"
        case .preparing, .finalizing:
            return "clock"
        case .capturing:
            return "record.circle"
        case .saved:
            return "checkmark.circle.fill"
        case .skipped:
            return "forward.end.circle"
        case .failed:
            return "exclamationmark.triangle"
        }
    }

    private var captureStateColor: Color {
        switch captureState {
        case .capturing:
            return .red
        case .saved:
            return .green
        case .preparing, .finalizing:
            return .orange
        case .idle, .skipped:
            return .secondary
        case .failed:
            return .orange
        }
    }

    private var cameraDetail: String {
        guard let preferredCamera = settingsStore.preferredCamera else {
            return cameraStatus == .notDetermined ? "Camera access and a preferred camera are required." : "Choose a preferred camera."
        }

        let isAvailable = availableCameras.contains { $0.hasSameIdentity(as: preferredCamera) }
        return isAvailable && cameraStatus == .allowed
            ? preferredCamera.label
            : "\(preferredCamera.label) is unavailable."
    }

    private var cameraStatusSystemImage: String {
        cameraIsReady ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var cameraStatusColor: Color {
        cameraIsReady ? .green : .orange
    }

    private var cameraIsReady: Bool {
        guard cameraStatus == .allowed,
              let preferredCamera = settingsStore.preferredCamera else {
            return false
        }
        return availableCameras.contains { $0.hasSameIdentity(as: preferredCamera) }
    }

    private var applicationDetail: String {
        let policy = settingsStore.applicationPolicy
        switch policy.mode {
        case .onlySelectedApps:
            let count = policy.activeApplications.count
            return count == 0 ? "No applications selected." : "\(count) selected \(count == 1 ? "application" : "applications")."
        case .allAppsExceptExcludedApps:
            let count = policy.activeApplications.count
            return count == 0 ? "All applications; no exclusions." : "All applications except \(count) excluded."
        }
    }

    private var applicationStatusSystemImage: String {
        settingsStore.applicationPolicy.hasEffectiveEligibility ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var applicationStatusColor: Color {
        settingsStore.applicationPolicy.hasEffectiveEligibility ? .green : .orange
    }

    private var storageDetail: String {
        if destinationStatus.isAvailable {
            return destinationStatus.displayName
        }
        return destinationStatus.isConfigured ? "\(destinationStatus.displayName) is unavailable." : "Choose a destination."
    }

    private var storageStatusSystemImage: String {
        destinationStatus.isAvailable ? "checkmark.circle.fill" : "exclamationmark.circle"
    }

    private var storageStatusColor: Color {
        destinationStatus.isAvailable ? .green : .orange
    }

    private var actionHint: String {
        settingsStore.isEnabled
            ? "Turns Dev Vlogs off for future dictation attempts."
            : "Enables setup without starting camera or microphone capture."
    }
}

#Preview("Off") {
    DevVlogsOverviewView(settingsStore: DevVlogsSettingsStore(isEnabled: false))
        .frame(width: 760, height: 520)
}

#Preview("Ready") {
    DevVlogsOverviewView(
        readiness: .ready,
        settingsStore: DevVlogsSettingsStore(
            isEnabled: true,
            preferredCamera: DevVlogsCamera(id: "built-in", label: "Studio Display Camera"),
            applicationPolicy: DevVlogsApplicationPolicy(
                mode: .onlySelectedApps,
                selectedApps: [DevVlogsApplication(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")!],
                excludedApps: []
            )
        ),
        cameraStatus: .allowed,
        availableCameras: [DevVlogsCamera(id: "built-in", label: "Studio Display Camera")],
        destinationStatus: DevVlogsDestinationStatus(
            selection: .defaultFolder(path: "/Preview/Movies/HoldType Dev Vlogs"),
            availability: .available
        )
    )
    .frame(width: 760, height: 520)
}
