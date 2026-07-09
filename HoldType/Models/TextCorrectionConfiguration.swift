import HoldTypeDomain

typealias TextCorrectionModelPreset = HoldTypeDomain.TextCorrectionModelPreset
typealias TextCorrectionConfiguration = HoldTypeDomain.TextCorrectionConfiguration

extension TextCorrectionModelPreset {
    var displayName: String {
        switch self {
        case .quality:
            return "Quality"
        case .balanced:
            return "Balanced"
        case .fast:
            return "Fast"
        case .custom:
            return "Custom"
        }
    }

    var detail: String {
        switch self {
        case .quality:
            return "Highest quality correction"
        case .balanced:
            return "Lower cost than Quality"
        case .fast:
            return "Lower latency and cost"
        case .custom:
            return "Use a model ID you enter"
        }
    }
}
