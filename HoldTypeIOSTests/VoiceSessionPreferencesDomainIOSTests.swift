import Foundation
import HoldTypeDomain
import Testing

struct VoiceSessionPreferencesDomainIOSTests {
    @Test func resolvesPortableVoiceSessionPreferencesOnIOS() {
        let defaults = VoiceSessionPreferences.defaults

        #expect(defaults.audioCuesEnabled)
        #expect(defaults.recordingStopTailDuration == .off)
        #expect(defaults.recordingDurationLimit == .defaultValue)
        #expect(RecordingDurationLimit.minimumMinutes == 1)
        #expect(RecordingDurationLimit.maximumMinutes == 15)
        #expect(RecordingDurationLimit.defaultValue.minutes == 5)
        #expect(RecordingStopTailDuration.allCases == [
            .off,
            .milliseconds500,
            .seconds1,
            .seconds1_5,
            .seconds2,
        ])
        #expect(RecordingStopTailDuration.milliseconds500.duration == 0.5)
        #expect(RecordingStopTailDuration.seconds2.duration == 2)

        let custom = VoiceSessionPreferences(
            audioCuesEnabled: false,
            recordingStopTailDuration: .seconds1_5,
            recordingDurationLimit: RecordingDurationLimit(minutes: 15)
        )
        #expect(custom.audioCuesEnabled == false)
        #expect(custom.recordingStopTailDuration.duration == 1.5)
        #expect(custom.recordingDurationLimit.minutes == 15)
        #expect(custom.recordingDurationLimit.wholeSeconds == 900)
        #expect(
            custom.recordingDurationLimit
                .maximumFinalizedMediaDurationMilliseconds == 902_000
        )
    }

    @Test func publicStopTailCodableContractWorksThroughANormalIOSImport() throws {
        requireSendable(RecordingStopTailDuration.self)
        requireSendable(RecordingDurationLimit.self)
        requireSendable(VoiceSessionPreferences.self)

        let encoded = try JSONEncoder().encode(RecordingStopTailDuration.seconds1_5)
        #expect(String(decoding: encoded, as: UTF8.self) == "\"seconds1_5\"")
        #expect(
            try JSONDecoder().decode(RecordingStopTailDuration.self, from: encoded) ==
                .seconds1_5
        )
        #expect(RecordingStopTailDuration(rawValue: "legacyUnknownTail") == nil)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
