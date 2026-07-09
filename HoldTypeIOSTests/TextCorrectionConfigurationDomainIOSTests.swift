import Foundation
import HoldTypeDomain
import Testing

struct TextCorrectionConfigurationDomainIOSTests {
    @Test func resolvesPortableTextCorrectionSettingsOnIOS() throws {
        let configuration = TextCorrectionConfiguration(
            isEnabled: true,
            modelPreset: .custom,
            customModel: "  custom-correction-model  ",
            prompt: "  Fix punctuation only.  "
        )
        let blankConfiguration = TextCorrectionConfiguration(
            modelPreset: .custom,
            customModel: " \n ",
            prompt: " \n "
        )
        let encodedPreset = try JSONEncoder().encode(TextCorrectionModelPreset.fast)

        #expect(TextCorrectionModelPreset.allCases.map(\.rawValue) == [
            "quality", "balanced", "fast", "custom",
        ])
        #expect(TextCorrectionConfiguration.defaults.isEnabled == false)
        #expect(TextCorrectionConfiguration.defaults.resolvedModel == "gpt-5.5")
        #expect(configuration.resolvedModel == "custom-correction-model")
        #expect(configuration.resolvedPrompt == "Fix punctuation only.")
        #expect(blankConfiguration.resolvedModel == "gpt-5.5")
        #expect(
            blankConfiguration.resolvedPrompt == TextCorrectionConfiguration.defaultPrompt
        )
        #expect(
            try JSONDecoder().decode(TextCorrectionModelPreset.self, from: encodedPreset) == .fast
        )
    }
}
