import HoldTypeDomain
import Testing

struct OutputDeliveryRequestDomainIOSTests {
    @Test func publicRuntimeRequestWorksThroughANormalIOSImport() throws {
        let acceptedTranscript = try AcceptedTranscript(rawText: "  translated result\n")
        let preferences = OutputDeliveryPreferences(
            automaticInsertionPreferenceEnabled: false,
            keepLatestResult: true
        )
        let request = OutputDeliveryRequest(
            acceptedTranscript: acceptedTranscript,
            preferences: preferences
        )

        #expect(request.acceptedTranscript.text == "translated result")
        #expect(request.preferences == preferences)
        #expect(
            request != OutputDeliveryRequest(
                acceptedTranscript: acceptedTranscript,
                preferences: OutputDeliveryPreferences(
                    automaticInsertionPreferenceEnabled: true,
                    keepLatestResult: true
                )
            )
        )
        requireSendable(OutputDeliveryRequest.self)
        #expect(((request as Any) is any Encodable) == false)
        #expect(((request as Any) is any Decodable) == false)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
