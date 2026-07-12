import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence

/// Builds one provider adapter already bound to the freshly resolved app-only
/// credential. The adapter owns the credential for that transient session.
protocol IOSFailedHistoryRetryProviderBuilding: Sendable {
    func makeFailedHistoryRetryProvider(
        credential: IOSResolvedOpenAICredential
    ) async -> any IOSFailedHistoryRetryProviderExecuting
}

/// Process-owned factory for explicit failed-History Retry actions.
actor IOSFailedHistoryRetrySessionFactory:
    IOSFailedHistoryRetrySessionProviding {
    typealias SettingsLoader = @Sendable () async throws -> IOSAppSettings
    typealias LibraryLoader = @Sendable () async throws -> IOSLibraryContent

    private let loadSettings: SettingsLoader
    private let loadLibrary: LibraryLoader
    private let credentialCoordinator: IOSOpenAICredentialCoordinator
    private let providerBuilder: any IOSFailedHistoryRetryProviderBuilding

    init(
        loadSettings: @escaping SettingsLoader,
        loadLibrary: @escaping LibraryLoader,
        credentialCoordinator: IOSOpenAICredentialCoordinator,
        providerBuilder: any IOSFailedHistoryRetryProviderBuilding
    ) {
        self.loadSettings = loadSettings
        self.loadLibrary = loadLibrary
        self.credentialCoordinator = credentialCoordinator
        self.providerBuilder = providerBuilder
    }

    func makeFailedHistoryRetrySession(
        for outputIntent: DictationOutputIntent
    ) async -> IOSFailedHistoryRetrySessionResolution {
        let settings: IOSAppSettings
        let library: IOSLibraryContent
        do {
            try Task.checkCancellation()
            settings = try await loadSettings()
            try Task.checkCancellation()
            library = try await loadLibrary()
            try Task.checkCancellation()
        } catch is CancellationError {
            return .cancelled
        } catch {
            return Task.isCancelled ? .cancelled : .temporarilyUnavailable
        }

        let translationConfiguration: TranslationConfiguration?
        switch outputIntent {
        case .standard:
            translationConfiguration = nil
        case .translate:
            guard settings.translationConfiguration.canRunAction else {
                return .setupRequired(.translation)
            }
            translationConfiguration = settings.translationConfiguration
        }

        let promptComposition = TranscriptionPromptComposition(
            resolvedFreeformPrompt:
                settings.transcriptionConfiguration.resolvedFreeformPrompt,
            context: nil,
            emojiCommandsConfiguration:
                library.emojiCommandsConfiguration,
            customDictionary: library.customDictionary
        )
        let postProcessingConfiguration =
            TranscriptPostProcessingConfiguration(
                localTextCleanupEnabled:
                    settings.localTextCleanupEnabled,
                emojiCommands: library.emojiCommandsConfiguration,
                textReplacementRules: library.replacementRules
            )
        guard let configuration = IOSFailedHistoryRetryConfiguration(
            transcriptionConfiguration:
                settings.transcriptionConfiguration,
            transcriptionPromptComposition: promptComposition,
            textCorrectionConfiguration:
                settings.textCorrectionConfiguration,
            postProcessingConfiguration: postProcessingConfiguration,
            translationConfiguration: translationConfiguration,
            keepLatestResult: settings.keepLatestResult
        ) else {
            return outputIntent == .translate
                ? .setupRequired(.translation)
                : .setupRequired(.transcription)
        }
        guard !Task.isCancelled else { return .cancelled }

        let credential: IOSResolvedOpenAICredential
        do {
            let outcome = try await credentialCoordinator.resolve(
                for: .voicePreflight
            )
            switch outcome.resolution {
            case .available(let resolved):
                credential = resolved
            case .notConfigured:
                return .setupRequired(.openAI)
            }
            try Task.checkCancellation()
        } catch IOSOpenAICredentialCoordinatorError.providerRejected {
            return .setupRequired(.openAI)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return Task.isCancelled ? .cancelled : .temporarilyUnavailable
        }

        let builtProvider = await providerBuilder
            .makeFailedHistoryRetryProvider(credential: credential)
        guard !Task.isCancelled else { return .cancelled }
        let provider = IOSFailedHistoryRetryCredentialTrackingProvider(
            provider: builtProvider,
            credentialCoordinator: credentialCoordinator,
            credentialGeneration: credential.generation
        )
        return .ready(
            IOSFailedHistoryRetrySession(
                configuration: configuration,
                provider: provider
            )
        )
    }
}

/// Records only rejection of the exact credential generation bound to this
/// provider. A replacement that happens while a request is in flight therefore
/// cannot poison the newer runtime credential.
struct IOSFailedHistoryRetryCredentialTrackingProvider:
    IOSFailedHistoryRetryProviderExecuting {
    private let provider: any IOSFailedHistoryRetryProviderExecuting
    private let credentialCoordinator: IOSOpenAICredentialCoordinator
    private let credentialGeneration: IOSOpenAICredentialGeneration

    init(
        provider: any IOSFailedHistoryRetryProviderExecuting,
        credentialCoordinator: IOSOpenAICredentialCoordinator,
        credentialGeneration: IOSOpenAICredentialGeneration
    ) {
        self.provider = provider
        self.credentialCoordinator = credentialCoordinator
        self.credentialGeneration = credentialGeneration
    }

    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        await tracked { await provider.transcribe(request) }
    }

    func correct(
        _ request: IOSFailedHistoryRetryCorrectionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        await tracked { await provider.correct(request) }
    }

    func translate(
        _ request: IOSFailedHistoryRetryTranslationRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        await tracked { await provider.translate(request) }
    }

    func recordCredentialRejectionIfNeeded(
        _ outcome: IOSFailedHistoryRetryProviderTextOutcome
    ) async {
        guard outcome == .failure(.credentialRejected) else { return }
        await credentialCoordinator.recordProviderRejection(
            for: credentialGeneration
        )
    }

    private func tracked(
        _ operation: () async -> IOSFailedHistoryRetryProviderTextOutcome
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        let outcome = await operation()
        await recordCredentialRejectionIfNeeded(outcome)
        return outcome
    }
}

extension IOSFailedHistoryRetrySessionFactory: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSFailedHistoryRetrySessionFactory(redacted)"
    }
    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror {
        Mirror(self, children: [:])
    }
}
