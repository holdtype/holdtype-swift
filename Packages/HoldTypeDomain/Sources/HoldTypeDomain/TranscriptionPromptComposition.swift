public struct TranscriptionPromptComposition: Equatable, Sendable {
    public static let emojiCommandsPromptPrefix =
        "Emoji command vocabulary (transcribe these spoken phrases exactly when spoken): "
    public static let customDictionaryPromptPrefix =
        "Custom Dictionary (use these exact spellings when they appear in the text): "

    public let providerPrompt: String?
    public let gptTranscribeContextPrompt: String?
    public let dictionaryKeywordHints: [String]
    public let dictionaryEchoGuardText: String?
    public let contextEchoGuardText: String?

    public init(
        resolvedFreeformPrompt: String?,
        context: TranscriptionPromptContext?,
        emojiCommandsConfiguration: EmojiCommandsConfiguration,
        customDictionary: CustomDictionary
    ) {
        let emojiPrompt = emojiCommandsConfiguration.promptText
        let dictionaryPrompt = customDictionary.promptText
        var contextPromptParts: [String] = []

        if let resolvedFreeformPrompt, !resolvedFreeformPrompt.isEmpty {
            contextPromptParts.append(resolvedFreeformPrompt)
        }
        if let context {
            contextPromptParts.append(context.promptText)
        }
        if let emojiPrompt {
            contextPromptParts.append(Self.emojiCommandsPromptPrefix + emojiPrompt)
        }

        let contextPrompt = contextPromptParts.joined(separator: "\n\n")
        gptTranscribeContextPrompt = contextPrompt.isEmpty ? nil : contextPrompt

        var legacyPromptParts = contextPromptParts
        if let dictionaryPrompt {
            legacyPromptParts.append(Self.customDictionaryPromptPrefix + dictionaryPrompt)
        }

        let legacyPrompt = legacyPromptParts.joined(separator: "\n\n")
        providerPrompt = legacyPrompt.isEmpty ? nil : legacyPrompt
        dictionaryKeywordHints = customDictionary.keywordHints
        dictionaryEchoGuardText = dictionaryPrompt
        contextEchoGuardText = context?.text
    }
}
