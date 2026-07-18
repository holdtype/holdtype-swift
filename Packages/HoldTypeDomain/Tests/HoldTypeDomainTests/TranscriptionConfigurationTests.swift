import Testing
import HoldTypeDomain

struct TranscriptionConfigurationTests {
    @Test func defaultsMatchTheTranscriptionContract() {
        let configuration = TranscriptionConfiguration()

        #expect(configuration == .defaults)
        #expect(configuration.model == "gpt-4o-transcribe")
        #expect(configuration.resolvedModel == "gpt-4o-transcribe")
        #expect(configuration.language == .automatic)
        #expect(configuration.customLanguageCode.isEmpty)
        #expect(configuration.resolvedLanguageCode == nil)
        #expect(configuration.customLanguageCodeValidation == .notRequired)
        #expect(configuration.freeformPrompt.isEmpty)
        #expect(configuration.resolvedFreeformPrompt == nil)
    }

    @Test func resolvesValuesWithoutMutatingRawInput() {
        let configuration = TranscriptionConfiguration(
            model: "  custom-transcribe  ",
            language: .custom,
            customLanguageCode: " RU ",
            freeformPrompt: "  Preserve  internal spacing.\nSecond line.  "
        )

        #expect(configuration.model == "  custom-transcribe  ")
        #expect(configuration.resolvedModel == "custom-transcribe")
        #expect(configuration.customLanguageCode == " RU ")
        #expect(configuration.resolvedLanguageCode == "ru")
        #expect(
            configuration.customLanguageCodeValidation == .valid(normalizedCode: "ru")
        )
        #expect(configuration.freeformPrompt == "  Preserve  internal spacing.\nSecond line.  ")
        #expect(
            configuration.resolvedFreeformPrompt ==
                "Preserve  internal spacing.\nSecond line."
        )
    }

    @Test func blankModelFallsBackAndBlankPromptIsOmitted() {
        let configuration = TranscriptionConfiguration(
            model: " \n\t ",
            freeformPrompt: " \n\t "
        )

        #expect(configuration.resolvedModel == TranscriptionConfiguration.defaultModel)
        #expect(configuration.resolvedFreeformPrompt == nil)
    }

    @Test func invalidCustomLanguageRemainsAnExplicitValidationFailure() {
        let configuration = TranscriptionConfiguration(
            language: .custom,
            customLanguageCode: "en-US"
        )

        #expect(configuration.customLanguageCodeValidation == .invalid)
        #expect(configuration.resolvedLanguageCode == nil)
    }
}
