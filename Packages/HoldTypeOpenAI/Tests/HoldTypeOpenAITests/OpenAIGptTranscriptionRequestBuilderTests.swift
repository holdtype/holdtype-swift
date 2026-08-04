import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypeOpenAI

@MainActor
struct OpenAIGptTranscriptionRequestBuilderTests {
    @Test func usesLanguagesAndKeywordHintsInsteadOfLegacyFields() async throws {
        let audio = Data([1, 2, 3, 4])
        let source = try gptTemporaryAudio(named: "gpt-transcribe.m4a", data: audio)
        let scratchDirectory = gptTemporaryDirectory("multipart-gpt-transcribe")
        defer { gptRemove(source.deletingLastPathComponent()); gptRemove(scratchDirectory) }

        let configuration = TranscriptionConfiguration(
            model: "gpt-transcribe",
            language: .russian,
            freeformPrompt: "Product context"
        )
        let builder = OpenAITranscriptionRequestBuilder(
            boundary: "Boundary-GPT-Transcribe",
            scratchDirectoryURL: scratchDirectory
        )
        let request = try AudioTranscriptionRequest(
            audioFileURL: source,
            transcriptionConfiguration: configuration,
            promptComposition: TranscriptionPromptComposition(
                resolvedFreeformPrompt: configuration.resolvedFreeformPrompt,
                context: nil,
                emojiCommandsConfiguration: EmojiCommandsConfiguration(isEnabled: false),
                customDictionary: CustomDictionary(
                    entries: ["HoldType", "Line\nBreak", "<unsafe>", "OpenAI"]
                )
            )
        )
        let cleanup = builder.makeCleanupRegistration()
        let preparation = try await builder.makePreparation(request, cleanupRegistration: cleanup)
        defer { preparation.cleanup(); cleanup.requestCleanup() }

        let body = String(decoding: try gptReadAll(try await preparation.prepareRequest().body), as: UTF8.self)
        #expect(body.contains("name=\"languages[]\"\r\n\r\nru\r\n"))
        #expect(body.contains("name=\"keywords[]\"\r\n\r\nHoldType\r\n"))
        #expect(body.contains("name=\"keywords[]\"\r\n\r\nOpenAI\r\n"))
        #expect(body.contains("name=\"language\"") == false)
        #expect(
            body.contains(
                "name=\"prompt\"\r\n\r\nProduct context\n\n" +
                    "Custom Dictionary (use these exact spellings when they appear in the text): " +
                    "HoldType, OpenAI\r\n"
            )
        )
        #expect(body.contains("Line\nBreak") == false)
        #expect(body.contains("<unsafe>") == false)
        #expect(body.contains("name=\"prompt\"\r\n\r\nProduct context\n"))
        #expect(body.contains("filename=\"recording.m4a\"") == true)
        #expect(body.hasSuffix("\r\n--Boundary-GPT-Transcribe--\r\n"))
    }

    private func gptTemporaryDirectory(_ prefix: String) -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-gpt-\(prefix)-\(UUID().uuidString)",
            isDirectory: true
        )
    }

    private func gptTemporaryAudio(named: String, data: Data) throws -> URL {
        let directory = gptTemporaryDirectory("audio")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(named)
        try data.write(to: url)
        return url
    }

    private func gptRemove(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    private func gptReadAll(_ body: any OpenAIFileUploadBody) throws -> Data {
        let stream = try body.makeInputStream { _ in }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count >= 0 else {
                throw stream.streamError ?? OpenAITranscriptionRequestBuilderError.multipartBodyUnavailable
            }
            if count == 0 { break }
            result.append(contentsOf: buffer.prefix(count))
        }
        return result
    }
}
