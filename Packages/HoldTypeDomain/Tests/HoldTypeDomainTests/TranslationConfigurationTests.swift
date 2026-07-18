import Foundation
import Testing
import HoldTypeDomain

struct TranslationConfigurationTests {
    @Test func defaultsMatchTheTranslationContract() {
        let configuration = TranslationConfiguration()

        #expect(configuration == .defaults)
        #expect(configuration.actionPreferenceEnabled)
        #expect(configuration.sourceMode == .sameAsTranscription)
        #expect(configuration.sourceLanguage == .automatic)
        #expect(configuration.customSourceLanguageCode.isEmpty)
        #expect(configuration.targetLanguage == .automatic)
        #expect(configuration.customTargetLanguageCode.isEmpty)
        #expect(configuration.model == "gpt-5.4-mini")
        #expect(configuration.resolvedModel == "gpt-5.4-mini")
        #expect(configuration.prompt == Self.frozenDefaultPrompt)
        #expect(configuration.resolvedPrompt == Self.frozenDefaultPrompt)
        #expect(configuration.isPromptDefault)
        #expect(configuration.isSourceConfigurationValid)
        #expect(configuration.routeConfigurationIssue == .missingTargetLanguage)
        #expect(configuration.configurationIssue == .missingTargetLanguage)
        #expect(configuration.isConfigurationReady == false)
        #expect(configuration.canRunAction == false)
        #expect(TranslationConfiguration.defaultModel == "gpt-5.4-mini")
        #expect(TranslationConfiguration.defaultPrompt == Self.frozenDefaultPrompt)
    }

    @Test func sourceModePreservesItsRawValuesOrderAndCodableRepresentation() throws {
        #expect(
            TranslationSourceMode.allCases.map(\.rawValue) ==
                ["sameAsTranscription", "override"]
        )

        let encoded = try JSONEncoder().encode(TranslationSourceMode.override)

