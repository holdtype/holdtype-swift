import HoldTypeDomain
import Testing

struct VoiceWorkPhaseDomainIOSTests {
    @Test func publicRuntimePhaseContractWorksThroughANormalIOSImport() {
        let phases: [VoiceWorkPhase] = [
            .inactive,
            .arming,
            .ready,
            .listening,
            .finalizing,
            .processing,
        ]

        #expect(phases.count == 6)
        for phase in phases {
            assertKnownPhase(phase)
        }
        requireSendable(VoiceWorkPhase.self)
    }

    private func assertKnownPhase(_ phase: VoiceWorkPhase) {
        switch phase {
        case .inactive,
             .arming,
             .ready,
             .listening,
             .finalizing,
             .processing:
            break
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
