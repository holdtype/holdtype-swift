import Combine
import Foundation

final class DevVlogsSettingsStore: ObservableObject {
    private enum Key {
        static let isEnabled = "holdtype.dev-vlogs.is-enabled"
        static let preferredCameraID = "holdtype.dev-vlogs.preferred-camera-id"
        static let preferredCameraLabel = "holdtype.dev-vlogs.preferred-camera-label"
        static let applicationPolicy = "holdtype.dev-vlogs.application-policy"
    }

    @Published private(set) var isEnabled: Bool
    @Published private(set) var preferredCamera: DevVlogsCamera?
    @Published private(set) var applicationPolicy: DevVlogsApplicationPolicy
    @Published private(set) var applicationPolicyLoadMessage: String?

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isEnabled = userDefaults.bool(forKey: Key.isEnabled)
        preferredCamera = Self.preferredCamera(from: userDefaults)
        let persistedPolicy = Self.applicationPolicy(from: userDefaults)
        applicationPolicy = persistedPolicy.policy
        applicationPolicyLoadMessage = persistedPolicy.loadMessage
    }

    init(
        isEnabled: Bool,
        preferredCamera: DevVlogsCamera? = nil,
        applicationPolicy: DevVlogsApplicationPolicy = .defaultPolicy,
        applicationPolicyLoadMessage: String? = nil
    ) {
        userDefaults = nil
        self.isEnabled = isEnabled
        self.preferredCamera = preferredCamera
        self.applicationPolicy = applicationPolicy
        self.applicationPolicyLoadMessage = applicationPolicyLoadMessage
    }

    var readiness: DevVlogsReadiness {
        DevVlogsReadinessReducer.reduce(
            DevVlogsReadinessInput(
                isEnabled: isEnabled,
                preferredCamera: preferredCamera,
                cameraPermissionStatus: .unavailable,
                availableCameras: [],
                applicationPolicy: applicationPolicy,
                destination: DevVlogsDestinationStatus(
                    selection: .proposedDefault(path: "~/Movies/HoldType Dev Vlogs"),
                    availability: .needsSetup
                )
            )
        )
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        userDefaults?.set(isEnabled, forKey: Key.isEnabled)
    }

    func setPreferredCamera(_ camera: DevVlogsCamera) {
        preferredCamera = camera
        userDefaults?.set(camera.id, forKey: Key.preferredCameraID)
        userDefaults?.set(camera.label, forKey: Key.preferredCameraLabel)
    }

    func returnToOnlySelectedApps() throws {
        try requireEnabled()
        applicationPolicy.setMode(.onlySelectedApps)
        persistApplicationPolicy()
    }

    func confirmAllAppsExceptExcludedApps() throws {
        try requireEnabled()
        applicationPolicy.setMode(.allAppsExceptExcludedApps)
        persistApplicationPolicy()
    }

    func addApplication(_ application: DevVlogsApplication) throws {
        try requireEnabled()
        try applicationPolicy.add(application)
        persistApplicationPolicy()
    }

    func removeApplication(bundleIdentifier: String) throws {
        try requireEnabled()
        applicationPolicy.remove(bundleIdentifier: bundleIdentifier)
        persistApplicationPolicy()
    }

    static var applicationPolicyStorageKey: String {
        Key.applicationPolicy
    }

    private static func preferredCamera(from userDefaults: UserDefaults) -> DevVlogsCamera? {
        guard let id = userDefaults.string(forKey: Key.preferredCameraID),
              let label = userDefaults.string(forKey: Key.preferredCameraLabel),
              !id.isEmpty,
              !label.isEmpty else {
            return nil
        }

        return DevVlogsCamera(id: id, label: label)
    }

    private func requireEnabled() throws {
        guard isEnabled else {
            throw DevVlogsApplicationPolicyError.featureDisabled
        }
    }

    private func persistApplicationPolicy() {
        guard let data = try? JSONEncoder().encode(applicationPolicy) else {
            return
        }

        userDefaults?.set(data, forKey: Key.applicationPolicy)
        applicationPolicyLoadMessage = nil
    }

    private static func applicationPolicy(
        from userDefaults: UserDefaults
    ) -> (policy: DevVlogsApplicationPolicy, loadMessage: String?) {
        guard let data = userDefaults.data(forKey: Key.applicationPolicy) else {
            return (.defaultPolicy, nil)
        }

        guard let policy = try? JSONDecoder().decode(DevVlogsApplicationPolicy.self, from: data) else {
            return (
                .defaultPolicy,
                "The saved application policy could not be read. It has been preserved; only selected apps is active until you save a new policy."
            )
        }

        return (policy, nil)
    }
}
