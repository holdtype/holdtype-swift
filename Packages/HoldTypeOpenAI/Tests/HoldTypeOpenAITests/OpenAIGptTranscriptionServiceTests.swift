import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypeOpenAI

@MainActor
struct OpenAIGptTranscriptionServiceTests {
    @Test func gptTranscribeAcceptsTranscriptMadeOfDictionaryKeywords() async throws {
        let audioDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-gpt-service-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: audioDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: audioDirectory) }

        let audioURL = audioDirectory.appendingPathComponent("recording.m4a")
        try Data([1, 2, 3]).write(to: audioURL)
        let configuration = TranscriptionConfiguration(
            model: TranscriptionConfiguration.defaultModel
        )
        let request = try AudioTranscriptionRequest(
            audioFileURL: audioURL,
            transcriptionConfiguration: configuration,
            promptComposition: TranscriptionPromptComposition(
                resolvedFreeformPrompt: nil,
                context: nil,
                emojiCommandsConfiguration: EmojiCommandsConfiguration(isEnabled: false),
                customDictionary: CustomDictionary(entries: ["CMD", "кодекс"])
            )
        )
        let service = OpenAITranscriptionService(
            requestBuilder: OpenAITranscriptionRequestBuilder(boundary: "Boundary-GPT-Service"),
            urlUploader: GPTServiceFakeUploader(),
            timeoutSleeper: GPTServiceNoopSleeper()
        )

        let transcript = try await service.transcribe(
            request,
            credential: OpenAICredential(apiKey: "sk-test")
        )

        #expect(transcript == "CMD кодекс")
    }
}

private struct GPTServiceFakeUploader: URLFileUploading {
    func uploadData(
        for request: URLRequest,
        body: any OpenAIFileUploadBody
    ) async throws -> (Data, URLResponse) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: 200,
                  httpVersion: nil,
                  headerFields: nil
              ) else {
            throw OpenAIFileUploadTransportError.invalidResponse
        }

        return (
            Data(#"{"text":"CMD кодекс"}"#.utf8),
            response
        )
    }
}

private struct GPTServiceNoopSleeper: TranscriptionTimeoutSleeping {
    func sleep(seconds: TimeInterval) async throws {
        try await Task.sleep(nanoseconds: 60_000_000_000)
    }
}
