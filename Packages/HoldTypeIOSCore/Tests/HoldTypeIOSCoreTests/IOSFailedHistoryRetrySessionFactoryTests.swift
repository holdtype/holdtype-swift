import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOSCore

struct IOSFailedHistoryRetrySessionFactoryTests {
    @Test func everyRequestedSessionReloadsSettingsAndLibraryWithoutNearbyText()
        async throws {
        let root = try retryFactoryTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var initialSettings = IOSAppSettings.defaults
        initialSettings.transcriptionConfiguration = TranscriptionConfiguration(
            model: "first-model",
            language: .english,
            freeformPrompt: "first prompt"
        )
        let configurationStore = RetryFactoryConfigurationStore(
            settings: initialSettings,
            library: IOSLibraryContent(
                customDictionary: CustomDictionary(entries: ["HoldType"])
            )
        )

        let keyStore = RetryFactoryAPIKeyStore(storedKey: "sk-session-one")
        let credentialCoordinator = IOSOpenAICredentialCoordinator(
            keychainStorage: keyStore,
            markerRepository: CredentialPresenceMarkerRepository(
                fileURL: IOSCredentialPresenceMarkerStorageLocation.fileURL(
                    in: root
                )
            )
        )
        let providerBuilder = RetryFactoryProviderBuilder()
        let factory = IOSFailedHistoryRetrySessionFactory(
            loadSettings: { await configurationStore.loadSettings() },
            loadLibrary: { await configurationStore.loadLibrary() },
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder
        )

        guard case .ready(let first) = await factory
            .makeFailedHistoryRetrySession(for: .standard) else {
            Issue.record("Expected a ready standard Retry session.")
            return
        }
        #expect(
            first.configuration.transcriptionConfiguration.resolvedModel
                == "first-model"
        )
        #expect(
            first.configuration.transcriptionPromptComposition.providerPrompt?
                .contains("HoldType") == true
        )
        #expect(
            first.configuration.transcriptionPromptComposition
                .contextEchoGuardText == nil
        )
        #expect(first.configuration.translationConfiguration == nil)

        var updatedSettings = initialSettings
        updatedSettings.transcriptionConfiguration = TranscriptionConfiguration(
            model: "second-model",
            language: .french,
            freeformPrompt: "second prompt"
        )
        updatedSettings.translationConfiguration = TranslationConfiguration(
            targetLanguage: .english
        )
        await configurationStore.replace(
            settings: updatedSettings,
            library: IOSLibraryContent(
                customDictionary: CustomDictionary(entries: ["VibeType"])
            )
        )

        guard case .ready(let second) = await factory
            .makeFailedHistoryRetrySession(for: .translate) else {
            Issue.record("Expected a ready Translation Retry session.")
            return
        }
        #expect(
            second.configuration.transcriptionConfiguration.resolvedModel
                == "second-model"
        )
        #expect(
            second.configuration.transcriptionPromptComposition.providerPrompt?
                .contains("VibeType") == true
        )
        #expect(
            second.configuration.transcriptionPromptComposition.providerPrompt?
                .contains("HoldType") == false
        )
        #expect(second.configuration.translationConfiguration?.canRunAction == true)
        #expect(await providerBuilder.resolvedKeys() == [
            "sk-session-one", "sk-session-one",
        ])
        #expect(await keyStore.loadCallCount() == 1)
    }

    @Test func missingCredentialAndInvalidTranslationRouteBeforeProviderBuild()
        async throws {
        let root = try retryFactoryTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let keyStore = RetryFactoryAPIKeyStore(storedKey: nil)
        let credentialCoordinator = IOSOpenAICredentialCoordinator(
            keychainStorage: keyStore,
            markerRepository: CredentialPresenceMarkerRepository(
                fileURL: IOSCredentialPresenceMarkerStorageLocation.fileURL(
                    in: root
                )
            )
        )
        let providerBuilder = RetryFactoryProviderBuilder()
        let factory = IOSFailedHistoryRetrySessionFactory(
            loadSettings: { .defaults },
            loadLibrary: { .defaults },
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder
        )

        guard case .setupRequired(.openAI) = await factory
            .makeFailedHistoryRetrySession(for: .standard) else {
            Issue.record("Expected OpenAI setup before Retry.")
            return
        }
        #expect(await providerBuilder.resolvedKeys().isEmpty)

        let configuredKeyStore = RetryFactoryAPIKeyStore(
            storedKey: "sk-session-two"
        )
        let configuredCoordinator = IOSOpenAICredentialCoordinator(
            keychainStorage: configuredKeyStore,
            markerRepository: CredentialPresenceMarkerRepository(
                fileURL: root.appendingPathComponent(
                    "credential-marker-2.json"
                )
            )
        )
        let invalidTranslationFactory = IOSFailedHistoryRetrySessionFactory(
            loadSettings: { .defaults },
            loadLibrary: { .defaults },
            credentialCoordinator: configuredCoordinator,
            providerBuilder: providerBuilder
        )
        guard case .setupRequired(.translation) = await
                invalidTranslationFactory.makeFailedHistoryRetrySession(
                    for: .translate
                ) else {
            Issue.record("Expected Translation setup before Retry.")
            return
        }
        #expect(await providerBuilder.resolvedKeys().isEmpty)
    }

    @Test func configurationLoadFailureStopsBeforeCredentialOrProvider()
        async throws {
        let root = try retryFactoryTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let keyStore = RetryFactoryAPIKeyStore(
            storedKey: "sk-never-resolved"
        )
        let credentialCoordinator = IOSOpenAICredentialCoordinator(
            keychainStorage: keyStore,
            markerRepository: CredentialPresenceMarkerRepository(
                fileURL: IOSCredentialPresenceMarkerStorageLocation.fileURL(
                    in: root
                )
            )
        )
        let providerBuilder = RetryFactoryProviderBuilder()
        let settingsFailure = IOSFailedHistoryRetrySessionFactory(
            loadSettings: {
                throw RetryFactoryConfigurationLoadError.scripted
            },
            loadLibrary: {
                Issue.record("Library must not load after Settings failure.")
                return .defaults
            },
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder
        )
        let libraryFailure = IOSFailedHistoryRetrySessionFactory(
            loadSettings: { .defaults },
            loadLibrary: {
                throw RetryFactoryConfigurationLoadError.scripted
            },
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder
        )

        guard case .temporarilyUnavailable = await settingsFailure
            .makeFailedHistoryRetrySession(for: .standard) else {
            Issue.record("Expected Settings load failure to stay local.")
            return
        }
        guard case .temporarilyUnavailable = await libraryFailure
            .makeFailedHistoryRetrySession(for: .standard) else {
            Issue.record("Expected Library load failure to stay local.")
            return
        }
        #expect(await keyStore.loadCallCount() == 0)
        #expect(await providerBuilder.resolvedKeys().isEmpty)
    }

    @Test func cancellationDuringFreshSettingsLoadReturnsCancelledBeforeBuild()
        async throws {
        let root = try retryFactoryTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let settingsGate = RetryFactoryValueGate(IOSAppSettings.defaults)
        let keyStore = RetryFactoryAPIKeyStore(storedKey: "sk-cancelled")
        let credentialCoordinator = IOSOpenAICredentialCoordinator(
            keychainStorage: keyStore,
            markerRepository: CredentialPresenceMarkerRepository(
                fileURL: IOSCredentialPresenceMarkerStorageLocation.fileURL(
                    in: root
                )
            )
        )
        let providerBuilder = RetryFactoryProviderBuilder()
        let factory = IOSFailedHistoryRetrySessionFactory(
            loadSettings: { await settingsGate.load() },
            loadLibrary: { IOSLibraryContent.defaults },
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder
        )

        let task = Task {
            await factory.makeFailedHistoryRetrySession(for: .standard)
        }
        while await settingsGate.hasStarted() == false {
            await Task.yield()
        }
        task.cancel()
        await settingsGate.resume()

        guard case .cancelled = await task.value else {
            Issue.record("Expected cancellation before provider construction.")
            return
        }
        #expect(await providerBuilder.resolvedKeys().isEmpty)
        #expect(await keyStore.loadCallCount() == 0)
    }

    @Test func cancellationDuringProviderBuildReturnsCancelledSession()
        async throws {
        let root = try retryFactoryTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let keyStore = RetryFactoryAPIKeyStore(storedKey: "sk-provider-build")
        let credentialCoordinator = IOSOpenAICredentialCoordinator(
            keychainStorage: keyStore,
            markerRepository: CredentialPresenceMarkerRepository(
                fileURL: IOSCredentialPresenceMarkerStorageLocation.fileURL(
                    in: root
                )
            )
        )
        let providerBuilder = RetryFactorySuspendingProviderBuilder()
        let factory = IOSFailedHistoryRetrySessionFactory(
            loadSettings: { .defaults },
            loadLibrary: { .defaults },
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder
        )

        let task = Task {
            await factory.makeFailedHistoryRetrySession(for: .standard)
        }
        while await providerBuilder.hasStarted() == false {
            await Task.yield()
        }
        task.cancel()
        await providerBuilder.resume()

        guard case .cancelled = await task.value else {
            Issue.record("Expected cancellation after provider construction.")
            return
        }
        #expect(await providerBuilder.buildCount() == 1)
    }

    @Test func credentialRejectionTracksOnlyTheBoundGenerationAcrossStages()
        async throws {
        let root = try retryFactoryTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let keyStore = RetryFactoryAPIKeyStore(storedKey: "sk-generation-one")
        let credentialCoordinator = IOSOpenAICredentialCoordinator(
            keychainStorage: keyStore,
            markerRepository: CredentialPresenceMarkerRepository(
                fileURL: IOSCredentialPresenceMarkerStorageLocation.fileURL(
                    in: root
                )
            )
        )
        let firstCredential = try await resolvedCredential(
            from: credentialCoordinator
        )
        let firstProvider = IOSFailedHistoryRetryCredentialTrackingProvider(
            provider: RetryFactoryRejectedProvider(),
            credentialCoordinator: credentialCoordinator,
            credentialGeneration: firstCredential.generation
        )
        let transcript = try AcceptedTranscript(rawText: "hello")

        #expect(
            await firstProvider.correct(
                IOSFailedHistoryRetryCorrectionRequest(
                    transcript: transcript,
                    configuration: .defaults,
                    timeout: .seconds(1)
                )
            ) == .failure(.credentialRejected)
        )
        await expectProviderRejected(credentialCoordinator)

        _ = try await credentialCoordinator.saveOrReplace(
            "sk-generation-two"
        )
        let secondCredential = try await resolvedCredential(
            from: credentialCoordinator
        )
        #expect(
            secondCredential.credential.apiKey == "sk-generation-two"
        )

        let translation = TranslationConfiguration(
            targetLanguage: .english
        )
        #expect(
            await firstProvider.translate(
                IOSFailedHistoryRetryTranslationRequest(
                    translationRequest: TextTranslationRequest(
                        acceptedTranscript: transcript,
                        translationConfiguration: translation,
                        transcriptionConfiguration: .defaults
                    ),
                    timeout: .seconds(1)
                )
            ) == .failure(.credentialRejected)
        )
        let afterLateOldRejection = try await resolvedCredential(
            from: credentialCoordinator
        )
        #expect(afterLateOldRejection == secondCredential)

        let secondProvider = IOSFailedHistoryRetryCredentialTrackingProvider(
            provider: RetryFactoryRejectedProvider(),
            credentialCoordinator: credentialCoordinator,
            credentialGeneration: secondCredential.generation
        )
        await secondProvider.recordCredentialRejectionIfNeeded(
            .failure(.credentialRejected)
        )
        await expectProviderRejected(credentialCoordinator)
    }
}

