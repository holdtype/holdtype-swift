import Darwin
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOSCore

struct IOSOpenAIFailedHistoryRetryProviderTests {
    @Test func materializationIsExactPrivateAndRemovedAfterSuccess()
        async throws {
        let root = try retryProviderTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data((0..<4_097).map { UInt8($0 % 251) })
        let audio = RetryProviderAudio(data: bytes, format: .wav)
        let materializer = IOSFailedHistoryRetryAudioMaterializer(
            scratchDirectoryURL: root
        )
        let capture = RetryProviderURLCapture()

        let count = try await materializer.withMaterializedAudio(audio) {
            fileURL in
            await capture.store(fileURL)
            let copied = try Data(contentsOf: fileURL)
            let attributes = try FileManager.default.attributesOfItem(
                atPath: fileURL.path
            )
            let permissions = try #require(
                attributes[.posixPermissions] as? NSNumber
            )
            #expect(permissions.intValue & 0o077 == 0)
            #if os(iOS)
            let descriptor = Darwin.open(
                fileURL.path,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
            #expect(descriptor >= 0)
            if descriptor >= 0 {
                #expect(
                    Darwin.fcntl(descriptor, F_GETPROTECTIONCLASS) == 1
                )
                _ = Darwin.close(descriptor)
            }
            #endif
            #expect(
                try fileURL.resourceValues(
                    forKeys: [.isExcludedFromBackupKey]
                ).isExcludedFromBackup == true
            )
            #expect(fileURL.pathExtension == "wav")
            #expect(copied == bytes)
            return copied.count
        }

        #expect(count == bytes.count)
        let fileURL = try #require(await capture.value())
        #expect(FileManager.default.fileExists(atPath: fileURL.path) == false)
        try expectRetryScratchNamespaceIsEmpty(in: root)
    }

    @Test func materializationRemovesCopyWhenProviderThrowsOrCancels()
        async throws {
        let root = try retryProviderTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = RetryProviderAudio(
            data: Data(repeating: 7, count: 1_025),
            format: .m4a
        )
        let materializer = IOSFailedHistoryRetryAudioMaterializer(
            scratchDirectoryURL: root
        )
        let capture = RetryProviderURLCapture()

        do {
            _ = try await materializer.withMaterializedAudio(audio) {
                fileURL -> Int in
                await capture.store(fileURL)
                throw RetryProviderTestError.providerFailed
            }
            Issue.record("Expected the provider operation to fail.")
        } catch RetryProviderTestError.providerFailed {
            // Expected.
        }
        let failedURL = try #require(await capture.value())
        #expect(FileManager.default.fileExists(atPath: failedURL.path) == false)
        try expectRetryScratchNamespaceIsEmpty(in: root)

        await capture.clear()
        do {
            _ = try await materializer.withMaterializedAudio(audio) {
                fileURL -> Int in
                await capture.store(fileURL)
                throw CancellationError()
            }
            Issue.record("Expected cancellation from the provider operation.")
        } catch is CancellationError {
            // Expected.
        }
        let cancelledURL = try #require(await capture.value())
        #expect(
            FileManager.default.fileExists(atPath: cancelledURL.path) == false
        )
        try expectRetryScratchNamespaceIsEmpty(in: root)
    }

    @Test func materializationRejectsShortSourceAndLeavesNoScratchFile()
        async throws {
        let root = try retryProviderTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let audio = RetryProviderAudio(
            data: Data(repeating: 3, count: 32),
            format: .wav,
            advertisedByteCount: 33
        )
        let materializer = IOSFailedHistoryRetryAudioMaterializer(
            scratchDirectoryURL: root
        )

        do {
            _ = try await materializer.withMaterializedAudio(audio) {
                _ in 0
            }
            Issue.record("Expected exact byte-count validation to fail.")
        } catch IOSFailedHistoryRetryAudioMaterializationError.invalidAudio {
            // Expected.
        }
        try expectRetryScratchNamespaceIsEmpty(in: root)
    }

    @Test func fixedAdapterUsesInjectedServicesWithoutNetwork() async throws {
        let root = try retryProviderTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let credential = try OpenAICredential(apiKey: "sk-adapter-test")
        let provider = IOSOpenAIFailedHistoryRetryProvider(
            credential: credential,
            materializer: IOSFailedHistoryRetryAudioMaterializer(
                scratchDirectoryURL: root
            ),
            transcribe: { _, _ in
                throw RetryProviderTestError.unexpectedCall
            },
            correct: { transcript, configuration, receivedCredential in
                #expect(transcript.text == "before")
                #expect(configuration == .defaults)
                #expect(receivedCredential == credential)
                return "after"
            },
            translate: { _, receivedCredential in
                #expect(receivedCredential == credential)
                throw OpenAITextTranslationServiceError.invalidAPIKey
            }
        )
        let transcript = try AcceptedTranscript(rawText: "before")

        #expect(
            await provider.correct(
                IOSFailedHistoryRetryCorrectionRequest(
                    transcript: transcript,
                    configuration: .defaults,
                    timeout: .seconds(1)
                )
            ) == .success("after")
        )
        #expect(
            await provider.translate(
                IOSFailedHistoryRetryTranslationRequest(
                    translationRequest: TextTranslationRequest(
                        acceptedTranscript: transcript,
                        translationConfiguration: TranslationConfiguration(
                            targetLanguage: .english
                        ),
                        transcriptionConfiguration: .defaults
                    ),
                    timeout: .seconds(1)
                )
            ) == .failure(.credentialRejected)
        )
    }

    @Test func fixedAdapterMapsEveryPublicServiceErrorWithoutPayloads() {
        let sampleURL = URL(fileURLWithPath: "/redacted/sample.wav")
        let transcriptionCases: [(any Error,
                IOSFailedHistoryRetryRuntimeFailure)] = [
            (OpenAITranscriptionServiceError.missingAPIKey, .credentialMissing),
            (OpenAITranscriptionServiceError.apiKeyUnavailable, .credentialUnavailable),
            (OpenAITranscriptionServiceError.invalidAPIKey, .credentialRejected),
            (OpenAITranscriptionServiceError.networkUnavailable, .networkUnavailable),
            (OpenAITranscriptionServiceError.networkFailure, .networkFailure),
            (OpenAITranscriptionServiceError.timedOut, .timedOut),
            (OpenAITranscriptionServiceError.rateLimited, .rateLimited),
            (OpenAITranscriptionServiceError.providerUnavailable, .providerUnavailable),
            (OpenAITranscriptionServiceError.badRequest, .badRequest),
            (OpenAITranscriptionServiceError.providerRejected(statusCode: 418), .providerRejected),
            (OpenAITranscriptionServiceError.invalidResponse, .invalidResponse),
            (OpenAITranscriptionServiceError.emptyTranscript, .emptyResult),
            (OpenAITranscriptionServiceError.dictionaryEcho, .dictionaryEcho),
            (OpenAITranscriptionServiceError.contextEcho, .contextEcho),
            (
                OpenAITranscriptionServiceError.invalidRecording(
                    .emptyAudioFile(sampleURL)
                ),
                .invalidRecording
            ),
            (OpenAITranscriptionServiceError.invalidRequest, .invalidRequest),
            (
                OpenAITranscriptionServiceError.multipartMetadataTooLarge,
                .multipartMetadataTooLarge
            ),
            (OpenAITranscriptionServiceError.cancelled, .cancelled),
        ]
        for (error, expected) in transcriptionCases {
            #expect(
                IOSOpenAIFailedHistoryRetryProvider.transcriptionFailure(
                    for: error
                ) == expected
            )
        }

        let correctionCases: [(any Error,
                IOSFailedHistoryRetryRuntimeFailure)] = [
            (OpenAITextCorrectionServiceError.missingAPIKey, .credentialMissing),
            (OpenAITextCorrectionServiceError.apiKeyUnavailable, .credentialUnavailable),
            (OpenAITextCorrectionServiceError.invalidAPIKey, .credentialRejected),
            (OpenAITextCorrectionServiceError.networkUnavailable, .networkUnavailable),
            (OpenAITextCorrectionServiceError.networkFailure, .networkFailure),
            (OpenAITextCorrectionServiceError.timedOut, .timedOut),
            (OpenAITextCorrectionServiceError.rateLimited, .rateLimited),
            (OpenAITextCorrectionServiceError.providerUnavailable, .providerUnavailable),
            (OpenAITextCorrectionServiceError.badRequest, .badRequest),
            (
                OpenAITextCorrectionServiceError.providerRejected(
                    statusCode: 409
                ),
                .providerRejected
            ),
            (OpenAITextCorrectionServiceError.invalidResponse, .invalidResponse),
            (OpenAITextCorrectionServiceError.emptyCorrection, .emptyResult),
            (OpenAITextCorrectionServiceError.invalidRequest, .invalidRequest),
            (OpenAITextCorrectionServiceError.cancelled, .cancelled),
        ]
        for (error, expected) in correctionCases {
            #expect(
                IOSOpenAIFailedHistoryRetryProvider.correctionFailure(
                    for: error
                ) == expected
            )
        }

        let translationCases: [(any Error,
                IOSFailedHistoryRetryRuntimeFailure)] = [
            (OpenAITextTranslationServiceError.missingAPIKey, .credentialMissing),
            (OpenAITextTranslationServiceError.apiKeyUnavailable, .credentialUnavailable),
            (OpenAITextTranslationServiceError.invalidAPIKey, .credentialRejected),
            (OpenAITextTranslationServiceError.networkUnavailable, .networkUnavailable),
            (OpenAITextTranslationServiceError.networkFailure, .networkFailure),
            (OpenAITextTranslationServiceError.timedOut, .timedOut),
            (OpenAITextTranslationServiceError.rateLimited, .rateLimited),
            (OpenAITextTranslationServiceError.providerUnavailable, .providerUnavailable),
            (OpenAITextTranslationServiceError.badRequest, .badRequest),
            (
                OpenAITextTranslationServiceError.providerRejected(
                    statusCode: 451
                ),
                .providerRejected
            ),
            (OpenAITextTranslationServiceError.invalidResponse, .invalidResponse),
            (OpenAITextTranslationServiceError.emptyTranslation, .emptyResult),
            (
                OpenAITextTranslationServiceError.invalidLanguageConfiguration,
                .invalidTranslationRoute
            ),
            (OpenAITextTranslationServiceError.invalidRequest, .invalidRequest),
            (OpenAITextTranslationServiceError.cancelled, .cancelled),
        ]
        for (error, expected) in translationCases {
            #expect(
                IOSOpenAIFailedHistoryRetryProvider.translationFailure(
                    for: error
                ) == expected
            )
        }

        #expect(
            IOSOpenAIFailedHistoryRetryProvider.transcriptionFailure(
                for: CancellationError()
            ) == .cancelled
        )
        #expect(
            IOSOpenAIFailedHistoryRetryProvider.transcriptionFailure(
                for: IOSFailedHistoryRetryAudioMaterializationError.writeFailed
            ) == .invalidRecording
        )
        #expect(
            String(
                describing:
                    IOSFailedHistoryRetryAudioMaterializationError.writeFailed
            ) == "IOSFailedHistoryRetryAudioMaterializationError(redacted)"
        )
    }
}

