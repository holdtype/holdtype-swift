import Foundation
import HoldTypeDomain
@testable import HoldTypeIOSCore
import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSFailedHistoryServiceIntegrationTests {
    @Test func fixedServiceRetriesCurrentAppStateWithoutLiveNetwork()
        async throws {
        let fixture = try await FailedHistoryServiceIntegrationFixture.make(
            providerMode: .success("Fixed graph retry")
        )
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let item = try #require(
            try await fixture.onlyFailedHistoryItem()
        )

        #expect(
            await fixture.service.retryFailedHistory(item.id) == .accepted
        )
        #expect(await fixture.provider.transcriptionCallCount() == 1)
        let request = try #require(
            await fixture.provider.lastTranscriptionRequest()
        )
        #expect(request.resolvedModel == "current-retry-model")
        #expect(request.resolvedLanguageCode == "en")
        #expect(
            request.promptComposition.dictionaryEchoGuardText
                == "HoldType Integration"
        )
        #expect(await fixture.keyStore.loadCallCount() == 0)
        guard case .ready = fixture.settingsStateOwner.state else {
            Issue.record("Expected one ready Settings state owner.")
            return
        }
        guard case .ready = fixture.libraryStateOwner.state else {
            Issue.record("Expected one ready Library state owner.")
            return
        }
        guard case .active(let delivery)? = try await fixture.context
                .deliveryStore.load() else {
            Issue.record("Expected accepted Retry delivery.")
            return
        }
        #expect(delivery.acceptedText == "Fixed graph retry")
        #expect(delivery.attemptID == fixture.attemptID)
    }

    @Test func missingConsentStopsBeforeReservationCredentialAndProvider()
        async throws {
        let fixture = try await FailedHistoryServiceIntegrationFixture.make(
            providerMode: .success("must not run"),
            acceptConsent: false
        )
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let item = try #require(
            try await fixture.onlyFailedHistoryItem()
        )

        #expect(
            await fixture.service.retryFailedHistory(item.id)
                == .setupRequired(.microphoneAndPrivacy)
        )
        #expect(await fixture.provider.transcriptionCallCount() == 0)
        #expect(await fixture.keyStore.loadCallCount() == 0)
        let unchanged = try #require(
            try await fixture.onlyFailedHistoryItem()
        )
        #expect(unchanged.retryCount == item.retryCount)
        #expect(try await fixture.context.deliveryStore.load() == nil)
    }

    @Test func fixedServiceCancellationAfterDispatchPublishesNoResult()
        async throws {
        let fixture = try await FailedHistoryServiceIntegrationFixture.make(
            providerMode: .waitForCancellation
        )
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let item = try #require(
            try await fixture.onlyFailedHistoryItem()
        )
        let retryTask = Task {
            await fixture.service.retryFailedHistory(item.id)
        }
        try await failedHistoryServiceEventually {
            await fixture.provider.transcriptionCallCount() == 1
        }

        retryTask.cancel()
        #expect(await retryTask.value == .cancelled)
        #expect(try await fixture.context.deliveryStore.load() == nil)
        guard case .available(let remaining) = await fixture.service
                .loadFailedHistory() else {
            Issue.record("Expected the cancelled row to remain retryable.")
            return
        }
        #expect(remaining.map(\.id).contains(item.id))
        #expect(await fixture.keyStore.loadCallCount() == 0)
    }

    @Test func withdrawalRejectsLateProviderResultAndCredentialFailure()
        async throws {
        let fixture = try await FailedHistoryServiceIntegrationFixture.make(
            providerMode: .waitForRelease(.failure(.credentialRejected))
        )
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let item = try #require(
            try await fixture.onlyFailedHistoryItem()
        )
        let acceptedConsent = try #require(
            fixture.acceptedConsentObservation
        )
        let retryTask = Task {
            await fixture.service.retryFailedHistory(item.id)
        }
        try await failedHistoryServiceEventually {
            await fixture.provider.transcriptionCallCount() == 1
        }

        _ = try await fixture.providerConsentCoordinator.withdraw(
            using: acceptedConsent
        )
        #expect(
            await retryTask.value
                == .setupRequired(.microphoneAndPrivacy)
        )
        #expect(try await fixture.context.deliveryStore.load() == nil)
        let remaining = try #require(
            try await fixture.onlyFailedHistoryItem()
        )
        #expect(remaining.retryCount == item.retryCount + 1)

        await fixture.provider.release()
        for _ in 0..<8 { await Task.yield() }
        #expect(try await fixture.context.deliveryStore.load() == nil)
        let credentialOutcome = try await fixture.credentialCoordinator
            .resolve(for: .voicePreflight)
        guard case .available = credentialOutcome.resolution else {
            Issue.record("Late rejected output must not poison the credential.")
            return
        }
    }
}

