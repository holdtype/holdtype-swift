import HoldTypeDomain
import Testing

struct RecoveryDestinationDomainIOSTests {
    @Test func publicRecoveryDestinationContractWorksThroughANormalIOSImport() {
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
