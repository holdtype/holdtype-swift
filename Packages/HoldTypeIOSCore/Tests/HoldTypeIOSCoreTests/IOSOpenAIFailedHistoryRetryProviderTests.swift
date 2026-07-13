import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence
import Testing
@testable import HoldTypeOpenAI
@testable import HoldTypeIOSCore

struct IOSOpenAIFailedHistoryRetryProviderTests {
    @Test func readerAdapterBindsExactMetadataAndBoundedAudioWithoutSourceCopy()
        async throws {
        let root = try retryProviderTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let bytes = Data(
            (0..<(OpenAITranscriptionAudioReader.maximumReadByteCount * 2 + 17))
                .map { UInt8($0 % 251) }
        )
        let promptComposition = TranscriptionPromptComposition(
            resolvedFreeformPrompt: "reader-bound retry prompt",
            context: nil,
            emojiCommandsConfiguration: EmojiCommandsConfiguration(
                isEnabled: false
            ),
            customDictionary: CustomDictionary(entries: ["HoldType"])
        )
        let credential = try OpenAICredential(apiKey: "sk-reader-adapter-test")
        let capture = RetryProviderReaderRequestCapture()
        let scratchBefore = try legacyRetryScratchEntries()
        let provider = IOSOpenAIFailedHistoryRetryProvider(
            credential: credential,
            transcribe: { request, receivedCredential in
                capture.record(
                    try await inspectRetryReaderRequest(
                        request,
                        credential: receivedCredential
                    )
                )
                return "reader result"
            },
            correct: { _, _, _ in
                throw RetryProviderTestError.unexpectedCall
            },
            translate: { _, _ in
                throw RetryProviderTestError.unexpectedCall
            }
        )

        for format in IOSPendingRecordingAudioFormat.allCases {
            let lease = RetryProviderAudioLease(
                data: bytes,
                format: format,
                durationMilliseconds: 1_234,
                root: root
            )
            let audio = IOSPendingTranscriptionAudio(lease: lease)
            let outcome = await provider.transcribe(
                IOSFailedHistoryRetryTranscriptionRequest(
                    transcriptionID: UUID(),
                    audio: audio,
                    resolvedModel: "gpt-4o-mini-transcribe",
                    resolvedLanguageCode: "fr",
                    promptComposition: promptComposition,
                    timeout: .seconds(1)
                )
            )
            let observation = try #require(capture.take())

            #expect(outcome == .success("reader result"))
            #expect(observation.credential == credential)
            #expect(observation.format == retryReaderFormat(format))
            #expect(observation.durationMilliseconds == 1_234)
            #expect(observation.byteCount == Int64(bytes.count))
            #expect(observation.model == "gpt-4o-mini-transcribe")
            #expect(observation.languageCode == "fr")
            #expect(observation.promptComposition == promptComposition)
            #expect(observation.audio == bytes)
            #expect(
                observation.offsets
                    == [
                        0,
                        Int64(
                            OpenAITranscriptionAudioReader
                                .maximumReadByteCount
                        ),
                        Int64(
                            OpenAITranscriptionAudioReader
                                .maximumReadByteCount * 2
                        ),
                        Int64(bytes.count),
                    ]
            )
            #expect(
                observation.chunkByteCounts
                    == [
                        OpenAITranscriptionAudioReader.maximumReadByteCount,
                        OpenAITranscriptionAudioReader.maximumReadByteCount,
                        17,
                        0,
                    ]
            )
            #expect(observation.oversizedReadWasRejected)
            #expect(
                lease.requestedMaximumByteCounts().allSatisfy {
                    $0
                        <= OpenAITranscriptionAudioReader
                            .maximumReadByteCount
                }
            )
        }

        #expect(try legacyRetryScratchEntries() == scratchBefore)
        #expect(
            try FileManager.default.contentsOfDirectory(atPath: root.path)
                .isEmpty
        )
    }

    @Test func invalidReaderMetadataFailsBeforeProviderOrAudioRead()
        async throws {
        let root = try retryProviderTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let credential = try OpenAICredential(apiKey: "sk-invalid-reader-test")
        let providerCalls = RetryProviderCallCounter()
        let provider = IOSOpenAIFailedHistoryRetryProvider(
            credential: credential,
            transcribe: { _, _ in
                providerCalls.increment()
                return "unexpected"
            },
            correct: { _, _, _ in
                throw RetryProviderTestError.unexpectedCall
            },
            translate: { _, _ in
                throw RetryProviderTestError.unexpectedCall
            }
        )
        let invalidMetadata: [(duration: Int64, byteCount: Int64)] = [
            (300_000, 1),
            (1_000, 25_000_000),
        ]

        for metadata in invalidMetadata {
            let lease = RetryProviderAudioLease(
                data: Data([1]),
                format: .m4a,
                durationMilliseconds: metadata.duration,
                advertisedByteCount: metadata.byteCount,
                root: root
            )
            let outcome = await provider.transcribe(
                IOSFailedHistoryRetryTranscriptionRequest(
                    transcriptionID: UUID(),
                    audio: IOSPendingTranscriptionAudio(lease: lease),
                    resolvedModel: "gpt-4o-mini-transcribe",
                    resolvedLanguageCode: nil,
                    promptComposition: .init(
                        resolvedFreeformPrompt: nil,
                        context: nil,
                        emojiCommandsConfiguration: .init(isEnabled: false),
                        customDictionary: .empty
                    ),
                    timeout: .seconds(1)
                )
            )

            #expect(outcome == .failure(.invalidRecording))
            #expect(lease.requestedMaximumByteCounts().isEmpty)
        }
        #expect(providerCalls.value == 0)
    }

    @Test func fixedAdapterUsesInjectedServicesWithoutNetwork() async throws {
        let credential = try OpenAICredential(apiKey: "sk-adapter-test")
        let provider = IOSOpenAIFailedHistoryRetryProvider(
            credential: credential,
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
                for: OpenAIReaderTranscriptionRequest.ValidationError
                    .invalidByteCount
            ) == .invalidRecording
        )
        #expect(
            IOSOpenAIFailedHistoryRetryProvider.transcriptionFailure(
                for: IOSFailedHistoryRetryAudioMaterializationError.writeFailed
            ) == .unknown
        )
        #expect(
            String(
                describing:
                    IOSFailedHistoryRetryAudioMaterializationError.writeFailed
            ) == "IOSFailedHistoryRetryAudioMaterializationError(redacted)"
        )
    }
}