@MainActor
private struct FailedHistoryServiceIntegrationFixture {
    let root: URL
    let attemptID: UUID
    let context: IOSAcceptedHistoryCoordinatorProcessContext
    let service: IOSFailedHistoryService
    let settingsStateOwner: IOSAppSettingsStateOwner
    let libraryStateOwner: IOSLibraryStateOwner
    let providerConsentCoordinator: IOSProviderConsentCoordinator
    let acceptedConsentObservation: IOSProviderConsentObservation?
    let credentialCoordinator: IOSOpenAICredentialCoordinator
    let provider: FailedHistoryServiceProvider
    let keyStore: FailedHistoryServiceKeyStore

    static func make(
        providerMode: FailedHistoryServiceProvider.Mode,
        acceptConsent: Bool = true
    ) async throws -> Self {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "ios-failed-history-service-integration-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        do {
            let attemptID = try await seedFailedHistory(in: root)
            let settingsRepository = IOSAppSettingsRepository(
                applicationSupportDirectoryURL: root
            )
            try await settingsRepository.save(
                IOSAppSettings(
                    transcriptionConfiguration: TranscriptionConfiguration(
                        model: "stale-retry-model",
                        language: .french
                    )
                )
            )
            let libraryRepository = IOSLibraryRepository(
                applicationSupportDirectoryURL: root
            )
            try await libraryRepository.save(
                IOSLibraryContent(
                    customDictionary: CustomDictionary(
                        entries: ["Stale Integration"]
                    )
                )
            )
            let settingsStore = FailedHistoryServiceStateStore(
                value: IOSAppSettings.defaults
            )
            let libraryStore = FailedHistoryServiceStateStore(
                value: IOSLibraryContent.defaults
            )
            let settingsStateOwner = IOSAppSettingsStateOwner(
                load: { await settingsStore.load() },
                commit: { await settingsStore.commit($0) }
            )
            let libraryStateOwner = IOSLibraryStateOwner(
                load: { await libraryStore.load() },
                commit: { await libraryStore.commit($0) }
            )
            let keyStore = FailedHistoryServiceKeyStore()
            let credentialCoordinator = IOSOpenAICredentialCoordinator(
                keychainStorage: keyStore,
                markerRepository: CredentialPresenceMarkerRepository(
                    fileURL: IOSCredentialPresenceMarkerStorageLocation
                        .fileURL(in: root)
                )
            )
            _ = try await credentialCoordinator.saveOrReplace(
                "sk-fixed-service-integration"
            )
            let providerConsentCoordinator = IOSProviderConsentCoordinator(
                applicationSupportDirectoryURL: root
            )
            let acceptedConsentObservation:
                IOSProviderConsentObservation?
            if acceptConsent {
                let initial = await providerConsentCoordinator.observe()
                acceptedConsentObservation = try await
                    providerConsentCoordinator.accept(using: initial)
            } else {
                acceptedConsentObservation = nil
            }
            let provider = FailedHistoryServiceProvider(mode: providerMode)
            let service = IOSFailedHistoryService(
                applicationSupportDirectoryURL: root,
                loadSettings: {
                    try await settingsStateOwner
                        .confirmedValueForProviderAction()
                },
                loadLibrary: {
                    try await libraryStateOwner
                        .confirmedValueForProviderAction()
                },
                providerConsentCoordinator: providerConsentCoordinator,
                credentialCoordinator: credentialCoordinator,
                providerBuilder: FailedHistoryServiceProviderBuilder(
                    provider: provider
                )
            )
            try await settingsStateOwner.update { settings in
                settings.transcriptionConfiguration =
                    TranscriptionConfiguration(
                        model: "current-retry-model",
                        language: .english
                    )
            }
            try await libraryStateOwner.update { library in
                library.customDictionary = CustomDictionary(
                    entries: ["HoldType Integration"]
                )
            }
            let context = IOSAcceptedHistoryCoordinatorProcessContextRegistry
                .shared.context(for: root)
            let lifecycleCoordinator = IOSAcceptedHistoryCoordinator(
                applicationSupportDirectoryURL: root
            )
            var disposition = await lifecycleCoordinator
                .recoverContainingAppLifecycle(.processLaunch)
            for _ in 0..<12 where disposition == .pendingLocalRecovery {
                disposition = await lifecycleCoordinator
                    .recoverContainingAppLifecycle(.processLaunch)
            }
            #expect(disposition == .complete)
            return Self(
                root: root,
                attemptID: attemptID,
                context: context,
                service: service,
                settingsStateOwner: settingsStateOwner,
                libraryStateOwner: libraryStateOwner,
                providerConsentCoordinator: providerConsentCoordinator,
                acceptedConsentObservation: acceptedConsentObservation,
                credentialCoordinator: credentialCoordinator,
                provider: provider,
                keyStore: keyStore
            )
        } catch {
            try? FileManager.default.removeItem(at: root)
            throw error
        }
    }

    func onlyFailedHistoryItem() async throws -> IOSFailedHistoryItem? {
        guard case .available(let items) = await service.loadFailedHistory()
        else {
            return nil
        }
        #expect(items.count == 1)
        return items.first
    }

    private static func seedFailedHistory(in root: URL) async throws -> UUID {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let context = registry.context(for: root)
        let coordinator = failedHistoryServiceCoordinator(
            context: context,
            registry: registry,
            root: root
        )
        _ = try await coordinator.capture(
            transcriptionModel: "seed-model",
            transcriptionLanguageCode: "en",
            durationMilliseconds: 1_000
        )
        let attemptID = UUID()
        let sourceURL = root.appendingPathComponent(
            "seed-\(attemptID.uuidString.lowercased()).wav"
        )
        let audio = failedHistoryServiceWAV()
        try audio.write(to: sourceURL)
        let pending = try await context.pendingRecordingStore.prepare(
            IOSPendingRecordingPreparation(
                attemptID: attemptID,
                sourceArtifact: AudioRecordingArtifact(
                    fileURL: sourceURL,
                    duration: 1,
                    byteCount: Int64(audio.count)
                ),
                initialState: .awaitingRecovery,
                outputIntent: .standard,
                transcriptionConfiguration: .defaults
            )
        )
        #expect(
            try await coordinator.transferPendingRecordingFailure(
                expected: IOSPendingRecordingCASExpectation(
                    recording: pending
                ),
                failure: IOSFailedHistoryTransferFailure(
                    category: .networkUnavailable,
                    pipelineStage: .transcription
                )
            ) == .transferred
        )
        return attemptID
    }
}

