import HoldTypeDomain
import Testing

struct EmojiCommandsConfigurationDomainIOSTests {
    @Test func packageResolvesEmojiConfigurationOnIOS() {
        let configuration = EmojiCommandsConfiguration(
            enabledBuiltInSetIDs: ["missing", " ru ", "en"],
            customCommands: [
                CustomEmojiCommand(emoji: " 🚀 ", command: " Emoji   Rocket ")
            ]
        )

        #expect(configuration.enabledBuiltInSets.map(\.id) == ["ru"])
        #expect(configuration.enabledCustomCommands.first?.emoji == "🚀")
        #expect(configuration.enabledCustomCommands.first?.command == "Emoji Rocket")
        #expect(configuration.promptText?.contains("эмодзи сердце") == true)
        #expect(configuration.promptText?.hasSuffix("Emoji Rocket") == true)
    }
}
