//
//  OpenAITextTransformationCancellationTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/23/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypeOpenAI

struct OpenAITextTransformationCancellationTests {
    @Test func timeoutIsBoundedAndCancelsTransport() async throws {
        let loader = TransformationFakeURLLoader(
            result: .delayedSuccess(
                Data(#"{"output_text":"late"}"#.utf8),
                makeTransformationHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = TransformationFakeTimeoutSleeper(mode: .timeoutImmediately)
        let service = makeService(
            loader: loader,
            sleeper: sleeper,
            requestTimeout: 2
        )

        await expectTransformationError(.timedOut) {
            try await service.transform(
                makeRequest(),
                credential: testCredential()
            )
        }

        #expect(loader.requests.count == 1)
        #expect(loader.requests.first?.timeoutInterval == 2)
        #expect(sleeper.sleepCalls == [2])
        try await loader.waitForCancellationCount(1)
        #expect(loader.cancellationCount == 1)
    }

    @Test func defaultTimeoutIsTwentySeconds() async throws {
        #expect(OpenAITextTransformationService.defaultRequestTimeout == 20)

        let loader = TransformationFakeURLLoader(
            result: .success(
                Data(#"{"output_text":"result"}"#.utf8),
                makeTransformationHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = TransformationFakeTimeoutSleeper()
        let service = makeService(
            loader: loader,
            sleeper: sleeper,
            requestTimeout: 0
        )

        _ = try await service.transform(
            makeRequest(),
            credential: testCredential()
        )

        #expect(loader.requests.first?.timeoutInterval == 20)
        #expect(sleeper.sleepCalls == [20])
    }

    @Test func explicitCancellationIsImmediateAndIdempotent() async throws {
        let loader = TransformationFakeURLLoader(
            result: .delayedSuccess(
                Data(#"{"output_text":"late"}"#.utf8),
                makeTransformationHTTPResponse(statusCode: 200)
            )
        )
        let service = makeService(loader: loader)
        let request = try makeRequest()
        let credential = try testCredential()

        service.cancelActiveTransformation()
        let transformation = Task {
            try await service.transform(request, credential: credential)
        }
        try await loader.waitForRequestCount(1)

        service.cancelActiveTransformation()
        service.cancelActiveTransformation()

        await expectTransformationError(.cancelled) {
            try await transformation.value
        }
        try await loader.waitForCancellationCount(1)
        #expect(loader.cancellationCount == 1)

        service.cancelActiveTransformation()
        #expect(loader.cancellationCount == 1)
    }

    @Test func parentTaskCancellationCancelsTransport() async throws {
        let loader = TransformationFakeURLLoader(
            result: .delayedSuccess(
                Data(#"{"output_text":"late"}"#.utf8),
                makeTransformationHTTPResponse(statusCode: 200)
            )
        )
        let service = makeService(loader: loader)
        let request = try makeRequest()
        let credential = try testCredential()
        let transformation = Task {
            try await service.transform(request, credential: credential)
        }
        try await loader.waitForRequestCount(1)

        transformation.cancel()

        await expectTransformationError(.cancelled) {
            try await transformation.value
        }
        try await loader.waitForCancellationCount(1)
        #expect(loader.cancellationCount == 1)
    }

    @Test func newerRequestCancelsOlderRequestInsteadOfQueueingIt() async throws {
        let loader = TransformationSequencedURLLoader(
            steps: [
                .waitForCancellation,
                .success(
                    Data(#"{"output_text":"fresh"}"#.utf8),
                    makeTransformationHTTPResponse(statusCode: 200)
                ),
            ]
        )
        let service = makeService(loader: loader)
        let request = try makeRequest()
        let credential = try testCredential()
        let older = Task {
            try await service.transform(request, credential: credential)
        }
        try await loader.waitForRequestCount(1)

        let newer = Task {
            try await service.transform(request, credential: credential)
        }
        try await loader.waitForRequestCount(2)

        await expectTransformationError(.cancelled) {
            try await older.value
        }
        #expect(try await newer.value == "fresh")
        try await loader.waitForCancellationCount(1)
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
            sourceText: "Source",
            prompt: "Transform it.",
            model: "gpt-test"
        )
    }

    private func testCredential() throws -> OpenAICredential {
        try OpenAICredential(apiKey: "sk-test")
    }
}
