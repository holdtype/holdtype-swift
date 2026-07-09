import HoldTypeDomain
import Testing

struct TranscriptionLanguageDomainIOSTests {
    @Test func packagePreservesProviderCodesIndependentlyOfTypingLayout() {
        #expect(TranscriptionLanguage(rawValue: "auto") == .automatic)
        #expect(TranscriptionLanguage.chinese.apiLanguageCode(customCode: "") == "zh")
        #expect(TranscriptionLanguage.custom.apiLanguageCode(customCode: " ENG ") == "eng")
        #expect(TranscriptionLanguage.custom.apiLanguageCode(customCode: "en-US") == nil)
    }
}
