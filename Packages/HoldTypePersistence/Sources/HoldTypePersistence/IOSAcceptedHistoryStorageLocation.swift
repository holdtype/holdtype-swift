import Foundation

/// Stable app-private location for canonical accepted iOS History rows.
public enum IOSAcceptedHistoryStorageLocation {
    public static let directoryName = "HoldType"
    public static let fileName = "ios-accepted-history.json"

    public static func fileURL(in applicationSupportDirectoryURL: URL) -> URL {
        applicationSupportDirectoryURL
            .appendingPathComponent(directoryName, isDirectory: true)
            .appendingPathComponent(fileName, isDirectory: false)
    }
}

extension IOSStrictProtectedRecordConfiguration {
    static let acceptedHistory = Self(
        rootDirectoryName: IOSAcceptedHistoryStorageLocation.directoryName,
        fileName: IOSAcceptedHistoryStorageLocation.fileName,
        maximumByteCount: IOSAcceptedHistoryJournal.maximumByteCount,
        marker: Marker(
            name: "com.holdtype.ios.accepted-history",
            value: Array("v1".utf8)
        )
    )
}
