import HoldTypeDomain
import Testing

struct TextCorrectionRequestDomainIOSTests {
    @Test func publicRuntimeRequestWorksThroughANormalIOSImport() throws {
        let correctionConfiguration = TextCorrectionConfiguration(
            isEnabled: true,
            modelPreset: .fast,
            prompt: "Only fix obvious errors"
        )
        let postProcessingConfiguration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: true,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: [
                TextReplacementRule(search: "draft", replacement: "final")
            ]
        )
        let request = TextCorrectionRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "  draft text\n"),
            correctionConfiguration: correctionConfiguration,
            postProcessingConfiguration: postProcessingConfiguration
        )

        #expect(request.acceptedTranscript.text == "draft text")
        #expect(request.correctionConfiguration == correctionConfiguration)
        #expect(request.postProcessingConfiguration == postProcessingConfiguration)
        requireSendable(TextCorrectionRequest.self)
        #expect(((request as Any) is any Encodable) == false)
        #expect(((request as Any) is any Decodable) == false)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
