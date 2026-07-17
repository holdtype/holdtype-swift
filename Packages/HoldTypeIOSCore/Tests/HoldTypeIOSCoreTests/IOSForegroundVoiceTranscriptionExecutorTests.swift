import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence
import Testing
@testable import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) @testable import HoldTypeIOSCore

@MainActor
@Suite(.serialized)
struct IOSForegroundVoiceTranscriptionExecutorTests {
    @Test func dispatchBindsExactM4AReaderMetadataAndNormalizedResult()
        async throws {
        let fixture = try await TranscriptionExecutorFixture()
        defer { fixture.removeFiles() }
        let capture = ReaderRequestCapture()
        let composition = makePromptComposition("reader-bound prompt")
        let executor = try fixture.makeExecutor(
            promptComposition: composition,
            transcribe: { request, _ in
                capture.record(try await inspectReaderRequest(request))
                return " \n  Reader-bound result  \t"
            }
        )
        let dispatch = try await fixture.beginTranscription()

        let result = try await dispatch.execute(using: executor)
        let observation = try #require(capture.observation)

        #expect(result == "Reader-bound result")
        #expect(observation.format == .m4a)
        #expect(observation.durationMilliseconds == fixture.durationMilliseconds)
        #expect(observation.byteCount == Int64(fixture.audio.count))
        #expect(observation.model == fixture.configuration.resolvedModel)
        #expect(
            observation.languageCode
                == fixture.configuration.resolvedLanguageCode
        )
        #expect(observation.promptComposition == composition)
        #expect(observation.audio == fixture.audio)
        #expect(observation.offsets.first == 0)
        #expect(observation.chunkByteCounts.last == 0)
        #expect(
            observation.maximumRequestedByteCount
                == OpenAITranscriptionAudioReader.maximumReadByteCount
        )
        #expect(observation.oversizedReadWasRejected)
        #expect(
            OpenAITranscriptionAudioReader.maximumReadByteCount
                == IOSV1PendingTranscriptionAudio.maximumReadByteCount
        )
    }

    @Test func completedHandoffInvalidatesCapturedReader() async throws {
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
            throws: IOSV1ForegroundVoicePersistenceError
                .dispatchAlreadyExecuted
        ) {
            try await reader.read(
                atOffset: 0,
                maximumByteCount:
                    OpenAITranscriptionAudioReader.maximumReadByteCount
            )
        }
    }

    @Test func dispatchCanExecuteOnlyOnce() async throws {
        let fixture = try await TranscriptionExecutorFixture()
        defer { fixture.removeFiles() }
        let providerCalls = LockedInteger()
        let executor = try fixture.makeExecutor(
            promptComposition: makePromptComposition(nil),
            transcribe: { _, _ in
                providerCalls.increment()
                return "Once"
            }
        )
        let dispatch = try await fixture.beginTranscription()

        #expect(try await dispatch.execute(using: executor) == "Once")
        await #expect(
            throws: IOSV1ForegroundVoicePersistenceError
                .dispatchAlreadyExecuted
        ) {
            _ = try await dispatch.execute(using: executor)
        }
        #expect(providerCalls.value == 1)
    }

    @Test func explicitUnknownDurationRetryReachesProviderExactlyOnce()
        async throws {
        let fixture = try await TranscriptionExecutorFixture(
            unknownDuration: true
        )
        defer { fixture.removeFiles() }

        await #expect(
            throws: IOSV1ForegroundVoicePersistenceError.audioInvalid
        ) {
            _ = try await fixture.beginTranscription()
        }
        let failed = try #require(
            try await fixture.persistenceOwner.load()?.recording
        )
        #expect(failed.phase == .failed)
        #expect(failed.durationMilliseconds == 0)

        let capture = ReaderRequestCapture()
        let providerCalls = LockedInteger()
        let executor = try fixture.makeExecutor(
            promptComposition: makePromptComposition(nil),
            transcribe: { request, _ in
                providerCalls.increment()
                capture.record(try await inspectReaderRequest(request))
                return "Manual retry"
            }
        )
        let dispatch = try await fixture.persistenceOwner.retryTranscription(
            expected: IOSV1PendingRecordingExpectation(recording: failed),
            transcriptionID: UUID(),
            transcriptionConfiguration: fixture.configuration
        )

        #expect(
            try await dispatch.execute(using: executor) == "Manual retry"
        )
        let observation = try #require(capture.observation)
        #expect(observation.durationMilliseconds == 1)
        #expect(observation.byteCount == Int64(fixture.audio.count))
        #expect(observation.audio == fixture.audio)
        await #expect(
            throws: IOSV1ForegroundVoicePersistenceError
                .dispatchAlreadyExecuted
        ) {
            _ = try await dispatch.execute(using: executor)
        }
        #expect(providerCalls.value == 1)
    }

    @Test func executorDiagnosticsRedactCredentialPromptAndProviderState()
        async throws {
        let fixture = try await TranscriptionExecutorFixture()
        defer { fixture.removeFiles() }
        let promptCanary = "EXECUTOR-PROMPT-CANARY-712"
        let executor = try fixture.makeExecutor(
            promptComposition: makePromptComposition(promptCanary),
            transcribe: { _, _ in "unused" }
        )
        var dumped = ""
        dump(executor, to: &dumped)
        let diagnostics = [
            dumped,
            String(describing: executor),
            String(reflecting: executor),
        ].joined(separator: "\n")

        #expect(
            diagnostics.contains(
                "IOSForegroundVoiceTranscriptionExecutor(redacted)"
            )
        )
        for canary in [promptCanary, "sk-adapter-test", fixture.root.path] {
            #expect(!diagnostics.contains(canary))
        }
    }
}

