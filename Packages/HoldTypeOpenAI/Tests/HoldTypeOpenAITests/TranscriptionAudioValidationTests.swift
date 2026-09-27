import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypeOpenAI

struct TranscriptionAudioValidationTests {
    @Test(arguments: [Data("not audio".utf8), Data(), Data(TranscriptionTestAudio.wav.prefix(44)),
                      Data([0, 0, 0, 28]) + Data("ftypM4A ".utf8) + Data(repeating: 0, count: 64)])
    func rejectsIncompleteAudioWithoutUpload(bytes: Data) async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = root.appendingPathComponent("recording.m4a")
        try bytes.write(to: audio)
        let upload = UnexpectedAudioUpload()
        let service = OpenAITranscriptionService(
            requestBuilder: .init(scratchDirectoryURL: root.appendingPathComponent("scratch")),
            urlUploader: upload
        )
        do {
            _ = try await service.transcribe(
                AudioTranscriptionRequest(audioFileURL: audio, transcriptionConfiguration: .defaults,
                                          promptComposition: .init(resolvedFreeformPrompt: nil, context: nil, emojiCommandsConfiguration: .defaults, customDictionary: .empty)),
                credential: OpenAICredential(apiKey: "test-only")
            )
            Issue.record("Invalid recording was accepted")
        } catch let error as OpenAITranscriptionServiceError {
            guard case .invalidRecording = error else { Issue.record("Wrong error: \(error.operatorLogCategory)"); return }
        }
        #expect(FileManager.default.fileExists(atPath: audio.path))
        #expect(try Data(contentsOf: audio) == bytes)
    }

    @Test func decodesCompletedAudio() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID()).wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try TranscriptionTestAudio.wav.write(to: url)
        try TranscriptionAudioValidation.validate(url)
    }
}

private struct UnexpectedAudioUpload: URLFileUploading {
    func uploadData(for request: URLRequest, body: any OpenAIFileUploadBody) async throws -> (Data, URLResponse) {
        Issue.record("Invalid audio reached the upload boundary")
        throw URLError(.badURL)
    }
}