private actor RetryFactoryConfigurationStore {
    private var settings: IOSAppSettings
    private var library: IOSLibraryContent

    init(settings: IOSAppSettings, library: IOSLibraryContent) {
        self.settings = settings
        self.library = library
    }

    func loadSettings() -> IOSAppSettings { settings }
    func loadLibrary() -> IOSLibraryContent { library }

    func replace(
        settings: IOSAppSettings,
        library: IOSLibraryContent
    ) {
        self.settings = settings
        self.library = library
    }
}

private enum RetryFactoryConfigurationLoadError: Error {
    case scripted
}

private actor RetryFactoryAPIKeyStore: OpenAIAPIKeyStoring {
    private var storedKey: String?
    private var storedLoadCallCount = 0

    init(storedKey: String?) {
        self.storedKey = storedKey
    }

    func saveOrReplaceAPIKey(_ candidate: String) async throws {
        storedKey = candidate
    }

    func loadAPIKey() async throws -> String? {
        storedLoadCallCount += 1
        return storedKey
    }

    func removeAPIKey() async throws {
        storedKey = nil
    }

    func loadCallCount() -> Int {
        storedLoadCallCount
    }
}

private actor RetryFactoryProviderBuilder:
    IOSFailedHistoryRetryProviderBuilding {
    private var keys: [String] = []

    func makeFailedHistoryRetryProvider(
        credential: IOSResolvedOpenAICredential
    ) async -> any IOSFailedHistoryRetryProviderExecuting {
        keys.append(credential.credential.apiKey)
        return RetryFactoryProvider()
    }

    func resolvedKeys() -> [String] {
        keys
    }
}