private final class TranscriptionExecutorFixture: @unchecked Sendable {
    let root: URL
    let audio: Data
    let durationMilliseconds: Int64
    let configuration: TranscriptionConfiguration
    let persistenceOwner: IOSV1ForegroundVoicePersistenceOwner
    let consentCoordinator: IOSV1ProviderConsentCoordinator
    let acceptedConsent: IOSV1ProviderConsentObservation
    let pending: IOSV1PendingRecording
    let credential: OpenAICredential

    init(unknownDuration: Bool = false) async throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ios-v1-transcription-executor-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let audioData: Data
        if unknownDuration {
            durationMilliseconds = 0
            audioData = Data([1, 2, 3, 4])
        } else {
            durationMilliseconds = 6_000
            audioData = try makeForegroundVoiceTestM4A(durationSeconds: 6)
        }
        audio = audioData
        configuration = TranscriptionConfiguration(
            model: "reader-bound-model",
            language: .russian,
            freeformPrompt: "initial fixture prompt"
        )
        persistenceOwner = IOSV1ForegroundVoicePersistenceOwner(
            applicationSupportDirectoryURL: root
        )
        let lease = try await persistenceOwner.createCapture(
            attemptID: UUID(),
            outputIntent: .standard
        )
        try lease.withTransientRecordingURL { url in
            let handle = try FileHandle(forWritingTo: url)
            try handle.truncate(atOffset: 0)
            try handle.write(contentsOf: audioData)
            try handle.close()
        }
        try lease.revalidateRecorderCheckpoint()
        try await lease.beginFinalizing()
        guard case .completed(let completed) =
            try await lease.completeAfterRecorderClose(
                fallbackDurationMilliseconds: unknownDuration
                    ? nil : durationMilliseconds
            ) else {
            throw TranscriptionExecutorFixtureError.setupFailed
        }
        _ = try await persistenceOwner.prepareCompletedCapture(
            completed,
            transcriptionConfiguration: configuration
        )
        guard let prepared = try await persistenceOwner.load()?.recording else {
            throw TranscriptionExecutorFixtureError.setupFailed
        }
        pending = prepared

        consentCoordinator = IOSV1ProviderConsentCoordinator(
            applicationSupportDirectoryURL: root
        )
        acceptedConsent = try await consentCoordinator.accept(
            using: await consentCoordinator.observe(),
            decisionAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        credential = try OpenAICredential(apiKey: "sk-adapter-test")
    }

    func beginTranscription() async throws
        -> IOSV1ForegroundVoiceTranscriptionDispatch {
        try await persistenceOwner.beginTranscription(
            expected: IOSV1PendingRecordingExpectation(recording: pending),
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
    func increment() { lock.withLock { storedValue += 1 } }
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
