import Testing
@testable import HoldTypeDomain

struct OutputDeliveryPreferencesTests {
    @Test func defaultsEnableBothIndependentPreferences() {
        let preferences = OutputDeliveryPreferences()

        #expect(preferences == .defaults)
        #expect(preferences.automaticInsertionPreferenceEnabled)
        #expect(preferences.keepLatestResult)
    }

    @Test func everyPreferenceCombinationIsPreservedWithoutNormalization() {
        let combinations = [
            OutputDeliveryPreferences(
                automaticInsertionPreferenceEnabled: false,
                keepLatestResult: false
            ),
            OutputDeliveryPreferences(
                automaticInsertionPreferenceEnabled: false,
                keepLatestResult: true
            ),
            OutputDeliveryPreferences(
                automaticInsertionPreferenceEnabled: true,
                keepLatestResult: false
            ),
            .defaults,
        ]

        #expect(combinations.map {
            [$0.automaticInsertionPreferenceEnabled, $0.keepLatestResult]
        } == [
            [false, false],
            [false, true],
            [true, false],
            [true, true],
        ])
        for preferences in combinations {
            #expect(
                OutputDeliveryPreferences(
                    automaticInsertionPreferenceEnabled:
                        preferences.automaticInsertionPreferenceEnabled,
                    keepLatestResult: preferences.keepLatestResult
                ) == preferences
            )
        }
    }

    @Test func publicValueIsSendable() {
        requireSendable(OutputDeliveryPreferences.self)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
