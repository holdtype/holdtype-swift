import Foundation
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
import HoldTypeOpenAI
import HoldTypePersistence

enum IOSContainingAppCompositionAvailability: Equatable {
    case ready
    case credentialUnavailable
    case storageUnavailable
    case injected
}

/// One process-owned dependency graph shared by every containing-app scene.
/// Construction is synchronous and passive: it never reads Keychain, contacts
/// a provider, or performs persistence recovery inline.
@MainActor
final class IOSContainingAppComposition {
    struct Factories {
        let resolveApplicationSupportDirectoryURL: @MainActor () throws -> URL
        let resolveApplicationIdentifierAccessGroup: @MainActor () -> String?
        let makeHistoryCoordinator: @MainActor (
            URL
        ) -> IOSAcceptedHistoryCoordinator
        let makeSettingsStateOwner: @MainActor (
            URL
        ) -> IOSAppSettingsStateOwner
        let makeLibraryStateOwner: @MainActor (
            URL
        ) -> IOSLibraryStateOwner
        let makeCredentialCoordinator: @MainActor (
            URL,
            String
        ) throws -> IOSOpenAICredentialCoordinator
        let makeFailedHistoryService: @MainActor (
            URL,
            IOSAppSettingsStateOwner,
            IOSLibraryStateOwner,
            IOSOpenAICredentialCoordinator?
        ) -> IOSFailedHistoryService

        static let production = Factories(
            resolveApplicationSupportDirectoryURL: {
                try FileManager.default.url(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
            },
            resolveApplicationIdentifierAccessGroup: {
                IOSContainingAppComposition.applicationIdentifierAccessGroup(
                    in: .main
                )
            },
            makeHistoryCoordinator: { applicationSupportDirectoryURL in
                IOSAcceptedHistoryCoordinator(
                    applicationSupportDirectoryURL:
                        applicationSupportDirectoryURL
                )
            },
            makeSettingsStateOwner: { applicationSupportDirectoryURL in
                IOSAppSettingsStateOwner(
                    applicationSupportDirectoryURL:
                        applicationSupportDirectoryURL
                )
            },
            makeLibraryStateOwner: { applicationSupportDirectoryURL in
                IOSLibraryStateOwner(
                    applicationSupportDirectoryURL:
                        applicationSupportDirectoryURL
                )
            },
            makeCredentialCoordinator: {
                applicationSupportDirectoryURL,
                applicationIdentifierAccessGroup in
                try IOSOpenAICredentialCoordinator(
                    applicationSupportDirectoryURL:
                        applicationSupportDirectoryURL,
                    applicationIdentifierAccessGroup:
                        applicationIdentifierAccessGroup
                )
            },
            makeFailedHistoryService: {
                applicationSupportDirectoryURL,
                settingsStateOwner,
                libraryStateOwner,
                credentialCoordinator in
                IOSFailedHistoryService(
                    applicationSupportDirectoryURL:
                        applicationSupportDirectoryURL,
                    loadSettings: {
                        try await settingsStateOwner
                            .confirmedValueForProviderAction()
                    },
                    loadLibrary: {
                        try await libraryStateOwner
                            .confirmedValueForProviderAction()
                    },
                    credentialCoordinator: credentialCoordinator
                )
            }
        )
    }

    let applicationSupportDirectoryURL: URL?
    let historyCoordinator: IOSAcceptedHistoryCoordinator?
    let settingsStateOwner: IOSAppSettingsStateOwner?
    let libraryStateOwner: IOSLibraryStateOwner?
    let credentialCoordinator: IOSOpenAICredentialCoordinator?
    let failedHistoryService: IOSFailedHistoryService?
    let lifecycleScheduler: IOSContainingAppLifecycleScheduler
    let availability: IOSContainingAppCompositionAvailability

