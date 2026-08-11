import SwiftUI
import UniformTypeIdentifiers

struct DevVlogsApplicationsView: View {
    @ObservedObject var settingsStore: DevVlogsSettingsStore

    private let applicationResolver: any DevVlogsApplicationResolving
    @State private var isApplicationImporterPresented: Bool
    @State private var isBroaderScopeConfirmationPresented: Bool
    @State private var feedback: String?

    init(
        settingsStore: DevVlogsSettingsStore,
        applicationResolver: any DevVlogsApplicationResolving = BundleDevVlogsApplicationResolver(),
        isApplicationImporterPresented: Bool = false,
        isBroaderScopeConfirmationPresented: Bool = false,
        feedback: String? = nil
    ) {
        self.settingsStore = settingsStore
        self.applicationResolver = applicationResolver
        _isApplicationImporterPresented = State(initialValue: isApplicationImporterPresented)
        _isBroaderScopeConfirmationPresented = State(initialValue: isBroaderScopeConfirmationPresented)
        _feedback = State(initialValue: feedback)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Applications")
                    .font(.largeTitle)

                Text("Choose which apps may later trigger Dev Vlogs. This setup never starts capture or checks the frontmost app.")
                    .foregroundStyle(.secondary)

                if let loadMessage = settingsStore.applicationPolicyLoadMessage {
                    Text(loadMessage)
                        .foregroundStyle(.orange)
                }

                if !settingsStore.isEnabled {
                    Text("Enable Dev Vlogs to edit its application policy.")
                        .foregroundStyle(.secondary)
                }

                policySection
                applicationsSection

                if let feedback {
                    Text(feedback)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel(feedback)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(32)
        }
        .navigationTitle(HoldTypeWindowTitle.titled("Dev Vlogs"))
        .fileImporter(
            isPresented: $isApplicationImporterPresented,
            allowedContentTypes: [.applicationBundle],
            allowsMultipleSelection: false,
            onCompletion: handleApplicationSelection
        )
        .alert(
            "Allow Dev Vlogs for all apps?",
            isPresented: $isBroaderScopeConfirmationPresented
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Use All Apps Except Exclusions") {
                mutatePolicy { try settingsStore.confirmAllAppsExceptExcludedApps() }
            }
        } message: {
            Text("This broader policy permits Dev Vlogs to use any app except the apps you exclude. You can switch back to only selected apps at any time.")
        }
    }

    private var policySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("App scope")
                .font(.title2.weight(.semibold))

            Picker("App scope", selection: policyModeSelection) {
                ForEach(DevVlogsApplicationPolicyMode.allCases, id: \.self) { mode in
                    Text(mode.title)
                        .tag(mode)
                }
            }
            .pickerStyle(.radioGroup)
            .disabled(!settingsStore.isEnabled)

            Text(policyExplanation)
                .foregroundStyle(.secondary)
        }
    }

    private var applicationsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(applicationsTitle)
                    .font(.title2.weight(.semibold))

                Spacer()

                Button(addButtonTitle) {
                    isApplicationImporterPresented = true
                }
                .disabled(!settingsStore.isEnabled)
                .accessibilityLabel(addButtonTitle)
            }

            if settingsStore.applicationPolicy.activeApplications.isEmpty {
                Text(emptyApplicationsMessage)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(settingsStore.applicationPolicy.activeApplications) { application in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(application.displayName)
                            Text(application.bundleIdentifier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Button("Remove") {
                            mutatePolicy {
                                try settingsStore.removeApplication(
                                    bundleIdentifier: application.bundleIdentifier
                                )
                            }
                        }
                        .disabled(!settingsStore.isEnabled)
                        .accessibilityLabel("Remove \(application.displayName)")
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var policyModeSelection: Binding<DevVlogsApplicationPolicyMode> {
        Binding(
            get: { settingsStore.applicationPolicy.mode },
            set: requestPolicyModeChange
        )
    }

    private var applicationsTitle: String {
        switch settingsStore.applicationPolicy.mode {
        case .onlySelectedApps:
            return "Selected apps"
        case .allAppsExceptExcludedApps:
            return "Excluded apps"
        }
    }

    private var addButtonTitle: String {
        switch settingsStore.applicationPolicy.mode {
        case .onlySelectedApps:
            return "Add Application"
        case .allAppsExceptExcludedApps:
            return "Add Exclusion"
        }
    }

    private var policyExplanation: String {
        switch settingsStore.applicationPolicy.mode {
        case .onlySelectedApps:
            return settingsStore.applicationPolicy.hasEffectiveEligibility
                ? "Only these selected apps may later trigger Dev Vlogs."
                : "Add at least one app before this policy can be effective."
        case .allAppsExceptExcludedApps:
            return "Any app except the apps below may later trigger Dev Vlogs. This broader policy has been explicitly accepted."
        }
    }

    private var emptyApplicationsMessage: String {
        switch settingsStore.applicationPolicy.mode {
        case .onlySelectedApps:
            return "No apps are selected. Dev Vlogs will not be eligible for any app until you add one."
        case .allAppsExceptExcludedApps:
            return "No apps are excluded. All apps are eligible under this broader policy."
        }
    }

    private func requestPolicyModeChange(_ mode: DevVlogsApplicationPolicyMode) {
        guard settingsStore.isEnabled, mode != settingsStore.applicationPolicy.mode else {
            return
        }

        switch mode {
        case .onlySelectedApps:
            mutatePolicy { try settingsStore.returnToOnlySelectedApps() }
        case .allAppsExceptExcludedApps:
            isBroaderScopeConfirmationPresented = true
        }
    }

    private func handleApplicationSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure:
            feedback = "Application selection was cancelled or could not be completed."
        case .success(let urls):
            guard let url = urls.first else {
                feedback = "Choose one macOS application bundle."
                return
            }

            switch applicationResolver.resolveApplication(at: url) {
            case .failure(let error):
                feedback = error.message
            case .success(let application):
                mutatePolicy { try settingsStore.addApplication(application) }
            }
        }
    }

    private func mutatePolicy(_ mutation: () throws -> Void) {
        do {
            try mutation()
            feedback = nil
        } catch DevVlogsApplicationPolicyError.featureDisabled {
            feedback = "Enable Dev Vlogs before changing its application policy."
        } catch DevVlogsApplicationPolicyError.duplicateBundleIdentifier {
            feedback = "This application is already listed by its bundle identifier."
        } catch {
            feedback = "The application policy could not be changed."
        }
    }
}

