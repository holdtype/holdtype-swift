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
}
