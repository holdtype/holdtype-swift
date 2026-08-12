import HoldTypeDomain
import Testing

struct TextFixWritingSkillCompatibilityTests {
    @Test func recognizesOnlyDocumentedModelFamiliesAndSnapshots() {
        for model in [
            "gpt-5.4",
            "gpt-5.4-mini",
            "gpt-5.5",
            "gpt-5.6",
            "gpt-5.6-luna",
            "gpt-5.6-sol",
            "gpt-5.6-terra",
            "gpt-5.6-terra-2026-08-01",
        ] {
            #expect(TextFixWritingSkillCompatibility.supports(model: model))
        }

        for model in [
            "gpt-5",
            "gpt-5.3",
            "gpt-5.60",
            "gpt-5.6-terrestrial",
            "custom-gpt-5.6-terra",
            " gpt-5.6-terra ",
        ] {
            #expect(!TextFixWritingSkillCompatibility.supports(model: model))
        }
    }
}
