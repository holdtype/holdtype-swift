//
//  OpenAITextTransformationServiceTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/23/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypeOpenAI

struct OpenAITextTransformationServiceTests {
    @Test func requestProjectsExactValuesAndResponsePreservesWhitespace() async throws {
        let expectedOutput = "\n  Short result.\t \n"
        let loader = TransformationFakeURLLoader(
            result: .success(
                try responseData(output: expectedOutput),
                makeTransformationHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = TransformationFakeTimeoutSleeper()
        let service = makeService(
            loader: loader,
            sleeper: sleeper,
            requestTimeout: 4
        )
        let source = "\n  Original — text.\t \n"
        let prompt = "  Make this shorter without trimming its edges.\n"
        let transformationRequest = try TextTransformationRequest(
            sourceText: source,
            prompt: prompt,
            model: "gpt-fix-test"
        )

        let output = try await service.transform(
            transformationRequest,
            credential: testCredential("sk-test-secret")
        )

        #expect(output == expectedOutput)
        #expect(loader.requests.count == 1)

        let request = try #require(loader.requests.first)
        #expect(request.url == OpenAITextTransformationService.defaultEndpointURL)
        #expect(request.httpMethod == "POST")
        #expect(request.timeoutInterval == 4)
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret")
        #expect(request.httpBody?.contains(Data("sk-test-secret".utf8)) == false)
        #expect(sleeper.sleepCalls == [4])

        let payload = try decodedRequestPayload(from: request)
        #expect(payload["model"] as? String == "gpt-fix-test")
        #expect(payload["instructions"] as? String == prompt)
        #expect(payload["tool_choice"] as? String == "none")
        #expect(payload["store"] as? Bool == false)
        #expect(
            payload["max_output_tokens"] as? Int
                == OpenAITextTransformationService.defaultMaxOutputTokens
        )

        let reasoning = try #require(payload["reasoning"] as? [String: Any])
        #expect(reasoning["effort"] as? String == "low")
        let text = try #require(payload["text"] as? [String: Any])
        #expect(text["verbosity"] as? String == "low")
        let format = try #require(text["format"] as? [String: Any])
        #expect(format["type"] as? String == "text")

        let input = try #require(payload["input"] as? [[String: Any]])
        let message = try #require(input.first)
        #expect(message["role"] as? String == "user")
        let content = try #require(message["content"] as? [[String: Any]])
        let firstContent = try #require(content.first)
        #expect(firstContent["type"] as? String == "input_text")
        #expect(firstContent["text"] as? String == source)
    }

    @Test func outputArrayFallbackPreservesExactText() async throws {
        let expectedOutput = "  Array result\n"
        let response = try JSONSerialization.data(
            withJSONObject: [
                "output": [
                    [
                        "type": "message",
                        "content": [
                            ["type": "output_text", "text": expectedOutput],
                        ],
                    ],
                ],
            ]
        )
        let service = makeService(
            loader: TransformationFakeURLLoader(
                result: .success(
                    response,
                    makeTransformationHTTPResponse(statusCode: 200)
                )
            )
        )

        let output = try await service.transform(
            makeRequest(),
            credential: testCredential()
        )

        #expect(output == expectedOutput)
    }

    @Test func whitespaceOnlyAndMissingOutputAreRejected() async throws {
        for response in [
            try responseData(output: " \n\t "),
            Data(#"{"output":[{"type":"message","content":[]}]}"#.utf8),
        ] {
            let service = makeService(
                loader: TransformationFakeURLLoader(
                    result: .success(
                        response,
                        makeTransformationHTTPResponse(statusCode: 200)
                    )
                )
            )

            await expectTransformationError(.emptyOutput) {
                try await service.transform(
                    makeRequest(),
                    credential: testCredential()
                )
            }
        }
    }

    @Test func UTF8OutputBoundaryIsExactAndNeverTruncates() async throws {
        let maximumByteCount = OpenAITextTransformationService.maximumOutputUTF8ByteCount
        let exactLimitOutput = String(
            repeating: "é",
            count: maximumByteCount / 2
        )
        let exactLimitService = makeService(
            loader: TransformationFakeURLLoader(
                result: .success(
                    try responseData(output: exactLimitOutput),
                    makeTransformationHTTPResponse(statusCode: 200)
                )
            )
        )
        let acceptedOutput = try await exactLimitService.transform(
            makeRequest(),
            credential: testCredential()
        )
        #expect(acceptedOutput == exactLimitOutput)

        let oversizedOutput = exactLimitOutput + "x"
        let oversizedService = makeService(
            loader: TransformationFakeURLLoader(
                result: .success(
                    try responseData(output: oversizedOutput),
                    makeTransformationHTTPResponse(statusCode: 200)
                )
            )
        )
        await expectTransformationError(
            .outputTooLarge(maximumUTF8ByteCount: maximumByteCount)
        ) {
            try await oversizedService.transform(
                makeRequest(),
                credential: testCredential()
            )
        }
    }

    @Test func malformedAndNonHTTPResponsesAreRejected() async throws {
        let nonHTTPResponse = URLResponse(
            url: OpenAITextTransformationService.defaultEndpointURL,
            mimeType: "application/json",
            expectedContentLength: 0,
            textEncodingName: nil
        )
        let cases: [(Data, URLResponse)] = [
            (Data("not-json".utf8), makeTransformationHTTPResponse(statusCode: 200)),
            (try responseData(output: "valid"), nonHTTPResponse),
        ]

        for (data, response) in cases {
            let service = makeService(
                loader: TransformationFakeURLLoader(
                    result: .success(data, response)
                )
            )

            await expectTransformationError(.invalidResponse) {
                try await service.transform(
                    makeRequest(),
                    credential: testCredential()
                )
            }
        }
    }

    @Test func providerStatusCodesMapToTypedErrors() async throws {
        let cases: [(Int, OpenAITextTransformationServiceError)] = [
            (400, .badRequest),
            (401, .invalidAPIKey),
            (403, .invalidAPIKey),
            (408, .timedOut),
            (429, .rateLimited),
            (503, .providerUnavailable),
            (418, .providerRejected(statusCode: 418)),
        ]

        for (statusCode, expectedError) in cases {
            let service = makeService(
                loader: TransformationFakeURLLoader(
                    result: .success(
                        Data(#"{"error":"unused"}"#.utf8),
                        makeTransformationHTTPResponse(statusCode: statusCode)
                    )
                )
            )

            await expectTransformationError(expectedError) {
                try await service.transform(
                    makeRequest(),
                    credential: testCredential()
                )
            }
        }
    }

    @Test func transportErrorsMapWithoutExposingProviderDetails() async throws {
        let cases: [(URLError, OpenAITextTransformationServiceError)] = [
            (URLError(.notConnectedToInternet), .networkUnavailable),
            (URLError(.networkConnectionLost), .networkUnavailable),
            (URLError(.timedOut), .timedOut),
            (URLError(.cancelled), .cancelled),
            (URLError(.badServerResponse), .networkFailure),
        ]

        for (transportError, expectedError) in cases {
            let service = makeService(
                loader: TransformationFakeURLLoader(
                    result: .failure(transportError)
                )
            )

            await expectTransformationError(expectedError) {
                try await service.transform(
                    makeRequest(),
                    credential: testCredential()
                )
            }
        }
    }

    private func makeService(
        loader: any URLLoading,
        sleeper: TransformationFakeTimeoutSleeper = TransformationFakeTimeoutSleeper(),
        requestTimeout: TimeInterval = 5
    ) -> OpenAITextTransformationService {
        OpenAITextTransformationService(
            endpointURL: OpenAITextTransformationService.defaultEndpointURL,
            urlLoader: loader,
            timeoutSleeper: sleeper,
            requestTimeout: requestTimeout
        )
    }

    private func makeRequest() throws -> TextTransformationRequest {
        try TextTransformationRequest(
            sourceText: "Source text",
            prompt: "Transform it.",
            model: "gpt-test"
        )
    }

    private func testCredential(_ apiKey: String = "sk-test") throws -> OpenAICredential {
        try OpenAICredential(apiKey: apiKey)
    }

    private func decodedRequestPayload(from request: URLRequest) throws -> [String: Any] {
        let body = try #require(request.httpBody)
        return try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    }

    private func responseData(output: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["output_text": output])
    }
}
