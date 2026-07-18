import Foundation
import Testing

func makeIsolatedUserDefaults() -> (UserDefaults, String) {
    let suiteName = "holdtype.AppSettingsTests.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        Issue.record("Could not create isolated UserDefaults suite")
        return (.standard, suiteName)
    }

    defaults.removePersistentDomain(forName: suiteName)
    return (defaults, suiteName)
}
