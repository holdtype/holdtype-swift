import Foundation

public struct TranscriptionConfiguration: Equatable, Sendable {
    public static let defaultModel = "gpt-4o-transcribe"
    public static let defaults = TranscriptionConfiguration()

    public var model: String
    public var language: TranscriptionLanguage
    public var customLanguageCode: String
    public var freeformPrompt: String

    public init(
        model: String = Self.defaultModel,
        language: TranscriptionLanguage = .automatic,
        customLanguageCode: String = "",
        freeformPrompt: String = ""
    ) {
        self.model = model
        self.language = language
        self.customLanguageCode = customLanguageCode
        self.freeformPrompt = freeformPrompt
    }

    public var resolvedModel: String {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedModel.isEmpty ? Self.defaultModel : trimmedModel
    }

    public var resolvedFreeformPrompt: String? {
        let trimmedPrompt = freeformPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPrompt.isEmpty ? nil : trimmedPrompt
    }

    public var customLanguageCodeValidation: CustomLanguageCodeValidation {
        language.customLanguageCodeValidation(customCode: customLanguageCode)
    }

    public var resolvedLanguageCode: String? {
        language.apiLanguageCode(customCode: customLanguageCode)
    }
}
