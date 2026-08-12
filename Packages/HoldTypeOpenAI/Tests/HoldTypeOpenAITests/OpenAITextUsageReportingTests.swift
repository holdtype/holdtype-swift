import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypeOpenAI

struct OpenAITextUsageReportingTests {
    @Test func providerUsageIsReportedBeforeLocalOutputValidation() async throws {
        let collector = TextUsageObservationCollector()
        let response = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-5.4-mini-2026-08-01",
            "output_text": "   ",
            "usage": [
                "input_tokens": 120,
                "input_tokens_details": ["cached_tokens": 20],
                "output_tokens": 30,
                "output_tokens_details": ["reasoning_tokens": 10],
            ],
        ])
        let service = makeService(response: response, collector: collector)

        await expectTransformationError(.emptyOutput) {
            try await service.transform(makeRequest(), credential: makeCredential())
        }

        let observations = await collector.observations
        let usage = try #require(observations.first?.measuredUsage)
        #expect(observations.count == 1)
        #expect(usage.model == "gpt-5.4-mini-2026-08-01")
        #expect(usage.inputTokens == 120)
        #expect(usage.cachedInputTokens == 20)
        #expect(usage.outputTokens == 30)
        #expect(usage.reasoningTokens == 10)
    }

    @Test func successfulResponseWithoutUsageReportsUnavailable() async throws {
        let collector = TextUsageObservationCollector()
        let response = try JSONSerialization.data(withJSONObject: [
            "model": "gpt-test",
            "output_text": "Valid result",
        ])
        let service = makeService(response: response, collector: collector)

        let result = try await service.transform(makeRequest(), credential: makeCredential())

        #expect(result == "Valid result")
        #expect(await collector.observations == [.unavailable])
    }

    @Test func correctionReportsProviderUsage() async throws {
        let collector = TextUsageObservationCollector()
        let response = try measuredResponse(output: "Corrected", model: "gpt-5.5-2026-04-23")
        let service = OpenAITextCorrectionService(
            endpointURL: OpenAITextCorrectionService.defaultEndpointURL,
            urlLoader: makeLoader(response),
            timeoutSleeper: TransformationFakeTimeoutSleeper(),
            usageReporter: { observation in await collector.append(observation) }
        )

        _ = try await service.correct(
            try AcceptedTranscript(rawText: "raw"),
            configuration: .defaults,
            credential: makeCredential()
        )

        #expect(await collector.observations.first?.measuredUsage?.model == "gpt-5.5-2026-04-23")
    }

    @Test func translationReportsProviderUsage() async throws {
        let collector = TextUsageObservationCollector()
        let response = try measuredResponse(output: "Translated", model: "gpt-5.4-mini-2026-03-17")
        let service = OpenAITextTranslationService(
            endpointURL: OpenAITextTranslationService.defaultEndpointURL,
            urlLoader: makeLoader(response),
            timeoutSleeper: TransformationFakeTimeoutSleeper(),
            usageReporter: { observation in await collector.append(observation) }
        )
        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "Source"),
            translationConfiguration: TranslationConfiguration(
                targetLanguage: .english,
                model: "gpt-5.4-mini"
            ),
            transcriptionConfiguration: TranscriptionConfiguration()
        )

        _ = try await service.translate(request, credential: makeCredential())

        #expect(await collector.observations.first?.measuredUsage?.model == "gpt-5.4-mini-2026-03-17")
    }

    private func makeService(
        response: Data,
        collector: TextUsageObservationCollector
    ) -> OpenAITextTransformationService {
        OpenAITextTransformationService(
            endpointURL: OpenAITextTransformationService.defaultEndpointURL,
            urlLoader: TransformationFakeURLLoader(
                result: .success(response, makeTransformationHTTPResponse(statusCode: 200))
            ),
            usageReporter: { observation in
                await collector.append(observation)
            }
        )
    }

    private func makeRequest() throws -> TextTransformationRequest {
        try TextTransformationRequest(
            sourceText: "Source",
            prompt: "Transform it.",
            model: "gpt-requested"
        )
    }

    private func makeCredential() throws -> OpenAICredential {
        try OpenAICredential(apiKey: "sk-test")
    }

    private func makeLoader(_ response: Data) -> TransformationFakeURLLoader {
        TransformationFakeURLLoader(
            result: .success(response, makeTransformationHTTPResponse(statusCode: 200))
        )
    }

    private func measuredResponse(output: String, model: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "model": model,
            "output_text": output,
            "usage": [
                "input_tokens": 120,
                "input_tokens_details": ["cached_tokens": 20],
                "output_tokens": 30,
                "output_tokens_details": ["reasoning_tokens": 10],
            ],
        ])
    }
}

private actor TextUsageObservationCollector {
    private(set) var observations: [OpenAITextUsageObservation] = []

    func append(_ observation: OpenAITextUsageObservation) {
        observations.append(observation)
    }
}

private extension OpenAITextUsageObservation {
    var measuredUsage: OpenAITextResponseUsage? {
        guard case .measured(let usage) = self else { return nil }
        return usage
    }
}
