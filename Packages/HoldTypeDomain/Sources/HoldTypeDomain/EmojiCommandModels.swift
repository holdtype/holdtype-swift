//
//  EmojiCommandModels.swift
//  HoldType
//
//  Created by Codex on 7/18/26.
//

import Foundation

public struct EmojiCommandAlias: Equatable, Sendable {
    public let spokenPhrase: String
    public let replacement: String

    public init(spokenPhrase: String, replacement: String) {
        self.spokenPhrase = spokenPhrase
        self.replacement = replacement
    }

}

public struct EmojiCommand: Equatable, Identifiable, Sendable {
    public let id: String
    public let emoji: String
    public let displayName: String
    public let aliases: [String]

    public init(id: String, emoji: String, displayName: String, aliases: [String]) {
        self.id = id
        self.emoji = emoji
        self.displayName = displayName
        self.aliases = Self.normalizedSpokenPhrases(aliases)
    }

    public var primarySpokenPhrase: String {
        aliases.first ?? ""
    }

    public var secondarySpokenPhrases: [String] {
        Array(aliases.dropFirst())
    }

    public var replacementAliases: [EmojiCommandAlias] {
        aliases.map { EmojiCommandAlias(spokenPhrase: $0, replacement: emoji) }
    }

    public var promptHints: [String] {
        Array(aliases.prefix(3))
    }

    public static func normalizedSpokenPhrase(_ phrase: String) -> String {
        phrase
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    public static func normalizedSpokenPhrases(_ phrases: [String]) -> [String] {
        var normalizedPhrases: [String] = []
        var seenKeys = Set<String>()

        for phrase in phrases {
            let normalizedPhrase = normalizedSpokenPhrase(phrase)
            guard !normalizedPhrase.isEmpty else {
                continue
            }

            let key = normalizedPhrase.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: nil
            )
            guard !seenKeys.contains(key) else {
                continue
            }

            seenKeys.insert(key)
            normalizedPhrases.append(normalizedPhrase)
        }

        return normalizedPhrases
    }
}

public struct CustomEmojiCommand: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var emoji: String
    public var command: String
    public var aliases: [String]
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        emoji: String,
        command: String,
        aliases: [String] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.emoji = emoji
        self.command = command
        self.aliases = aliases
        self.isEnabled = isEnabled
    }

    public var normalizedEmoji: String {
        emoji.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var normalizedSpokenPhrases: [String] {
        EmojiCommand.normalizedSpokenPhrases([command] + aliases)
    }

    public var displayCommand: String {
        normalizedSpokenPhrases.first ?? EmojiCommand.normalizedSpokenPhrase(command)
    }

    public var replacementAliases: [EmojiCommandAlias] {
        normalizedSpokenPhrases.map {
            EmojiCommandAlias(spokenPhrase: $0, replacement: normalizedEmoji)
        }
    }

    public var promptHints: [String] {
        Array(normalizedSpokenPhrases.prefix(3))
    }

    public var hasUsableCommand: Bool {
        !normalizedEmoji.isEmpty && !normalizedSpokenPhrases.isEmpty
    }

    public var normalizedForStorage: CustomEmojiCommand {
        let normalizedPhrases = normalizedSpokenPhrases
        let normalizedCommand = normalizedPhrases.first ?? ""
        let normalizedAliases = Array(normalizedPhrases.dropFirst())

        return CustomEmojiCommand(
            id: id,
            emoji: normalizedEmoji,
            command: normalizedCommand,
            aliases: normalizedAliases,
            isEnabled: isEnabled
        )
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case emoji
        case command
        case aliases
        case isEnabled
    }
}
