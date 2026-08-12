import Foundation
import HoldTypeDomain

struct FixesEditorDraft:
    Equatable,
    Identifiable,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    let id: String
    var title: String
    var prompt: String
    var icon: TextFixIcon
    var processingPreset: TextFixProcessingProfile.Preset
    var customModel: String
    var reasoningEffort: TextFixReasoningEffort
    var isEnabled: Bool
    let isNew: Bool

    init(action: TextFixAction) {
        id = action.id
        title = action.title
        prompt = action.prompt ?? ""
        icon = action.icon
        processingPreset = action.processingProfile.preset
        customModel = action.processingProfile.customModel ?? ""
        reasoningEffort = action.processingProfile.customReasoningEffort ?? .low
        isEnabled = action.isEnabled
        isNew = false
    }

    init(
        id: String,
        title: String = "",
        prompt: String = "",
        icon: TextFixIcon = .custom,
        processingPreset: TextFixProcessingProfile.Preset = .inherit,
        customModel: String = "",
        reasoningEffort: TextFixReasoningEffort = .low,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.prompt = prompt
        self.icon = icon
        self.processingPreset = processingPreset
        self.customModel = customModel
        self.reasoningEffort = reasoningEffort
        self.isEnabled = isEnabled
        isNew = true
    }

    var validation: FixesEditorDraftValidation {
        FixesEditorDraftValidation(
            title: title,
            prompt: prompt,
            processingPreset: processingPreset,
            customModel: customModel
        )
    }

    var description: String {
        "FixesEditorDraft(id: <redacted>, title: <redacted>, prompt: <redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "id": "<redacted>",
                "title": "<redacted>",
                "prompt": "<redacted>",
                "icon": icon.rawValue,
                "processingPreset": processingPreset.rawValue,
                "customModel": "<redacted>",
                "reasoningEffort": reasoningEffort.rawValue,
                "isEnabled": isEnabled,
                "isNew": isNew,
            ]
        )
    }

    func makeAction() throws -> TextFixAction {
        let processingProfile: TextFixProcessingProfile
        switch processingPreset {
        case .inherit:
            processingProfile = .inherit
        case .gpt56Terra:
            processingProfile = .gpt56Terra
        case .gpt56SolMax:
            processingProfile = .gpt56SolMax
        case .custom:
            processingProfile = try .custom(
                model: customModel,
                reasoningEffort: reasoningEffort
            )
        }
        return try TextFixAction(
            id: id,
            kind: .customPrompt,
            title: title,
            icon: icon,
            prompt: prompt,
            processingProfile: processingProfile,
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
            || processingPreset != action.processingProfile.preset
            || customModel != (action.processingProfile.customModel ?? "")
            || reasoningEffort
                != (action.processingProfile.customReasoningEffort ?? .low)
            || isEnabled != action.isEnabled
    }
}

struct FixesEditorDraftValidation: Equatable {
    let titleMessage: String?
    let promptMessage: String?
    let customModelMessage: String?

    init(
        title: String,
        prompt: String,
        processingPreset: TextFixProcessingProfile.Preset = .inherit,
        customModel: String = ""
    ) {
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

        let normalizedModel = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if processingPreset != .custom {
            customModelMessage = nil
        } else if normalizedModel.isEmpty {
            customModelMessage = "Enter a model identifier."
        } else if normalizedModel.utf8.count
                    > TextFixProcessingProfile.maximumCustomModelUTF8ByteCount {
            customModelMessage =
                "Keep the model under \(TextFixProcessingProfile.maximumCustomModelUTF8ByteCount) UTF-8 bytes."
        } else {
            customModelMessage = nil
        }
    }

    var isValid: Bool {
        titleMessage == nil && promptMessage == nil && customModelMessage == nil
    }
}
