import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence
import Testing
@testable import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) @testable import HoldTypeIOSCore

@MainActor
struct IOSForegroundVoiceTranscriptionExecutorTests {
    @Test func pendingDispatchBindsExactWAVReaderMetadataAndNormalizedResult()
        async throws {
        let fixture = try await TranscriptionExecutorFixture()
        defer { fixture.removeFiles() }
        let capture = ReaderRequestCapture()
        let composition = makePromptComposition("reader-bound prompt")
        let executor = try fixture.makeExecutor(
            promptComposition: composition,
            transcribe: { request, _ in
                let observation = try await inspectReaderRequest(request)
                capture.record(observation)
                return " \n  Reader-bound result  \t"
            }
        )
        let dispatch = try await fixture.beginTranscription()

        let result = try await dispatch.execute(using: executor)
        let observation = try #require(capture.observation)

        #expect(result == "Reader-bound result")
        #expect(observation.format == .wav)
        #expect(observation.durationMilliseconds == fixture.durationMilliseconds)
        #expect(observation.byteCount == Int64(fixture.audio.count))
        #expect(observation.model == fixture.configuration.resolvedModel)
        #expect(
            observation.languageCode
                == fixture.configuration.resolvedLanguageCode
        )
        #expect(observation.promptComposition == composition)
        #expect(observation.audio == fixture.audio)
        #expect(
            observation.offsets
                == [0, Int64(OpenAITranscriptionAudioReader.maximumReadByteCount),
                    Int64(fixture.audio.count)]
        )
        #expect(
            observation.chunkByteCounts
                == [
                    OpenAITranscriptionAudioReader.maximumReadByteCount,
                    fixture.audio.count
                        - OpenAITranscriptionAudioReader.maximumReadByteCount,
                    0,
                ]
        )
        #expect(
            observation.maximumRequestedByteCount
                == OpenAITranscriptionAudioReader.maximumReadByteCount
        )
        #expect(observation.oversizedReadWasRejected)
        #expect(
            OpenAITranscriptionAudioReader.maximumReadByteCount
                == IOSPendingTranscriptionAudio.maximumReadByteCount
        )
    }

    @Test func completedHandoffMakesCapturedUnclaimedRequestUnreadable()
        async throws {
        let fixture = try await TranscriptionExecutorFixture()
        defer { fixture.removeFiles() }
        let capture = ReaderRequestBox()
        let executor = try fixture.makeExecutor(
            promptComposition: makePromptComposition(nil),
            transcribe: { request, _ in
                capture.record(request)
                return "Finished"
            }
        )
        let dispatch = try await fixture.beginTranscription()

        #expect(try await dispatch.execute(using: executor) == "Finished")

        let request = try #require(capture.request)
        let reader = try request.claimReader()
        await #expect(
            throws: IOSPendingRecordingError.dispatchAlreadyCommitted
        ) {
            try await reader.read(
                atOffset: 0,
                maximumByteCount:
                    OpenAITranscriptionAudioReader.maximumReadByteCount
            )
        }
    }

    @Test func pendingMetadataMismatchFailsBeforeProviderLaunch()
        async throws {
        let fixture = try await TranscriptionExecutorFixture()
        defer { fixture.removeFiles() }
        let providerCalls = LockedInteger()
        let executor = try fixture.makeExecutor(
            promptComposition: makePromptComposition(nil),
            transcribe: { _, _ in
                providerCalls.increment()
                return "unexpected"
            }
        )
        let dispatch = try await fixture.beginTranscription()
        let mismatchingExecutor = DurationMismatchingExecutor(base: executor)

        do {
            _ = try await dispatch.execute(using: mismatchingExecutor)
            Issue.record("Expected mismatched Pending metadata to fail.")
        } catch let error as IOSForegroundVoiceTranscriptionStageError {
            guard case .failure(.invalidRecording) = error else {
                Issue.record("Expected invalid-recording stage failure.")
                return
            }
        }

        #expect(providerCalls.value == 0)
    }

    @Test func explicitRetryGetsFreshOneShotDispatchAndCurrentRequestValues()
        async throws {
        let fixture = try await TranscriptionExecutorFixture()
        defer { fixture.removeFiles() }
        let initialCapture = ReaderRequestCapture()
        let initialExecutor = try fixture.makeExecutor(
            promptComposition: makePromptComposition("initial prompt"),
            transcribe: { request, _ in
                initialCapture.record(try await inspectReaderRequest(request))
                return "Initial"
            }
        )
        let initialDispatch = try await fixture.beginTranscription()
        #expect(
            try await initialDispatch.execute(using: initialExecutor)
                == "Initial"
        )
        let recovery = try await fixture.persistenceOwner.markAwaitingRecovery(
            expected: initialDispatch.expectation
        )

        await #expect(
            throws: IOSPendingRecordingError.dispatchAlreadyCommitted
        ) {
            try await initialDispatch.execute(using: initialExecutor)
        }

        let retryConfiguration = TranscriptionConfiguration(
            model: "fresh-retry-model",
            language: .custom,
            customLanguageCode: "RU",
            freeformPrompt: "fresh retry prompt"
        )
        let retryComposition = makePromptComposition(
            retryConfiguration.resolvedFreeformPrompt
        )
        let retryCapture = ReaderRequestCapture()
        let retryExecutor = try fixture.makeExecutor(
            promptComposition: retryComposition,
            transcribe: { request, _ in
                retryCapture.record(try await inspectReaderRequest(request))
                return "Retried"
            }
        )
        let retryDispatch = try await fixture.persistenceOwner.retryTranscription(
            expected: IOSPendingRecordingCASExpectation(recording: recovery),
            transcriptionID: UUID(),
            transcriptionConfiguration: retryConfiguration
        )

        #expect(
            try await retryDispatch.execute(using: retryExecutor)
                == "Retried"
        )
        let initial = try #require(initialCapture.observation)
        let retried = try #require(retryCapture.observation)

        #expect(initial.audio == fixture.audio)
        #expect(retried.audio == fixture.audio)
        #expect(initial.model == fixture.configuration.resolvedModel)
        #expect(initial.languageCode == fixture.configuration.resolvedLanguageCode)
        #expect(retried.model == "fresh-retry-model")
        #expect(retried.languageCode == "ru")
        #expect(retried.promptComposition == retryComposition)
        #expect(retryDispatch.recording.attemptID == fixture.pending.attemptID)
        #expect(
            retryDispatch.recording.transcriptionID
                != initialDispatch.recording.transcriptionID
        )
    }
}

