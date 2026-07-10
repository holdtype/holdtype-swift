import HoldTypeDomain
import Testing
@testable import HoldType

struct TranscriptTextCorrectionServiceRequestTests {
    @Test func disabledCorrectionRunsLocalPipelineWithoutProviderCall() async throws {
        let provider = RequestFakeOpenAITextCorrectionService(result: .success("unexpected"))
        let service = TranscriptTextCorrectionService(openAITextCorrectionService: provider)
        let request = TextCorrectionRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "“AI-looking”—emoji smile"),
            correctionConfiguration: TextCorrectionConfiguration(isEnabled: false),
            postProcessingConfiguration: orderedPostProcessingConfiguration()
        )

        let output = try await service.correct(request, credential: testCredential())

        #expect(output == "\"human\" - 🙂")
        #expect(provider.calls.isEmpty)
    }

    @Test func enabledCorrectionPassesOnlyProviderInputsThenRunsLocalPipeline() async throws {
        let provider = RequestFakeOpenAITextCorrectionService(
            result: .success("“AI-looking”—emoji smile")
        )
        let service = TranscriptTextCorrectionService(openAITextCorrectionService: provider)
        let correctionConfiguration = TextCorrectionConfiguration(
            isEnabled: true,
            modelPreset: .custom,
            customModel: "gpt-correction-test",
            prompt: "Minimal edits only"
        )
        let request = TextCorrectionRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "uncorrected source"),
            correctionConfiguration: correctionConfiguration,
            postProcessingConfiguration: orderedPostProcessingConfiguration()
        )

        let output = try await service.correct(
            request,
            credential: testCredential("sk-correction-request")
        )

        #expect(output == "\"human\" - 🙂")
        #expect(
            provider.calls == [
                RequestCorrectionProviderCall(
                    transcript: request.acceptedTranscript,
                    configuration: correctionConfiguration,
                    credentialAPIKey: "sk-correction-request"
                )
            ]
        )
    }

    @Test func failedEmptyAndUnsafeCorrectionsFailOpenBeforeLocalPipeline() async throws {
        let cases: [Result<String, OpenAITextCorrectionServiceError>] = [
            .failure(.timedOut),
            .success(""),
            .success("tiny"),
            .success(String(repeating: "expanded correction ", count: 20)),
        ]
        let originalText = "This original transcript is long enough for safety checks."
        let postProcessingConfiguration = TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: false,
            emojiCommands: EmojiCommandsConfiguration(isEnabled: false),
            textReplacementRules: [
                TextReplacementRule(search: "original", replacement: "fallback")
            ]
        )

        for result in cases {
            let provider = RequestFakeOpenAITextCorrectionService(result: result)
            let service = TranscriptTextCorrectionService(openAITextCorrectionService: provider)
            let request = TextCorrectionRequest(
                acceptedTranscript: try AcceptedTranscript(rawText: originalText),
                correctionConfiguration: TextCorrectionConfiguration(isEnabled: true),
                postProcessingConfiguration: postProcessingConfiguration
            )

            let output = try await service.correct(request, credential: testCredential())

            #expect(output == "This fallback transcript is long enough for safety checks.")
            #expect(provider.calls.count == 1)
        }
    }

    @Test func cancellationDelegatesToProviderAdapter() {
        let provider = RequestFakeOpenAITextCorrectionService(result: .success("unused"))
        let service = TranscriptTextCorrectionService(openAITextCorrectionService: provider)

        service.cancelActiveCorrection()

        #expect(provider.cancelCount == 1)
    }

    private func orderedPostProcessingConfiguration() -> TranscriptPostProcessingConfiguration {
        TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: true,
            emojiCommands: .defaults,
            textReplacementRules: [
                TextReplacementRule(search: "AI-looking", replacement: "plain"),
                TextReplacementRule(search: "plain", replacement: "human"),
            ]
        )
    }

    private func testCredential(_ apiKey: String = "sk-correction-test") throws -> OpenAICredential {
        try OpenAICredential(apiKey: apiKey)
    }
}

private struct RequestCorrectionProviderCall: Equatable {
    let transcript: AcceptedTranscript
    let configuration: TextCorrectionConfiguration
    let credentialAPIKey: String
}

private final class RequestFakeOpenAITextCorrectionService: OpenAITextCorrectionServing {
    private let result: Result<String, OpenAITextCorrectionServiceError>
    private(set) var calls: [RequestCorrectionProviderCall] = []
    private(set) var cancelCount = 0

    init(result: Result<String, OpenAITextCorrectionServiceError>) {
        self.result = result
    }

    func correct(
        _ transcript: AcceptedTranscript,
        configuration: TextCorrectionConfiguration,
        credential: OpenAICredential
    ) async throws -> String {
        calls.append(
            RequestCorrectionProviderCall(
                transcript: transcript,
                configuration: configuration,
                credentialAPIKey: credential.apiKey
            )
        )
        return try result.get()
    }

    func cancelActiveCorrection() {
        cancelCount += 1
    }
}
