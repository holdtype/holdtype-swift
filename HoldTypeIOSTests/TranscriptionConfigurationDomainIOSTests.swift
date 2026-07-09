import HoldTypeDomain
import Testing

struct TranscriptionConfigurationDomainIOSTests {
    @Test func packageResolvesPortableTranscriptionSettingsOnIOS() {
        let configuration = TranscriptionConfiguration(
            model: "  gpt-4o-mini-transcribe ",
            language: .custom,
            customLanguageCode: " UK ",
            freeformPrompt: "  Prefer HoldType.  "
        )

        #expect(TranscriptionConfiguration.defaults == TranscriptionConfiguration())
        #expect(configuration.resolvedModel == "gpt-4o-mini-transcribe")
        #expect(configuration.resolvedLanguageCode == "uk")
        #expect(configuration.resolvedFreeformPrompt == "Prefer HoldType.")
    }
}
