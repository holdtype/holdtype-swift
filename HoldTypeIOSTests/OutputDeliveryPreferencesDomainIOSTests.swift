import HoldTypeDomain
import Testing

struct OutputDeliveryPreferencesDomainIOSTests {
    @Test func resolvesPortableOutputDeliveryPreferencesOnIOS() {
        let defaults = OutputDeliveryPreferences.defaults

        #expect(defaults.automaticInsertionPreferenceEnabled)
        #expect(defaults.keepLatestResult)

        let insertionOnly = OutputDeliveryPreferences(
            automaticInsertionPreferenceEnabled: true,
            keepLatestResult: false
        )
        #expect(insertionOnly.automaticInsertionPreferenceEnabled)
        #expect(insertionOnly.keepLatestResult == false)
        requireSendable(OutputDeliveryPreferences.self)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
