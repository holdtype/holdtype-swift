import AppKit
import HoldTypeDomain

/// Non-visual platform boundary: SwiftUI has no foreground-application identity API.
/// Reads only bundle identity, without Accessibility, window titles or field text.
@MainActor
enum DictationWritingContextCapture {
    static func capture(
        _ settings: AppSettings,
        intent: DictationOutputIntent,
        applicationBundleIdentifier: () -> String? = {
            NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        }
    ) -> AppSettings {
        var snapshot = settings
        guard intent == .standard else {
            snapshot.writingContextMode = .off
            return snapshot
        }
        let identifier = settings.writingContextMode == .automatic
            ? applicationBundleIdentifier() : nil
        snapshot.writingContextMode = settings.writingContextMode.resolved(
            applicationBundleIdentifier: identifier
        )
        return snapshot
    }
}
