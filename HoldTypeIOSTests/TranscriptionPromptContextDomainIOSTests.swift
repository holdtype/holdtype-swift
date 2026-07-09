import HoldTypeDomain
import Testing

struct TranscriptionPromptContextDomainIOSTests {
    @Test func packageBoundsContextByCharactersOnIOS() throws {
        let context = try #require(
            TranscriptionPromptContext("  zero 1️⃣2️⃣3️⃣  ", maximumCharacterCount: 2)
        )

        #expect(context.text == "2️⃣3️⃣")
        #expect(context.promptText.hasSuffix("new speech:\n2️⃣3️⃣"))
    }

    @Test func packageRejectsEmptyContextOnIOS() {
        #expect(TranscriptionPromptContext(" \n\t ") == nil)
    }
}
