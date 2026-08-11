import AppKit
import Foundation

@MainActor
protocol DevVlogsTriggerApplicationProviding {
    func currentTriggerApplication() -> DevVlogsTriggerApplication?
}

@MainActor
struct WorkspaceDevVlogsTriggerApplicationProvider: DevVlogsTriggerApplicationProviding {
    func currentTriggerApplication() -> DevVlogsTriggerApplication? {
        guard let application = NSWorkspace.shared.frontmostApplication,
              let bundleIdentifier = application.bundleIdentifier,
              !bundleIdentifier.isEmpty,
              bundleIdentifier != Bundle.main.bundleIdentifier else {
            return nil
        }

        let normalizedDisplayName = application.localizedName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return DevVlogsTriggerApplication(
            bundleIdentifier: bundleIdentifier,
            displayName: normalizedDisplayName.flatMap { $0.isEmpty ? nil : $0 }
                ?? bundleIdentifier
        )
    }
}
