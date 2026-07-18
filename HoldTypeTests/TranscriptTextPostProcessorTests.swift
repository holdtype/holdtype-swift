import HoldTypeDomain
import Testing
@testable import HoldType

struct TranscriptTextPostProcessorTests {
    @Test func appSettingsAdapterMatchesPureDomainConfiguration() {
        var settings = AppSettings.defaults
        settings.localTextCleanupEnabled = true
        settings.enabledEmojiCommandSetIDs = []
        settings.customEmojiCommands = [
            CustomEmojiCommand(emoji: "🚀", command: "emoji rocket")
        ]
        settings.textReplacementRules = [
            TextReplacementRule(search: "🚀", replacement: "launched")
        ]
        let processor = TranscriptTextPostProcessor()

        #expect(
            processor.process("“emoji rocket”—now", settings: settings) ==
                processor.process(
                    "“emoji rocket”—now",
                    configuration: settings.transcriptPostProcessingConfiguration
                )
        )
    }
}