        #expect(String(decoding: encoded, as: UTF8.self) == #""override""#)
        #expect(
            try JSONDecoder().decode(TranslationSourceMode.self, from: encoded) == .override
        )
    }

    @Test func sameAsTranscriptionUsesThePortableTranscriptionLanguageResolution() {
        let configuration = TranslationConfiguration(targetLanguage: .english)

        #expect(
            configuration.resolvedSourceLanguageCode(
                transcriptionConfiguration: TranscriptionConfiguration(language: .automatic)
            ) == nil
        )
        #expect(
            configuration.resolvedSourceLanguageCode(
                transcriptionConfiguration: TranscriptionConfiguration(language: .spanish)
            ) == "es"
        )
        #expect(
            configuration.resolvedSourceLanguageCode(
                transcriptionConfiguration: TranscriptionConfiguration(
                    language: .custom,
                    customLanguageCode: " UK "
                )
            ) == "uk"
        )
        #expect(
            configuration.resolvedSourceLanguageCode(
                transcriptionConfiguration: TranscriptionConfiguration(
                    language: .custom,
                    customLanguageCode: "en-US"
                )
            ) == nil
        )
        #expect(configuration.isSourceConfigurationValid)
        #expect(configuration.isConfigurationReady)
        #expect(configuration.canRunAction)
    }

    @Test func overrideAndTargetLanguagesResolveWithoutMutatingRawCodes() {
        let configuration = TranslationConfiguration(
            sourceMode: .override,
            sourceLanguage: .custom,
            customSourceLanguageCode: "  ES  ",
            targetLanguage: .custom,
            customTargetLanguageCode: "  ENG  "
        )

        #expect(configuration.customSourceLanguageCode == "  ES  ")
        #expect(configuration.customTargetLanguageCode == "  ENG  ")
        #expect(
            configuration.resolvedSourceLanguageCode(
                transcriptionConfiguration: .defaults
            ) == "es"
        )
        #expect(configuration.resolvedTargetLanguageCode == "eng")
        #expect(configuration.isSourceConfigurationValid)
        #expect(configuration.routeConfigurationIssue == nil)
        #expect(configuration.configurationIssue == nil)
        #expect(configuration.isConfigurationReady)
        #expect(configuration.canRunAction)
    }

    @Test func invalidSourceTakesPriorityOverMissingTarget() {
        let configuration = TranslationConfiguration(
            sourceMode: .override,
            sourceLanguage: .custom,
            customSourceLanguageCode: "es-MX",
            targetLanguage: .automatic
        )

        #expect(configuration.isSourceConfigurationValid == false)
        #expect(configuration.resolvedTargetLanguageCode == nil)
        #expect(configuration.routeConfigurationIssue == .invalidSourceLanguage)
        #expect(configuration.configurationIssue == .invalidSourceLanguage)
        #expect(configuration.isConfigurationReady == false)
        #expect(configuration.canRunAction == false)
    }

    @Test func automaticOrBlankOverrideIsInvalidAndInvalidTargetIsMissing() {
        let automaticSource = TranslationConfiguration(
            sourceMode: .override,
            sourceLanguage: .automatic,
            targetLanguage: .english
        )
        let blankCustomSource = TranslationConfiguration(
            sourceMode: .override,
            sourceLanguage: .custom,
            customSourceLanguageCode: " \n ",
            targetLanguage: .english
        )
        let invalidTarget = TranslationConfiguration(
            sourceMode: .override,
            sourceLanguage: .spanish,
            targetLanguage: .custom,
            customTargetLanguageCode: "en-US"
        )

        #expect(automaticSource.routeConfigurationIssue == .invalidSourceLanguage)
        #expect(blankCustomSource.routeConfigurationIssue == .invalidSourceLanguage)
        #expect(invalidTarget.routeConfigurationIssue == .missingTargetLanguage)
    }

    @Test func disabledPreferenceSuppressesTheActiveIssueButNotRouteReadiness() {
        let invalid = TranslationConfiguration(
            actionPreferenceEnabled: false,
            sourceMode: .override,
            sourceLanguage: .automatic,
            targetLanguage: .automatic
        )
        let ready = TranslationConfiguration(
            actionPreferenceEnabled: false,
            targetLanguage: .japanese
        )

        #expect(invalid.routeConfigurationIssue == .invalidSourceLanguage)
        #expect(invalid.configurationIssue == nil)
        #expect(invalid.isConfigurationReady == false)
        #expect(invalid.canRunAction == false)
        #expect(ready.routeConfigurationIssue == nil)
        #expect(ready.configurationIssue == nil)
        #expect(ready.isConfigurationReady)
        #expect(ready.canRunAction == false)
    }

    @Test func modelAndPromptResolveWithoutMutatingRawInput() {
        let configuration = TranslationConfiguration(
            actionPreferenceEnabled: false,
            targetLanguage: .english,
            model: "  custom-translation-model  ",
            prompt: "  Translate  product labels.\nKeep this line.  "
        )

        #expect(configuration.model == "  custom-translation-model  ")
        #expect(configuration.resolvedModel == "custom-translation-model")
        #expect(configuration.prompt == "  Translate  product labels.\nKeep this line.  ")
        #expect(configuration.resolvedPrompt == "Translate  product labels.\nKeep this line.")
        #expect(configuration.isPromptDefault == false)
    }

    @Test func blankModelAndPromptFallBackWithoutBecomingRawDefaults() {
        let configuration = TranslationConfiguration(
            model: " \n\t ",
            prompt: " \n\t "
        )

        #expect(configuration.model == " \n\t ")
        #expect(configuration.resolvedModel == TranslationConfiguration.defaultModel)
        #expect(configuration.prompt == " \n\t ")
        #expect(configuration.resolvedPrompt == TranslationConfiguration.defaultPrompt)
        #expect(configuration.isPromptDefault == false)
    }

    @Test func resetPromptOnlyRestoresTheRawPrompt() {
        var configuration = TranslationConfiguration(
            actionPreferenceEnabled: false,
            sourceMode: .override,
            sourceLanguage: .spanish,
            targetLanguage: .english,
            model: "custom-model",
            prompt: "Translate names only."
        )

        configuration.resetPrompt()

        #expect(configuration.actionPreferenceEnabled == false)
        #expect(configuration.sourceMode == .override)
        #expect(configuration.sourceLanguage == .spanish)
        #expect(configuration.targetLanguage == .english)
        #expect(configuration.model == "custom-model")
        #expect(configuration.prompt == TranslationConfiguration.defaultPrompt)
        #expect(configuration.isPromptDefault)
    }

    private static let frozenDefaultPrompt =
        """
        Translate the user's dictation transcript into the target language.
        Return only the translated text.

        Preserve meaning, names, numbers, paragraph breaks, and list structure when practical.
        Do not add explanations, markdown, alternatives, diagnostics, or source text.
        """
}