private struct RetryProviderAudio: IOSFailedHistoryRetryAudioReading {
    let data: Data
    let format: IOSPendingRecordingAudioFormat
    let byteCount: Int64

    init(
        data: Data,
        format: IOSPendingRecordingAudioFormat,
        advertisedByteCount: Int64? = nil
    ) {
        self.data = data
        self.format = format
        byteCount = advertisedByteCount ?? Int64(data.count)
    }

    func read(
        atOffset offset: Int64,
        maximumByteCount: Int
    ) async throws -> Data {
        guard offset >= 0,
              maximumByteCount > 0,
              offset <= Int64(data.count) else {
            throw RetryProviderTestError.invalidRead
        }
        let lowerBound = Int(offset)
        guard lowerBound < data.count else { return Data() }
        let upperBound = min(data.count, lowerBound + maximumByteCount)
        return data.subdata(in: lowerBound..<upperBound)
    }
}

private actor RetryProviderURLCapture {
    private var storedURL: URL?

    func store(_ url: URL) { storedURL = url }
    func value() -> URL? { storedURL }
    func clear() { storedURL = nil }
}

private enum RetryProviderTestError: Error {
    case providerFailed
    case unexpectedCall
    case invalidRead
}

private func retryProviderTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ios-failed-retry-provider-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true,
        attributes: [.posixPermissions: 0o700]
    )
    #expect(Darwin.chmod(root.path, 0o700) == 0)
    return root
}

private func expectRetryScratchNamespaceIsEmpty(in root: URL) throws {
    let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(
        in: root
    )
    #expect(FileManager.default.fileExists(atPath: namespace.path))
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: namespace.path)
            .isEmpty
    )
}