private struct RetryProviderReaderRequestObservation: Sendable {
    let credential: OpenAICredential
    let format: OpenAIReaderTranscriptionRequest.AudioFormat
    let durationMilliseconds: Int64
    let byteCount: Int64
    let model: String
    let languageCode: String?
    let promptComposition: TranscriptionPromptComposition
    let audio: Data
    let offsets: [Int64]
    let chunkByteCounts: [Int]
    let oversizedReadWasRejected: Bool
}

private func inspectRetryReaderRequest(
    _ request: OpenAIReaderTranscriptionRequest,
    credential: OpenAICredential
) async throws -> RetryProviderReaderRequestObservation {
    let reader = try request.claimReader()
    let oversizedReadWasRejected: Bool
    do {
        _ = try await reader.read(
            atOffset: 0,
            maximumByteCount:
                OpenAITranscriptionAudioReader.maximumReadByteCount + 1
        )
        oversizedReadWasRejected = false
    } catch let error as OpenAITranscriptionAudioReaderError {
        oversizedReadWasRejected = error == .invalidRead
    }

    let maximumByteCount = OpenAITranscriptionAudioReader.maximumReadByteCount
    var audio = Data()
    var offsets: [Int64] = []
    var chunkByteCounts: [Int] = []
    var offset: Int64 = 0
    while true {
        offsets.append(offset)
        let chunk = try await reader.read(
            atOffset: offset,
            maximumByteCount: maximumByteCount
        )
        chunkByteCounts.append(chunk.count)
        guard !chunk.isEmpty else { break }
        audio.append(chunk)
        offset += Int64(chunk.count)
    }

    return RetryProviderReaderRequestObservation(
        credential: credential,
        format: request.format,
        durationMilliseconds: request.durationMilliseconds,
        byteCount: request.byteCount,
        model: request.model,
        languageCode: request.languageCode,
        promptComposition: request.promptComposition,
        audio: audio,
        offsets: offsets,
        chunkByteCounts: chunkByteCounts,
        oversizedReadWasRejected: oversizedReadWasRejected
    )
}

