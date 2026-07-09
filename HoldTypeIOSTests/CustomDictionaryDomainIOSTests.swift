import HoldTypeDomain
import Testing

struct CustomDictionaryDomainIOSTests {
    @Test func packageNormalizesCustomDictionaryOnIOS() {
        let dictionary = CustomDictionary(entries: [" HoldType ", "holdtype", "Synty"])
            .appendingEntries(from: "OpenWhispr\nsynty")

        #expect(dictionary.entries == ["HoldType", "Synty", "OpenWhispr"])
        #expect(dictionary.promptText == "HoldType, Synty, OpenWhispr")
    }
}
