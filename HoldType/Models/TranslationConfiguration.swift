import Foundation
import HoldTypeDomain

typealias TranslationSourceMode = HoldTypeDomain.TranslationSourceMode
typealias TranslationConfigurationIssue = HoldTypeDomain.TranslationConfigurationIssue
typealias TranslationConfiguration = HoldTypeDomain.TranslationConfiguration

extension TranslationSourceMode {
    var displayName: String {
        switch self {
        case .sameAsTranscription:
            return "Same as Transcription"
        case .override:
            return "Override source language"
        }
    }
}

extension HoldTypeDomain.TranslationConfigurationIssue: @retroactive LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .invalidSourceLanguage:
            return "Choose a valid source language override in Translation settings."
        case .missingTargetLanguage:
            return "Choose a target language in Translation settings."
        }
    }

    var title: String {
        "Translation settings need attention"
    }
}
