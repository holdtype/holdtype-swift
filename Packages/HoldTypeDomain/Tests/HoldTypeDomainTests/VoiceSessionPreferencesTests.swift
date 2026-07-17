import Foundation
import Testing
@testable import HoldTypeDomain

struct VoiceSessionPreferencesTests {
    @Test func publicValuesAreSendable() {
        requireSendable(RecordingStopTailDuration.self)
        requireSendable(VoiceSessionWarningUrgency.self)
        requireSendable(VoiceSessionWarning.self)
        requireSendable(VoiceSessionCountdown.self)
        requireSendable(VoiceSessionMilestone.self)
        requireSendable(VoiceSessionPreferences.self)
    }

    @Test func defaultsMatchTheVoiceSessionContract() {
        let preferences = VoiceSessionPreferences()

        #expect(preferences == .defaults)
        #expect(preferences.audioCuesEnabled)
        #expect(preferences.recordingStopTailDuration == .off)
        #expect(VoiceSessionPreferences.maximumUtteranceDuration == 300)
        #expect(VoiceSessionPreferences.quickSessionDuration == 300)
    }

    @Test func warningScheduleMatchesTheFiveMinuteContract() {
        let expectedElapsedSeconds = [
            240,
            270,
            290,
            292,
            294,
            295,
            296,
            297,
            298,
            299,
        ]

        #expect(VoiceSessionWarningSchedule.maximumDurationWholeSeconds == 300)
        #expect(VoiceSessionWarningSchedule.countdownStartElapsedWholeSecond == 240)
        #expect(
            VoiceSessionWarningSchedule.warnings.map(\.elapsedWholeSeconds)
                == expectedElapsedSeconds
        )
        #expect(
            VoiceSessionWarningSchedule.warnings.map(\.remainingWholeSeconds)
                == expectedElapsedSeconds.map { 300 - $0 }
        )
        #expect(
            VoiceSessionWarningSchedule.warnings.map(\.urgency)
                == [.amber, .amber] + Array(repeating: .red, count: 8)
        )
    }

    @Test func terminalMilestoneIsDistinctFromWarnings() {
        let milestones = VoiceSessionWarningSchedule.milestones

        #expect(milestones.count == 11)
        #expect(milestones.dropLast().allSatisfy {
            if case .warning = $0 {
                return true
            }
            return false
        })
        #expect(milestones.last == .maximumDurationReached)
        #expect(milestones.map(\.elapsedWholeSeconds) == [
            240,
            270,
            290,
            292,
            294,
            295,
            296,
            297,
            298,
            299,
            300,
        ])
        #expect(
            VoiceSessionWarningSchedule.warning(atElapsedWholeSecond: 300) == nil
        )
        #expect(
            VoiceSessionWarningSchedule.milestone(atElapsedWholeSecond: 300)
                == .maximumDurationReached
        )
    }

    @Test func wholeSecondLookupDoesNotDependOnFloatingPointEquality() {
        #expect(
            VoiceSessionWarningSchedule.warning(atElapsedWholeSecond: 240)
                == VoiceSessionWarningSchedule.warnings[0]
        )
        #expect(
            VoiceSessionWarningSchedule.milestone(atElapsedWholeSecond: 239) == nil
        )
        #expect(
            VoiceSessionWarningSchedule.milestone(atElapsedWholeSecond: 241) == nil
        )

        let crossed = VoiceSessionWarningSchedule.milestones(
            afterElapsedWholeSecond: 289,
            throughElapsedWholeSecond: 295
        )
        #expect(crossed.map(\.elapsedWholeSeconds) == [290, 292, 294, 295])
        #expect(VoiceSessionWarningSchedule.milestones(
            afterElapsedWholeSecond: 295,
            throughElapsedWholeSecond: 295
        ).isEmpty)
        #expect(VoiceSessionWarningSchedule.milestones(
            afterElapsedWholeSecond: 300,
            throughElapsedWholeSecond: 299
        ).isEmpty)
    }

    @Test func countdownUsesWholeSecondsAndChangesUrgencyAtTwoNinety() {
        #expect(VoiceSessionWarningSchedule.countdown(
            atElapsedWholeSecond: 239
        ) == nil)
        #expect(VoiceSessionWarningSchedule.countdown(
            atElapsedWholeSecond: 240
        ) == VoiceSessionCountdown(
            remainingWholeSeconds: 60,
            urgency: .amber
        ))
        #expect(VoiceSessionWarningSchedule.countdown(
            atElapsedWholeSecond: 289
        ) == VoiceSessionCountdown(
            remainingWholeSeconds: 11,
            urgency: .amber
        ))
        #expect(VoiceSessionWarningSchedule.countdown(
            atElapsedWholeSecond: 290
        ) == VoiceSessionCountdown(
            remainingWholeSeconds: 10,
            urgency: .red
        ))
        #expect(VoiceSessionWarningSchedule.countdown(
            atElapsedWholeSecond: 299
        ) == VoiceSessionCountdown(
            remainingWholeSeconds: 1,
            urgency: .red
        ))
        #expect(VoiceSessionWarningSchedule.countdown(
            atElapsedWholeSecond: 300
        ) == nil)
    }

    @Test func stopTailCasesPreserveLegacyRawValuesAndDurations() {
        let expected: [(RecordingStopTailDuration, String, TimeInterval)] = [
            (.off, "off", 0),
            (.milliseconds500, "milliseconds500", 0.5),
            (.seconds1, "seconds1", 1),
            (.seconds1_5, "seconds1_5", 1.5),
            (.seconds2, "seconds2", 2),
        ]

        #expect(RecordingStopTailDuration.allCases == expected.map(\.0))
        for (tail, rawValue, duration) in expected {
            #expect(tail.rawValue == rawValue)
            #expect(tail.duration == duration)
            #expect(RecordingStopTailDuration(rawValue: rawValue) == tail)
        }
        #expect(RecordingStopTailDuration(rawValue: "legacyUnknownTail") == nil)
    }

    @Test func stopTailCodableShapeRemainsOneRawString() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        for tail in RecordingStopTailDuration.allCases {
            let encoded = try encoder.encode(tail)
            #expect(String(decoding: encoded, as: UTF8.self) == "\"\(tail.rawValue)\"")
            #expect(try decoder.decode(RecordingStopTailDuration.self, from: encoded) == tail)
        }

        #expect(throws: DecodingError.self) {
            try decoder.decode(
                RecordingStopTailDuration.self,
                from: Data("\"legacyUnknownTail\"".utf8)
            )
        }
    }

    @Test func customPreferencesPreserveTheirRawValues() {
        var preferences = VoiceSessionPreferences(
            audioCuesEnabled: false,
            recordingStopTailDuration: .seconds1_5
        )

        #expect(preferences.audioCuesEnabled == false)
        #expect(preferences.recordingStopTailDuration == .seconds1_5)

        preferences.audioCuesEnabled = true
        preferences.recordingStopTailDuration = .milliseconds500
        #expect(preferences == VoiceSessionPreferences(
            audioCuesEnabled: true,
            recordingStopTailDuration: .milliseconds500
        ))
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