private struct FailedHistoryServiceProviderBuilder:
    IOSFailedHistoryRetryProviderBuilding {
    let provider: FailedHistoryServiceProvider

    func makeFailedHistoryRetryProvider(
        credential: IOSResolvedOpenAICredential
    ) async -> any IOSFailedHistoryRetryProviderExecuting {
        _ = credential
        return provider
    }
}

private actor FailedHistoryServiceStateStore<Value: Sendable> {
    private var value: Value

    init(value: Value) {
        self.value = value
    }

    func load() -> Value { value }

    func commit(_ candidate: Value) -> Value {
        value = candidate
        return candidate
    }
}

private actor FailedHistoryServiceProvider:
    IOSFailedHistoryRetryProviderExecuting {
    enum Mode: Sendable {
        case success(String)
        case waitForCancellation
        case waitForRelease(IOSFailedHistoryRetryProviderTextOutcome)
    }

    private let mode: Mode
    private var transcriptionCalls = 0
    private var lastRequest:
        IOSFailedHistoryRetryTranscriptionRequest?
    private var releaseContinuation: CheckedContinuation<
        IOSFailedHistoryRetryProviderTextOutcome,
        Never
    >?

    init(mode: Mode) {
        self.mode = mode
    }

    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        transcriptionCalls += 1
        lastRequest = request
        switch mode {
        case .success(let text):
            return .success(text)
        case .waitForCancellation:
            do {
                try await Task.sleep(for: .seconds(60))
                return .failure(.unknown)
            } catch {
                return .failure(.cancelled)
            }
        case .waitForRelease:
            return await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
    }

    func correct(
        _ request: IOSFailedHistoryRetryCorrectionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        return .failure(.unknown)
    }

    func translate(
        _ request: IOSFailedHistoryRetryTranslationRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        return .failure(.unknown)
    }

    func transcriptionCallCount() -> Int { transcriptionCalls }

    func lastTranscriptionRequest()
        -> IOSFailedHistoryRetryTranscriptionRequest? {
        lastRequest
    }

    func release() {
        guard case .waitForRelease(let outcome) = mode else { return }
        let continuation = releaseContinuation
        releaseContinuation = nil
        continuation?.resume(returning: outcome)
    }
}

