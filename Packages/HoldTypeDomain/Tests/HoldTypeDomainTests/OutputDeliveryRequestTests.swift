import Testing
@testable import HoldTypeDomain

struct OutputDeliveryRequestTests {
    @Test func preservesAcceptedTextAndEveryPreferenceCombination() throws {
        let acceptedTranscript = try AcceptedTranscript(rawText: "  Final accepted text\n")

        for automaticInsertionPreferenceEnabled in [false, true] {
            for keepLatestResult in [false, true] {
                let preferences = OutputDeliveryPreferences(
                    automaticInsertionPreferenceEnabled: automaticInsertionPreferenceEnabled,
                    keepLatestResult: keepLatestResult
                )
                let request = OutputDeliveryRequest(
                    acceptedTranscript: acceptedTranscript,
                    preferences: preferences
                )

                #expect(request.acceptedTranscript.text == "Final accepted text")
                #expect(request.preferences == preferences)
            }
        }
    }

    @Test func equalityIncludesAcceptedTextAndBothPreferences() throws {
        let firstTranscript = try AcceptedTranscript(rawText: "first")
        let secondTranscript = try AcceptedTranscript(rawText: "second")
        let first = OutputDeliveryRequest(
            acceptedTranscript: firstTranscript,
            preferences: .defaults
        )

        #expect(first == first)
        #expect(
            first != OutputDeliveryRequest(
                acceptedTranscript: secondTranscript,
                preferences: .defaults
            )
        )
        #expect(
            first != OutputDeliveryRequest(
                acceptedTranscript: firstTranscript,
                preferences: OutputDeliveryPreferences(
                    automaticInsertionPreferenceEnabled: false,
                    keepLatestResult: true
                )
            )
        )
        #expect(
            first != OutputDeliveryRequest(
                acceptedTranscript: firstTranscript,
                preferences: OutputDeliveryPreferences(
                    automaticInsertionPreferenceEnabled: true,
                    keepLatestResult: false
                )
            )
        )
    }

    @Test func publicValueIsSendableButNotATransportContract() throws {
        requireSendable(OutputDeliveryRequest.self)
        let request = OutputDeliveryRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "accepted"),
            preferences: .defaults
        )

        #expect(((request as Any) is any Encodable) == false)
        #expect(((request as Any) is any Decodable) == false)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
