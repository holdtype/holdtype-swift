import Testing
@testable import HoldTypeDomain

struct TranscriptionPromptCompositionTests {
    @Test func emptyInputsProduceNoProviderPromptOrEchoGuards() {
        let composition = TranscriptionPromptComposition(
            resolvedFreeformPrompt: nil,
            context: nil,
            emojiCommandsConfiguration: EmojiCommandsConfiguration(isEnabled: false),
            customDictionary: .empty
        )

        #expect(composition.providerPrompt == nil)
        #expect(composition.dictionaryEchoGuardText == nil)
        #expect(composition.contextEchoGuardText == nil)
    }

    @Test func eachIndividualSourceUsesItsExactProviderShape() throws {
        let context = try #require(TranscriptionPromptContext("Existing sentence."))
        let emojiConfiguration = EmojiCommandsConfiguration(
            enabledBuiltInSetIDs: [],
            customCommands: [
                CustomEmojiCommand(emoji: "🚀", command: "emoji rocket")
            ]
        )
        let dictionary = CustomDictionary(entries: [" HoldType ", "holdtype", "Synty"])

        #expect(
            composition(freeform: "Prefer product vocabulary.").providerPrompt ==
                "Prefer product vocabulary."
        )
        #expect(
            composition(context: context).providerPrompt == context.promptText
        )
        #expect(
            composition(emoji: emojiConfiguration).providerPrompt ==
                TranscriptionPromptComposition.emojiCommandsPromptPrefix + "emoji rocket"
        )
        #expect(
            composition(dictionary: dictionary).providerPrompt ==
                TranscriptionPromptComposition.customDictionaryPromptPrefix +
                "HoldType, Synty"
        )
    }

    @Test func fourSourcesPreserveExactOrderSeparatorsAndEchoGuards() throws {
        let context = try #require(TranscriptionPromptContext("Existing sentence."))
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

        #expect(
            composition.providerPrompt ==
                """
                Prefer product vocabulary.

                Current writing context near the cursor. Use this only for continuity; transcribe only the new speech:
                Existing sentence.

                Emoji command vocabulary (transcribe these spoken phrases exactly when spoken): emoji rocket

                Custom Dictionary (use these exact spellings when they appear in the text): HoldType
                """
        )
        #expect(composition.dictionaryEchoGuardText == "HoldType")
        #expect(composition.contextEchoGuardText == "Existing sentence.")
    }

    @Test func disabledEmojiAndEmptyDictionaryAddNoSections() {
        let composition = TranscriptionPromptComposition(
            resolvedFreeformPrompt: "Freeform only",
            context: nil,
            emojiCommandsConfiguration: EmojiCommandsConfiguration(
                isEnabled: false,
                customCommands: [
                    CustomEmojiCommand(emoji: "🚀", command: "emoji rocket")
                ]
            ),
            customDictionary: CustomDictionary(entries: [" ", "\n"])
        )

        #expect(composition.providerPrompt == "Freeform only")
        #expect(composition.dictionaryEchoGuardText == nil)
        #expect(composition.contextEchoGuardText == nil)
    }

    @Test func equalityIncludesProviderPromptAndBothEchoGuards() throws {
        let context = try #require(TranscriptionPromptContext("Existing sentence."))
        let first = composition(freeform: "Freeform", context: context)

        #expect(first == first)
        #expect(first != composition(freeform: "Different", context: context))
        #expect(first != composition(freeform: "Freeform"))
        #expect(
            first != composition(
                freeform: "Freeform",
                context: context,
                dictionary: CustomDictionary(entries: ["HoldType"])
            )
        )
    }

    @Test func publicValueIsSendableButNotATransportContract() {
        requireSendable(TranscriptionPromptComposition.self)
        let composition = composition(freeform: "Freeform")

        #expect(((composition as Any) is any Encodable) == false)
        #expect(((composition as Any) is any Decodable) == false)
    }

    private func composition(
        freeform: String? = nil,
        context: TranscriptionPromptContext? = nil,
        emoji: EmojiCommandsConfiguration = EmojiCommandsConfiguration(isEnabled: false),
        dictionary: CustomDictionary = .empty
    ) -> TranscriptionPromptComposition {
        TranscriptionPromptComposition(
            resolvedFreeformPrompt: freeform,
            context: context,
            emojiCommandsConfiguration: emoji,
            customDictionary: dictionary
        )
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
