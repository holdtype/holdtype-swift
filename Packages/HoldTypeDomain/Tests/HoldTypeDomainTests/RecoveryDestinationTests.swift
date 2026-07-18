import Testing
import HoldTypeDomain

struct RecoveryDestinationTests {
    @Test func representsExactlyTheApprovedSetupOwners() {
        let destinations: [RecoveryDestination] = [
            .openAI,
            .transcription,
            .translation,
            .keyboard,
            .fullAccess,
            .microphoneAndPrivacy,
        ]

        #expect(destinations.count == 6)
        for destination in destinations {
            assertKnownDestination(destination)
        }
        for leftIndex in destinations.indices {
            for rightIndex in destinations.indices where leftIndex != rightIndex {
                #expect(destinations[leftIndex] != destinations[rightIndex])
            }
        }
    }

    @Test func publicValueIsSendable() {
        requireSendable(RecoveryDestination.self)
    }

    private func assertKnownDestination(_ destination: RecoveryDestination) {
        switch destination {
        case .openAI,
             .transcription,
             .translation,
             .keyboard,
             .fullAccess,
             .microphoneAndPrivacy:
            break
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
