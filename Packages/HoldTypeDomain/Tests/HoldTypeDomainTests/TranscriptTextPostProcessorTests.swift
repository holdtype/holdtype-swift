import Testing
import HoldTypeDomain

struct TranscriptTextPostProcessorTests {
    private let processor = TranscriptTextPostProcessor()

    @Test func defaultConfigurationMatchesCurrentLocalPostProcessingDefaults() {
        let configuration = TranscriptPostProcessingConfiguration.defaults

        #expect(configuration.localTextCleanupEnabled)
        #expect(configuration.emojiCommands == .defaults)
        #expect(configuration.textReplacementRules.isEmpty)
        #expect(configuration.enabledTextReplacementRules.isEmpty)
    }

    @Test func normalizesInformalTypographyExactly() {
        let input = """
        “Hello”—world…\u{00A0}5 – 7
        — bullet


        Done
        """

        #expect(
            TranscriptTextPostProcessor.normalizeInformalTypography(input) ==
                """
                "Hello" - world... 5-7
                - bullet

                Done
                """
        )
    }

    @Test func translatesEveryInformalCharacterMapping() {
        let input =
            "«a» “b” „c‟ ‘d’ ‚e‛ `f´ …\u{00A0}x\u{202F}y\u{2009}z\u{2060}!"

        #expect(
            TranscriptTextPostProcessor.normalizeInformalTypography(input) ==
                "\"a\" \"b\" \"c\" 'd' 'e' 'f' ... x y z!"
        )
    }

    @Test func runsCleanupThenEmojiThenOrderedLiteralReplacements() {
        let configuration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: true,
            emojiCommands: EmojiCommandsConfiguration(
                enabledBuiltInSetIDs: ["en"]
            ),
            textReplacementRules: [
                TextReplacementRule(search: "🙂", replacement: "smile"),
                TextReplacementRule(search: "smile", replacement: "human"),
                TextReplacementRule(search: "—", replacement: "not-used"),
            ]
        )

        #expect(
            processor.process(
                "“Emoji Smile”—ready",
                configuration: configuration
            ) == "\"human\" - ready"
        )
    }

    @Test func replacementsAreCaseInsensitiveAndKeepRawRuleOrder() {
        let configuration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: [
                TextReplacementRule(search: "openai", replacement: "OpenAI"),
                TextReplacementRule(search: "hello", replacement: "hi"),
                TextReplacementRule(
                    search: "ignored",
                    replacement: "value",
                    isEnabled: false
                ),
                TextReplacementRule(search: " \n ", replacement: "invalid"),
            ]
        )

        #expect(configuration.textReplacementRules.count == 4)
        #expect(configuration.enabledTextReplacementRules.count == 2)
        #expect(
            processor.process(
                "OPENAI and OpenAi say HELLO.",
                configuration: configuration
            ) == "OpenAI and OpenAI say hi."
        )
    }

    @Test func replacementsAreLiteralAndEachOrderedRuleRunsOnce() {
        let literalConfiguration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: [
                TextReplacementRule(search: ".", replacement: "dot"),
                TextReplacementRule(search: "[x]", replacement: "bracket"),
                TextReplacementRule(search: "*", replacement: "star"),
                TextReplacementRule(search: "$", replacement: "dollar"),
            ]
        )
        let orderedConfiguration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: [
                TextReplacementRule(search: "a", replacement: "b"),
                TextReplacementRule(search: "b", replacement: "c"),
                TextReplacementRule(search: "a", replacement: "d"),
            ]
        )

        #expect(
            processor.process(
                "a.b [x] * $",
                configuration: literalConfiguration
            ) == "adotb bracket star dollar"
        )
        #expect(processor.process("a", configuration: orderedConfiguration) == "c")
    }

    @Test func duplicateSearchRulesRemainDistinctAndBothRunInOrder() {
        let configuration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: [
                TextReplacementRule(search: "a", replacement: "aa"),
                TextReplacementRule(search: "a", replacement: "b"),
            ]
        )

        #expect(processor.process("a", configuration: configuration) == "bb")
    }

    @Test func emptyProcessedOutputFallsBackWithoutInventingText() {
        let configuration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: [
                TextReplacementRule(search: "transcript", replacement: "")
            ]
        )

        #expect(
            processor.process(
                "transcript",
                configuration: configuration,
                fallback: "original transcript"
            ) == "original transcript"
        )
        #expect(
            processor.process(
                "transcript",
                configuration: configuration,
                fallback: " \n "
            ) == " \n "
        )
        #expect(
            processor.process(
                "transcript",
                configuration: configuration
            ) == "transcript"
        )
    }

    @Test func disabledFeaturesPreserveInputExceptAcceptedEdgeTrimming() {
        let configuration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: []
        )

        #expect(
            processor.process(
                "  “emoji smile”—text  ",
                configuration: configuration
            ) == "“emoji smile”—text"
        )
    }

    @Test func typographyOnlyHelperDoesNotRunEmojiOrUserRules() {
        #expect(
            TranscriptTextPostProcessor.normalizedInformalTypography(
                from: "  emoji smile…  "
            ) == "emoji smile..."
        )
    }

    @Test func typographyOnlyHelperRetainsNonEmptyInputWhenCleanupWouldEmptyIt() {
        #expect(
            TranscriptTextPostProcessor.normalizedInformalTypography(
                from: "\u{2060}"
            ) == "\u{2060}"
        )
    }
}
