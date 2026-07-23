import Testing
import UIKit
@testable import HoldTypeIOS

@MainActor
struct IOSLibraryDestinationTests {
    @Test func destinationsHaveStableContentFreePresentation() {
        #expect(
            IOSLibraryDestination.allCases == [
                .dictionary,
                .emojiCommands,
                .replacementRules,
                .fixes,
            ]
        )
        #expect(
            IOSLibraryDestination.allCases.map(\.title) == [
                "Dictionary",
                "Emoji Commands",
                "Replacements",
                "Fixes",
            ]
        )
        #expect(
            IOSLibraryDestination.allCases.map(\.detail) == [
                "Names, brands, and terms to recognize",
                "Say a phrase to insert an emoji",
                "Automatic cleanup and custom replacements",
                "Reusable actions for selected text and Voice Drafts",
            ]
        )
        #expect(
            IOSLibrarySummaryList.introduction
                == "Teach HoldType the words you use and choose how the final "
                    + "text should look. These rules apply automatically to new "
                    + "dictations."
        )
        #expect(
            Set(
                IOSLibraryDestination.allCases.map(
                    \.rowAccessibilityIdentifier
                )
            ).count == 4
        )
        #expect(UIImage(systemName: "wand.and.stars") != nil)
    }
}