private final class TranscriptionExecutorFixture: @unchecked Sendable {
    let root: URL
    let sourceURL: URL
    let audio: Data
    let durationMilliseconds: Int64
    let configuration: TranscriptionConfiguration
    let historyCoordinator: IOSAcceptedHistoryCoordinator
    let persistenceOwner: IOSForegroundVoicePersistenceOwner
    let consentCoordinator: IOSProviderConsentCoordinator
    let acceptedConsent: IOSProviderConsentObservation
    let pending: IOSPendingRecording
    let credential: OpenAICredential

    init() async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ios-transcription-executor-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        sourceURL = root.appendingPathComponent(
            "source-\(UUID().uuidString).wav",
            isDirectory: false
        )
        durationMilliseconds = 6_000
        audio = makeWAV(durationMilliseconds: durationMilliseconds)
        try audio.write(to: sourceURL, options: .withoutOverwriting)
        configuration = TranscriptionConfiguration(
            model: "reader-bound-model",
            language: .russian,
            freeformPrompt: "initial fixture prompt"
        )
        historyCoordinator = IOSAcceptedHistoryCoordinator(
            applicationSupportDirectoryURL: root
        )
        guard await historyCoordinator.recoverContainingAppLifecycle(
            .processLaunch
        ) == .complete else {
            throw TranscriptionExecutorFixtureError.setupFailed
        }
        persistenceOwner = IOSForegroundVoicePersistenceOwner(
            applicationSupportDirectoryURL: root
        )
        pending = try await persistenceOwner.prepare(
            IOSPendingRecordingPreparation(
                attemptID: UUID(),
                sourceArtifact: AudioRecordingArtifact(
                    fileURL: sourceURL,
                    duration: TimeInterval(durationMilliseconds) / 1_000,
                    byteCount: Int64(audio.count)
                ),
                initialState: .readyForTranscription,
                outputIntent: .standard,
                transcriptionConfiguration: configuration
            )
        )
        consentCoordinator = IOSProviderConsentCoordinator(
            applicationSupportDirectoryURL: root
        )
        let observed = await consentCoordinator.observe()
        acceptedConsent = try await consentCoordinator.accept(
            using: observed,
            decisionAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        credential = try OpenAICredential(apiKey: "sk-adapter-test")
    }

    func beginTranscription() async throws
        -> IOSForegroundVoiceTranscriptionDispatch {
        try await persistenceOwner.beginTranscription(
            expected: IOSPendingRecordingCASExpectation(recording: pending),
            transcriptionID: UUID()
        )
    }

    func makeExecutor(
        promptComposition: TranscriptionPromptComposition,
        transcribe: @escaping IOSForegroundVoiceOpenAIProviderOperations.Transcribe
    ) throws -> IOSForegroundVoiceTranscriptionExecutor {
        guard let authorization = consentCoordinator.makeAuthorization(
            from: acceptedConsent
        ) else {
            throw TranscriptionExecutorFixtureError.setupFailed
        }
        return IOSForegroundVoiceTranscriptionExecutor(
            authorization: authorization,
            stageExecutor: IOSProviderConsentStageExecutor(
                consentCoordinator: consentCoordinator
            ),
            provider: IOSForegroundVoiceOpenAIProviderOperations(
                transcribe: transcribe,
                correct: { transcript, _, _ in transcript.text },
                translate: { request, _ in request.acceptedTranscript.text }
            ),
            credential: credential,
            promptComposition: promptComposition
        )
    }

