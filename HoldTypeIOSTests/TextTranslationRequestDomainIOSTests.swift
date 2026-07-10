import HoldTypeDomain
import Testing

struct TextTranslationRequestDomainIOSTests {
    @Test func publicRuntimeRequestWorksThroughANormalIOSImport() throws {
        let translationConfiguration = TranslationConfiguration(
            sourceMode: .override,
            sourceLanguage: .custom,
            customSourceLanguageCode: " PT ",
            targetLanguage: .english,
            model: "translation-model",
            prompt: "Translate only"
        )
        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "  fonte\n"),
            translationConfiguration: translationConfiguration,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "unrelated-transcription-model",
                language: .japanese,
                freeformPrompt: "unrelated transcription prompt"
            )
        )

        #expect(request.acceptedTranscript.text == "fonte")
        #expect(request.translationConfiguration == translationConfiguration)
        #expect(request.resolvedSourceLanguageCode == "pt")
        requireSendable(TextTranslationRequest.self)
        #expect(((request as Any) is any Encodable) == false)
        #expect(((request as Any) is any Decodable) == false)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
