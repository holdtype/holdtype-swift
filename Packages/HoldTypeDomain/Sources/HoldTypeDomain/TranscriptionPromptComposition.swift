public struct TranscriptionPromptComposition: Equatable, Sendable {
    public static let emojiCommandsPromptPrefix =
        "Emoji command vocabulary (transcribe these spoken phrases exactly when spoken): "
    public static let customDictionaryPromptPrefix =
        "Custom Dictionary (use these exact spellings when they appear in the text): "

    public let providerPrompt: String?
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
        var promptParts: [String] = []

        if let resolvedFreeformPrompt, !resolvedFreeformPrompt.isEmpty {
            promptParts.append(resolvedFreeformPrompt)
        }
        if let context {
            promptParts.append(context.promptText)
        }
        if let emojiPrompt {
            promptParts.append(Self.emojiCommandsPromptPrefix + emojiPrompt)
        }
        if let dictionaryPrompt {
            promptParts.append(Self.customDictionaryPromptPrefix + dictionaryPrompt)
        }

        let composedPrompt = promptParts.joined(separator: "\n\n")
        providerPrompt = composedPrompt.isEmpty ? nil : composedPrompt
        dictionaryEchoGuardText = dictionaryPrompt
        contextEchoGuardText = context?.text
    }
}
