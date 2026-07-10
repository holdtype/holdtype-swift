import Foundation

/// Stable app-private location for the containing app's versioned settings file.
public enum IOSAppSettingsStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-app-settings.json"

    public static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
