import HoldTypeDomain
import Testing
@testable import HoldType

struct TranscriptionLanguagePresentationTests {
    @Test func preservesMacOSPickerOrderAndLabels() {
        let expectedNames = [
            "Auto", "English", "Spanish", "French", "German", "Italian",
            "Portuguese", "Dutch", "Polish", "Russian", "Ukrainian",
            "Turkish", "Arabic", "Hebrew", "Hindi", "Chinese", "Japanese",
            "Korean", "Vietnamese", "Indonesian", "Thai", "Swedish",
            "Danish", "Finnish", "Czech", "Greek", "Romanian", "Hungarian",
            "Custom",
        ]
        let expectedDisplayNames = [
            "Auto", "English (en)", "Spanish (es)", "French (fr)",
            "German (de)", "Italian (it)", "Portuguese (pt)", "Dutch (nl)",
            "Polish (pl)", "Russian (ru)", "Ukrainian (uk)", "Turkish (tr)",
            "Arabic (ar)", "Hebrew (he)", "Hindi (hi)", "Chinese (zh)",
            "Japanese (ja)", "Korean (ko)", "Vietnamese (vi)",
            "Indonesian (id)", "Thai (th)", "Swedish (sv)", "Danish (da)",
            "Finnish (fi)", "Czech (cs)", "Greek (el)", "Romanian (ro)",
            "Hungarian (hu)", "Custom",
        ]

        #expect(TranscriptionLanguage.allCases.map(\.languageName) == expectedNames)
        #expect(TranscriptionLanguage.allCases.map(\.displayName) == expectedDisplayNames)
        #expect(
            TranscriptionLanguage.translationCases ==
                Array(TranscriptionLanguage.allCases.dropFirst())
        )
    }
}
