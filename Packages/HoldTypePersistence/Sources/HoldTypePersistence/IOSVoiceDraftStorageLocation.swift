import Foundation

/// Stable app-private location for the containing-app composed Voice Draft.
public enum IOSVoiceDraftStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-voice-draft.json"

    public static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
