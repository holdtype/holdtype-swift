import Foundation

public enum TranscriptionLanguage: String, CaseIterable, Codable, Equatable, Sendable {
    case automatic = "auto"
    case english = "english"
    case spanish = "spanish"
    case french = "french"
    case german = "german"
    case italian = "italian"
    case portuguese = "portuguese"
    case dutch = "dutch"
    case polish = "polish"
    case russian = "russian"
    case ukrainian = "ukrainian"
    case turkish = "turkish"
    case arabic = "arabic"
    case hebrew = "hebrew"
    case hindi = "hindi"
    case chinese = "chinese"
    case japanese = "japanese"
    case korean = "korean"
    case vietnamese = "vietnamese"
    case indonesian = "indonesian"
    case thai = "thai"
    case swedish = "swedish"
    case danish = "danish"
    case finnish = "finnish"
    case czech = "czech"
    case greek = "greek"
    case romanian = "romanian"
    case hungarian = "hungarian"
    case custom = "custom"

    public var languageCode: String? {
        switch self {
        case .automatic, .custom:
            return nil
        case .english:
            return "en"
        case .spanish:
            return "es"
        case .french:
            return "fr"
        case .german:
            return "de"
        case .italian:
            return "it"
        case .portuguese:
            return "pt"
        case .dutch:
            return "nl"
        case .polish:
            return "pl"
        case .russian:
            return "ru"
        case .ukrainian:
            return "uk"
        case .turkish:
            return "tr"
        case .arabic:
            return "ar"
        case .hebrew:
            return "he"
        case .hindi:
            return "hi"
        case .chinese:
            return "zh"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        case .vietnamese:
            return "vi"
        case .indonesian:
            return "id"
        case .thai:
            return "th"
        case .swedish:
            return "sv"
        case .danish:
            return "da"
        case .finnish:
            return "fi"
        case .czech:
            return "cs"
        case .greek:
            return "el"
        case .romanian:
            return "ro"
        case .hungarian:
            return "hu"
        }
    }

    public func apiLanguageCode(customCode: String) -> String? {
        switch self {
        case .automatic:
            return nil
        case .custom:
            return customLanguageCodeValidation(customCode: customCode).resolvedLanguageCode
        default:
            return languageCode
        }
    }

    public func customLanguageCodeValidation(
        customCode: String
    ) -> CustomLanguageCodeValidation {
        guard self == .custom else {
            return .notRequired
        }

        let trimmedCode = customCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            return .emptyFallsBackToAutomatic
        }

        guard Self.isWellFormedCustomLanguageCode(trimmedCode) else {
            return .invalid
        }

        return .valid(normalizedCode: trimmedCode.lowercased())
    }

    public static func isWellFormedCustomLanguageCode(_ code: String) -> Bool {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedCode.count == 2 || trimmedCode.count == 3 else {
            return false
        }

        return trimmedCode.unicodeScalars.allSatisfy { scalar in
            (65...90).contains(scalar.value) || (97...122).contains(scalar.value)
        }
    }
}

public enum CustomLanguageCodeValidation: Equatable, Sendable {
    case notRequired
    case emptyFallsBackToAutomatic
    case valid(normalizedCode: String)
    case invalid

    public var isInvalid: Bool {
        self == .invalid
    }

    public var resolvedLanguageCode: String? {
        switch self {
        case .valid(let normalizedCode):
            return normalizedCode
        case .notRequired, .emptyFallsBackToAutomatic, .invalid:
            return nil
        }
    }
}