#Preview("Off") {
    DevVlogsApplicationsView(settingsStore: DevVlogsSettingsStore(isEnabled: false))
        .frame(width: 700, height: 500)
}

#Preview("Selected apps") {
    DevVlogsApplicationsView(
        settingsStore: DevVlogsSettingsStore(
            isEnabled: true,
            applicationPolicy: DevVlogsApplicationPolicy(
                mode: .onlySelectedApps,
                selectedApps: [DevVlogsApplication(bundleIdentifier: "com.apple.dt.Xcode", displayName: "Xcode")!],
                excludedApps: []
            )
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("All apps confirmation") {
    DevVlogsApplicationsView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        isBroaderScopeConfirmationPresented: true
    )
    .frame(width: 700, height: 500)
}

#Preview("All apps exclusions") {
    DevVlogsApplicationsView(
        settingsStore: DevVlogsSettingsStore(
            isEnabled: true,
            applicationPolicy: DevVlogsApplicationPolicy(
                mode: .allAppsExceptExcludedApps,
                selectedApps: [],
                excludedApps: [DevVlogsApplication(bundleIdentifier: "com.apple.Notes", displayName: "Notes")!]
            )
        )
    )
    .frame(width: 700, height: 500)
}

#Preview("Invalid application feedback") {
    DevVlogsApplicationsView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        feedback: "Choose a macOS application bundle."
    )
    .frame(width: 700, height: 500)
}

#Preview("Duplicate application feedback") {
    DevVlogsApplicationsView(
        settingsStore: DevVlogsSettingsStore(isEnabled: true),
        feedback: "This application is already listed by its bundle identifier."
    )
    .frame(width: 700, height: 500)
}
