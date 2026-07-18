import Foundation
import Testing
import HoldTypeDomain

struct TranscriptionLanguageTests {
    @Test func preservesOrderedPersistenceRawValues() {
        let expectedRawValues = [
            "auto", "english", "spanish", "french", "german", "italian",
            "portuguese", "dutch", "polish", "russian", "ukrainian",
            "turkish", "arabic", "hebrew", "hindi", "chinese", "japanese",
            "korean", "vietnamese", "indonesian", "thai", "swedish",
            "danish", "finnish", "czech", "greek", "romanian", "hungarian",
            "custom",
        ]

        #expect(TranscriptionLanguage.allCases.map(\.rawValue) == expectedRawValues)
        #expect(TranscriptionLanguage(rawValue: "automatic") == nil)
        #expect(TranscriptionLanguage(rawValue: "unknown") == nil)
    }

    @Test func mapsEveryPresetToItsProviderCode() {
        let presetLanguages = Array(TranscriptionLanguage.allCases.dropFirst().dropLast())
        let expectedCodes = [
            "en", "es", "fr", "de", "it", "pt", "nl", "pl", "ru", "uk",
            "tr", "ar", "he", "hi", "zh", "ja", "ko", "vi", "id", "th",
            "sv", "da", "fi", "cs", "el", "ro", "hu",
        ]

        #expect(presetLanguages.map(\.languageCode) == expectedCodes.map(Optional.some))
        #expect(TranscriptionLanguage.automatic.languageCode == nil)
        #expect(TranscriptionLanguage.custom.languageCode == nil)
    }

    @Test func automaticAndPresetsIgnoreTheCustomField() {
        #expect(TranscriptionLanguage.automatic.apiLanguageCode(customCode: "ru") == nil)
        #expect(TranscriptionLanguage.english.apiLanguageCode(customCode: "not-a-code") == "en")
        #expect(
            TranscriptionLanguage.english.customLanguageCodeValidation(
                customCode: "not-a-code"
            ) == .notRequired
        )
    }

    @Test func validatesAndNormalizesCustomCodes() {
        let validCases = [
            (" en ", "en"),
            ("RU", "ru"),
            (" ENG\n", "eng"),
        ]

        for (rawValue, normalizedValue) in validCases {
            let validation = TranscriptionLanguage.custom.customLanguageCodeValidation(
                customCode: rawValue
            )

            #expect(validation == .valid(normalizedCode: normalizedValue))
            #expect(
                TranscriptionLanguage.custom.apiLanguageCode(customCode: rawValue) ==
                    normalizedValue
            )
        }

        #expect(
            TranscriptionLanguage.custom.customLanguageCodeValidation(customCode: " \n") ==
                .emptyFallsBackToAutomatic
        )

        for rawValue in ["e", "engl", "e1", "en-US", "e n", "рус", "éñ"] {
            #expect(
                TranscriptionLanguage.custom.customLanguageCodeValidation(
                    customCode: rawValue
                ) == .invalid
            )
            #expect(TranscriptionLanguage.custom.apiLanguageCode(customCode: rawValue) == nil)
        }
    }

    @Test func exposesValidationAccessors() {
        #expect(CustomLanguageCodeValidation.notRequired.isInvalid == false)
        #expect(CustomLanguageCodeValidation.emptyFallsBackToAutomatic.isInvalid == false)
        #expect(CustomLanguageCodeValidation.invalid.isInvalid)
        #expect(
            CustomLanguageCodeValidation.valid(normalizedCode: "en").resolvedLanguageCode ==
                "en"
        )
        #expect(CustomLanguageCodeValidation.invalid.resolvedLanguageCode == nil)
    }

    @Test func codableRoundTripsEveryRawValue() throws {
        for language in TranscriptionLanguage.allCases {
            let data = try JSONEncoder().encode(language)
            let decoded = try JSONDecoder().decode(TranscriptionLanguage.self, from: data)

            #expect(decoded == language)
        }
    }
}
