import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence
import Testing
@testable import HoldTypeIOSCore

struct IOSProviderConsentFailedHistoryRetryProviderTests {
    @Test func retryMethodsMapToThreeIndependentConsentStages()
        async throws {
        let fixture = try await RetryConsentProviderFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let baseProvider = RetryConsentRecordingProvider()
        let stageExecutor = RetryConsentStageExecutorSpy()
        let provider = IOSProviderConsentFailedHistoryRetryProvider(
            provider: baseProvider,
            consentObservation: fixture.acceptedObservation,
            consentCoordinator: fixture.coordinator,
            stageExecutor: stageExecutor
        )
        let requests = try RetryConsentRequests(root: fixture.root)

        #expect(
            await provider.transcribe(requests.transcription)
                == .success("transcription")
        )
        #expect(
            await provider.correct(requests.correction)
                == .success("correction")
        )
        #expect(
            await provider.translate(requests.translation)
                == .success("translation")
        )
        #expect(
            await stageExecutor.recordedStages()
                == [.transcription, .correction, .translation]
        )
        #expect(
            await baseProvider.recordedStages()
                == [.transcription, .correction, .translation]
        )
    }

    @Test func withdrawnObservationInvokesNoRetryProviderStage()
        async throws {
        let fixture = try await RetryConsentProviderFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let baseProvider = RetryConsentRecordingProvider()
        let provider = IOSProviderConsentFailedHistoryRetryProvider(
            provider: baseProvider,
            consentObservation: fixture.acceptedObservation,
            consentCoordinator: fixture.coordinator
        )
        let requests = try RetryConsentRequests(root: fixture.root)
        _ = try await fixture.coordinator.withdraw(
            using: fixture.acceptedObservation
        )

        #expect(
            await provider.transcribe(requests.transcription)
                == .failure(.authorizationUnavailable)
        )
        #expect(
            await provider.correct(requests.correction)
                == .failure(.authorizationUnavailable)
        )
        #expect(
            await provider.translate(requests.translation)
                == .failure(.authorizationUnavailable)
        )
        #expect(await baseProvider.recordedStages().isEmpty)
    }

    @Test func withdrawalFinishesBeforeNoncooperativeLateRetryResult()
        async throws {
        let fixture = try await RetryConsentProviderFixture.make()
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let baseProvider = RetryConsentControlledProvider()
        let provider = IOSProviderConsentFailedHistoryRetryProvider(
            provider: baseProvider,
            consentObservation: fixture.acceptedObservation,
            consentCoordinator: fixture.coordinator
        )
        let request = try RetryConsentRequests(root: fixture.root).correction
        let outcome = RetryConsentLockedOutcome()
        let task = Task {
            outcome.set(await provider.correct(request))
        }
        await baseProvider.waitUntilStarted()

        _ = try await fixture.coordinator.withdraw(
            using: fixture.acceptedObservation
        )
        for _ in 0..<100 where outcome.value == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        let completedBeforeRelease = outcome.value != nil
        #expect(completedBeforeRelease)
        #expect(outcome.value == .failure(.authorizationUnavailable))

        await baseProvider.release(.success("late correction"))
        await task.value
        #expect(outcome.value == .failure(.authorizationUnavailable))
        #expect(await baseProvider.callCount() == 1)
    }
}

private struct RetryConsentProviderFixture {
    let root: URL
    let coordinator: IOSProviderConsentCoordinator
    let acceptedObservation: IOSProviderConsentObservation

    static func make() async throws -> Self {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ios-retry-consent-provider-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false,
            attributes: [.posixPermissions: 0o700]
        )
        do {
            let coordinator = IOSProviderConsentCoordinator(
                applicationSupportDirectoryURL: root
            )
            let initial = await coordinator.observe()
            let accepted = try await coordinator.accept(using: initial)
            return Self(
                root: root,
                coordinator: coordinator,
                acceptedObservation: accepted
            )
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }
}

private struct RetryConsentRequests {
    let transcription: IOSFailedHistoryRetryTranscriptionRequest
    let correction: IOSFailedHistoryRetryCorrectionRequest
    let translation: IOSFailedHistoryRetryTranslationRequest