    func removeFiles() {
        try? FileManager.default.removeItem(at: root)
    }
}

private struct DurationMismatchingExecutor:
    IOSPendingTranscriptionExecutor,
    Sendable {
    let base: IOSForegroundVoiceTranscriptionExecutor

    func transcribe(
        recording: IOSPendingRecording,
        audio: IOSPendingTranscriptionAudio
    ) async throws -> String {
        let mismatched = try IOSPendingRecording(
            attemptID: recording.attemptID,
            audioRelativeIdentifier: recording.audioRelativeIdentifier,
            createdAt: recording.createdAt,
            updatedAt: recording.updatedAt,
            phase: recording.phase,
            outputIntent: recording.outputIntent,
            transcriptionID: recording.transcriptionID,
            transcriptionModel: recording.transcriptionModel,
            transcriptionLanguageCode: recording.transcriptionLanguageCode,
            durationMilliseconds: recording.durationMilliseconds + 1,
            byteCount: recording.byteCount
        )
        return try await base.transcribe(
            recording: mismatched,
            audio: audio
        )
    }
}

private struct ReaderRequestObservation: Sendable {
    let format: OpenAIReaderTranscriptionRequest.AudioFormat
    let durationMilliseconds: Int64
    let byteCount: Int64
    let model: String
    let languageCode: String?
    let promptComposition: TranscriptionPromptComposition
    let audio: Data
    let offsets: [Int64]
    let chunkByteCounts: [Int]
    let maximumRequestedByteCount: Int
    let oversizedReadWasRejected: Bool
}

private func inspectReaderRequest(
    _ request: OpenAIReaderTranscriptionRequest
) async throws -> ReaderRequestObservation {
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

    return ReaderRequestObservation(
        format: request.format,
        durationMilliseconds: request.durationMilliseconds,
        byteCount: request.byteCount,
        model: request.model,
        languageCode: request.languageCode,
        promptComposition: request.promptComposition,
        audio: audio,
        offsets: offsets,
        chunkByteCounts: chunkByteCounts,
        maximumRequestedByteCount: maximumByteCount,
        oversizedReadWasRejected: oversizedReadWasRejected
    )
}

private final class ReaderRequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var storedObservation: ReaderRequestObservation?

    var observation: ReaderRequestObservation? {
        lock.withLock { storedObservation }
    }

    func record(_ observation: ReaderRequestObservation) {
        lock.withLock { storedObservation = observation }
    }
}

private final class ReaderRequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequest: OpenAIReaderTranscriptionRequest?

    var request: OpenAIReaderTranscriptionRequest? {
        lock.withLock { storedRequest }
    }

    func record(_ request: OpenAIReaderTranscriptionRequest) {
        lock.withLock { storedRequest = request }
    }
}

private final class LockedInteger: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int { lock.withLock { storedValue } }

    func increment() {
        lock.withLock { storedValue += 1 }
    }
}

private enum TranscriptionExecutorFixtureError: Error {
    case setupFailed
}

private func makePromptComposition(
    _ prompt: String?
) -> TranscriptionPromptComposition {
    TranscriptionPromptComposition(
        resolvedFreeformPrompt: prompt,
        context: nil,
        emojiCommandsConfiguration: EmojiCommandsConfiguration(
            isEnabled: false
        ),
        customDictionary: .empty
    )
}

private func makeWAV(durationMilliseconds: Int64) -> Data {
    let sampleRate: UInt32 = 8_000
    let channelCount: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let sampleCount = Int(
        Int64(sampleRate) * durationMilliseconds / 1_000
    )
    let dataByteCount = UInt32(sampleCount * Int(bitsPerSample / 8))
    let byteRate = sampleRate * UInt32(channelCount)
        * UInt32(bitsPerSample / 8)
    let blockAlign = channelCount * (bitsPerSample / 8)

    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.appendExecutorLittleEndian(UInt32(36) + dataByteCount)
    data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8)
    data.appendExecutorLittleEndian(UInt32(16))
    data.appendExecutorLittleEndian(UInt16(1))
    data.appendExecutorLittleEndian(channelCount)
    data.appendExecutorLittleEndian(sampleRate)
    data.appendExecutorLittleEndian(byteRate)
    data.appendExecutorLittleEndian(blockAlign)
    data.appendExecutorLittleEndian(bitsPerSample)
    data.append(contentsOf: "data".utf8)
    data.appendExecutorLittleEndian(dataByteCount)
    data.append(Data(repeating: 0, count: Int(dataByteCount)))
    return data
}

private extension Data {
    mutating func appendExecutorLittleEndian<Value: FixedWidthInteger>(
        _ value: Value
    ) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