private actor RetryFactoryValueGate<Value: Sendable> {
    private let value: Value
    private var started = false
    private var continuation: CheckedContinuation<Value, Never>?

    init(_ value: Value) {
        self.value = value
    }

    func load() async -> Value {
        started = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func hasStarted() -> Bool { started }

    func resume() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume(returning: value)
    }
}

private actor RetryFactorySuspendingProviderBuilder:
    IOSFailedHistoryRetryProviderBuilding {
    private var started = false
    private var builds = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func makeFailedHistoryRetryProvider(
        credential: IOSResolvedOpenAICredential
    ) async -> any IOSFailedHistoryRetryProviderExecuting {
        _ = credential
        started = true
        builds += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
        return RetryFactoryProvider()
    }

    func hasStarted() -> Bool { started }
    func buildCount() -> Int { builds }

    func resume() {
        let continuation = continuation
        self.continuation = nil
        continuation?.resume()
    }
}

private struct RetryFactoryProvider:
    IOSFailedHistoryRetryProviderExecuting {
    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        return .failure(.unknown)
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
}

private struct RetryFactoryRejectedProvider:
    IOSFailedHistoryRetryProviderExecuting {
    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        return .failure(.credentialRejected)
    }

    func correct(
        _ request: IOSFailedHistoryRetryCorrectionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        return .failure(.credentialRejected)
    }

    func translate(
        _ request: IOSFailedHistoryRetryTranslationRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        _ = request
        return .failure(.credentialRejected)
    }
}

private func resolvedCredential(
    from coordinator: IOSOpenAICredentialCoordinator
) async throws -> IOSResolvedOpenAICredential {
    let outcome = try await coordinator.resolve(for: .voicePreflight)
    guard case .available(let credential) = outcome.resolution else {
        throw RetryFactoryTestError.missingCredential
    }
    return credential
}

private func expectProviderRejected(
    _ coordinator: IOSOpenAICredentialCoordinator
) async {
    do {
        _ = try await coordinator.resolve(for: .voicePreflight)
        Issue.record("Expected the exact credential generation to be rejected.")
    } catch IOSOpenAICredentialCoordinatorError.providerRejected {
        // Expected.
    } catch {
        Issue.record("Expected providerRejected, received a different error.")
    }
}

private enum RetryFactoryTestError: Error {
    case missingCredential
}

private func retryFactoryTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ios-failed-retry-session-factory-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    return root
}
