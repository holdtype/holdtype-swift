import Foundation

nonisolated enum DevVlogsArchiveNaming {
    static func appFolder(displayName: String, bundleIdentifier: String) -> String {
        "\(sanitize(displayName))--\(sanitize(bundleIdentifier))"
    }

    static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        formatter("yyyy-MM-dd", calendar: calendar).string(from: date)
    }

    static func yearKey(for date: Date, calendar: Calendar = .current) -> String {
        formatter("yyyy", calendar: calendar).string(from: date)
    }

    static func clipDirectoryName(startedAt: Date, clipID: UUID, calendar: Calendar = .current) -> String {
        "\(formatter("HH-mm-ss", calendar: calendar).string(from: startedAt))--\(clipID.uuidString.lowercased())"
    }

    static func sanitize(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character(String($0)) : "-" }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
        return sanitized.isEmpty ? "Unknown" : sanitized
    }

    private static func formatter(_ format: String, calendar: Calendar) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter
    }
}

nonisolated struct DevVlogsClipMetadata: Codable, Equatable {
    let schemaVersion: Int
    let clipID: UUID
    let attemptID: UUID
    let createdAt: Date
    let triggerBundleIdentifier: String
    let triggerApplicationName: String
    let cameraID: String
    let cameraName: String
    let duration: TimeInterval
    let byteCount: Int64
    let mediaHealth: String
    let realizedVideoFormat: DevVlogsRealizedVideoFormat
}
