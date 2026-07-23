import Foundation

public enum TextFixActionKind: String, CaseIterable, Equatable, Sendable {
    case translate
    case fix
    case customPrompt
}

/// A stable semantic icon token that each HoldType surface maps to its native symbol.
public enum TextFixIcon: String, CaseIterable, Equatable, Sendable {
    case translate
    case fix
    case improveWriting = "improve-writing"
    case makeShorter = "make-shorter"
    case summarize
    case bulletPoints = "bullet-points"
    case casual
    case markdown
    case formal
    case expand
    case rewrite
    case custom
}

/// A validated runtime Fix. Persistence layers own versioned wire representations.
public struct TextFixAction:
    Equatable,
    Identifiable,
    Sendable,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    public enum ValidationError: Error, Equatable, Sendable {
        case emptyIdentifier
        case identifierTooLarge(maximumUTF8ByteCount: Int)
        case emptyTitle
        case titleTooLong(maximumCharacterCount: Int)
        case invalidBuiltInIdentifier
        case invalidBuiltInTitle
        case invalidBuiltInIcon
        case reservedBuiltInIdentifier
        case missingPrompt
        case unexpectedPrompt
        case emptyPrompt
        case promptTooLarge(maximumUTF8ByteCount: Int)
        case builtInActionCannotBeDisabled
    }

    public static let translateIdentifier = "builtin.translate"
    public static let fixIdentifier = "builtin.fix"
    public static let maximumIdentifierUTF8ByteCount = 128
    public static let maximumTitleCharacterCount = 80
    public static let maximumPromptUTF8ByteCount = 8 * 1024

    public let id: String
    public let kind: TextFixActionKind
    public let title: String
    public let icon: TextFixIcon
    public let prompt: String?
    public let isEnabled: Bool

    public init(
        id: String,
        kind: TextFixActionKind,
        title: String,
        icon: TextFixIcon,
        prompt: String?,
        isEnabled: Bool = true
    ) throws {
        try Self.validateIdentifier(id)
        try Self.validateTitle(title)
        try Self.validatePayload(
            id: id,
            kind: kind,
            title: title,
            icon: icon,
            prompt: prompt,
            isEnabled: isEnabled
        )

        self.init(
            validatedID: id,
            kind: kind,
            title: title,
            icon: icon,
            prompt: prompt,
            isEnabled: isEnabled
        )
    }

    public var description: String {
        "TextFixAction(id: \(id), kind: \(kind.rawValue), prompt: <redacted>)"
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "id": id,
                "kind": kind.rawValue,
                "titleCharacterCount": title.count,
                "icon": icon.rawValue,
                "prompt": "<redacted>",
                "isEnabled": isEnabled,
            ]
        )
    }

    func replacingEnabledState(_ isEnabled: Bool) -> TextFixAction {
        TextFixAction(
            validatedID: id,
            kind: kind,
            title: title,
            icon: icon,
            prompt: prompt,
            isEnabled: isEnabled
        )
    }

    private init(
        validatedID id: String,
        kind: TextFixActionKind,
        title: String,
        icon: TextFixIcon,
        prompt: String?,
        isEnabled: Bool
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.icon = icon
        self.prompt = prompt
        self.isEnabled = isEnabled
    }

    private static func validateIdentifier(_ id: String) throws {
        guard !id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyIdentifier
        }
        guard id.utf8.count <= maximumIdentifierUTF8ByteCount else {
            throw ValidationError.identifierTooLarge(
                maximumUTF8ByteCount: maximumIdentifierUTF8ByteCount
            )
        }
    }

    private static func validateTitle(_ title: String) throws {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyTitle
        }
        guard title.count <= maximumTitleCharacterCount else {
            throw ValidationError.titleTooLong(
                maximumCharacterCount: maximumTitleCharacterCount
            )
        }
    }

    private static func validatePayload(
        id: String,
        kind: TextFixActionKind,
        title: String,
        icon: TextFixIcon,
        prompt: String?,
        isEnabled: Bool
    ) throws {
        switch kind {
        case .translate:
            guard id == translateIdentifier else {
                throw ValidationError.invalidBuiltInIdentifier
            }
            try validateBuiltInPayload(
                title: title,
                expectedTitle: "Translate",
                icon: icon,
                expectedIcon: .translate,
                prompt: prompt,
                isEnabled: isEnabled
            )
        case .fix:
            guard id == fixIdentifier else {
                throw ValidationError.invalidBuiltInIdentifier
            }
            try validateBuiltInPayload(
                title: title,
                expectedTitle: "Fix",
                icon: icon,
                expectedIcon: .fix,
                prompt: prompt,
                isEnabled: isEnabled
            )
        case .customPrompt:
            guard id != translateIdentifier, id != fixIdentifier else {
                throw ValidationError.reservedBuiltInIdentifier
            }
            guard let prompt else {
                throw ValidationError.missingPrompt
            }
            guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ValidationError.emptyPrompt
            }
            guard prompt.utf8.count <= maximumPromptUTF8ByteCount else {
                throw ValidationError.promptTooLarge(
                    maximumUTF8ByteCount: maximumPromptUTF8ByteCount
                )
            }
        }
    }

    private static func validateBuiltInPayload(
        title: String,
        expectedTitle: String,
        icon: TextFixIcon,
        expectedIcon: TextFixIcon,
        prompt: String?,
        isEnabled: Bool
    ) throws {
        guard title == expectedTitle else {
            throw ValidationError.invalidBuiltInTitle
        }
        guard icon == expectedIcon else {
            throw ValidationError.invalidBuiltInIcon
        }
        guard prompt == nil else {
            throw ValidationError.unexpectedPrompt
        }
        guard isEnabled else {
            throw ValidationError.builtInActionCannotBeDisabled
        }
    }

    static let builtInTranslate = TextFixAction(
        validatedID: translateIdentifier,
        kind: .translate,
        title: "Translate",
        icon: .translate,
        prompt: nil,
        isEnabled: true
    )

    static let builtInFix = TextFixAction(
        validatedID: fixIdentifier,
        kind: .fix,
        title: "Fix",
        icon: .fix,
        prompt: nil,
        isEnabled: true
    )

    static func validatedDefaultCustom(
        id: String,
        title: String,
        icon: TextFixIcon,
        prompt: String
    ) -> TextFixAction {
        TextFixAction(
            validatedID: id,
            kind: .customPrompt,
            title: title,
            icon: icon,
            prompt: prompt,
            isEnabled: true
        )
    }
}
