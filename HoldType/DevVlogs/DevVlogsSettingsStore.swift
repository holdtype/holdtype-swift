import Combine
import Foundation

enum DevVlogsReadiness: Equatable {
    case off
    case setupRequired

    var title: String {
        switch self {
        case .off:
            return "Off"
        case .setupRequired:
            return "Setup required"
        }
    }
}

final class DevVlogsSettingsStore: ObservableObject {
    private enum Key {
        static let isEnabled = "holdtype.dev-vlogs.is-enabled"
        static let preferredCameraID = "holdtype.dev-vlogs.preferred-camera-id"
        static let preferredCameraLabel = "holdtype.dev-vlogs.preferred-camera-label"
    }

    @Published private(set) var isEnabled: Bool
    @Published private(set) var preferredCamera: DevVlogsCamera?

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isEnabled = userDefaults.bool(forKey: Key.isEnabled)
        preferredCamera = Self.preferredCamera(from: userDefaults)
    }

    init(isEnabled: Bool, preferredCamera: DevVlogsCamera? = nil) {
        userDefaults = nil
        self.isEnabled = isEnabled
        self.preferredCamera = preferredCamera
    }

    var readiness: DevVlogsReadiness {
        isEnabled ? .setupRequired : .off
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

    private static func preferredCamera(from userDefaults: UserDefaults) -> DevVlogsCamera? {
        guard let id = userDefaults.string(forKey: Key.preferredCameraID),
              let label = userDefaults.string(forKey: Key.preferredCameraLabel),
              !id.isEmpty,
              !label.isEmpty else {
            return nil
        }

        return DevVlogsCamera(id: id, label: label)
    }
}
