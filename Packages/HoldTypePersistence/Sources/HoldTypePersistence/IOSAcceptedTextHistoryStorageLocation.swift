import Foundation

/// Stable app-private location for compact successful-text History.
public enum IOSAcceptedTextHistoryStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-accepted-text-history.json"

    public static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
