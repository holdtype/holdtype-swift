import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence

/// The containing app's one process-owned failed-History entry point.
///
/// Provider construction, current settings, credentials, and durable mutation
/// authority remain behind this actor. Callers receive only redacted read and
/// action results and cannot supply Retry configuration or provider capability.
public actor IOSFailedHistoryService {
    private let boundary: IOSFailedHistoryAppBoundary

    @_spi(HoldTypeIOSCore)
    public init(
        applicationSupportDirectoryURL: URL,
        loadSettings: @escaping @Sendable () async throws -> IOSAppSettings,
        loadLibrary: @escaping @Sendable () async throws -> IOSLibraryContent,
        providerConsentCoordinator: IOSProviderConsentCoordinator,
        credentialCoordinator: IOSOpenAICredentialCoordinator?,
        usageRecordingClient: IOSTranscriptionUsageRecordingClient
    ) {
        let retrySessionProvider:
            any IOSFailedHistoryRetrySessionProviding
        if let credentialCoordinator {
            retrySessionProvider = IOSFailedHistoryRetrySessionFactory(
                loadSettings: loadSettings,
                loadLibrary: loadLibrary,
                consentCoordinator: providerConsentCoordinator,
                credentialCoordinator: credentialCoordinator,
                providerBuilder: IOSOpenAIFailedHistoryRetryProviderBuilder()
            )
        } else {
            retrySessionProvider =
                IOSUnavailableFailedHistoryRetrySessionProvider()
        }
        boundary = IOSFailedHistoryAppBoundary(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            retrySessionProvider: retrySessionProvider,
            usageRecordingClient: usageRecordingClient
        )
    }

    /// Test-only convenience. Production composition must inject its one
    /// shared recording client explicitly.
    init(
        applicationSupportDirectoryURL: URL,
        loadSettings: @escaping @Sendable () async throws -> IOSAppSettings,
        loadLibrary: @escaping @Sendable () async throws -> IOSLibraryContent,
        providerConsentCoordinator: IOSProviderConsentCoordinator,
        credentialCoordinator: IOSOpenAICredentialCoordinator?
    ) {
        let repository = IOSTranscriptionUsageRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL
        )
        self.init(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            loadSettings: loadSettings,
            loadLibrary: loadLibrary,
            providerConsentCoordinator: providerConsentCoordinator,
            credentialCoordinator: credentialCoordinator,
            usageRecordingClient: IOSTranscriptionUsageRecordingClient(
                repository: repository,
                reportFailure: { _ in }
            )
        )
    }

    init(
        applicationSupportDirectoryURL: URL,
        loadSettings: @escaping @Sendable () async throws -> IOSAppSettings,
        loadLibrary: @escaping @Sendable () async throws -> IOSLibraryContent,
        providerConsentCoordinator: IOSProviderConsentCoordinator,
        credentialCoordinator: IOSOpenAICredentialCoordinator,
        providerBuilder: any IOSFailedHistoryRetryProviderBuilding,
        usageRecordingClient: IOSTranscriptionUsageRecordingClient
    ) {
        let sessionFactory = IOSFailedHistoryRetrySessionFactory(
            loadSettings: loadSettings,
            loadLibrary: loadLibrary,
            consentCoordinator: providerConsentCoordinator,
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder
        )
        boundary = IOSFailedHistoryAppBoundary(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            retrySessionProvider: sessionFactory,
            usageRecordingClient: usageRecordingClient
        )
    }

    /// Test-only convenience for injected provider builders.
    init(
        applicationSupportDirectoryURL: URL,
        loadSettings: @escaping @Sendable () async throws -> IOSAppSettings,
        loadLibrary: @escaping @Sendable () async throws -> IOSLibraryContent,
        providerConsentCoordinator: IOSProviderConsentCoordinator,
        credentialCoordinator: IOSOpenAICredentialCoordinator,
        providerBuilder: any IOSFailedHistoryRetryProviderBuilding
    ) {
        let repository = IOSTranscriptionUsageRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL
        )
        self.init(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            loadSettings: loadSettings,
            loadLibrary: loadLibrary,
            providerConsentCoordinator: providerConsentCoordinator,
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder,
            usageRecordingClient: IOSTranscriptionUsageRecordingClient(
                repository: repository,
                reportFailure: { _ in }
            )
        )
    }

    public func loadFailedHistory() async -> IOSFailedHistoryLoadDisposition {
        await boundary.loadFailedHistory()
    }

    public func deleteFailedHistory(
        _ id: IOSFailedHistoryRowID
    ) async -> IOSFailedHistoryMutationDisposition {
        await boundary.deleteFailedHistory(id)
    }

    public func retryFailedHistory(
        _ id: IOSFailedHistoryRowID
    ) async -> IOSFailedHistoryRetryDisposition {
        await boundary.retryFailedHistory(id)
    }
}

private struct IOSUnavailableFailedHistoryRetrySessionProvider:
    IOSFailedHistoryRetrySessionProviding {
    func makeFailedHistoryRetrySession(
        for outputIntent: DictationOutputIntent
    ) async -> IOSFailedHistoryRetrySessionResolution {
        _ = outputIntent
        return Task.isCancelled ? .cancelled : .temporarilyUnavailable
    }
}

extension IOSFailedHistoryService: CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public nonisolated var description: String {
        "IOSFailedHistoryService(redacted)"
    }
    public nonisolated var debugDescription: String { description }
    public nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
