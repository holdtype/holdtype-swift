import Foundation
import Testing
import HoldTypeDomain

struct TextCorrectionConfigurationTests {
    @Test func defaultsMatchTheTextCorrectionContract() {
        let configuration = TextCorrectionConfiguration()

        #expect(configuration == .defaults)
        #expect(configuration.isEnabled == false)
        #expect(configuration.modelPreset == .quality)
        #expect(configuration.customModel.isEmpty)
        #expect(configuration.resolvedModel == "gpt-5.5")
        #expect(configuration.prompt == Self.frozenDefaultPrompt)
        #expect(configuration.resolvedPrompt == Self.frozenDefaultPrompt)
        #expect(configuration.isPromptDefault)
        #expect(TextCorrectionConfiguration.defaultModel == "gpt-5.5")
        #expect(TextCorrectionConfiguration.defaultPrompt == Self.frozenDefaultPrompt)
    }

    @Test func presetsPreserveTheirRawValuesOrderAndModelMapping() {
        #expect(
            TextCorrectionModelPreset.allCases.map(\.rawValue) ==
                ["quality", "balanced", "fast", "custom"]
        )
        #expect(TextCorrectionModelPreset.quality.modelName == "gpt-5.5")
        #expect(TextCorrectionModelPreset.balanced.modelName == "gpt-5.4")
        #expect(TextCorrectionModelPreset.fast.modelName == "gpt-5.4-mini")
        #expect(TextCorrectionModelPreset.custom.modelName == nil)
    }

    @Test func presetCodableRepresentationRemainsTheRawString() throws {
        let encoded = try JSONEncoder().encode(TextCorrectionModelPreset.fast)

        #expect(String(decoding: encoded, as: UTF8.self) == #""fast""#)
        #expect(
            try JSONDecoder().decode(TextCorrectionModelPreset.self, from: encoded) == .fast
        )
    }

    @Test func fixedPresetIgnoresButPreservesTheRawCustomModel() {
        let configuration = TextCorrectionConfiguration(
            isEnabled: false,
            modelPreset: .balanced,
            customModel: "  should-not-be-used  "
        )

        #expect(configuration.customModel == "  should-not-be-used  ")
        #expect(configuration.resolvedModel == "gpt-5.4")
        #expect(configuration.resolvedPrompt == Self.frozenDefaultPrompt)
    }

    @Test func customValuesResolveWithoutMutatingRawInput() {
        let configuration = TextCorrectionConfiguration(
            isEnabled: true,
            modelPreset: .custom,
            customModel: "  custom-correction-model  ",
            prompt: "  Fix  punctuation only.\nKeep this line.  "
        )

        #expect(configuration.isEnabled)
        #expect(configuration.customModel == "  custom-correction-model  ")
        #expect(configuration.resolvedModel == "custom-correction-model")
        #expect(configuration.prompt == "  Fix  punctuation only.\nKeep this line.  ")
        #expect(configuration.resolvedPrompt == "Fix  punctuation only.\nKeep this line.")
        #expect(configuration.isPromptDefault == false)
    }

    @Test func blankCustomValuesFallBackWithoutBecomingRawDefaults() {
        let configuration = TextCorrectionConfiguration(
            modelPreset: .custom,
            customModel: " \n\t ",
            prompt: " \n\t "
        )

        #expect(configuration.customModel == " \n\t ")
        #expect(configuration.resolvedModel == TextCorrectionConfiguration.defaultModel)
        #expect(configuration.prompt == " \n\t ")
        #expect(configuration.resolvedPrompt == TextCorrectionConfiguration.defaultPrompt)
        #expect(configuration.isPromptDefault == false)
    }

    @Test func resetPromptOnlyRestoresTheRawPrompt() {
        var configuration = TextCorrectionConfiguration(
            isEnabled: true,
            modelPreset: .custom,
            customModel: "custom-correction-model",
            prompt: "Correct names only."
        )

        configuration.resetPrompt()

        #expect(configuration.isEnabled)
        #expect(configuration.modelPreset == .custom)
        #expect(configuration.customModel == "custom-correction-model")
        #expect(configuration.prompt == TextCorrectionConfiguration.defaultPrompt)
        #expect(configuration.isPromptDefault)
    }

    private static let frozenDefaultPrompt =
        """
        You are correcting a speech transcript.
        Return only the corrected text.

        Make the smallest possible edits.
        Fix only obvious transcription errors, spacing, capitalization, and punctuation.
        Preserve the original language, wording, order, tone, meaning, and line breaks when possible.
        Do not rewrite for style.
        Do not summarize, expand, translate, add facts, remove facts, or make the text more formal.
        If a change is uncertain, leave the text unchanged.
        """
}