    init(root: URL) throws {
        let transcript = try AcceptedTranscript(rawText: "source")
        transcription = IOSFailedHistoryRetryTranscriptionRequest(
            transcriptionID: UUID(),
            audio: IOSPendingTranscriptionAudio(
                lease: RetryConsentAudioLease(root: root)
            ),
            resolvedModel: "gpt-4o-mini-transcribe",
            resolvedLanguageCode: "en",
            promptComposition: TranscriptionPromptComposition(
                resolvedFreeformPrompt: nil,
                context: nil,
                emojiCommandsConfiguration: .init(isEnabled: false),
                customDictionary: .empty
            ),
            timeout: .seconds(1)
        )
        correction = IOSFailedHistoryRetryCorrectionRequest(
            transcript: transcript,
            configuration: .defaults,
            timeout: .seconds(1)
        )
        translation = IOSFailedHistoryRetryTranslationRequest(
            translationRequest: TextTranslationRequest(
                acceptedTranscript: transcript,
                translationConfiguration: TranslationConfiguration(
                    targetLanguage: .english
                ),
                transcriptionConfiguration: .defaults
            ),
            timeout: .seconds(1)
        )
    }
}

private actor RetryConsentStageExecutorSpy:
    IOSFailedHistoryRetryConsentStageExecuting {
    private var stages: [IOSProviderConsentProviderStage] = []

    func execute(
        _ authorization: IOSProviderConsentAuthorization,
        for stage: IOSProviderConsentProviderStage,
        operation: @escaping @concurrent @Sendable () async
            -> IOSFailedHistoryRetryProviderTextOutcome
    ) async -> IOSProviderConsentStageOutcome<
        IOSFailedHistoryRetryProviderTextOutcome,
        IOSFailedHistoryRetryRuntimeFailure
    > {
        _ = authorization
        stages.append(stage)
        return .success(await operation())
    }

    func recordedStages() -> [IOSProviderConsentProviderStage] { stages }
}

private actor RetryConsentRecordingProvider:
    IOSFailedHistoryRetryProviderExecuting {
    private var stages: [IOSProviderConsentProviderStage] = []

    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        stages.append(.transcription)
        return .success("transcription")
    }

    func correct(
        _ request: IOSFailedHistoryRetryCorrectionRequest
    ) -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        stages.append(.correction)
        return .success("correction")
    }

    func translate(
        _ request: IOSFailedHistoryRetryTranslationRequest
    ) -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        stages.append(.translation)
        return .success("translation")
    }

    func recordedStages() -> [IOSProviderConsentProviderStage] { stages }
}

private actor RetryConsentControlledProvider:
    IOSFailedHistoryRetryProviderExecuting {
    private var calls = 0
    private var started = false
    private var startWaiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<
        IOSFailedHistoryRetryProviderTextOutcome,
        Never
    >?

    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        return .failure(.unknown)
    }

    func correct(
        _ request: IOSFailedHistoryRetryCorrectionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        calls += 1
        started = true
        startWaiters.forEach { $0.resume() }
        startWaiters.removeAll(keepingCapacity: false)
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func translate(
        _ request: IOSFailedHistoryRetryTranslationRequest
    ) -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        return .failure(.unknown)
    }

    func waitUntilStarted() async {
        guard !started else { return }
        await withCheckedContinuation { continuation in
            startWaiters.append(continuation)
        }
    }

    func release(_ outcome: IOSFailedHistoryRetryProviderTextOutcome) {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: outcome)
    }

    func callCount() -> Int { calls }
}

private final class RetryConsentAudioLease:
    IOSPendingRecordingPublishedAudioLease,
    @unchecked Sendable {
    let relativeIdentifier = "Recordings/Pending/consent-retry.wav"
    let audioArtifact: AudioRecordingArtifact
    let durationMilliseconds: Int64 = 1_000

    init(root: URL) {
        audioArtifact = AudioRecordingArtifact(
            fileURL: root.appendingPathComponent("consent-retry.wav"),
            duration: 1,
            byteCount: 1
        )
    }

    func revalidate() async throws -> AudioRecordingArtifact { audioArtifact }

    func read(
        atOffset offset: Int64,
        maximumByteCount: Int
    ) async throws -> Data {
        _ = maximumByteCount
        return offset == 0 ? Data([1]) : Data()
    }

    func release() {}
}

private final class RetryConsentLockedOutcome: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: IOSFailedHistoryRetryProviderTextOutcome?

    var value: IOSFailedHistoryRetryProviderTextOutcome? {
        lock.withLock { storedValue }
    }

    func set(_ value: IOSFailedHistoryRetryProviderTextOutcome) {
        lock.withLock { storedValue = value }
    }
}
