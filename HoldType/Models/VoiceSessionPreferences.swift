import HoldTypeDomain

typealias RecordingStopTailDuration = HoldTypeDomain.RecordingStopTailDuration
typealias RecordingDurationLimit = HoldTypeDomain.RecordingDurationLimit
typealias VoiceSessionPreferences = HoldTypeDomain.VoiceSessionPreferences

extension RecordingDurationLimit {
    var displayName: String {
        minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }
}

extension RecordingStopTailDuration {
    var displayName: String {
        switch self {
        case .off:
            return "Off"
        case .milliseconds500:
            return "0.5 seconds"
        case .seconds1:
            return "1.0 second"
        case .seconds1_5:
            return "1.5 seconds"
        case .seconds2:
            return "2.0 seconds"
        }
    }
}
