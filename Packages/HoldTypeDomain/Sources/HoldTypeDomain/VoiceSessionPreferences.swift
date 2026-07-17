import Foundation

public enum RecordingStopTailDuration: String, CaseIterable, Codable, Equatable, Sendable {
    case off = "off"
    case milliseconds500 = "milliseconds500"
    case seconds1 = "seconds1"
    case seconds1_5 = "seconds1_5"
    case seconds2 = "seconds2"

    public var duration: TimeInterval {
        switch self {
        case .off:
            return 0
        case .milliseconds500:
            return 0.5
        case .seconds1:
            return 1
        case .seconds1_5:
            return 1.5
        case .seconds2:
            return 2
        }
    }
}

public enum VoiceSessionWarningUrgency: Equatable, Sendable {
    case amber
    case red
}

public struct VoiceSessionWarning: Equatable, Sendable {
    public let elapsedWholeSeconds: Int
    public let remainingWholeSeconds: Int
    public let urgency: VoiceSessionWarningUrgency

    public init(
        elapsedWholeSeconds: Int,
        remainingWholeSeconds: Int,
        urgency: VoiceSessionWarningUrgency
    ) {
        self.elapsedWholeSeconds = elapsedWholeSeconds
        self.remainingWholeSeconds = remainingWholeSeconds
        self.urgency = urgency
    }
}

public struct VoiceSessionCountdown: Equatable, Sendable {
    public let remainingWholeSeconds: Int
    public let urgency: VoiceSessionWarningUrgency

    public init(
        remainingWholeSeconds: Int,
        urgency: VoiceSessionWarningUrgency
    ) {
        self.remainingWholeSeconds = remainingWholeSeconds
        self.urgency = urgency
    }
}

public enum VoiceSessionMilestone: Equatable, Sendable {
    case warning(VoiceSessionWarning)
    case maximumDurationReached

    public var elapsedWholeSeconds: Int {
        switch self {
        case .warning(let warning):
            return warning.elapsedWholeSeconds
        case .maximumDurationReached:
            return VoiceSessionWarningSchedule.maximumDurationWholeSeconds
        }
    }
}

/// Whole-second milestones for one bounded voice recording.
///
/// Consumers schedule or compare these integer offsets against a monotonic
/// clock; no warning depends on exact `TimeInterval` equality.
public enum VoiceSessionWarningSchedule {
    public static let maximumDurationWholeSeconds = 300
    public static let countdownStartElapsedWholeSecond = 240

    public static let warnings: [VoiceSessionWarning] = [
        warning(at: 240),
        warning(at: 270),
        warning(at: 290),
        warning(at: 292),
        warning(at: 294),
        warning(at: 295),
        warning(at: 296),
        warning(at: 297),
        warning(at: 298),
        warning(at: 299),
    ]

    public static let milestones: [VoiceSessionMilestone] =
        warnings.map(VoiceSessionMilestone.warning)
        + [.maximumDurationReached]

    public static func warning(
        atElapsedWholeSecond elapsedWholeSecond: Int
    ) -> VoiceSessionWarning? {
        warnings.first { $0.elapsedWholeSeconds == elapsedWholeSecond }
    }

    public static func milestone(
        atElapsedWholeSecond elapsedWholeSecond: Int
    ) -> VoiceSessionMilestone? {
        if elapsedWholeSecond == maximumDurationWholeSeconds {
            return .maximumDurationReached
        }

        return warning(atElapsedWholeSecond: elapsedWholeSecond).map(
            VoiceSessionMilestone.warning
        )
    }

    public static func milestones(
        afterElapsedWholeSecond previousElapsedWholeSecond: Int,
        throughElapsedWholeSecond currentElapsedWholeSecond: Int
    ) -> [VoiceSessionMilestone] {
        guard currentElapsedWholeSecond > previousElapsedWholeSecond else {
            return []
        }

        return milestones.filter {
            $0.elapsedWholeSeconds > previousElapsedWholeSecond
                && $0.elapsedWholeSeconds <= currentElapsedWholeSecond
        }
    }

    public static func countdown(
        atElapsedWholeSecond elapsedWholeSecond: Int
    ) -> VoiceSessionCountdown? {
        guard
            elapsedWholeSecond >= countdownStartElapsedWholeSecond,
            elapsedWholeSecond < maximumDurationWholeSeconds
        else {
            return nil
        }

        return VoiceSessionCountdown(
            remainingWholeSeconds: maximumDurationWholeSeconds - elapsedWholeSecond,
            urgency: urgency(atElapsedWholeSecond: elapsedWholeSecond)
        )
    }

    private static func warning(at elapsedWholeSecond: Int) -> VoiceSessionWarning {
        VoiceSessionWarning(
            elapsedWholeSeconds: elapsedWholeSecond,
            remainingWholeSeconds: maximumDurationWholeSeconds - elapsedWholeSecond,
            urgency: urgency(atElapsedWholeSecond: elapsedWholeSecond)
        )
    }

    private static func urgency(
        atElapsedWholeSecond elapsedWholeSecond: Int
    ) -> VoiceSessionWarningUrgency {
        elapsedWholeSecond < 290 ? .amber : .red
    }
}

public struct VoiceSessionPreferences: Equatable, Sendable {
    public static let maximumUtteranceDuration: TimeInterval =
        TimeInterval(VoiceSessionWarningSchedule.maximumDurationWholeSeconds)
    public static let maximumFinalizedMediaDurationMilliseconds: Int64 =
        302_000
    public static let quickSessionDuration: TimeInterval = 300
    public static let defaults = VoiceSessionPreferences()

    public var audioCuesEnabled: Bool
    public var recordingStopTailDuration: RecordingStopTailDuration

    public init(
        audioCuesEnabled: Bool = true,
        recordingStopTailDuration: RecordingStopTailDuration = .off
    ) {
        self.audioCuesEnabled = audioCuesEnabled
        self.recordingStopTailDuration = recordingStopTailDuration
    }
}
