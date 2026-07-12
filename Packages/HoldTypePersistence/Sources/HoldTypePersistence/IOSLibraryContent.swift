import HoldTypeDomain

/// User-managed Library content owned by the iOS containing app.
public struct IOSLibraryContent: Equatable, Sendable {
    public static let defaults = IOSLibraryContent()

    public var customDictionary: CustomDictionary
    public var emojiCommandsConfiguration: EmojiCommandsConfiguration
    public var replacementRules: [TextReplacementRule]

    public init(
        customDictionary: CustomDictionary = .empty,
        emojiCommandsConfiguration: EmojiCommandsConfiguration = .defaults,
        replacementRules: [TextReplacementRule] = []
    ) {
        self.customDictionary = customDictionary
        self.emojiCommandsConfiguration = emojiCommandsConfiguration
        self.replacementRules = replacementRules
    }
}

extension IOSLibraryContent: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String { "IOSLibraryContent(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { Mirror(self, children: [:]) }
}
