//
//  OpenAITextTranslationServiceTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/5/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct OpenAITextTranslationServiceTests {

    @Test func successfulOutputTextReturnsTranslationAndAuthorizedRequest() async throws {
        let loader = TranslationFakeURLLoader(
            result: .success(
                Data(#"{"output_text":"  Hello, world. \n"}"#.utf8),
                makeTranslationHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = TranslationFakeTimeoutSleeper()
        let service = makeService(
            loader: loader,
            sleeper: sleeper,
            requestTimeout: 4
        )
        let translationRequest = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "  Hola, mundo. \n"),
            translationConfiguration: TranslationConfiguration(
                targetLanguage: .english,
                model: "gpt-translation-test",
                prompt: "Prefer concise product UI wording."
            ),
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "unrelated-transcription-model",
                language: .spanish,
                freeformPrompt: "private transcription instructions"
            )
        )

        let translation = try await service.translate(
            translationRequest,
            credential: testCredential("sk-test-secret")
        )

        #expect(translation == "Hello, world.")
        #expect(loader.requests.count == 1)

        let request = try #require(loader.requests.first)
        #expect(request.url == OpenAITextTranslationService.defaultEndpointURL)
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 4)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody?.contains(Data("sk-test-secret".utf8)) == false)
        #expect(sleeper.sleepCalls == [4])

        let payload = try decodedRequestPayload(from: request)
        #expect(payload["model"] as? String == "gpt-translation-test")
        #expect(payload["tool_choice"] as? String == "none")
        #expect(payload["store"] as? Bool == false)
        #expect(payload["max_output_tokens"] as? Int == OpenAITextTranslationService.defaultMaxOutputTokens)
        let instructions = try #require(payload["instructions"] as? String)
        #expect(instructions.contains("language code es"))
        #expect(instructions.contains("language code en"))
        #expect(instructions.contains("Prefer concise product UI wording."))
        #expect(instructions.contains("private transcription instructions") == false)
        #expect(instructions.contains("unrelated-transcription-model") == false)
        #expect(instructions.contains("Russian") == false)

        let reasoning = try #require(payload["reasoning"] as? [String: Any])
        #expect(reasoning["effort"] as? String == "low")

        let text = try #require(payload["text"] as? [String: Any])
        #expect(text["verbosity"] as? String == "low")

        let input = try #require(payload["input"] as? [[String: Any]])
        let firstMessage = try #require(input.first)
        let content = try #require(firstMessage["content"] as? [[String: Any]])
        let firstContent = try #require(content.first)
        #expect(firstContent["type"] as? String == "input_text")
        #expect(firstContent["text"] as? String == "Hola, mundo.")
    }

    @Test func autoTranscriptionSourceOmitsSourceLanguageInstruction() async throws {
        let loader = TranslationFakeURLLoader(
            result: .success(
                Data(#"{"output_text":"Hello."}"#.utf8),
                makeTranslationHTTPResponse(statusCode: 200)
            )
        )
        let service = makeService(loader: loader)
        _ = try await service.translate(
            try configuredTranslationRequest(
                "Hola.",
                transcriptionConfiguration: TranscriptionConfiguration(language: .automatic)
            ),
            credential: testCredential()
        )

        let request = try #require(loader.requests.first)
        let payload = try decodedRequestPayload(from: request)
        let instructions = try #require(payload["instructions"] as? String)
        #expect(instructions.contains("Translate the user's transcript to language code en."))
        #expect(instructions.contains("from language code") == false)
    }

    @Test func outputArrayFallbackReturnsTranslationText() async throws {
        let service = makeService(
            loader: TranslationFakeURLLoader(
                result: .success(
                    Data(
                        #"""
                        {
                          "output": [
                            {
                              "type": "message",
                              "content": [
                                {"type": "output_text", "text": "Translated from array"}
                              ]
                            }
                          ]
                        }
                        """#.utf8
                    ),
                    makeTranslationHTTPResponse(statusCode: 200)
                )
            )
        )

        let translation = try await service.translate(
            try configuredTranslationRequest("сырой текст"),
            credential: testCredential()
        )

        #expect(translation == "Translated from array")
    }

    @Test func timeoutMapsToTranslationTimeout() async throws {
        let loader = TranslationFakeURLLoader(
            result: .delayedSuccess(
                Data(#"{"output_text":"late"}"#.utf8),
                makeTranslationHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = TranslationFakeTimeoutSleeper(mode: .timeoutImmediately)
        let service = makeService(loader: loader, sleeper: sleeper, requestTimeout: 2)

        await expectTranslationError(.timedOut) {
            try await service.translate(
                try configuredTranslationRequest("transcript"),
                credential: testCredential()
            )
        }

        #expect(loader.requests.count == 1)
        #expect(sleeper.sleepCalls == [2])
    }

    @Test func invalidProviderResponseIsRejected() async throws {
        let service = makeService(
            loader: TranslationFakeURLLoader(
                result: .success(
                    Data(#"{"output":[{"type":"message","content":[]}]}"#.utf8),
                    makeTranslationHTTPResponse(statusCode: 200)
                )
            )
        )

        await expectTranslationError(.emptyTranslation) {
            try await service.translate(
                try configuredTranslationRequest("transcript"),
                credential: testCredential()
            )
        }
    }

    @Test func providerStatusCodesMapToProductErrors() async throws {
        let cases: [(Int, OpenAITextTranslationServiceError)] = [
            (401, .invalidAPIKey),
            (429, .rateLimited),
            (500, .providerUnavailable),
            (418, .providerRejected(statusCode: 418)),
        ]

        for (statusCode, expectedError) in cases {
            let service = makeService(
                loader: TranslationFakeURLLoader(
                    result: .success(
                        Data(#"{"error":"unused"}"#.utf8),
                        makeTranslationHTTPResponse(statusCode: statusCode)
                    )
                )
            )

            await expectTranslationError(expectedError) {
                try await service.translate(
                    try configuredTranslationRequest("transcript"),
                    credential: testCredential()
                )
            }
        }
    }

    @Test func invalidLanguageConfigurationStopsBeforeNetworkRequest() async throws {
        let loader = TranslationFakeURLLoader(
            result: .success(Data(#"{"output_text":"unused"}"#.utf8), makeTranslationHTTPResponse(statusCode: 200))
        )
        let service = makeService(loader: loader)
        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "transcript"),
            translationConfiguration: TranslationConfiguration(
                sourceMode: .override,
                sourceLanguage: .custom,
                customSourceLanguageCode: "",
                targetLanguage: .english
            ),
            transcriptionConfiguration: .defaults
        )

        await expectTranslationError(.invalidLanguageConfiguration) {
            try await service.translate(
                request,
                credential: testCredential()
            )
        }

        #expect(loader.requests.isEmpty)
    }

    @Test func missingTargetLanguageStopsBeforeNetworkRequest() async throws {
        let loader = TranslationFakeURLLoader(
            result: .success(Data(#"{"output_text":"unused"}"#.utf8), makeTranslationHTTPResponse(statusCode: 200))
        )
        let service = makeService(loader: loader)

        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: "transcript"),
            translationConfiguration: .defaults,
            transcriptionConfiguration: .defaults
        )

        await expectTranslationError(.invalidLanguageConfiguration) {
            try await service.translate(
                request,
                credential: testCredential()
            )
        }

        #expect(loader.requests.isEmpty)
    }

    private func makeService(
        loader: TranslationFakeURLLoader,
        sleeper: TranslationFakeTimeoutSleeper = TranslationFakeTimeoutSleeper(),
        requestTimeout: TimeInterval = 5
    ) -> OpenAITextTranslationService {
        OpenAITextTranslationService(
            urlLoader: loader,
            timeoutSleeper: sleeper,
            requestTimeout: requestTimeout
        )
    }

    private func testCredential(_ apiKey: String = "sk-test") throws -> OpenAICredential {
        try OpenAICredential(apiKey: apiKey)
    }

    private func decodedRequestPayload(from request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }
}

private func configuredTranslationRequest(
    _ transcript: String,
    transcriptionConfiguration: TranscriptionConfiguration = .defaults
) throws -> TextTranslationRequest {
    TextTranslationRequest(
        acceptedTranscript: try AcceptedTranscript(rawText: transcript),
        translationConfiguration: TranslationConfiguration(targetLanguage: .english),
        transcriptionConfiguration: transcriptionConfiguration
    )
}

private func expectTranslationError(
    _ expectedError: OpenAITextTranslationServiceError,
    operation: () async throws -> String
) async {
    do {
        _ = try await operation()
        Issue.record("Expected OpenAITextTranslationServiceError.\(expectedError)")
    } catch let error as OpenAITextTranslationServiceError {
        #expect(error == expectedError)
    } catch {
        Issue.record("Expected OpenAITextTranslationServiceError, got \(error)")
    }
}

private func makeTranslationHTTPResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: OpenAITextTranslationService.defaultEndpointURL,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

private final class TranslationFakeURLLoader: URLLoading {
    enum Result {
        case success(Data, URLResponse)
        case delayedSuccess(Data, URLResponse)
        case failure(Error)
    }

    private let result: Result
    private(set) var requests: [URLRequest] = []

    init(result: Result) {
        self.result = result
    }

    func loadData(for request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)

        switch result {
        case let .success(data, response):
            return (data, response)
        case let .delayedSuccess(data, response):
            try await Task.sleep(nanoseconds: 1_000_000_000)
            return (data, response)
        case let .failure(error):
            throw error
        }
    }
}

private final class TranslationFakeTimeoutSleeper: TranscriptionTimeoutSleeping {
    enum Mode {
        case waitForCancellation
        case timeoutImmediately
    }

    private let mode: Mode
    private(set) var sleepCalls: [TimeInterval] = []

    init(mode: Mode = .waitForCancellation) {
        self.mode = mode
    }

    func sleep(seconds: TimeInterval) async throws {
        sleepCalls.append(seconds)

        switch mode {
        case .waitForCancellation:
            try await Task.sleep(nanoseconds: 1_000_000_000)
        case .timeoutImmediately:
            return
        }
    }
}
