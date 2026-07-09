import Foundation
import HoldTypeDomain
import Testing

struct TranslationConfigurationDomainIOSTests {
    @Test func resolvesPortableTranslationConfigurationOnIOS() throws {
        let configuration = TranslationConfiguration(
            actionPreferenceEnabled: true,
            sourceMode: .sameAsTranscription,
            targetLanguage: .japanese,
            model: "  custom-translation-model  ",
            prompt: "  Translate only.  "
        )
        let transcription = TranscriptionConfiguration(language: .spanish)
        let encodedMode = try JSONEncoder().encode(TranslationSourceMode.override)

        #expect(TranslationConfiguration.defaults.actionPreferenceEnabled)
        #expect(
            TranslationConfiguration.defaults.configurationIssue == .missingTargetLanguage
        )
        #expect(TranslationConfiguration.defaults.isConfigurationReady == false)
        #expect(
            configuration.resolvedSourceLanguageCode(
                transcriptionConfiguration: transcription
            ) == "es"
        )
        #expect(configuration.resolvedTargetLanguageCode == "ja")
        #expect(configuration.isConfigurationReady)
        #expect(configuration.canRunAction)
        #expect(configuration.resolvedModel == "custom-translation-model")
        #expect(configuration.resolvedPrompt == "Translate only.")
        #expect(
            try JSONDecoder().decode(TranslationSourceMode.self, from: encodedMode) == .override
        )
    }
}
