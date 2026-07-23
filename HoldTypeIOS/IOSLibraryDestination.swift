enum IOSLibraryDestination: String, CaseIterable, Hashable {
    case dictionary
    case emojiCommands = "emoji-commands"
    case replacementRules = "replacement-rules"
    case fixes

    var title: String {
        switch self {
        case .dictionary: "Dictionary"
        case .emojiCommands: "Emoji Commands"
        case .replacementRules: "Replacements"
        case .fixes: "Fixes"
        }
    }

    var detail: String {
        switch self {
        case .dictionary: "Names, brands, and terms to recognize"
        case .emojiCommands: "Say a phrase to insert an emoji"
        case .replacementRules: "Automatic cleanup and custom replacements"
        case .fixes: "Reusable actions for selected text and Voice Drafts"
        }
    }

    var systemImage: String {
        switch self {
        case .dictionary: "text.book.closed"
        case .emojiCommands: "face.smiling"
        case .replacementRules: "arrow.left.arrow.right"
        case .fixes: "wand.and.stars"
        }
    }

    var rowAccessibilityIdentifier: String {
        "ios.library.\(rawValue).row"
    }
}
