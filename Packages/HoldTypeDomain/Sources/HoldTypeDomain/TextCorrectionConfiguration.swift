import Foundation

public enum TextCorrectionModelPreset: String, CaseIterable, Codable, Equatable, Sendable {
    case quality
    case balanced
    case fast
    case custom

    public var modelName: String? {
        switch self {
        case .quality:
            return TextCorrectionConfiguration.defaultModel
        case .balanced:
            return "gpt-5.4"
        case .fast:
            return "gpt-5.4-mini"
        case .custom:
            return nil
        }
    }
}

public struct TextCorrectionConfiguration: Equatable, Sendable {
    public static let defaultModel = "gpt-5.5"
    public static let defaultPrompt =
        """
        You are correcting a speech transcript.
        Return only the corrected text.

        Make the smallest possible edits.
        Fix only obvious transcription errors, spacing, capitalization, and punctuation.
        Preserve the original language, wording, order, tone, meaning, and line breaks when possible.
        Do not rewrite for style.
        Do not summarize, expand, translate, add facts, remove facts, or make the text more formal.
        If a change is uncertain, leave the text unchanged.
        """
    public static let defaults = TextCorrectionConfiguration()

    public var isEnabled: Bool
    public var modelPreset: TextCorrectionModelPreset
    public var customModel: String
    public var prompt: String

    public init(
        isEnabled: Bool = false,
        modelPreset: TextCorrectionModelPreset = .quality,
        customModel: String = "",
        prompt: String = Self.defaultPrompt
    ) {
        self.isEnabled = isEnabled
        self.modelPreset = modelPreset
        self.customModel = customModel
        self.prompt = prompt
    }

    public var resolvedModel: String {
        if let modelName = modelPreset.modelName {
            return modelName
        }

        let trimmedModel = customModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedModel.isEmpty ? Self.defaultModel : trimmedModel
    }

    public var resolvedPrompt: String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPrompt.isEmpty ? Self.defaultPrompt : trimmedPrompt
    }

    public var isPromptDefault: Bool {
        prompt == Self.defaultPrompt
    }

    public mutating func resetPrompt() {
        prompt = Self.defaultPrompt
    }
}
