import Foundation

struct KeyboardQuickInsertItem: Equatable, Sendable {
    let id: String
    let text: String
    let accessibilityLabel: String
}

enum KeyboardQuickInsertCatalog {
    static let punctuation: [KeyboardQuickInsertItem] = [
        KeyboardQuickInsertItem(
            id: "period",
            text: ".",
            accessibilityLabel: "Period"
        ),
        KeyboardQuickInsertItem(
            id: "comma",
            text: ",",
            accessibilityLabel: "Comma"
        ),
        KeyboardQuickInsertItem(
            id: "question-mark",
            text: "?",
            accessibilityLabel: "Question mark"
        ),
        KeyboardQuickInsertItem(
            id: "exclamation-mark",
            text: "!",
            accessibilityLabel: "Exclamation mark"
        ),
        KeyboardQuickInsertItem(
            id: "colon",
            text: ":",
            accessibilityLabel: "Colon"
        ),
        KeyboardQuickInsertItem(
            id: "semicolon",
            text: ";",
            accessibilityLabel: "Semicolon"
        ),
        KeyboardQuickInsertItem(
            id: "em-dash",
            text: "—",
            accessibilityLabel: "Em dash"
        ),
        KeyboardQuickInsertItem(
            id: "ellipsis",
            text: "…",
            accessibilityLabel: "Ellipsis"
        ),
    ]

    static let emojiPrimary: [KeyboardQuickInsertItem] = [
        KeyboardQuickInsertItem(
            id: "smile",
            text: "🙂",
            accessibilityLabel: "Smile"
        ),
        KeyboardQuickInsertItem(
            id: "laugh",
            text: "😂",
            accessibilityLabel: "Laugh"
        ),
        KeyboardQuickInsertItem(
            id: "heart",
            text: "❤️",
            accessibilityLabel: "Heart"
        ),
        KeyboardQuickInsertItem(
            id: "thumbs-up",
            text: "👍",
            accessibilityLabel: "Thumbs up"
        ),
        KeyboardQuickInsertItem(
            id: "folded-hands",
            text: "🙏",
            accessibilityLabel: "Folded hands"
        ),
        KeyboardQuickInsertItem(
            id: "fire",
            text: "🔥",
            accessibilityLabel: "Fire"
        ),
        KeyboardQuickInsertItem(
            id: "check-mark",
            text: "✅",
            accessibilityLabel: "Check mark"
        ),
        KeyboardQuickInsertItem(
            id: "sparkles",
            text: "✨",
            accessibilityLabel: "Sparkles"
        ),
    ]

    static let emojiSecondary: [KeyboardQuickInsertItem] = [
        KeyboardQuickInsertItem(
            id: "smiling-eyes",
            text: "😊",
            accessibilityLabel: "Smiling face with smiling eyes"
        ),
        KeyboardQuickInsertItem(
            id: "heart-eyes",
            text: "😍",
            accessibilityLabel: "Heart eyes"
        ),
        KeyboardQuickInsertItem(
            id: "thinking",
            text: "🤔",
            accessibilityLabel: "Thinking face"
        ),
        KeyboardQuickInsertItem(
            id: "clapping-hands",
            text: "👏",
            accessibilityLabel: "Clapping hands"
        ),
        KeyboardQuickInsertItem(
            id: "hundred-points",
            text: "💯",
            accessibilityLabel: "Hundred points"
        ),
        KeyboardQuickInsertItem(
            id: "party-popper",
            text: "🎉",
            accessibilityLabel: "Party popper"
        ),
        KeyboardQuickInsertItem(
            id: "rocket",
            text: "🚀",
            accessibilityLabel: "Rocket"
        ),
        KeyboardQuickInsertItem(
            id: "eyes",
            text: "👀",
            accessibilityLabel: "Eyes"
        ),
    ]

    static let emoji = emojiPrimary + emojiSecondary
}

