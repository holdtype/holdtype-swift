import Foundation
import Testing
@testable import HoldTypeDomain

struct OutputDeliveryStateTests {
    @Test func insertionOutcomesPreserveStableRawAndCodableValues() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let expected: [(InsertionAttemptOutcome, String)] = [
            (.confirmedInserted, "confirmedInserted"),
            (.submittedUnverified, "submittedUnverified"),
        ]

        for (outcome, rawValue) in expected {
            #expect(outcome.rawValue == rawValue)
            #expect(InsertionAttemptOutcome(rawValue: rawValue) == outcome)

            let encoded = try encoder.encode(outcome)
            #expect(String(decoding: encoded, as: UTF8.self) == "\"\(rawValue)\"")
            #expect(try decoder.decode(InsertionAttemptOutcome.self, from: encoded) == outcome)
        }
    }

    @Test func unknownInsertionOutcomesFailClosed() {
        #expect(InsertionAttemptOutcome(rawValue: "unknown") == nil)
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(
                InsertionAttemptOutcome.self,
                from: Data("\"unknown\"".utf8)
            )
        }
    }

    @Test func deliveryStateRepresentsExactlySevenProductStates() {
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
        for state in states {
            assertKnownProductState(state)
        }
        for leftIndex in states.indices {
            for rightIndex in states.indices where leftIndex != rightIndex {
                #expect(states[leftIndex] != states[rightIndex])
            }
        }
    }

    @Test func observerScopedStatesKeepLocalOutcomesDistinctFromAppPendingState() {
        let localOutcomes: [InsertionAttemptOutcome] = [
            .confirmedInserted,
            .submittedUnverified,
        ]

        for localOutcome in localOutcomes {
            let keyboardState = OutputDeliveryState.insertionOutcome(localOutcome)
            let appStateWithoutAcknowledgement = OutputDeliveryState.pending

            #expect(keyboardState == .insertionOutcome(localOutcome))
            #expect(appStateWithoutAcknowledgement == .pending)
            #expect(keyboardState != appStateWithoutAcknowledgement)
        }
    }

    @Test func publicValuesAreSendable() {
        requireSendable(InsertionAttemptOutcome.self)
        requireSendable(OutputDeliveryState.self)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}

    private func assertKnownProductState(_ state: OutputDeliveryState) {
        switch state {
        case .pending,
             .automaticallyEligible,
             .explicitActionRequired,
             .recoverablePreAttemptFailure,
             .expired:
            break
        case let .insertionOutcome(outcome):
            switch outcome {
            case .confirmedInserted, .submittedUnverified:
                break
            }
        }
    }
}
