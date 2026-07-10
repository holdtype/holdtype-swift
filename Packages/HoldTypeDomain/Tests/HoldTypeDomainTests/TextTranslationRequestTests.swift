import Testing
@testable import HoldTypeDomain

struct TextTranslationRequestTests {
    @Test func preservesAcceptedTextConfigurationAndSameAsTranscriptionSource() throws {
        let translationConfiguration = TranslationConfiguration(
            actionPreferenceEnabled: true,
            sourceMode: .sameAsTranscription,
            targetLanguage: .english,
            model: "custom-translation-model",
            prompt: "Translate concisely"
        )
        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "  texto aceptado\n"),
            translationConfiguration: translationConfiguration,
            transcriptionConfiguration: TranscriptionConfiguration(language: .spanish)
        )

        #expect(request.acceptedTranscript.text == "texto aceptado")
        #expect(request.translationConfiguration == translationConfiguration)
        #expect(request.resolvedSourceLanguageCode == "es")
    }

    @Test func sameAsTranscriptionAutoOmitsSourceCode() throws {
        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "source"),
            translationConfiguration: TranslationConfiguration(
                sourceMode: .sameAsTranscription,
                targetLanguage: .english
            ),
            transcriptionConfiguration: TranscriptionConfiguration(language: .automatic)
        )

        #expect(request.resolvedSourceLanguageCode == nil)
    }

    @Test func sameAsTranscriptionNormalizesCustomSourceCode() throws {
        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "source"),
            translationConfiguration: TranslationConfiguration(
                sourceMode: .sameAsTranscription,
                targetLanguage: .english
            ),
            transcriptionConfiguration: TranscriptionConfiguration(
                language: .custom,
                customLanguageCode: " FR "
            )
        )

        #expect(request.resolvedSourceLanguageCode == "fr")
    }

    @Test func overrideNormalizesItsOwnSourceIndependentlyOfTranscription() throws {
        let translationConfiguration = TranslationConfiguration(
            sourceMode: .override,
            sourceLanguage: .custom,
            customSourceLanguageCode: " PT ",
            targetLanguage: .english
        )
        let first = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "source"),
            translationConfiguration: translationConfiguration,
            transcriptionConfiguration: TranscriptionConfiguration(language: .spanish)
        )
        let second = TextTranslationRequest(
            acceptedTranscript: first.acceptedTranscript,
            translationConfiguration: translationConfiguration,
            transcriptionConfiguration: TranscriptionConfiguration(language: .japanese)
        )

        #expect(first.resolvedSourceLanguageCode == "pt")
        #expect(first == second)
    }

    @Test func equalityIncludesAcceptedTextConfigurationAndResolvedSource() throws {
        let acceptedTranscript = try AcceptedTranscript(rawText: "source")
        let translationConfiguration = TranslationConfiguration(targetLanguage: .english)
        let first = TextTranslationRequest(
            acceptedTranscript: acceptedTranscript,
            translationConfiguration: translationConfiguration,
            transcriptionConfiguration: TranscriptionConfiguration(language: .spanish)
        )

        #expect(
            first != TextTranslationRequest(
                acceptedTranscript: try AcceptedTranscript(rawText: "different"),
                translationConfiguration: translationConfiguration,
                transcriptionConfiguration: TranscriptionConfiguration(language: .spanish)
            )
        )
        #expect(
            first != TextTranslationRequest(
                acceptedTranscript: acceptedTranscript,
                translationConfiguration: TranslationConfiguration(
                    targetLanguage: .french
                ),
                transcriptionConfiguration: TranscriptionConfiguration(language: .spanish)
            )
        )
        #expect(
            first != TextTranslationRequest(
                acceptedTranscript: acceptedTranscript,
                translationConfiguration: translationConfiguration,
                transcriptionConfiguration: TranscriptionConfiguration(language: .french)
            )
        )
    }

    @Test func unrelatedTranscriptionModelAndPromptDoNotEnterRequest() throws {
        let acceptedTranscript = try AcceptedTranscript(rawText: "source")
        let translationConfiguration = TranslationConfiguration(targetLanguage: .english)
        let first = TextTranslationRequest(
            acceptedTranscript: acceptedTranscript,
            translationConfiguration: translationConfiguration,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "first-transcription-model",
                language: .spanish,
                freeformPrompt: "first private transcription prompt"
            )
        )
        let second = TextTranslationRequest(
            acceptedTranscript: acceptedTranscript,
            translationConfiguration: translationConfiguration,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "second-transcription-model",
                language: .spanish,
                freeformPrompt: "second private transcription prompt"
            )
        )

        #expect(first == second)
    }

    @Test func publicValueIsSendableButNotATransportContract() throws {
        requireSendable(TextTranslationRequest.self)
        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "source"),
            translationConfiguration: TranslationConfiguration(targetLanguage: .english),
            transcriptionConfiguration: .defaults
        )

        #expect(((request as Any) is any Encodable) == false)
        #expect(((request as Any) is any Decodable) == false)
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}
