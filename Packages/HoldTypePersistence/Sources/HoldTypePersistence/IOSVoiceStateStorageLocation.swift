import Foundation

enum IOSVoiceStateStorageLocation {
    static let rootDirectoryName = "HoldType"
    static let voiceStateDirectoryName = "VoiceState"
    static let recordFileName = "ios-v1-voice-state.json"
    static let audioFilePrefix = "pending-v1-"

    static func directoryURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(rootDirectoryName, isDirectory: true)
            .appendingPathComponent(voiceStateDirectoryName, isDirectory: true)
    }

    static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        directoryURL(in: applicationSupportDirectoryURL)
            .appendingPathComponent(recordFileName, isDirectory: false)
    }

    static func relativeAudioIdentifier(
        for attemptID: UUID,
        extension fileExtension: String = "m4a"
    ) -> String {
        voiceStateDirectoryName + "/" + audioFilePrefix
            + attemptID.uuidString.lowercased() + "." + fileExtension
    }

    static func audioFileURL(
        for attemptID: UUID,
        extension fileExtension: String = "m4a",
        in applicationSupportDirectoryURL: URL
    ) -> URL {
        directoryURL(in: applicationSupportDirectoryURL)
            .appendingPathComponent(
                audioFilePrefix + attemptID.uuidString.lowercased()
                    + "." + fileExtension,
                isDirectory: false
            )
    }
}
