import HoldTypeDomain

typealias TranscriptionLanguage = HoldTypeDomain.TranscriptionLanguage
typealias CustomLanguageCodeValidation = HoldTypeDomain.CustomLanguageCodeValidation

extension HoldTypeDomain.TranscriptionLanguage {
    static var translationCases: [Self] {
        allCases.filter { $0 != .automatic }
    }

    var displayName: String {
        guard let languageCode else {
            switch self {
            case .automatic:
                return "Auto"
            case .custom:
                return "Custom"
            default:
                return languageName
            }
        }

        return "\(languageName) (\(languageCode))"
    }

    var languageName: String {
        switch self {
        case .automatic:
            return "Auto"
        case .english:
            return "English"
        case .spanish:
            return "Spanish"
        case .french:
            return "French"
        case .german:
            return "German"
        case .italian:
            return "Italian"
        case .portuguese:
            return "Portuguese"
        case .dutch:
            return "Dutch"
        case .polish:
            return "Polish"
        case .russian:
            return "Russian"
        case .ukrainian:
            return "Ukrainian"
        case .turkish:
            return "Turkish"
        case .arabic:
            return "Arabic"
        case .hebrew:
            return "Hebrew"
        case .hindi:
            return "Hindi"
        case .chinese:
            return "Chinese"
        case .japanese:
            return "Japanese"
        case .korean:
            return "Korean"
        case .vietnamese:
            return "Vietnamese"
        case .indonesian:
            return "Indonesian"
        case .thai:
            return "Thai"
        case .swedish:
            return "Swedish"
        case .danish:
            return "Danish"
        case .finnish:
            return "Finnish"
        case .czech:
            return "Czech"
        case .greek:
            return "Greek"
        case .romanian:
            return "Romanian"
        case .hungarian:
            return "Hungarian"
        case .custom:
            return "Custom"
        }
    }
}
