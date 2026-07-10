import Foundation

/// Stable app-private location for the containing app's local usage estimate.
public enum IOSTranscriptionUsageStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-transcription-usage.json"

    public static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
