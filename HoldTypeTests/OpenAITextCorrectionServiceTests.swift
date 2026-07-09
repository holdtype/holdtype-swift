//
//  OpenAITextCorrectionServiceTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/5/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct OpenAITextCorrectionServiceTests {

    @Test func successfulOutputTextReturnsCorrectionAndAuthorizedRequest() async throws {
        let loader = CorrectionFakeURLLoader(
            result: .success(
                Data(#"{"output_text":"  Corrected text. \n"}"#.utf8),
                makeCorrectionHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = CorrectionFakeTimeoutSleeper()
        let service = makeService(
            loader: loader,
            sleeper: sleeper,
            requestTimeout: 4
        )

        let correction = try await service.correct(
            "  hello text \n",
            settings: .defaults,
            credential: testCredential("sk-test-secret")
        )

        #expect(correction == "Corrected text.")
        #expect(loader.requests.count == 1)

        let request = try #require(loader.requests.first)
        #expect(request.url == OpenAITextCorrectionService.defaultEndpointURL)
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 4)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.httpBody?.contains(Data("sk-test-secret".utf8)) == false)
        #expect(sleeper.sleepCalls == [4])

        let payload = try decodedRequestPayload(from: request)
        #expect(payload["model"] as? String == "gpt-5.5")
        #expect(payload["instructions"] as? String == AppSettings.defaultTextCorrectionPrompt)
        #expect(payload["tool_choice"] as? String == "none")
        #expect(payload["store"] as? Bool == false)
        #expect(payload["max_output_tokens"] as? Int == OpenAITextCorrectionService.defaultMaxOutputTokens)

        let reasoning = try #require(payload["reasoning"] as? [String: Any])
        #expect(reasoning["effort"] as? String == "low")

        let text = try #require(payload["text"] as? [String: Any])
        #expect(text["verbosity"] as? String == "low")

        let input = try #require(payload["input"] as? [[String: Any]])
        let firstMessage = try #require(input.first)
        let content = try #require(firstMessage["content"] as? [[String: Any]])
        let firstContent = try #require(content.first)
        #expect(firstContent["type"] as? String == "input_text")
        #expect(firstContent["text"] as? String == "hello text")
    }

    @Test func outputArrayFallbackReturnsCorrectionText() async throws {
        let service = makeService(
            loader: CorrectionFakeURLLoader(
                result: .success(
                    Data(
                        #"""
                        {
                          "output": [
                            {
                              "type": "message",
                              "content": [
                                {"type": "output_text", "text": "Corrected from array"}
                              ]
                            }
                          ]
                        }
                        """#.utf8
                    ),
                    makeCorrectionHTTPResponse(statusCode: 200)
                )
            )
        )

        let correction = try await service.correct(
            "raw text",
            settings: .defaults,
            credential: testCredential()
        )

        #expect(correction == "Corrected from array")
    }

    @Test func timeoutMapsToTextCorrectionTimeout() async {
        let loader = CorrectionFakeURLLoader(
            result: .delayedSuccess(
                Data(#"{"output_text":"late"}"#.utf8),
                makeCorrectionHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = CorrectionFakeTimeoutSleeper(mode: .timeoutImmediately)
        let service = makeService(loader: loader, sleeper: sleeper, requestTimeout: 2)

        await expectCorrectionError(.timedOut) {
            try await service.correct(
                "transcript",
                settings: .defaults,
                credential: testCredential()
            )
        }

        #expect(loader.requests.count == 1)
        #expect(sleeper.sleepCalls == [2])
    }

    @Test func invalidProviderResponseIsRejected() async {
        let service = makeService(
            loader: CorrectionFakeURLLoader(
                result: .success(
                    Data(#"{"output":[{"type":"message","content":[]}]}"#.utf8),
                    makeCorrectionHTTPResponse(statusCode: 200)
                )
            )
        )

        await expectCorrectionError(.emptyCorrection) {
            try await service.correct(
                "transcript",
                settings: .defaults,
                credential: testCredential()
            )
        }
    }

    @Test func providerStatusCodesMapToProductErrors() async {
        let cases: [(Int, OpenAITextCorrectionServiceError)] = [
            (401, .invalidAPIKey),
            (429, .rateLimited),
            (500, .providerUnavailable),
            (418, .providerRejected(statusCode: 418)),
        ]

        for (statusCode, expectedError) in cases {
            let service = makeService(
                loader: CorrectionFakeURLLoader(
                    result: .success(Data(#"{"error":"unused"}"#.utf8), makeCorrectionHTTPResponse(statusCode: statusCode))
                )
            )

            await expectCorrectionError(expectedError) {
                try await service.correct(
                    "transcript",
                    settings: .defaults,
                    credential: testCredential()
                )
            }
        }
    }

    private func makeService(
        loader: CorrectionFakeURLLoader,
        sleeper: CorrectionFakeTimeoutSleeper = CorrectionFakeTimeoutSleeper(),
        requestTimeout: TimeInterval = 5
    ) -> OpenAITextCorrectionService {
        OpenAITextCorrectionService(
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

private func expectCorrectionError(
    _ expectedError: OpenAITextCorrectionServiceError,
    operation: () async throws -> String
) async {
    do {
        _ = try await operation()
        Issue.record("Expected OpenAITextCorrectionServiceError.\(expectedError)")
    } catch let error as OpenAITextCorrectionServiceError {
        #expect(error == expectedError)
    } catch {
        Issue.record("Expected OpenAITextCorrectionServiceError, got \(error)")
    }
}

private func makeCorrectionHTTPResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: OpenAITextCorrectionService.defaultEndpointURL,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

private final class CorrectionFakeURLLoader: URLLoading {
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

private final class CorrectionFakeTimeoutSleeper: TranscriptionTimeoutSleeping {
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
