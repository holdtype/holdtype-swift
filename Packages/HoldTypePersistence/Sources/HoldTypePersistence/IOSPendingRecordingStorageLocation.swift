import Foundation

/// Canonical app-private locations for the single pending iOS recording.
enum IOSPendingRecordingStorageLocation {
    static let rootDirectoryName = "HoldType"
    static let journalFileName = "ios-pending-recording.json"
    static let recordingsDirectoryName = "Recordings"
    static let pendingDirectoryName = "Pending"

    private static let audioFilePrefix = "recording-v1-"

    static func journalFileURL(
        in applicationSupportDirectoryURL: URL
    ) -> URL {
        rootDirectoryURL(in: applicationSupportDirectoryURL)
            .appendingPathComponent(journalFileName, isDirectory: false)
    }

    static func audioDirectoryURL(
        in applicationSupportDirectoryURL: URL
    ) -> URL {
        rootDirectoryURL(in: applicationSupportDirectoryURL)
            .appendingPathComponent(recordingsDirectoryName, isDirectory: true)
            .appendingPathComponent(pendingDirectoryName, isDirectory: true)
    }

    static func relativeAudioIdentifier(
        for attemptID: UUID,
        format: IOSPendingRecordingAudioFormat
    ) -> String {
        [
            recordingsDirectoryName,
            pendingDirectoryName,
            audioFileName(for: attemptID, format: format),
        ].joined(separator: "/")
    }

    static func audioFileURL(
        forRelativeIdentifier relativeIdentifier: String,
        in applicationSupportDirectoryURL: URL
    ) -> URL? {
        guard parseRelativeAudioIdentifier(relativeIdentifier) != nil else {
            return nil
        }
        return rootDirectoryURL(in: applicationSupportDirectoryURL)
            .appendingPathComponent(relativeIdentifier, isDirectory: false)
    }

    static func parseRelativeAudioIdentifier(
        _ relativeIdentifier: String
    ) -> (attemptID: UUID, format: IOSPendingRecordingAudioFormat)? {
        guard relativeIdentifier.unicodeScalars.allSatisfy({ $0.isASCII }),
              !relativeIdentifier.contains("%"),
              !relativeIdentifier.contains("\\") else {
            return nil
        }

        let components = relativeIdentifier.split(
            separator: "/",
            omittingEmptySubsequences: false
        )
        guard components.count == 3,
              components[0] == Substring(recordingsDirectoryName),
              components[1] == Substring(pendingDirectoryName) else {
            return nil
        }

        let fileName = String(components[2])
        for format in IOSPendingRecordingAudioFormat.allCases {
            let suffix = ".\(format.fileExtension)"
            guard fileName.hasPrefix(audioFilePrefix),
                  fileName.hasSuffix(suffix) else {
                continue
            }
            let start = fileName.index(
                fileName.startIndex,
                offsetBy: audioFilePrefix.count
            )
            let end = fileName.index(fileName.endIndex, offsetBy: -suffix.count)
            let identifierString = String(fileName[start..<end])
            guard let identifier = UUID(uuidString: identifierString),
                  identifierString == identifier.uuidString.lowercased(),
                  fileName == audioFileName(for: identifier, format: format),
                  relativeIdentifier == relativeAudioIdentifier(
                      for: identifier,
                      format: format
                  ) else {
                continue
            }
            return (identifier, format)
        }
        return nil
    }

    static func audioFileName(
        for attemptID: UUID,
        format: IOSPendingRecordingAudioFormat
    ) -> String {
        audioFilePrefix
            + attemptID.uuidString.lowercased()
            + "."
            + format.fileExtension
    }

    private static func rootDirectoryURL(
        in applicationSupportDirectoryURL: URL
    ) -> URL {
        applicationSupportDirectoryURL.appendingPathComponent(
            rootDirectoryName,
            isDirectory: true
        )
    }
}
