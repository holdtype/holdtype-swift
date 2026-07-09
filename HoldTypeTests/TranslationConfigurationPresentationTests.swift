import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct TranslationConfigurationPresentationTests {
    @Test func macOSPresentationStringsRemainStable() {
        #expect(TranslationSourceMode.sameAsTranscription.displayName == "Same as Transcription")
        #expect(TranslationSourceMode.override.displayName == "Override source language")
        #expect(
            TranslationConfigurationIssue.invalidSourceLanguage.errorDescription ==
                "Choose a valid source language override in Translation settings."
        )
        #expect(
            TranslationConfigurationIssue.missingTargetLanguage.errorDescription ==
                "Choose a target language in Translation settings."
        )
        #expect(
            TranslationConfigurationIssue.missingTargetLanguage.title ==
                "Translation settings need attention"
        )
    }
}
