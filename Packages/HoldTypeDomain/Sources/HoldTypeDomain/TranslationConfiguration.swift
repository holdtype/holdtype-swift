import Foundation

public enum TranslationSourceMode: String, CaseIterable, Codable, Equatable, Sendable {
    case sameAsTranscription
    case override
}

public enum TranslationConfigurationIssue: Error, Equatable, Sendable {
    case invalidSourceLanguage
    case missingTargetLanguage
}

public struct TranslationConfiguration: Equatable, Sendable {
    public static let defaultModel = "gpt-5.4-mini"
    public static let defaultPrompt =
        """
        Translate the user's dictation transcript into the target language.
        Return only the translated text.

        Preserve meaning, names, numbers, paragraph breaks, and list structure when practical.
        Do not add explanations, markdown, alternatives, diagnostics, or source text.
        """
    public static let defaults = TranslationConfiguration()

    public var actionPreferenceEnabled: Bool
    public var sourceMode: TranslationSourceMode
    public var sourceLanguage: TranscriptionLanguage
    public var customSourceLanguageCode: String
    public var targetLanguage: TranscriptionLanguage
    public var customTargetLanguageCode: String
    public var model: String
    public var prompt: String

    public init(
        actionPreferenceEnabled: Bool = true,
        sourceMode: TranslationSourceMode = .sameAsTranscription,
        sourceLanguage: TranscriptionLanguage = .automatic,
        customSourceLanguageCode: String = "",
        targetLanguage: TranscriptionLanguage = .automatic,
        customTargetLanguageCode: String = "",
        model: String = Self.defaultModel,
        prompt: String = Self.defaultPrompt
    ) {
        self.actionPreferenceEnabled = actionPreferenceEnabled
        self.sourceMode = sourceMode
        self.sourceLanguage = sourceLanguage
        self.customSourceLanguageCode = customSourceLanguageCode
        self.targetLanguage = targetLanguage
        self.customTargetLanguageCode = customTargetLanguageCode
        self.model = model
        self.prompt = prompt
    }

    public func resolvedSourceLanguageCode(
        transcriptionConfiguration: TranscriptionConfiguration
    ) -> String? {
        switch sourceMode {
        case .sameAsTranscription:
            return transcriptionConfiguration.resolvedLanguageCode
        case .override:
            return sourceLanguage.apiLanguageCode(customCode: customSourceLanguageCode)
        }
    }

    public var resolvedTargetLanguageCode: String? {
        targetLanguage.apiLanguageCode(customCode: customTargetLanguageCode)
    }

    public var isSourceConfigurationValid: Bool {
        switch sourceMode {
        case .sameAsTranscription:
            return true
        case .override:
            return sourceLanguage.apiLanguageCode(customCode: customSourceLanguageCode) != nil
        }
    }

    public var routeConfigurationIssue: TranslationConfigurationIssue? {
        guard isSourceConfigurationValid else {
            return .invalidSourceLanguage
        }

        guard resolvedTargetLanguageCode != nil else {
            return .missingTargetLanguage
        }

        return nil
    }

    public var isConfigurationReady: Bool {
        routeConfigurationIssue == nil
    }

    public var configurationIssue: TranslationConfigurationIssue? {
        actionPreferenceEnabled ? routeConfigurationIssue : nil
    }

    public var canRunAction: Bool {
        actionPreferenceEnabled && isConfigurationReady
    }

    public var resolvedModel: String {
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
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
