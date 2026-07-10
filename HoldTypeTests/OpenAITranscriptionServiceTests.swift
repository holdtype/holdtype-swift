//
//  OpenAITranscriptionServiceTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/21/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct OpenAITranscriptionServiceTests {

    @Test func successfulResponseReturnsTrimmedTranscriptAndAuthorizedRequest() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = FakeURLLoader(
            result: .success(
                Data(#"{"text":"  Hello from HoldType \n"}"#.utf8),
                makeHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = FakeTimeoutSleeper()
        let service = makeService(
            loader: loader,
            sleeper: sleeper,
            requestTimeout: 7
        )

        let transcript = try await service.transcribe(
            try makeTranscriptionRequest(audioFileURL: audioFileURL),
            credential: testCredential("sk-test-secret")
        )

        #expect(transcript == "Hello from HoldType")
        #expect(loader.requests.count == 1)

        let request = try #require(loader.requests.first)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test-secret")
        #expect(request.timeoutInterval == 7)
        #expect(request.httpBody?.contains(Data("sk-test-secret".utf8)) == false)
        #expect(sleeper.sleepCalls == [7])
    }

    @Test func boundedTimeoutMapsToUserVisibleTimeoutError() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = FakeURLLoader(
            result: .delayedSuccess(
                Data(#"{"text":"late"}"#.utf8),
                makeHTTPResponse(statusCode: 200)
            )
        )
        let sleeper = FakeTimeoutSleeper(mode: .timeoutImmediately)
        let service = makeService(loader: loader, sleeper: sleeper, requestTimeout: 3)

        await expectTranscriptionError(.timedOut) {
            try await service.transcribe(
                try makeTranscriptionRequest(audioFileURL: audioFileURL),
                credential: testCredential()
            )
        }

        #expect(loader.requests.count == 1)
        #expect(loader.requests.first?.timeoutInterval == 3)
        #expect(sleeper.sleepCalls == [3])
    }

    @Test func explicitCancellationCancelsTransportAndIsIdempotent() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = ControlledURLLoader(cancellationBehaviors: [.failImmediately])
        let service = makeService(loader: loader)
        let request = try makeTranscriptionRequest(audioFileURL: audioFileURL)
        let credential = try testCredential()

        service.cancelActiveTranscription()
        let transcription = Task {
            try await service.transcribe(request, credential: credential)
        }
        try await loader.waitForRequestCount(1)

        service.cancelActiveTranscription()
        service.cancelActiveTranscription()

        await expectTranscriptionError(.cancelled) {
            try await transcription.value
        }
        try await loader.waitForCancellation(ofRequestAt: 0)
        #expect(loader.cancellationCount(forRequestAt: 0) == 1)

        service.cancelActiveTranscription()
        #expect(loader.cancellationCount(forRequestAt: 0) == 1)
    }

    @Test func cancelledLateLoaderResponseCannotBecomeTranscript() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = ControlledURLLoader(cancellationBehaviors: [.awaitResponse])
        let service = makeService(loader: loader)
        let request = try makeTranscriptionRequest(audioFileURL: audioFileURL)
        let credential = try testCredential()
        let transcription = Task {
            try await service.transcribe(request, credential: credential)
        }
        try await loader.waitForRequestCount(1)

        service.cancelActiveTranscription()
        try await loader.waitForCancellation(ofRequestAt: 0)
        loader.resolveRequest(
            at: 0,
            data: Data(#"{"text":"late transcript"}"#.utf8),
            response: makeHTTPResponse(statusCode: 200)
        )

        await expectTranscriptionError(.cancelled) {
            try await transcription.value
        }
    }

    @Test func parentTaskCancellationCancelsTransport() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = ControlledURLLoader(cancellationBehaviors: [.failImmediately])
        let service = makeService(loader: loader)
        let request = try makeTranscriptionRequest(audioFileURL: audioFileURL)
        let credential = try testCredential()
        let transcription = Task {
            try await service.transcribe(request, credential: credential)
        }
        try await loader.waitForRequestCount(1)

        transcription.cancel()

        await expectTranscriptionError(.cancelled) {
            try await transcription.value
        }
        try await loader.waitForCancellation(ofRequestAt: 0)
        #expect(loader.cancellationCount(forRequestAt: 0) == 1)
    }

    @Test func timeoutCancelsTransportWithoutChangingTimeoutError() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = ControlledURLLoader(cancellationBehaviors: [.failImmediately])
        let service = makeService(
            loader: loader,
            sleeper: FakeTimeoutSleeper(mode: .timeoutImmediately),
            requestTimeout: 3
        )

        await expectTranscriptionError(.timedOut) {
            try await service.transcribe(
                try makeTranscriptionRequest(audioFileURL: audioFileURL),
                credential: testCredential()
            )
        }

        try await loader.waitForRequestCount(1)
        try await loader.waitForCancellation(ofRequestAt: 0)
        #expect(loader.cancellationCount(forRequestAt: 0) == 1)
    }

    @Test func olderRequestCleanupCannotClearNewerRequestAndNextRequestCanSucceed() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = ControlledURLLoader(
            cancellationBehaviors: [.awaitResponse, .awaitResponse, .failImmediately]
        )
        let service = makeService(loader: loader)
        let request = try makeTranscriptionRequest(audioFileURL: audioFileURL)
        let credential = try testCredential()
        let olderTranscription = Task {
            try await service.transcribe(request, credential: credential)
        }
        try await loader.waitForRequestCount(1)

        let newerTranscription = Task {
            try await service.transcribe(request, credential: credential)
        }
        try await loader.waitForRequestCount(2)
        try await loader.waitForCancellation(ofRequestAt: 0)
        loader.resolveRequest(
            at: 0,
            data: Data(#"{"text":"stale transcript"}"#.utf8),
            response: makeHTTPResponse(statusCode: 200)
        )
        await expectTranscriptionError(.cancelled) {
            try await olderTranscription.value
        }

        service.cancelActiveTranscription()
        try await loader.waitForCancellation(ofRequestAt: 1)
        loader.resolveRequest(
            at: 1,
            data: Data(#"{"text":"also stale"}"#.utf8),
            response: makeHTTPResponse(statusCode: 200)
        )
        await expectTranscriptionError(.cancelled) {
            try await newerTranscription.value
        }

        let finalTranscription = Task {
            try await service.transcribe(request, credential: credential)
        }
        try await loader.waitForRequestCount(3)
        loader.resolveRequest(
            at: 2,
            data: Data(#"{"text":"independent success"}"#.utf8),
            response: makeHTTPResponse(statusCode: 200)
        )

        #expect(try await finalTranscription.value == "independent success")
    }

    @Test func urlSessionTimeoutErrorMapsToUserVisibleTimeoutError() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let service = makeService(loader: FakeURLLoader(result: .failure(URLError(.timedOut))))

        await expectTranscriptionError(.timedOut) {
            try await service.transcribe(
                try makeTranscriptionRequest(audioFileURL: audioFileURL),
                credential: testCredential()
            )
        }
    }

    @Test func urlLoadingFailuresMapToProductErrors() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let cases: [(URLError.Code, OpenAITranscriptionServiceError)] = [
            (.notConnectedToInternet, .networkUnavailable),
            (.networkConnectionLost, .networkUnavailable),
            (.cannotFindHost, .networkUnavailable),
            (.cannotConnectToHost, .networkUnavailable),
            (.cancelled, .cancelled),
            (.badServerResponse, .networkFailure),
        ]

        for (urlErrorCode, expectedError) in cases {
            let service = makeService(loader: FakeURLLoader(result: .failure(URLError(urlErrorCode))))

            await expectTranscriptionError(expectedError) {
                try await service.transcribe(
                    try makeTranscriptionRequest(audioFileURL: audioFileURL),
                    credential: testCredential()
                )
            }
        }
    }

    @Test func providerStatusCodesMapToProductErrors() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let cases: [(Int, OpenAITranscriptionServiceError)] = [
            (401, .invalidAPIKey),
            (403, .invalidAPIKey),
            (408, .timedOut),
            (429, .rateLimited),
            (400, .badRequest),
            (404, .badRequest),
            (413, .badRequest),
            (415, .badRequest),
            (422, .badRequest),
            (500, .providerUnavailable),
            (503, .providerUnavailable),
            (418, .providerRejected(statusCode: 418)),
        ]

        for (statusCode, expectedError) in cases {
            let service = makeService(
                loader: FakeURLLoader(
                    result: .success(Data(#"{"error":"not used"}"#.utf8), makeHTTPResponse(statusCode: statusCode))
                )
            )

            await expectTranscriptionError(expectedError) {
                try await service.transcribe(
                    try makeTranscriptionRequest(audioFileURL: audioFileURL),
                    credential: testCredential()
                )
            }
        }
    }

    @Test func emptyTranscriptIsRejected() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let service = makeService(
            loader: FakeURLLoader(
                result: .success(Data(#"{"text":"   \n"}"#.utf8), makeHTTPResponse(statusCode: 200))
            )
        )

        await expectTranscriptionError(.emptyTranscript) {
            try await service.transcribe(
                try makeTranscriptionRequest(audioFileURL: audioFileURL),
                credential: testCredential()
            )
        }
    }

    @Test func dictionaryEchoTranscriptIsRejected() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        var settings = AppSettings.defaults
        settings.customDictionary = ["OpenWhispr", "Parakeet", "Alcahest"]

        let service = makeService(
            loader: FakeURLLoader(
                result: .success(
                    Data(#"{"text":"OpenWhispr, Parakeet, Alcahest."}"#.utf8),
                    makeHTTPResponse(statusCode: 200)
                )
            )
        )

        await expectTranscriptionError(.dictionaryEcho) {
            try await service.transcribe(
                try makeTranscriptionRequest(
                    audioFileURL: audioFileURL,
                    settings: settings
                ),
                credential: testCredential()
            )
        }
    }

    @Test func dictionaryEchoFilterDistinguishesEchoFromLegitimateSpeech() {
        #expect(
            DictionaryEchoFilter.matches(
                transcript: "OpenWhispr, Parakeet, Alcahest",
                dictionaryPrompt: "OpenWhispr, Parakeet, Alcahest"
            )
        )
        #expect(
            DictionaryEchoFilter.matches(
                transcript: "openwhispr parakeet alcahest",
                dictionaryPrompt: "OpenWhispr, Parakeet, Alcahest"
            )
        )
        #expect(
            DictionaryEchoFilter.matches(
                transcript: "I just installed OpenWhispr and it works great",
                dictionaryPrompt: "OpenWhispr, Parakeet, Alcahest"
            ) == false
        )
        #expect(DictionaryEchoFilter.matches(transcript: nil, dictionaryPrompt: "OpenWhispr") == false)
        #expect(DictionaryEchoFilter.matches(transcript: "OpenWhispr", dictionaryPrompt: nil) == false)
    }

    @Test func activeTextContextEchoTranscriptIsRejected() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        var settings = AppSettings.defaults
        settings.useActiveTextContext = true
        let context = try #require(
            TranscriptionPromptContext("We are already writing about contextual dictation quality.")
        )
        let service = makeService(
            loader: FakeURLLoader(
                result: .success(
                    Data(#"{"text":"already writing about contextual dictation"}"#.utf8),
                    makeHTTPResponse(statusCode: 200)
                )
            )
        )

        await expectTranscriptionError(.contextEcho) {
            try await service.transcribe(
                try makeTranscriptionRequest(
                    audioFileURL: audioFileURL,
                    settings: settings,
                    context: context
                ),
                credential: testCredential()
            )
        }
    }

    @Test func disabledNearbyContextIsAbsentFromPromptAndEchoGuard() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        var settings = AppSettings.defaults
        settings.emojiCommandsEnabled = false
        settings.useActiveTextContext = false
        let context = try #require(
            TranscriptionPromptContext("We are already writing about contextual dictation quality.")
        )
        let loader = FakeURLLoader(
            result: .success(
                Data(#"{"text":"already writing about contextual dictation"}"#.utf8),
                makeHTTPResponse(statusCode: 200)
            )
        )
        let service = makeService(loader: loader)

        let transcript = try await service.transcribe(
            try makeTranscriptionRequest(
                audioFileURL: audioFileURL,
                settings: settings,
                context: context
            ),
            credential: testCredential()
        )

        #expect(transcript == "already writing about contextual dictation")
        let request = try #require(loader.requests.first)
        let body = try #require(request.httpBody)
        let bodyText = try #require(String(data: body, encoding: .utf8))
        #expect(bodyText.contains(context.text) == false)
    }

    @Test func activeTextContextEchoFilterDistinguishesEchoFromLegitimateSpeech() {
        #expect(
            ActiveTextContextEchoFilter.matches(
                transcript: "already writing about contextual dictation",
                contextText: "We are already writing about contextual dictation quality."
            )
        )
        #expect(
            ActiveTextContextEchoFilter.matches(
                transcript: "contextual dictation quality is better now",
                contextText: "We are already writing about contextual dictation quality."
            ) == false
        )
        #expect(
            ActiveTextContextEchoFilter.matches(
                transcript: "contextual dictation",
                contextText: "We are already writing about contextual dictation quality."
            ) == false
        )
    }

    @Test func invalidResponseIsRejected() async throws {
        let audioFileURL = try makeTemporaryAudioFile()
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let service = makeService(
            loader: FakeURLLoader(
                result: .success(Data(#"{"message":"missing text"}"#.utf8), makeHTTPResponse(statusCode: 200))
            )
        )

        await expectTranscriptionError(.invalidResponse) {
            try await service.transcribe(
                try makeTranscriptionRequest(audioFileURL: audioFileURL),
                credential: testCredential()
            )
        }
    }

    @Test func unsupportedRecordingErrorIsMappedBeforeNetworkRequest() async throws {
        let audioFileURL = try makeTemporaryAudioFile(named: "recording.txt")
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = FakeURLLoader(
            result: .success(Data(#"{"text":"unused"}"#.utf8), makeHTTPResponse(statusCode: 200))
        )
        let service = makeService(loader: loader)

        await expectTranscriptionError(.invalidRecording(.unsupportedAudioFileType("txt"))) {
            try await service.transcribe(
                try makeTranscriptionRequest(audioFileURL: audioFileURL),
                credential: testCredential()
            )
        }

        #expect(loader.requests.isEmpty)
    }

    @Test func emptyAudioFileErrorIsMappedBeforeNetworkRequest() async throws {
        let audioFileURL = try makeTemporaryAudioFile(contents: Data())
        defer { try? FileManager.default.removeItem(at: audioFileURL.deletingLastPathComponent()) }

        let loader = FakeURLLoader(
            result: .success(Data(#"{"text":"unused"}"#.utf8), makeHTTPResponse(statusCode: 200))
        )
        let service = makeService(loader: loader)

        await expectTranscriptionError(.invalidRecording(.emptyAudioFile(audioFileURL))) {
            try await service.transcribe(
                try makeTranscriptionRequest(audioFileURL: audioFileURL),
                credential: testCredential()
            )
        }

        #expect(loader.requests.isEmpty)
    }

    @Test func invalidCustomLanguageFailsDuringRequestConstructionBeforeServiceFileIO() {
        let missingFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-invalid-language-\(UUID().uuidString).m4a")
        var settings = AppSettings.defaults
        settings.language = .custom
        settings.customLanguageCode = "en-US"

        #expect(
            throws: AudioTranscriptionRequest.ValidationError.invalidCustomLanguageCode("en-US")
        ) {
            _ = try makeTranscriptionRequest(
                audioFileURL: missingFileURL,
                settings: settings
            )
        }
    }

    @Test func commonFailureMessagesAndLogCategoriesAreStable() {
        let audioFileURL = URL(fileURLWithPath: "/tmp/recording.m4a")
        let cases: [(OpenAITranscriptionServiceError, String, String)] = [
            (
                .missingAPIKey,
                "Enter an OpenAI API key before transcribing.",
                "missing_api_key"
            ),
            (
                .invalidAPIKey,
                "OpenAI rejected the saved API key.",
                "invalid_api_key"
            ),
            (
                .rateLimited,
                "OpenAI rate limits were reached. Try again later.",
                "rate_limited"
            ),
            (
                .timedOut,
                "Transcription timed out.",
                "timeout"
            ),
            (
                .invalidRecording(.emptyAudioFile(audioFileURL)),
                "No audio was captured. Try recording again.",
                "empty_audio"
            ),
            (
                .invalidRecording(.invalidCustomLanguageCode("en-US")),
                "Use a two- or three-letter custom language code.",
                "invalid_language_code"
            ),
            (
                .providerUnavailable,
                "OpenAI is unavailable. Try again later.",
                "provider_unavailable"
            ),
            (
                .emptyTranscript,
                "No speech text was detected.",
                "empty_transcript"
            ),
            (
                .dictionaryEcho,
                "Only dictionary hints were detected.",
                "dictionary_echo"
            ),
            (
                .contextEcho,
                "Only nearby context was detected.",
                "context_echo"
            ),
        ]

        for (error, expectedMessage, expectedLogCategory) in cases {
            #expect(error.userFacingMessage == expectedMessage)
            #expect(error.errorDescription == expectedMessage)
            #expect(error.operatorLogCategory == expectedLogCategory)
        }
    }

    private func makeTranscriptionRequest(
        audioFileURL: URL,
        settings: AppSettings = .defaults,
        context: TranscriptionPromptContext? = nil
    ) throws -> AudioTranscriptionRequest {
        try settings.audioTranscriptionRequest(
            audioFileURL: audioFileURL,
            context: context
        )
    }

    private func makeService(
        loader: any URLLoading,
        sleeper: any TranscriptionTimeoutSleeping = FakeTimeoutSleeper(),
        requestTimeout: TimeInterval = 7
    ) -> OpenAITranscriptionService {
        OpenAITranscriptionService(
            requestBuilder: OpenAITranscriptionRequestBuilder(boundary: "Boundary-Test"),
            urlLoader: loader,
            timeoutSleeper: sleeper,
            requestTimeout: requestTimeout
        )
    }

    private func testCredential(_ apiKey: String = "sk-test") throws -> OpenAICredential {
        try OpenAICredential(apiKey: apiKey)
    }

    private func makeTemporaryAudioFile(
        named fileName: String = "recording.m4a",
        contents: Data = Data("fake audio bytes".utf8)
    ) throws -> URL {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("holdtype-transcription-service-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        let fileURL = directoryURL.appendingPathComponent(fileName)
        try contents.write(to: fileURL)
        return fileURL
    }
}

private func expectTranscriptionError(
    _ expectedError: OpenAITranscriptionServiceError,
    operation: () async throws -> String
) async {
    do {
        _ = try await operation()
        Issue.record("Expected OpenAITranscriptionServiceError.\(expectedError)")
    } catch let error as OpenAITranscriptionServiceError {
        #expect(error == expectedError)
    } catch {
        Issue.record("Expected OpenAITranscriptionServiceError, got \(error)")
    }
}

private func makeHTTPResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: OpenAITranscriptionRequestBuilder.defaultEndpointURL,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

private final class FakeURLLoader: URLLoading {
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

private final class FakeTimeoutSleeper: TranscriptionTimeoutSleeping {
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

private final class ControlledURLLoader: URLLoading, @unchecked Sendable {
    enum CancellationBehavior {
        case failImmediately
        case awaitResponse
    }

    private typealias Output = (Data, URLResponse)

    private struct RequestState {
        let cancellationBehavior: CancellationBehavior
        var continuation: CheckedContinuation<Output, Error>?
        var resolvedOutput: Output?
        var cancellationCount = 0
        var isFinished = false
    }

    private enum WaitError: Error {
        case requestCountTimedOut(expected: Int)
        case cancellationTimedOut(requestIndex: Int)
    }

    private let cancellationBehaviors: [CancellationBehavior]
    private let lock = NSLock()
    private var requestStates: [RequestState] = []

    init(cancellationBehaviors: [CancellationBehavior]) {
        self.cancellationBehaviors = cancellationBehaviors
    }

    func loadData(for request: URLRequest) async throws -> (Data, URLResponse) {
        let requestIndex = registerRequest()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                registerResponseContinuation(continuation, forRequestAt: requestIndex)
            }
        } onCancel: {
            cancelRequest(at: requestIndex)
        }
    }

    func waitForRequestCount(_ count: Int) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))

        while lock.withLock({ requestStates.count }) < count {
            guard clock.now < deadline else {
                throw WaitError.requestCountTimedOut(expected: count)
            }
            try await clock.sleep(for: .milliseconds(1))
        }
    }

    func waitForCancellation(ofRequestAt requestIndex: Int) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))

        while cancellationCount(forRequestAt: requestIndex) == 0 {
            guard clock.now < deadline else {
                throw WaitError.cancellationTimedOut(requestIndex: requestIndex)
            }
            try await clock.sleep(for: .milliseconds(1))
        }
    }

    func cancellationCount(forRequestAt requestIndex: Int) -> Int {
        lock.withLock {
            guard requestStates.indices.contains(requestIndex) else {
                return 0
            }
            return requestStates[requestIndex].cancellationCount
        }
    }

    func resolveRequest(at requestIndex: Int, data: Data, response: URLResponse) {
        let continuation: CheckedContinuation<Output, Error>? = lock.withLock {
            guard requestStates.indices.contains(requestIndex),
                  !requestStates[requestIndex].isFinished else {
                return nil
            }

            if let continuation = requestStates[requestIndex].continuation {
                requestStates[requestIndex].continuation = nil
                requestStates[requestIndex].isFinished = true
                return continuation
            }

            requestStates[requestIndex].resolvedOutput = (data, response)
            return nil
        }

        continuation?.resume(returning: (data, response))
    }

    private func registerRequest() -> Int {
        lock.withLock {
            let requestIndex = requestStates.count
            let behavior = cancellationBehaviors.indices.contains(requestIndex)
                ? cancellationBehaviors[requestIndex]
                : .failImmediately
            requestStates.append(RequestState(cancellationBehavior: behavior))
            return requestIndex
        }
    }

    private func registerResponseContinuation(
        _ continuation: CheckedContinuation<Output, Error>,
        forRequestAt requestIndex: Int
    ) {
        enum ResumeAction {
            case wait
            case returnOutput(Output)
            case throwCancellation
        }

        let action: ResumeAction = lock.withLock {
            guard requestStates.indices.contains(requestIndex) else {
                return .throwCancellation
            }

            if let output = requestStates[requestIndex].resolvedOutput {
                requestStates[requestIndex].resolvedOutput = nil
                requestStates[requestIndex].isFinished = true
                return .returnOutput(output)
            }

            if requestStates[requestIndex].cancellationCount > 0,
               requestStates[requestIndex].cancellationBehavior == .failImmediately {
                requestStates[requestIndex].isFinished = true
                return .throwCancellation
            }

            requestStates[requestIndex].continuation = continuation
            return .wait
        }

        switch action {
        case .wait:
            return
        case .returnOutput(let output):
            continuation.resume(returning: output)
        case .throwCancellation:
            continuation.resume(throwing: CancellationError())
        }
    }

    private func cancelRequest(at requestIndex: Int) {
        let responseContinuation: CheckedContinuation<Output, Error>? = lock.withLock {
            guard requestStates.indices.contains(requestIndex) else {
                return nil
            }

            requestStates[requestIndex].cancellationCount += 1
            if requestStates[requestIndex].cancellationBehavior == .failImmediately,
               !requestStates[requestIndex].isFinished {
                let responseContinuation = requestStates[requestIndex].continuation
                requestStates[requestIndex].continuation = nil
                if responseContinuation != nil {
                    requestStates[requestIndex].isFinished = true
                }
                return responseContinuation
            } else {
                return nil
            }
        }

        responseContinuation?.resume(throwing: CancellationError())
    }
}
