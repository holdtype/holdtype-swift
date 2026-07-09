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
}
