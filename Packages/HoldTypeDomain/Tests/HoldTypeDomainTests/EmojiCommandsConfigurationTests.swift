import Foundation
import Testing
import HoldTypeDomain

struct EmojiCommandsConfigurationTests {
    @Test func defaultsEnableOnlyTheEnglishBuiltInSet() {
        let configuration = EmojiCommandsConfiguration.defaults

        #expect(configuration == EmojiCommandsConfiguration())
        #expect(configuration.isEnabled)
        #expect(configuration.enabledBuiltInSetIDs == ["en"])
        #expect(configuration.normalizedEnabledBuiltInSetIDs == ["en"])
        #expect(configuration.enabledBuiltInSets.map(\.id) == ["en"])
        #expect(configuration.customCommands.isEmpty)
        #expect(configuration.enabledCustomCommands.isEmpty)
        #expect(configuration.promptText?.contains("emoji smile") == true)
    }

    @Test func selectsOnlyTheFirstKnownBuiltInSetWithoutMutatingRawIDs() {
        let configuration = EmojiCommandsConfiguration(
            enabledBuiltInSetIDs: [" missing ", " ru ", "en", "de"]
        )

        #expect(configuration.enabledBuiltInSetIDs == [" missing ", " ru ", "en", "de"])
        #expect(configuration.normalizedEnabledBuiltInSetIDs == ["ru"])
        #expect(configuration.enabledBuiltInSets.map(\.id) == ["ru"])
        #expect(
            EmojiCommandsConfiguration(enabledBuiltInSetIDs: ["EN"]).enabledBuiltInSets.isEmpty
        )
        #expect(
            EmojiCommandsConfiguration(enabledBuiltInSetIDs: []).enabledBuiltInSets.isEmpty
        )
    }

    @Test func normalizesCustomCommandsAndKeepsTheFirstDuplicate() {
        let firstID = UUID(uuidString: "00000000-0000-0000-0000-000000000321")!
        let duplicateID = UUID(uuidString: "00000000-0000-0000-0000-000000000322")!
        let configuration = EmojiCommandsConfiguration(
            enabledBuiltInSetIDs: [],
            customCommands: [
                CustomEmojiCommand(
                    id: firstID,
                    emoji: " 🚀 ",
                    command: " Emoji   Rocket ",
                    aliases: ["Launch Emoji"],
                    isEnabled: true
                ),
                CustomEmojiCommand(
                    id: duplicateID,
                    emoji: "🚀",
                    command: "émóji rocket",
                    isEnabled: true
                ),
                CustomEmojiCommand(emoji: " ", command: "ignored"),
                CustomEmojiCommand(emoji: "😎", command: "cool", isEnabled: false),
            ]
        )

        #expect(configuration.normalizedCustomCommands.count == 2)
        #expect(configuration.normalizedCustomCommands[0].id == firstID)
        #expect(configuration.normalizedCustomCommands[0].emoji == "🚀")
        #expect(configuration.normalizedCustomCommands[0].command == "Emoji Rocket")
        #expect(configuration.normalizedCustomCommands[0].aliases == ["Launch Emoji"])
        #expect(configuration.enabledCustomCommands.map(\.id) == [firstID])
        #expect(configuration.promptText == "Emoji Rocket, Launch Emoji")
    }

    @Test func disabledConfigurationPublishesNoActiveCommandsOrPrompt() {
        let command = CustomEmojiCommand(emoji: "🚀", command: "emoji rocket")
        let configuration = EmojiCommandsConfiguration(
            isEnabled: false,
            enabledBuiltInSetIDs: ["ru"],
            customCommands: [command]
        )

        #expect(configuration.normalizedEnabledBuiltInSetIDs == ["ru"])
        #expect(configuration.normalizedCustomCommands == [command])
        #expect(configuration.enabledBuiltInSets.isEmpty)
        #expect(configuration.enabledCustomCommands.isEmpty)
        #expect(configuration.promptHints.isEmpty)
        #expect(configuration.promptText == nil)
    }

    @Test func disabledFirstDuplicateWinsAndAliasesCanBecomePrimaryCommands() {
        let disabledID = UUID(uuidString: "00000000-0000-0000-0000-000000000331")!
        let duplicateID = UUID(uuidString: "00000000-0000-0000-0000-000000000332")!
        let differentEmojiID = UUID(uuidString: "00000000-0000-0000-0000-000000000333")!
        let aliasPrimaryID = UUID(uuidString: "00000000-0000-0000-0000-000000000334")!
        let differentPhraseID = UUID(uuidString: "00000000-0000-0000-0000-000000000335")!
        let configuration = EmojiCommandsConfiguration(
            enabledBuiltInSetIDs: [],
            customCommands: [
                CustomEmojiCommand(
                    id: disabledID,
                    emoji: "🚀",
                    command: "emoji rocket",
                    isEnabled: false
                ),
                CustomEmojiCommand(
                    id: duplicateID,
                    emoji: "🚀",
                    command: "ÉMÓJI ROCKET",
                    isEnabled: true
                ),
                CustomEmojiCommand(
                    id: differentEmojiID,
                    emoji: "🛰️",
                    command: "emoji rocket",
                    isEnabled: true
                ),
                CustomEmojiCommand(
                    id: aliasPrimaryID,
                    emoji: "✅",
                    command: "",
                    aliases: ["ship it"],
                    isEnabled: true
                ),
                CustomEmojiCommand(
                    id: differentPhraseID,
                    emoji: "🚀",
                    command: "launch now",
                    isEnabled: true
                ),
            ]
        )

        #expect(
            configuration.normalizedCustomCommands.map(\.id) ==
                [disabledID, differentEmojiID, aliasPrimaryID, differentPhraseID]
        )
        #expect(
            configuration.enabledCustomCommands.map(\.id) ==
                [differentEmojiID, aliasPrimaryID, differentPhraseID]
        )
        #expect(configuration.enabledCustomCommands[1].command == "ship it")
        #expect(configuration.promptText == "emoji rocket, ship it, launch now")
    }

    @Test func promptHintsKeepBuiltInCommandsBeforeCustomCommands() {
        let configuration = EmojiCommandsConfiguration(
            enabledBuiltInSetIDs: ["en"],
            customCommands: [
                CustomEmojiCommand(emoji: "🚀", command: "emoji rocket")
            ]
        )

        let englishHintCount = EmojiCommandSet.builtIn[0].promptHints.count
        #expect(configuration.promptHints[0] == "emoji heart")
        #expect(configuration.promptHints[englishHintCount] == "emoji rocket")
    }
}
