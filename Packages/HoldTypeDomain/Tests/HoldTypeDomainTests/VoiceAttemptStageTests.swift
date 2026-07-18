import Testing
import HoldTypeDomain

struct VoiceAttemptStageTests {
    @Test func representsExactlyTheFourRuntimeAttributionStages() {
        let stages: [VoiceAttemptStage] = [
            .recordingFinalization,
            .transcription,
            .postProcessing,
            .outputDelivery,
        ]

        #expect(stages.map(marker(for:)) == [0, 1, 2, 3])
        for leftIndex in stages.indices {
            for rightIndex in stages.indices {
                #expect((stages[leftIndex] == stages[rightIndex]) == (leftIndex == rightIndex))
            }
        }
    }

    @Test func publicValueIsSendableButNotATransportContract() {
        requireSendable(VoiceAttemptStage.self)
        let stage = VoiceAttemptStage.transcription

        #expect(((stage as Any) is any Encodable) == false)
        #expect(((stage as Any) is any Decodable) == false)
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
