import Foundation

public struct CustomDictionary: Equatable, Sendable {
    public static let empty = CustomDictionary(entries: [])

    public let entries: [String]

    public init(entries: [String]) {
        var normalizedEntries: [String] = []
        var seenKeys = Set<String>()

        for entry in entries {
            let trimmedEntry = entry.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedEntry.isEmpty else {
                continue
            }

            let entryKey = trimmedEntry.lowercased()
            guard seenKeys.insert(entryKey).inserted else {
                continue
            }

            normalizedEntries.append(trimmedEntry)
        }

        self.entries = normalizedEntries
    }

    public static func parseEntries(from text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    public func appendingEntries(from text: String) -> CustomDictionary {
        CustomDictionary(entries: entries + Self.parseEntries(from: text))
    }

    public var promptText: String? {
        entries.isEmpty ? nil : entries.joined(separator: ", ")
    }

    /// Literal term hints accepted by the `gpt-transcribe` multipart API.
    ///
    /// The API rejects keyword values containing angle brackets or line
    /// breaks. Keep those local entries available for legacy prompt behavior,
    /// but do not send them as invalid keyword fields.
    public var keywordHints: [String] {
        entries.filter { entry in
            !entry.contains("<") &&
                !entry.contains(">") &&
                !entry.contains("\r") &&
                !entry.contains("\n")
        }
    }
}
