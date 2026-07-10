import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct TranscriptTranslationServiceRequestTests {
    @Test func forwardsExactRequestAndSeparateCredential() async throws {
        let provider = RequestFakeOpenAITextTranslationService(
            result: .success("translated text")
        )
        let service = TranscriptTranslationService(openAITextTranslationService: provider)
        let request = try translationRequest()

        let output = try await service.translate(
            request,
            credential: OpenAICredential(apiKey: "sk-translation-request")
        )

        #expect(output == "translated text")
        #expect(
            provider.calls == [
                TranslationProviderCall(
                    request: request,
                    credentialAPIKey: "sk-translation-request"
                )
            ]
        )
    }

    @Test func providerFailureRemainsStrict() async throws {
        let provider = RequestFakeOpenAITextTranslationService(result: .failure(.timedOut))
        let service = TranscriptTranslationService(openAITextTranslationService: provider)
        let request = try translationRequest()

        do {
            _ = try await service.translate(
                request,
                credential: OpenAICredential(apiKey: "sk-translation-request")
            )
            Issue.record("Expected the translation failure to propagate")
        } catch let error as OpenAITextTranslationServiceError {
            #expect(error == .timedOut)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(provider.calls.count == 1)
    }

    @Test func emptyProviderOutputRemainsStrict() async throws {
        let provider = RequestFakeOpenAITextTranslationService(result: .success(" \n "))
        let service = TranscriptTranslationService(openAITextTranslationService: provider)
        let request = try translationRequest()

        do {
            _ = try await service.translate(
                request,
                credential: OpenAICredential(apiKey: "sk-translation-request")
            )
            Issue.record("Expected empty translation output to fail")
        } catch let error as OpenAITextTranslationServiceError {
            #expect(error == .emptyTranslation)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }

        #expect(provider.calls.count == 1)
    }

    @Test func cancellationDelegatesToProviderAdapter() {
        let provider = RequestFakeOpenAITextTranslationService(result: .success("unused"))
        let service = TranscriptTranslationService(openAITextTranslationService: provider)

        service.cancelActiveTranslation()

        #expect(provider.cancelCount == 1)
    }

    private func translationRequest() throws -> TextTranslationRequest {
        TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "texto fuente"),
            translationConfiguration: TranslationConfiguration(
                sourceMode: .sameAsTranscription,
                targetLanguage: .english,
                model: "translation-model",
                prompt: "Translate only"
            ),
            transcriptionConfiguration: TranscriptionConfiguration(language: .spanish)
        )
    }
}

private struct TranslationProviderCall: Equatable {
    let request: TextTranslationRequest
    let credentialAPIKey: String
}

private final class RequestFakeOpenAITextTranslationService: OpenAITextTranslationServing {
    private let result: Result<String, OpenAITextTranslationServiceError>
    private(set) var calls: [TranslationProviderCall] = []
    private(set) var cancelCount = 0

    init(result: Result<String, OpenAITextTranslationServiceError>) {
        self.result = result
    }

    func translate(
        _ request: TextTranslationRequest,
        credential: OpenAICredential
    ) async throws -> String {
        calls.append(
            TranslationProviderCall(
                request: request,
                credentialAPIKey: credential.apiKey
            )
        )
        return try result.get()
    }

    func cancelActiveTranslation() {
        cancelCount += 1
    }
}
