import Foundation
import HoldTypeDomain
import Testing

struct OutputDeliveryStateDomainIOSTests {
    @Test func publicDeliveryStateContractWorksThroughANormalIOSImport() throws {
        let confirmed = InsertionAttemptOutcome.confirmedInserted
        let encoded = try JSONEncoder().encode(confirmed)

        #expect(confirmed.rawValue == "confirmedInserted")
        #expect(String(decoding: encoded, as: UTF8.self) == "\"confirmedInserted\"")
        #expect(
            try JSONDecoder().decode(InsertionAttemptOutcome.self, from: encoded) ==
                .confirmedInserted
        )
        #expect(InsertionAttemptOutcome(rawValue: "unknown") == nil)

        let states: [OutputDeliveryState] = [
            .pending,
            .automaticallyEligible,
            .explicitActionRequired,
            .insertionOutcome(.confirmedInserted),
            .insertionOutcome(.submittedUnverified),
            .recoverablePreAttemptFailure,
            .expired,
        ]
        #expect(states.count == 7)
        for outcome in [
            InsertionAttemptOutcome.confirmedInserted,
            .submittedUnverified,
        ] {
            #expect(OutputDeliveryState.pending != .insertionOutcome(outcome))
        }

        requireSendable(InsertionAttemptOutcome.self)
        requireSendable(OutputDeliveryState.self)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
