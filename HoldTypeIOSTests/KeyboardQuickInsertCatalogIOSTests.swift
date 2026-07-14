import Testing

struct KeyboardQuickInsertCatalogIOSTests {
    @Test func catalogKeepsTheApprovedPunctuationAndEmojiOrder() {
        #expect(
            KeyboardQuickInsertCatalog.punctuation.map(\.text)
                == [".", ",", "?", "!", ":", ";", "—", "…"]
        )
        #expect(
            KeyboardQuickInsertCatalog.emojiPrimary.map(\.text)
                == ["🙂", "😂", "❤️", "👍", "🙏", "🔥", "✅", "✨"]
        )
        #expect(
            KeyboardQuickInsertCatalog.emojiSecondary.map(\.text)
                == ["😊", "😍", "🤔", "👏", "💯", "🎉", "🚀", "👀"]
        )
        #expect(
            KeyboardQuickInsertCatalog.emoji
                == KeyboardQuickInsertCatalog.emojiPrimary
                    + KeyboardQuickInsertCatalog.emojiSecondary
        )
    }

    @Test func identifiersAreUniqueAcrossEachCatalog() {
        let punctuationIDs = KeyboardQuickInsertCatalog.punctuation.map(\.id)
        let emojiIDs = KeyboardQuickInsertCatalog.emoji.map(\.id)

        #expect(Set(punctuationIDs).count == punctuationIDs.count)
        #expect(Set(emojiIDs).count == emojiIDs.count)
    }
}
