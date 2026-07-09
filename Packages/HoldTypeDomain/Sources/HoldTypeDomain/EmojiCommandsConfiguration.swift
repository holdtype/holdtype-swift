import Foundation

public struct EmojiCommandsConfiguration: Equatable, Sendable {
    public static let defaultEnabledBuiltInSetIDs = ["en"]
    public static let defaults = EmojiCommandsConfiguration()

    public var isEnabled: Bool
    public var enabledBuiltInSetIDs: [String]
    public var customCommands: [CustomEmojiCommand]

    public init(
        isEnabled: Bool = true,
        enabledBuiltInSetIDs: [String] = Self.defaultEnabledBuiltInSetIDs,
        customCommands: [CustomEmojiCommand] = []
    ) {
        self.isEnabled = isEnabled
        self.enabledBuiltInSetIDs = enabledBuiltInSetIDs
        self.customCommands = customCommands
    }

    public var normalizedEnabledBuiltInSetIDs: [String] {
        EmojiCommandSet.normalizedBuiltInIDs(enabledBuiltInSetIDs)
    }

    public var enabledBuiltInSets: [EmojiCommandSet] {
        guard isEnabled else {
            return []
        }

        let enabledIDs = Set(normalizedEnabledBuiltInSetIDs)
        return EmojiCommandSet.builtIn.filter { enabledIDs.contains($0.id) }
    }

    public var normalizedCustomCommands: [CustomEmojiCommand] {
        Self.normalizedCustomCommands(customCommands)
    }

    public var enabledCustomCommands: [CustomEmojiCommand] {
        guard isEnabled else {
            return []
        }

        return normalizedCustomCommands.filter { $0.isEnabled && $0.hasUsableCommand }
    }

    public var promptHints: [String] {
        enabledBuiltInSets.flatMap(\.promptHints)
            + enabledCustomCommands.flatMap(\.promptHints)
    }

    public var promptText: String? {
        let hints = promptHints
        return hints.isEmpty ? nil : hints.joined(separator: ", ")
    }

    public static func normalizedCustomCommands(
        _ commands: [CustomEmojiCommand]
    ) -> [CustomEmojiCommand] {
        var normalizedCommands: [CustomEmojiCommand] = []
        var seenKeys = Set<String>()

        for command in commands {
            let normalizedCommand = command.normalizedForStorage
            guard normalizedCommand.hasUsableCommand else {
                continue
            }

            let commandKey =
                "\(normalizedCommand.normalizedEmoji)|\(normalizedCommand.displayCommand)"
                    .folding(
                        options: [.caseInsensitive, .diacriticInsensitive],
                        locale: nil
                    )
            guard seenKeys.insert(commandKey).inserted else {
                continue
            }

            normalizedCommands.append(normalizedCommand)
        }

        return normalizedCommands
    }
}
