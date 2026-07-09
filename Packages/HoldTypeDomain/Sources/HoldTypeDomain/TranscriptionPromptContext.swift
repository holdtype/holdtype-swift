import Foundation

public struct TranscriptionPromptContext: Equatable, Sendable {
    public static let defaultMaximumCharacterCount = 1_000
    private static let promptPrefix =
        "Current writing context near the cursor. Use this only for continuity; " +
        "transcribe only the new speech:"

    public let text: String

    public init?(
        _ text: String,
        maximumCharacterCount: Int = Self.defaultMaximumCharacterCount
    ) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return nil
        }

        self.text = String(trimmedText.suffix(max(1, maximumCharacterCount)))
    }

    public var promptText: String {
        """
        \(Self.promptPrefix)
        \(text)
        """
    }
}
