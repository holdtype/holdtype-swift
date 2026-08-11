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
    }

    @Published private(set) var isEnabled: Bool

    private let userDefaults: UserDefaults?

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        isEnabled = userDefaults.bool(forKey: Key.isEnabled)
    }

    init(isEnabled: Bool) {
        userDefaults = nil
        self.isEnabled = isEnabled
    }

    var readiness: DevVlogsReadiness {
        isEnabled ? .setupRequired : .off
    }

    func setEnabled(_ isEnabled: Bool) {
        self.isEnabled = isEnabled
        userDefaults?.set(isEnabled, forKey: Key.isEnabled)
    }
}
