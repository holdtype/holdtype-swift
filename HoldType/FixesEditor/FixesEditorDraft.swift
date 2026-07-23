import Foundation
import HoldTypeDomain

struct FixesEditorDraft: Equatable, Identifiable {
    let id: String
    var title: String
    var prompt: String
    var icon: TextFixIcon
    var isEnabled: Bool
    let isNew: Bool

    init(action: TextFixAction) {
        id = action.id
        title = action.title
        prompt = action.prompt ?? ""
        icon = action.icon
        isEnabled = action.isEnabled
        isNew = false
    }

    init(
        id: String,
        title: String = "",
        prompt: String = "",
        icon: TextFixIcon = .custom,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.icon = icon
        self.isEnabled = isEnabled
        isNew = true
    }

    var validation: FixesEditorDraftValidation {
        FixesEditorDraftValidation(title: title, prompt: prompt)
    }

    func makeAction() throws -> TextFixAction {
        try TextFixAction(
            id: id,
            kind: .customPrompt,
            title: title,
            icon: icon,
            prompt: prompt,
            isEnabled: isEnabled
        )
    }

    func differs(from action: TextFixAction?) -> Bool {
        guard let action else {
            return true
        }

        return title != action.title
            || prompt != action.prompt
            || icon != action.icon
            || isEnabled != action.isEnabled
    }
}

struct FixesEditorDraftValidation: Equatable {
    let titleMessage: String?
    let promptMessage: String?

    init(title: String, prompt: String) {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            titleMessage = "Enter a title."
        } else if title.count > TextFixAction.maximumTitleCharacterCount {
            titleMessage =
                "Use \(TextFixAction.maximumTitleCharacterCount) characters or fewer."
        } else {
            titleMessage = nil
        }

        if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptMessage = "Enter a prompt."
        } else if prompt.utf8.count > TextFixAction.maximumPromptUTF8ByteCount {
            promptMessage =
                "Keep the prompt under \(TextFixAction.maximumPromptUTF8ByteCount) UTF-8 bytes."
        } else {
            promptMessage = nil
        }
    }

    var isValid: Bool {
        titleMessage == nil && promptMessage == nil
    }
}
