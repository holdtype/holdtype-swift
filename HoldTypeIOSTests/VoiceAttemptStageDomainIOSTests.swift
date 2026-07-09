import HoldTypeDomain
import Testing

struct VoiceAttemptStageDomainIOSTests {
    @Test func publicRuntimeAttributionContractWorksThroughANormalIOSImport() {
        let stages: [VoiceAttemptStage] = [
            .recordingFinalization,
            .transcription,
            .postProcessing,
            .outputDelivery,
        ]

        #expect(stages.map(marker(for:)) == [0, 1, 2, 3])
        requireSendable(VoiceAttemptStage.self)
        #expect(((stages[0] as Any) is any Encodable) == false)
        #expect(((stages[0] as Any) is any Decodable) == false)
    }

    private func marker(for stage: VoiceAttemptStage) -> Int {
        switch stage {
        case .recordingFinalization:
            return 0
        case .transcription:
            return 1
        case .postProcessing:
            return 2
        case .outputDelivery:
            return 3
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
