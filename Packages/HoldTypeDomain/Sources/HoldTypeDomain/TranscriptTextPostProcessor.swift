import Foundation

public struct TranscriptPostProcessingConfiguration: Equatable, Sendable {
    public static let defaults = TranscriptPostProcessingConfiguration()

    public var localTextCleanupEnabled: Bool
    public var emojiCommands: EmojiCommandsConfiguration
    public var textReplacementRules: [TextReplacementRule]

    public init(
        localTextCleanupEnabled: Bool = true,
        emojiCommands: EmojiCommandsConfiguration = .defaults,
        textReplacementRules: [TextReplacementRule] = []
    ) {
        self.localTextCleanupEnabled = localTextCleanupEnabled
        self.emojiCommands = emojiCommands
        self.textReplacementRules = textReplacementRules
    }

    public var enabledTextReplacementRules: [TextReplacementRule] {
        textReplacementRules.filter { $0.isEnabled && $0.hasSearchText }
    }
}

public struct TranscriptTextPostProcessor: Sendable {
    private static let quoteTranslations: [Character: String] = [
        "«": "\"",
        "»": "\"",
        "“": "\"",
        "”": "\"",
        "„": "\"",
        "‟": "\"",
        "‘": "'",
        "’": "'",
        "‚": "'",
        "‛": "'",
        "`": "'",
        "´": "'",
        "…": "...",
        "\u{00A0}": " ",
        "\u{202F}": " ",
        "\u{2009}": " ",
        "\u{2060}": "",
    ]

    private static let dashCharacters = "\u{2012}\u{2013}\u{2014}\u{2015}\u{2212}\u{2011}"
    private let emojiCommandReplacementService: EmojiCommandReplacementService

    public init(
        emojiCommandReplacementService: EmojiCommandReplacementService =
            EmojiCommandReplacementService()
    ) {
        self.emojiCommandReplacementService = emojiCommandReplacementService
    }

    public func process(
        _ text: String,
        configuration: TranscriptPostProcessingConfiguration,
        fallback: String? = nil
    ) -> String {
        let originalText = fallback ?? text
        var processedText = text

        if configuration.localTextCleanupEnabled {
            processedText = Self.normalizeInformalTypography(processedText)
        }

        processedText = emojiCommandReplacementService.process(
            processedText,
            commandSets: configuration.emojiCommands.enabledBuiltInSets,
            customCommands: configuration.emojiCommands.enabledCustomCommands
        )

        for rule in configuration.enabledTextReplacementRules {
            processedText = processedText.replacingOccurrences(
                of: rule.search,
                with: rule.replacement,
                options: [.caseInsensitive]
            )
        }

        return AcceptedTranscript.nonEmptyNormalizedText(from: processedText)
            ?? AcceptedTranscript.nonEmptyNormalizedText(from: originalText)
            ?? originalText
    }

    public static func normalizeInformalTypography(_ text: String) -> String {
        let translatedText = translateCharacters(in: text)
        let dashNormalizedText = normalizeDashes(in: translatedText)
        return normalizeSpacing(in: dashNormalizedText)
    }

    public static func normalizedInformalTypography(
        from text: String,
        fallback: String? = nil
    ) -> String {
        let originalText = fallback ?? text
        return AcceptedTranscript.nonEmptyNormalizedText(from: normalizeInformalTypography(text))
            ?? AcceptedTranscript.nonEmptyNormalizedText(from: originalText)
            ?? originalText
    }

    private static func translateCharacters(in text: String) -> String {
        var translatedText = ""

        for character in text {
            translatedText.append(quoteTranslations[character] ?? String(character))
        }

        return translatedText
    }

    private static func normalizeDashes(in text: String) -> String {
        var normalizedText = text
        normalizedText = replacingMatches(
            in: normalizedText,
            pattern: "(?<=\\d)\\s*[\(dashCharacters)]\\s*(?=\\d)",
            with: "-"
        )
        normalizedText = replacingMatches(
            in: normalizedText,
            pattern: "(?m)^\\s*[\(dashCharacters)]\\s*",
            with: "- "
        )
        normalizedText = replacingMatches(
            in: normalizedText,
            pattern: "(?<=\\S)\\s*[\(dashCharacters)]\\s*(?=\\S)",
            with: " - "
        )
        return replacingMatches(in: normalizedText, pattern: "[\(dashCharacters)]", with: "-")
    }

    private static func normalizeSpacing(in text: String) -> String {
        var normalizedText = replacingMatches(in: text, pattern: "[ \\t]+", with: " ")
        normalizedText = replacingMatches(in: normalizedText, pattern: " *\\n", with: "\n")
        return replacingMatches(in: normalizedText, pattern: "\\n{3,}", with: "\n\n")
    }

    private static func replacingMatches(
        in text: String,
        pattern: String,
        with replacement: String
    ) -> String {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return text
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.stringByReplacingMatches(
            in: text,
            range: range,
            withTemplate: replacement
        )
    }
}
