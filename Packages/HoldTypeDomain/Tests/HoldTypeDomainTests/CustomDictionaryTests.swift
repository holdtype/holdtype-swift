import Testing
@testable import HoldTypeDomain

struct CustomDictionaryTests {
    @Test func parsesOnlyCommaAndNewlineSeparatedEntries() {
        let entries = CustomDictionary.parseEntries(
            from: " OpenWhispr, Synty\r\nThe  word is HoldType,, OpenWhispr;Alias\nOpenWhispr"
        )

        #expect(
            entries == [
                "OpenWhispr",
                "Synty",
                "The  word is HoldType",
                "OpenWhispr;Alias",
                "OpenWhispr",
            ]
        )
    }

    @Test func normalizesEntriesWithoutChangingFirstSpellingOrOrder() {
        let dictionary = CustomDictionary(
            entries: [" OpenWhispr ", "openwhispr", "", "  Synty\n", "SYNTY"]
        )

        #expect(dictionary.entries == ["OpenWhispr", "Synty"])
        #expect(dictionary.promptText == "OpenWhispr, Synty")
    }

    @Test func caseFoldingDoesNotMakeDiacriticsEquivalent() {
        let dictionary = CustomDictionary(entries: ["Éclair", "éclair", "cafe", "café"])

        #expect(dictionary.entries == ["Éclair", "cafe", "café"])
    }

    @Test func appendsParsedEntriesAndDeduplicatesAgainstExistingEntries() {
        let dictionary = CustomDictionary(entries: ["OpenWhispr"])
            .appendingEntries(from: "openwhispr, Sinead\nHoldType")

        #expect(dictionary.entries == ["OpenWhispr", "Sinead", "HoldType"])
        #expect(CustomDictionary(entries: dictionary.entries) == dictionary)
    }

    @Test func emptyDictionaryHasNoPromptText() {
        #expect(CustomDictionary.empty.entries.isEmpty)
        #expect(CustomDictionary.empty.promptText == nil)
    }
}