private final class RetryProviderReaderRequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var observation: RetryProviderReaderRequestObservation?

    func record(_ observation: RetryProviderReaderRequestObservation) {
        lock.withLock { self.observation = observation }
    }

    func take() -> RetryProviderReaderRequestObservation? {
        lock.withLock {
            defer { observation = nil }
            return observation
        }
    }
}

private final class RetryProviderAudioLease:
    IOSPendingRecordingPublishedAudioLease,
    @unchecked Sendable {
    let relativeIdentifier: String
    let audioArtifact: AudioRecordingArtifact
    let durationMilliseconds: Int64

    private let data: Data
    private let lock = NSLock()
    private var requestedMaximumByteCountValues: [Int] = []

    init(
        data: Data,
        format: IOSPendingRecordingAudioFormat,
        durationMilliseconds: Int64,
        advertisedByteCount: Int64? = nil,
        root: URL
    ) {
        let identifier = UUID().uuidString
        let pathExtension = switch format {
        case .m4a: "m4a"
        case .wav: "wav"
        }
        relativeIdentifier =
            "Recordings/Pending/retry-provider-\(identifier).\(pathExtension)"
        audioArtifact = AudioRecordingArtifact(
            fileURL: root.appendingPathComponent(
                "source-\(identifier).\(pathExtension)"
            ),
            duration: Double(durationMilliseconds) / 1_000,
            byteCount: advertisedByteCount ?? Int64(data.count)
        )
        self.durationMilliseconds = durationMilliseconds
        self.data = data
    }

    func revalidate() async throws -> AudioRecordingArtifact {
        audioArtifact
    }

    func read(
        atOffset offset: Int64,
        maximumByteCount: Int
    ) async throws -> Data {
        lock.withLock {
            requestedMaximumByteCountValues.append(maximumByteCount)
        }
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

    func release() {}

    func requestedMaximumByteCounts() -> [Int] {
        lock.withLock { requestedMaximumByteCountValues }
    }
}

private final class RetryProviderCallCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int { lock.withLock { storedValue } }

    func increment() {
        lock.withLock { storedValue += 1 }
    }
}

private enum RetryProviderTestError: Error {
    case unexpectedCall
    case invalidRead
}

private struct RetryProviderScratchSnapshot: Equatable {
    let exists: Bool
    let isDirectory: Bool
    let entries: [String]
}

private func legacyRetryScratchEntries() throws
    -> RetryProviderScratchSnapshot {
    let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(
        in: IOSFailedHistoryRetryScratchNamespace.defaultParentDirectoryURL
    )
    var isDirectory: ObjCBool = false
    let exists = FileManager.default.fileExists(
        atPath: namespace.path,
        isDirectory: &isDirectory
    )
    let entries = if exists, isDirectory.boolValue {
        try FileManager.default.contentsOfDirectory(atPath: namespace.path)
            .sorted()
    } else {
        [String]()
    }
    return RetryProviderScratchSnapshot(
        exists: exists,
        isDirectory: isDirectory.boolValue,
        entries: entries
    )
}

private func retryReaderFormat(
    _ format: IOSPendingRecordingAudioFormat
) -> OpenAIReaderTranscriptionRequest.AudioFormat {
    switch format {
    case .m4a: .m4a
    case .wav: .wav
    }
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
    return root
}