    init(
        factories: Factories? = nil,
        scheduleProviderStartupMaintenance: @MainActor () -> Void = {
            OpenAIProviderStartupMaintenance.schedule()
        },
        scheduleRetryScratchStartupMaintenance: @MainActor () -> Void = {
            IOSFailedHistoryRetryScratchStartupMaintenance.schedule()
        }
    ) {
        let factories = factories ?? .production
        let applicationSupportDirectoryURL: URL
        do {
            applicationSupportDirectoryURL = try factories
                .resolveApplicationSupportDirectoryURL()
        } catch {
            self.applicationSupportDirectoryURL = nil
            historyCoordinator = nil
            settingsStateOwner = nil
            libraryStateOwner = nil
            credentialCoordinator = nil
            failedHistoryService = nil
            availability = .storageUnavailable
            lifecycleScheduler = IOSContainingAppLifecycleScheduler { _ in
                .pendingLocalRecovery
            }
            scheduleStartup(
                scheduleProviderStartupMaintenance:
                    scheduleProviderStartupMaintenance,
                scheduleRetryScratchStartupMaintenance:
                    scheduleRetryScratchStartupMaintenance
            )
            return
        }

        self.applicationSupportDirectoryURL =
            applicationSupportDirectoryURL
        let settingsStateOwner = factories.makeSettingsStateOwner(
            applicationSupportDirectoryURL
        )
        self.settingsStateOwner = settingsStateOwner
        let libraryStateOwner = factories.makeLibraryStateOwner(
            applicationSupportDirectoryURL
        )
        self.libraryStateOwner = libraryStateOwner
        let historyCoordinator = factories.makeHistoryCoordinator(
            applicationSupportDirectoryURL
        )
        self.historyCoordinator = historyCoordinator

        let credentialCoordinator: IOSOpenAICredentialCoordinator?
        if let applicationIdentifierAccessGroup = factories
            .resolveApplicationIdentifierAccessGroup() {
            credentialCoordinator = try? factories.makeCredentialCoordinator(
                applicationSupportDirectoryURL,
                applicationIdentifierAccessGroup
            )
        } else {
            credentialCoordinator = nil
        }
        self.credentialCoordinator = credentialCoordinator
        failedHistoryService = factories.makeFailedHistoryService(
            applicationSupportDirectoryURL,
            settingsStateOwner,
            libraryStateOwner,
            credentialCoordinator
        )
        availability = credentialCoordinator == nil
            ? .credentialUnavailable
            : .ready
        lifecycleScheduler = IOSContainingAppLifecycleScheduler {
            opportunity in
            await historyCoordinator.recoverContainingAppLifecycle(
                opportunity
            )
        }
        scheduleStartup(
            scheduleProviderStartupMaintenance:
                scheduleProviderStartupMaintenance,
            scheduleRetryScratchStartupMaintenance:
                scheduleRetryScratchStartupMaintenance
        )
    }

    /// Retains the existing app test seam without constructing production
    /// storage, Keychain, or provider dependencies.
    init(
        scheduleProviderStartupMaintenance: @MainActor () -> Void,
        scheduleRetryScratchStartupMaintenance: @MainActor () -> Void,
        recoverContainingAppLifecycle:
            @escaping IOSContainingAppLifecycleScheduler.Recovery
    ) {
        applicationSupportDirectoryURL = nil
        historyCoordinator = nil
        settingsStateOwner = nil
        libraryStateOwner = nil
        credentialCoordinator = nil
        failedHistoryService = nil
        availability = .injected
        lifecycleScheduler = IOSContainingAppLifecycleScheduler(
            recover: recoverContainingAppLifecycle
        )
        scheduleStartup(
            scheduleProviderStartupMaintenance:
                scheduleProviderStartupMaintenance,
            scheduleRetryScratchStartupMaintenance:
                scheduleRetryScratchStartupMaintenance
        )
    }

    static func applicationIdentifierAccessGroup(
        in bundle: Bundle
    ) -> String? {
        bundle.object(
            forInfoDictionaryKey:
                OpenAIAPIKeyKeychainStorage
                    .applicationIdentifierAccessGroupInfoKey
        ) as? String
    }

    private func scheduleStartup(
        scheduleProviderStartupMaintenance: @MainActor () -> Void,
        scheduleRetryScratchStartupMaintenance: @MainActor () -> Void
    ) {
        _ = IOSContainingAppStartup(
            scheduleProviderStartupMaintenance:
                scheduleProviderStartupMaintenance,
            scheduleRetryScratchStartupMaintenance:
                scheduleRetryScratchStartupMaintenance,
            scheduleContainingAppRecovery: {
                lifecycleScheduler.scheduleProcessLaunch()
            }
        )
    }
}

extension IOSContainingAppCompositionAvailability:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSContainingAppCompositionAvailability(redacted)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
