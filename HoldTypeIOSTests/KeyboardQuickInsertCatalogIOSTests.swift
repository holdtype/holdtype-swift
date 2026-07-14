import Testing

struct KeyboardQuickInsertCatalogIOSTests {
    @Test func catalogKeepsTheApprovedPunctuationAndEmojiOrder() {
        #expect(
            KeyboardQuickInsertCatalog.punctuation.map(\.text)
                == [".", ",", "?", "!", ":", ";", "—", "…"]
        )
        #expect(
            KeyboardQuickInsertCatalog.emoji.map(\.text)
                == ["🙂", "😂", "❤️", "👍", "🙏", "🔥", "✅", "✨"]
        )
    }

    @Test func identifiersAreUniqueAcrossEachCatalog() {
        let punctuationIDs = KeyboardQuickInsertCatalog.punctuation.map(\.id)
        let emojiIDs = KeyboardQuickInsertCatalog.emoji.map(\.id)

        #expect(Set(punctuationIDs).count == punctuationIDs.count)
        #expect(Set(emojiIDs).count == emojiIDs.count)
    }
}
