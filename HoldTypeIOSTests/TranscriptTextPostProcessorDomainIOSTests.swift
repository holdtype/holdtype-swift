import HoldTypeDomain
import Testing

struct TranscriptTextPostProcessorDomainIOSTests {
    @Test func packageRunsPortablePostProcessingOnIOS() {
        let configuration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: true,
            emojiCommands: EmojiCommandsConfiguration(enabledBuiltInSetIDs: ["en"]),
            textReplacementRules: [
                TextReplacementRule(search: "🙂", replacement: ":smile:")
            ]
        )

        #expect(
            TranscriptTextPostProcessor().process(
                "“emoji smile”—ready",
                configuration: configuration
            ) == "\":smile:\" - ready"
        )
    }

    @Test func portableCleanupMatchesTheCompleteMacOSTransformationSet() {
        let input =
            "«a» “b” „c‟ ‘d’ ‚e‛ `f´ …\u{00A0}x\u{202F}y\u{2009}z\u{2060}! "
                + "5 – 7\n— bullet\n\n\nDone"

        #expect(
            TranscriptTextPostProcessor.normalizeInformalTypography(input)
                == "\"a\" \"b\" \"c\" 'd' 'e' 'f' ... x y z! 5-7\n- bullet\n\nDone"
        )
    }

    @Test func disablingPortableCleanupPreservesTypography() {
        let input = "  “Hello”—world…  "
        let configuration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false)
        )

        #expect(
            TranscriptTextPostProcessor().process(
                input,
                configuration: configuration
            ) == "“Hello”—world…"
        )
    }
}
