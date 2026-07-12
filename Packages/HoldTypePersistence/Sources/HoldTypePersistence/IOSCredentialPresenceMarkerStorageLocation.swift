import Foundation

/// Stable app-private location for the non-secret OpenAI credential marker.
public enum IOSCredentialPresenceMarkerStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-openai-credential-presence.json"

    public static func fileURL(
        in applicationSupportDirectoryURL: URL
    ) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}
