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
        credentialCoordinator: IOSOpenAICredentialCoordinator?
    ) {
        let retrySessionProvider:
            any IOSFailedHistoryRetrySessionProviding
        if let credentialCoordinator {
            retrySessionProvider = IOSFailedHistoryRetrySessionFactory(
                loadSettings: loadSettings,
                loadLibrary: loadLibrary,
                credentialCoordinator: credentialCoordinator,
                providerBuilder: IOSOpenAIFailedHistoryRetryProviderBuilder()
            )
        } else {
            retrySessionProvider =
                IOSUnavailableFailedHistoryRetrySessionProvider()
        }
        boundary = IOSFailedHistoryAppBoundary(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            retrySessionProvider: retrySessionProvider
        )
    }

    init(
        applicationSupportDirectoryURL: URL,
        loadSettings: @escaping @Sendable () async throws -> IOSAppSettings,
        loadLibrary: @escaping @Sendable () async throws -> IOSLibraryContent,
        credentialCoordinator: IOSOpenAICredentialCoordinator,
        providerBuilder: any IOSFailedHistoryRetryProviderBuilding
    ) {
        let sessionFactory = IOSFailedHistoryRetrySessionFactory(
            loadSettings: loadSettings,
            loadLibrary: loadLibrary,
            credentialCoordinator: credentialCoordinator,
            providerBuilder: providerBuilder
        )
        boundary = IOSFailedHistoryAppBoundary(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            retrySessionProvider: sessionFactory
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
