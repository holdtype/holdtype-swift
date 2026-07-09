import Testing
@testable import HoldTypeDomain

struct VoiceWorkPhaseTests {
    @Test func representsExactlyTheApprovedRuntimePhases() {
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
        for leftIndex in phases.indices {
            for rightIndex in phases.indices where leftIndex != rightIndex {
                #expect(phases[leftIndex] != phases[rightIndex])
            }
        }
    }

    @Test func publicValueIsSendableButNotATransportContract() {
        requireSendable(VoiceWorkPhase.self)

        let phase = VoiceWorkPhase.processing
        #expect(((phase as Any) is any Encodable) == false)
        #expect(((phase as Any) is any Decodable) == false)
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
