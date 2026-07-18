import Foundation
import HoldTypeDomain

struct IOSLibraryWireV1: Encodable {
    private let schemaVersion = 1
    private let dictionary: IOSLibraryDictionaryWireV1
    private let emojiCommands: IOSLibraryEmojiCommandsWireV1
    private let replacementRules: [IOSLibraryReplacementRuleWireV1]

    init(content: IOSLibraryContent) {
        dictionary = IOSLibraryDictionaryWireV1(
            entries: content.customDictionary.entries
        )
        emojiCommands = IOSLibraryEmojiCommandsWireV1(
            isEnabled: content.emojiCommandsConfiguration.isEnabled,
            enabledBuiltInSetIDs:
                content.emojiCommandsConfiguration.enabledBuiltInSetIDs,
            customCommands: content.emojiCommandsConfiguration.customCommands.map {
                IOSLibraryCustomCommandWireV1(command: $0)
            }
        )
        replacementRules = content.replacementRules.map {
            IOSLibraryReplacementRuleWireV1(rule: $0)
        }
    }
}

private struct IOSLibraryDictionaryWireV1: Encodable {
    let entries: [String]
}

private struct IOSLibraryEmojiCommandsWireV1: Encodable {
    let isEnabled: Bool
    let enabledBuiltInSetIDs: [String]
    let customCommands: [IOSLibraryCustomCommandWireV1]
}

private struct IOSLibraryCustomCommandWireV1: Encodable {
    let id: String
    let emoji: String
    let command: String
    let aliases: [String]
    let isEnabled: Bool

    init(command: CustomEmojiCommand) {
        id = command.id.uuidString
        emoji = command.emoji
        self.command = command.command
        aliases = command.aliases
        isEnabled = command.isEnabled
    }
}

private struct IOSLibraryReplacementRuleWireV1: Encodable {
    let id: String
    let search: String
    let replacement: String
    let isEnabled: Bool

    init(rule: TextReplacementRule) {
        id = rule.id.uuidString
        search = rule.search
        replacement = rule.replacement
        isEnabled = rule.isEnabled
    }
}
