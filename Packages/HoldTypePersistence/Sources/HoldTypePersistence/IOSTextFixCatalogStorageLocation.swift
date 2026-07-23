import Foundation

/// Stable app-private location for the containing app's versioned Fixes catalog.
public enum IOSTextFixCatalogStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-text-fixes.json"

    public static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