private actor FailedHistoryServiceKeyStore: OpenAIAPIKeyStoring {
    private var storedKey: String?
    private var loads = 0

    func saveOrReplaceAPIKey(_ candidate: String) async throws {
        storedKey = candidate
    }

    func loadAPIKey() async throws -> String? {
        loads += 1
        return storedKey
    }

    func removeAPIKey() async throws {
        storedKey = nil
    }

    func loadCallCount() -> Int { loads }
}

private func failedHistoryServiceCoordinator(
    context: IOSAcceptedHistoryCoordinatorProcessContext,
    registry: IOSAcceptedHistoryCoordinatorProcessContextRegistry,
    root: URL
) -> IOSAcceptedHistoryCoordinator {
    IOSAcceptedHistoryCoordinator(
        policyStore: context.policyStore,
        acceptedHistoryStore: context.acceptedHistoryStore,
        failedHistoryStore: context.failedHistoryStore,
        pendingRecordingStore: context.pendingRecordingStore,
        outboxStore: context.outboxStore,
        deliveryStore: context.deliveryStore,
        operationGate: context.operationGate,
        baselineRecoveryState: context.baselineRecoveryState,
        acceptanceState: context.acceptanceState,
        pendingReplacementState: context.pendingReplacementState,
        outboxWorkerState: context.outboxWorkerState,
        policyCutoverState: context.policyCutoverState,
        failedHistoryTransferState: context.failedHistoryTransferState,
        failedHistoryAudioCleanupState:
            context.failedHistoryAudioCleanupState,
        failedHistoryRetryState: context.failedHistoryRetryState,
        ownerIdentity: context.ownerIdentity,
        repositoryIdentityState: context.repositoryIdentityState,
        repositoryRegistration:
            IOSAcceptedHistoryCoordinatorRepositoryRegistration(
                registry: registry,
                context: context,
                applicationSupportDirectoryURL: root
            )
    )
}

private func failedHistoryServiceWAV() -> Data {
    let sampleRate: UInt32 = 8_000
    let channelCount: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let dataByteCount = sampleRate * UInt32(bitsPerSample / 8)
    let byteRate = sampleRate * UInt32(channelCount)
        * UInt32(bitsPerSample / 8)
    let blockAlign = channelCount * (bitsPerSample / 8)

    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.appendFailedHistoryServiceLittleEndian(UInt32(36) + dataByteCount)
    data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8)
    data.appendFailedHistoryServiceLittleEndian(UInt32(16))
    data.appendFailedHistoryServiceLittleEndian(UInt16(1))
    data.appendFailedHistoryServiceLittleEndian(channelCount)
    data.appendFailedHistoryServiceLittleEndian(sampleRate)
    data.appendFailedHistoryServiceLittleEndian(byteRate)
    data.appendFailedHistoryServiceLittleEndian(blockAlign)
    data.appendFailedHistoryServiceLittleEndian(bitsPerSample)
    data.append(contentsOf: "data".utf8)
    data.appendFailedHistoryServiceLittleEndian(dataByteCount)
    data.append(Data(repeating: 0, count: Int(dataByteCount)))
    return data
}

private extension Data {
    mutating func appendFailedHistoryServiceLittleEndian<
        Value: FixedWidthInteger
    >(_ value: Value) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}

private func failedHistoryServiceEventually(
    _ predicate: @escaping @Sendable () async -> Bool
) async throws {
    for _ in 0..<200 {
        if await predicate() { return }
        try await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Timed out waiting for fixed service provider dispatch.")
}
