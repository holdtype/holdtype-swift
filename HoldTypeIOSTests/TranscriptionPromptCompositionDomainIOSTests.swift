import HoldTypeDomain
import Testing

struct TranscriptionPromptCompositionDomainIOSTests {
    @Test func publicPromptCompositionWorksThroughANormalIOSImport() throws {
        let context = try #require(TranscriptionPromptContext("Existing iOS text."))
        let composition = TranscriptionPromptComposition(
            resolvedFreeformPrompt: "Prefer product vocabulary.",
            context: context,
            emojiCommandsConfiguration: EmojiCommandsConfiguration(
                enabledBuiltInSetIDs: [],
                customCommands: [
                    CustomEmojiCommand(emoji: "🚀", command: "emoji rocket")
                ]
            ),
            customDictionary: CustomDictionary(entries: ["HoldType"])
        )

        #expect(composition.providerPrompt?.hasPrefix("Prefer product vocabulary.\n\n") == true)
        #expect(composition.providerPrompt?.contains("emoji rocket") == true)
        #expect(composition.providerPrompt?.hasSuffix("HoldType") == true)
        #expect(composition.contextEchoGuardText == "Existing iOS text.")
        #expect(composition.dictionaryEchoGuardText == "HoldType")
        requireSendable(TranscriptionPromptComposition.self)
        #expect(((composition as Any) is any Encodable) == false)
        #expect(((composition as Any) is any Decodable) == false)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
