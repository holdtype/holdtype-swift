public struct TextFixCatalog:
    Equatable,
    Sendable,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    public enum ValidationError: Error, Equatable, Sendable {
        case tooManyActions(maximumCount: Int)
        case translateMustBeFirst
        case fixMustBeSecond
        case duplicateIdentifier(String)
        case typedActionOutsidePinnedPositions(String)
    }

    public enum MutationError: Error, Equatable, Sendable {
        case builtInActionCannotBeModified
        case customActionNotFound(String)
        case actionMustBeCustom
        case destinationIndexOutOfBounds
        case tooManyActions(maximumCount: Int)
    }

    public static let maximumActionCount = 100

    public let actions: [TextFixAction]

    public init(actions: [TextFixAction]) throws {
        guard actions.count <= Self.maximumActionCount else {
            throw ValidationError.tooManyActions(maximumCount: Self.maximumActionCount)
        }
        guard actions.first?.id == TextFixAction.translateIdentifier,
              actions.first?.kind == .translate
        else {
            throw ValidationError.translateMustBeFirst
        }
        guard actions.dropFirst().first?.id == TextFixAction.fixIdentifier,
              actions.dropFirst().first?.kind == .fix
        else {
            throw ValidationError.fixMustBeSecond
        }

        for action in actions.dropFirst(2) where action.kind != .customPrompt {
            throw ValidationError.typedActionOutsidePinnedPositions(action.id)
        }
        var identifiers = Set<String>()
        for action in actions {
            guard identifiers.insert(action.id).inserted else {
                throw ValidationError.duplicateIdentifier(action.id)
            }
        }

        self.actions = actions
    }

    public static let defaults = TextFixCatalog(validatedActions: [
        TextFixAction.builtInTranslate,
        TextFixAction.builtInFix,
    ] + defaultCustomActions)

    public var customActions: [TextFixAction] {
        Array(actions.dropFirst(2))
    }

    public var enabledActions: [TextFixAction] {
        actions.filter(\.isEnabled)
    }

    public func action(id: String) -> TextFixAction? {
        actions.first { $0.id == id }
    }

    public func addingCustomAction(_ action: TextFixAction) throws -> TextFixCatalog {
        guard action.kind == .customPrompt else {
            throw MutationError.actionMustBeCustom
        }
        guard actions.count < Self.maximumActionCount else {
            throw MutationError.tooManyActions(maximumCount: Self.maximumActionCount)
        }

        return try TextFixCatalog(actions: actions + [action])
    }

    public func replacingCustomAction(_ action: TextFixAction) throws -> TextFixCatalog {
        try requireMutableIdentifier(action.id)
        guard action.kind == .customPrompt else {
            throw MutationError.actionMustBeCustom
        }
        guard let index = actions.firstIndex(where: { $0.id == action.id }) else {
            throw MutationError.customActionNotFound(action.id)
        }

        var updatedActions = actions
        updatedActions[index] = action
        return try TextFixCatalog(actions: updatedActions)
    }

    public func settingCustomActionEnabled(
        id: String,
        isEnabled: Bool
    ) throws -> TextFixCatalog {
        try requireMutableIdentifier(id)
        guard let index = actions.firstIndex(where: { $0.id == id }) else {
            throw MutationError.customActionNotFound(id)
        }

        var updatedActions = actions
        updatedActions[index] = updatedActions[index].replacingEnabledState(isEnabled)
        return try TextFixCatalog(actions: updatedActions)
    }

    public func deletingCustomAction(id: String) throws -> TextFixCatalog {
        try requireMutableIdentifier(id)
        guard let index = actions.firstIndex(where: { $0.id == id }) else {
            throw MutationError.customActionNotFound(id)
        }

        var updatedActions = actions
        updatedActions.remove(at: index)
        return try TextFixCatalog(actions: updatedActions)
    }

    /// Moves a custom action to a zero-based final index within `customActions`.
    public func movingCustomAction(
        id: String,
        toCustomIndex destinationIndex: Int
    ) throws -> TextFixCatalog {
        try requireMutableIdentifier(id)
        let customActionCount = customActions.count
        guard (0..<customActionCount).contains(destinationIndex) else {
            throw MutationError.destinationIndexOutOfBounds
        }
        guard let sourceIndex = actions.firstIndex(where: { $0.id == id }) else {
            throw MutationError.customActionNotFound(id)
        }

        var updatedActions = actions
        let action = updatedActions.remove(at: sourceIndex)
        updatedActions.insert(action, at: destinationIndex + 2)
        return try TextFixCatalog(actions: updatedActions)
    }

    /// Appends any missing default custom Fixes without changing existing actions.
    public func restoringDefaults() throws -> TextFixCatalog {
        let existingIdentifiers = Set(actions.map(\.id))
        let missingDefaults = Self.defaultCustomActions.filter {
            !existingIdentifiers.contains($0.id)
        }
        guard actions.count + missingDefaults.count <= Self.maximumActionCount else {
            throw MutationError.tooManyActions(maximumCount: Self.maximumActionCount)
        }

        return try TextFixCatalog(actions: actions + missingDefaults)
    }

    public var description: String {
        "TextFixCatalog(actionCount: \(actions.count), prompts: <redacted>)"
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "actionCount": actions.count,
                "actionIdentifiers": actions.map(\.id),
                "prompts": "<redacted>",
            ]
        )
    }

    private init(validatedActions actions: [TextFixAction]) {
        self.actions = actions
    }

    private func requireMutableIdentifier(_ id: String) throws {
        guard id != TextFixAction.translateIdentifier,
              id != TextFixAction.fixIdentifier
        else {
            throw MutationError.builtInActionCannotBeModified
        }
    }

    private static let defaultCustomActions = [
        TextFixAction.validatedDefaultCustom(
            id: "default.improve-writing",
            title: "Improve Writing",
            icon: .improveWriting,
            prompt: """
            Improve the writing while preserving its meaning, language, and important details. \
            Return only the rewritten text.
            """
        ),
        TextFixAction.validatedDefaultCustom(
            id: "default.make-shorter",
            title: "Make Shorter",
            icon: .makeShorter,
            prompt: """
            Make the text shorter while preserving its core meaning and language. \
            Return only the shortened text.
            """
        ),
        TextFixAction.validatedDefaultCustom(
            id: "default.summarize",
            title: "Summarize",
            icon: .summarize,
            prompt: """
            Summarize the text concisely in the same language. Return only the summary.
            """
        ),
        TextFixAction.validatedDefaultCustom(
            id: "default.bullet-points",
            title: "Bullet Points",
            icon: .bulletPoints,
            prompt: """
            Convert the text into clear bullet points in the same language. \
            Return only the bullet-point list.
            """
        ),
        TextFixAction.validatedDefaultCustom(
            id: "default.change-to-casual",
            title: "Change to Casual",
            icon: .casual,
            prompt: """
            Rewrite the text in a casual, natural tone while preserving its meaning and language. \
            Return only the rewritten text.
            """
        ),
        TextFixAction.validatedDefaultCustom(
            id: "default.markdown",
            title: "Markdown",
            icon: .markdown,
            prompt: """
            Convert the text to clean Markdown while preserving its meaning, language, and all \
            important details. Return only the Markdown.
            """
        ),
    ]
}
