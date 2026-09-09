import Testing
import HoldTypeDomain

struct TranscriptionWritingContextTests {
    @Test func profileIsSeparateFromUserContextAndDictionaryEchoGuards() throws {
        let nearby = try #require(TranscriptionPromptContext("Existing sentence."))
        let composition = TranscriptionPromptComposition(
            resolvedFreeformPrompt: "Prefer technical vocabulary.",
            context: nearby,
            emojiCommandsConfiguration: EmojiCommandsConfiguration(isEnabled: false),
            customDictionary: CustomDictionary(entries: ["HoldType"]),
            writingContext: .aiTasks
        )

        let expected = [
            "Prefer technical vocabulary.",
            TranscriptionWritingContext.aiTasks.promptText,
            nearby.promptText,
            TranscriptionPromptComposition.customDictionaryPromptPrefix + "HoldType"
        ].joined(separator: "\n\n")
        #expect(composition.providerPrompt == expected)
        #expect(composition.gptTranscribeContextPrompt == expected)
        #expect(composition.dictionaryKeywordHints == ["HoldType"])
        #expect(composition.dictionaryEchoGuardText == "HoldType")
        #expect(composition.contextEchoGuardText == "Existing sentence.")
        #expect(!expected.contains("com.openai.codex"))
    }

    @Test func omittedProfilePreservesDefaultConsumerRequest() {
        let withoutProfile = TranscriptionPromptComposition(
            resolvedFreeformPrompt: nil,
            context: nil,
            emojiCommandsConfiguration: EmojiCommandsConfiguration(isEnabled: false),
            customDictionary: .empty
        )
        let withProfile = TranscriptionPromptComposition(
            resolvedFreeformPrompt: nil,
            context: nil,
            emojiCommandsConfiguration: EmojiCommandsConfiguration(isEnabled: false),
            customDictionary: .empty,
            writingContext: .aiTasks
        )
        #expect(withoutProfile.providerPrompt == nil)
        #expect(withProfile.providerPrompt == TranscriptionWritingContext.aiTasks.promptText)
        #expect(withProfile != withoutProfile)
        #expect(withProfile.dictionaryKeywordHints.isEmpty)
        #expect(withProfile.contextEchoGuardText == nil)
        #expect(withProfile.dictionaryEchoGuardText == nil)
    }
}
