import Testing
import HoldTypeDomain

struct TranscriptionPromptContextTests {
    @Test func trimsEdgesAndPreservesInteriorFormatting() throws {
        let context = try #require(
            TranscriptionPromptContext("  First  line.\nSecond line.  \n")
        )

        #expect(context.text == "First  line.\nSecond line.")
    }

    @Test func keepsTheRequestedCharacterSuffix() throws {
        let context = try #require(
            TranscriptionPromptContext("zero 1️⃣2️⃣3️⃣", maximumCharacterCount: 2)
        )

        #expect(context.text == "2️⃣3️⃣")
        #expect(TranscriptionPromptContext.defaultMaximumCharacterCount == 1_000)
    }

    @Test func clampsTheMaximumToOneCharacter() throws {
        let zeroContext = try #require(
            TranscriptionPromptContext("abc", maximumCharacterCount: 0)
        )
        let negativeContext = try #require(
            TranscriptionPromptContext("abc", maximumCharacterCount: -10)
        )

        #expect(zeroContext.text == "c")
        #expect(negativeContext.text == "c")
    }

    @Test func preservesWhitespaceAtTheSuffixBoundary() throws {
        let context = try #require(
            TranscriptionPromptContext("abc def", maximumCharacterCount: 4)
        )

        #expect(context.text == " def")
    }

    @Test func rejectsEmptyNormalizedText() {
        #expect(TranscriptionPromptContext(" \n\t ") == nil)
    }

    @Test func composesTheExactContextPrompt() throws {
        let context = try #require(TranscriptionPromptContext("Existing text."))

        #expect(
            context.promptText ==
                "Current writing context near the cursor. Use this only for continuity; " +
                "transcribe only the new speech:\nExisting text."
        )
    }
}
