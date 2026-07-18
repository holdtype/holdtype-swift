import Testing
import HoldTypeDomain

struct TextCorrectionRequestTests {
    @Test func preservesAcceptedTextAndBothConfigurationsExactly() throws {
        let correctionConfiguration = TextCorrectionConfiguration(
            isEnabled: true,
            modelPreset: .custom,
            customModel: "custom-correction-model",
            prompt: "Minimal correction only"
        )
        let postProcessingConfiguration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: [
                TextReplacementRule(search: "source", replacement: "replacement")
            ]
        )
        let request = TextCorrectionRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "  accepted source\n"),
            correctionConfiguration: correctionConfiguration,
            postProcessingConfiguration: postProcessingConfiguration
        )

        #expect(request.acceptedTranscript.text == "accepted source")
        #expect(request.correctionConfiguration == correctionConfiguration)
        #expect(request.postProcessingConfiguration == postProcessingConfiguration)
    }

    @Test func equalityIncludesAcceptedTextAndBothConfigurations() throws {
        let acceptedTranscript = try AcceptedTranscript(rawText: "accepted")
        let first = TextCorrectionRequest(
            acceptedTranscript: acceptedTranscript,
            correctionConfiguration: .defaults,
            postProcessingConfiguration: TranscriptPostProcessingConfiguration()
        )

        #expect(first == first)
        #expect(
            first != TextCorrectionRequest(
                acceptedTranscript: try AcceptedTranscript(rawText: "different"),
                correctionConfiguration: .defaults,
                postProcessingConfiguration: TranscriptPostProcessingConfiguration()
            )
        )
        #expect(
            first != TextCorrectionRequest(
                acceptedTranscript: acceptedTranscript,
                correctionConfiguration: TextCorrectionConfiguration(isEnabled: true),
                postProcessingConfiguration: TranscriptPostProcessingConfiguration()
            )
        )
        #expect(
            first != TextCorrectionRequest(
                acceptedTranscript: acceptedTranscript,
                correctionConfiguration: .defaults,
                postProcessingConfiguration: TranscriptPostProcessingConfiguration(
                    localTextCleanupEnabled: false
                )
            )
        )
    }

    @Test func publicValueIsSendableButNotATransportContract() throws {
        requireSendable(TextCorrectionRequest.self)
        let request = TextCorrectionRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "accepted"),
            correctionConfiguration: .defaults,
            postProcessingConfiguration: TranscriptPostProcessingConfiguration()
        )

        #expect(((request as Any) is any Encodable) == false)
        #expect(((request as Any) is any Decodable) == false)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
