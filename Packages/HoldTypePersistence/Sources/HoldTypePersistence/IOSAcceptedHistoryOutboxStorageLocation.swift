import Foundation

/// Stable app-private location for pending accepted-History transfers.
public enum IOSAcceptedHistoryOutboxStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-accepted-history-outbox.json"

    public static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}

extension IOSStrictProtectedRecordConfiguration {
    static let acceptedHistoryOutbox = Self(
        rootDirectoryName:
            IOSAcceptedHistoryOutboxStorageLocation.directoryName,
        fileName: IOSAcceptedHistoryOutboxStorageLocation.fileName,
        maximumByteCount: IOSAcceptedHistoryOutboxJournal.maximumByteCount,
        marker: Marker(
            name: "com.holdtype.ios.accepted-history-outbox",
            value: Array("v1".utf8)
        )
    )
}
