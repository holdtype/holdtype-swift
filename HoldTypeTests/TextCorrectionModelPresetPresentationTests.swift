import HoldTypeDomain
import Testing
@testable import HoldType

struct TextCorrectionModelPresetPresentationTests {
    @Test func macOSPresentationLabelsRemainStable() {
        #expect(TextCorrectionModelPreset.quality.displayName == "Quality")
        #expect(TextCorrectionModelPreset.quality.detail == "Highest quality correction")
        #expect(TextCorrectionModelPreset.balanced.displayName == "Balanced")
        #expect(TextCorrectionModelPreset.balanced.detail == "Lower cost than Quality")
        #expect(TextCorrectionModelPreset.fast.displayName == "Fast")
        #expect(TextCorrectionModelPreset.fast.detail == "Lower latency and cost")
        #expect(TextCorrectionModelPreset.custom.displayName == "Custom")
        #expect(TextCorrectionModelPreset.custom.detail == "Use a model ID you enter")
    }
}
