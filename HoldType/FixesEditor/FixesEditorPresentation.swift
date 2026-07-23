import Foundation
import HoldTypeDomain

struct FixesEditorActionPresentation: Equatable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let systemImageName: String
    let isBuiltIn: Bool
    let isEnabled: Bool
    let isPending: Bool

    init(action: TextFixAction) {
        id = action.id
        title = action.title
        subtitle = action.kind.isBuiltIn
            ? "Built-in"
            : Self.promptPreview(action.prompt ?? "")
        systemImageName = action.icon.fixesEditorSystemImageName
        isBuiltIn = action.kind.isBuiltIn
        isEnabled = action.isEnabled
        isPending = false
    }

    init(draft: FixesEditorDraft) {
        id = draft.id
        title = draft.title.isEmpty ? "New Fix" : draft.title
        subtitle = draft.isNew ? "Not saved" : Self.promptPreview(draft.prompt)
        systemImageName = draft.icon.fixesEditorSystemImageName
        isBuiltIn = false
        isEnabled = draft.isEnabled
        isPending = draft.isNew
    }

    private static func promptPreview(_ prompt: String) -> String {
        let compact = prompt
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return compact.isEmpty ? "Custom prompt" : compact
    }
}

struct FixesEditorIconOption: Equatable, Identifiable {
    let icon: TextFixIcon
    let title: String
    let systemImageName: String

    var id: TextFixIcon { icon }

    static let all = TextFixIcon.allCases.map { icon in
        FixesEditorIconOption(
            icon: icon,
            title: icon.fixesEditorTitle,
            systemImageName: icon.fixesEditorSystemImageName
        )
    }
}

struct FixesEditorBuiltInPresentation: Equatable {
    let title: String
    let detail: String
    let systemImageName: String

    init?(action: TextFixAction) {
        switch action.kind {
        case .translate:
            title = "Translate"
            detail =
                "Uses your saved Translation route and model. Edit those values in Settings."
        case .fix:
            title = "Fix"
            detail =
                "Uses your saved Writing & Correction model and prompt without changing automatic correction."
        case .customPrompt:
            return nil
        }
        systemImageName = action.icon.fixesEditorSystemImageName
    }
}

extension TextFixActionKind {
    var isBuiltIn: Bool {
        self != .customPrompt
    }
}

extension TextFixIcon {
    var fixesEditorSystemImageName: String {
        switch self {
        case .translate:
            return "character.bubble"
        case .fix:
            return "checkmark.seal"
        case .improveWriting:
            return "wand.and.stars"
        case .makeShorter:
            return "text.alignleft"
        case .summarize:
            return "doc.text"
        case .bulletPoints:
            return "list.bullet"
        case .casual:
            return "face.smiling"
        case .markdown:
            return "chevron.left.forwardslash.chevron.right"
        case .formal:
            return "briefcase"
        case .expand:
            return "arrow.up.left.and.arrow.down.right"
        case .rewrite:
            return "arrow.triangle.2.circlepath"
        case .custom:
            return "sparkles"
        }
    }

    var fixesEditorTitle: String {
        switch self {
        case .translate:
            return "Translate"
        case .fix:
            return "Fix"
        case .improveWriting:
            return "Improve Writing"
        case .makeShorter:
            return "Make Shorter"
        case .summarize:
            return "Summarize"
        case .bulletPoints:
            return "Bullet Points"
        case .casual:
            return "Casual"
        case .markdown:
            return "Markdown"
        case .formal:
            return "Formal"
        case .expand:
            return "Expand"
        case .rewrite:
            return "Rewrite"
        case .custom:
            return "Custom"
        }
    }
}
