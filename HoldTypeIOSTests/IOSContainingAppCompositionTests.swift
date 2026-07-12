import Foundation
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
import HoldTypePersistence
import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSContainingAppCompositionTests {
    @Test func processCompositionBuildsDependenciesOnceAndSharesThemAcrossScenes()
        async throws {
        let root = try compositionTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let expectedAccessGroup = "TESTTEAMID.app.holdtype.HoldType.ios"
        var events: [String] = []
        var providerScheduleCount = 0
        var retryScratchScheduleCount = 0
        var capturedCredentialCoordinator:
            IOSOpenAICredentialCoordinator?

        let composition = IOSContainingAppComposition(
            factories: IOSContainingAppComposition.Factories(
                resolveApplicationSupportDirectoryURL: {
                    events.append("root")
                    return root
                },
                resolveApplicationIdentifierAccessGroup: {
                    events.append("access-group")
                    return expectedAccessGroup
                },
                makeHistoryCoordinator: { resolvedRoot in
                    events.append("history")
                    #expect(resolvedRoot == root)
                    #expect(
                        FileManager.default.fileExists(
                            atPath: resolvedRoot.path
                        )
                    )
                    return IOSAcceptedHistoryCoordinator(
                        applicationSupportDirectoryURL: resolvedRoot
                    )
                },
                makeCredentialCoordinator: {
                    resolvedRoot,
                    accessGroup in
                    events.append("credential")
                    #expect(resolvedRoot == root)
                    #expect(accessGroup == expectedAccessGroup)
                    let coordinator = try IOSOpenAICredentialCoordinator(
                        applicationSupportDirectoryURL: resolvedRoot,
                        applicationIdentifierAccessGroup: accessGroup
                    )
                    capturedCredentialCoordinator = coordinator
                    return coordinator
                },
                makeFailedHistoryService: {
                    resolvedRoot,
                    credentialCoordinator in
                    events.append("failed-history")
                    #expect(resolvedRoot == root)
                    #expect(
                        credentialCoordinator
                            === capturedCredentialCoordinator
                    )
                    return IOSFailedHistoryService(
                        applicationSupportDirectoryURL: resolvedRoot,
                        credentialCoordinator: credentialCoordinator
                    )
                }
            ),
            scheduleProviderStartupMaintenance: {
                providerScheduleCount += 1
            },
            scheduleRetryScratchStartupMaintenance: {
                retryScratchScheduleCount += 1
            }
        )

        let app = HoldTypeIOSApp(composition: composition)
        let firstScene = HoldTypeIOSRootView(
            composition: app.composition
        )
        let secondScene = HoldTypeIOSRootView(
            composition: app.composition
        )

        #expect(
            events == [
                "root",
                "history",
                "access-group",
                "credential",
                "failed-history",
            ]
        )
        #expect(providerScheduleCount == 1)
        #expect(retryScratchScheduleCount == 1)
        #expect(composition.availability == .ready)
        #expect(composition.historyCoordinator != nil)
        #expect(
            composition.credentialCoordinator
                === capturedCredentialCoordinator
        )
        #expect(composition.failedHistoryService != nil)
        #expect(firstScene.composition === composition)
        #expect(secondScene.composition === composition)

        await composition.lifecycleScheduler.waitUntilIdle()
        let markerURL = IOSCredentialPresenceMarkerStorageLocation.fileURL(
            in: root
        )
        #expect(!FileManager.default.fileExists(atPath: markerURL.path))
    }

    @Test func missingAccessGroupKeepsProviderFreeHistoryAvailable()
        async throws {
        let root = try compositionTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var credentialFactoryCalls = 0
        var serviceCredentialWasNil = false

        let composition = IOSContainingAppComposition(
            factories: IOSContainingAppComposition.Factories(
                resolveApplicationSupportDirectoryURL: { root },
                resolveApplicationIdentifierAccessGroup: { nil },
                makeHistoryCoordinator: {
                    IOSAcceptedHistoryCoordinator(
                        applicationSupportDirectoryURL: $0
                    )
                },
                makeCredentialCoordinator: { _, _ in
                    credentialFactoryCalls += 1
                    throw CompositionFixtureError.unexpectedFactoryCall
                },
                makeFailedHistoryService: { resolvedRoot, coordinator in
                    serviceCredentialWasNil = coordinator == nil
                    return IOSFailedHistoryService(
                        applicationSupportDirectoryURL: resolvedRoot,
                        credentialCoordinator: coordinator
                    )
                }
            ),
            scheduleProviderStartupMaintenance: {},
            scheduleRetryScratchStartupMaintenance: {}
        )

        await composition.lifecycleScheduler.waitUntilIdle()
        #expect(composition.availability == .credentialUnavailable)
        #expect(composition.historyCoordinator != nil)
        #expect(composition.credentialCoordinator == nil)
        #expect(composition.failedHistoryService != nil)
        #expect(credentialFactoryCalls == 0)
        #expect(serviceCredentialWasNil)

        let service = try #require(composition.failedHistoryService)
        #expect(await service.loadFailedHistory() == .available([]))
        #expect(
            !FileManager.default.fileExists(
                atPath: IOSCredentialPresenceMarkerStorageLocation
                    .fileURL(in: root).path
            )
        )
    }

    @Test func invalidAccessGroupDegradesRetryWithoutPoisoningStorage()
        async throws {
        let root = try compositionTemporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        var credentialFactoryCalls = 0
        var serviceCredentialWasNil = false

        let composition = IOSContainingAppComposition(
            factories: IOSContainingAppComposition.Factories(
                resolveApplicationSupportDirectoryURL: { root },
                resolveApplicationIdentifierAccessGroup: {
                    "group.app.holdtype.HoldType.shared"
                },
                makeHistoryCoordinator: {
                    IOSAcceptedHistoryCoordinator(
                        applicationSupportDirectoryURL: $0
                    )
                },
                makeCredentialCoordinator: { resolvedRoot, accessGroup in
                    credentialFactoryCalls += 1
                    return try IOSOpenAICredentialCoordinator(
                        applicationSupportDirectoryURL: resolvedRoot,
                        applicationIdentifierAccessGroup: accessGroup
                    )
                },
                makeFailedHistoryService: { resolvedRoot, coordinator in
                    serviceCredentialWasNil = coordinator == nil
                    return IOSFailedHistoryService(
                        applicationSupportDirectoryURL: resolvedRoot,
                        credentialCoordinator: coordinator
                    )
                }
            ),
            scheduleProviderStartupMaintenance: {},
            scheduleRetryScratchStartupMaintenance: {}
        )

        await composition.lifecycleScheduler.waitUntilIdle()
        #expect(credentialFactoryCalls == 1)
        #expect(serviceCredentialWasNil)
        #expect(composition.availability == .credentialUnavailable)
        #expect(composition.historyCoordinator != nil)
        #expect(composition.credentialCoordinator == nil)
        let service = try #require(composition.failedHistoryService)
        #expect(await service.loadFailedHistory() == .available([]))
        #expect(
            !FileManager.default.fileExists(
                atPath: IOSCredentialPresenceMarkerStorageLocation
                    .fileURL(in: root).path
            )
        )
    }

    @Test func storageRootFailureKeepsAppLaunchableAndRecoveryPending()
        async {
        var historyFactoryCalls = 0
        var credentialFactoryCalls = 0
        var serviceFactoryCalls = 0
        var providerScheduleCount = 0
        var retryScratchScheduleCount = 0

        let composition = IOSContainingAppComposition(
            factories: IOSContainingAppComposition.Factories(
                resolveApplicationSupportDirectoryURL: {
                    throw CompositionFixtureError.storageUnavailable
                },
                resolveApplicationIdentifierAccessGroup: {
                    Issue.record("Access group must not be read without storage.")
                    return nil
                },
                makeHistoryCoordinator: { _ in
                    historyFactoryCalls += 1
                    preconditionFailure("History must not be constructed.")
                },
                makeCredentialCoordinator: { _, _ in
                    credentialFactoryCalls += 1
                    throw CompositionFixtureError.unexpectedFactoryCall
                },
                makeFailedHistoryService: { _, _ in
                    serviceFactoryCalls += 1
                    preconditionFailure("Service must not be constructed.")
                }
            ),
            scheduleProviderStartupMaintenance: {
                providerScheduleCount += 1
            },
            scheduleRetryScratchStartupMaintenance: {
                retryScratchScheduleCount += 1
            }
        )
        let app = HoldTypeIOSApp(composition: composition)
        let root = HoldTypeIOSRootView(composition: app.composition)

        await composition.lifecycleScheduler.waitUntilIdle()
        #expect(root.composition === composition)
        #expect(composition.availability == .storageUnavailable)
        #expect(composition.applicationSupportDirectoryURL == nil)
        #expect(composition.historyCoordinator == nil)
        #expect(composition.credentialCoordinator == nil)
        #expect(composition.failedHistoryService == nil)
        #expect(
            composition.lifecycleScheduler.latestDisposition
                == .pendingLocalRecovery
        )
        #expect(historyFactoryCalls == 0)
        #expect(credentialFactoryCalls == 0)
        #expect(serviceFactoryCalls == 0)
        #expect(providerScheduleCount == 1)
        #expect(retryScratchScheduleCount == 1)
    }

    @Test func providerOnlyTestInjectionStaysPassive() async {
        var providerScheduleCount = 0

        let app = HoldTypeIOSApp(scheduleProviderStartupMaintenance: {
            providerScheduleCount += 1
        })

        await app.composition.lifecycleScheduler.waitUntilIdle()
        #expect(providerScheduleCount == 1)
        #expect(app.composition.availability == .injected)
        #expect(app.composition.applicationSupportDirectoryURL == nil)
        #expect(app.composition.historyCoordinator == nil)
        #expect(app.composition.credentialCoordinator == nil)
        #expect(app.composition.failedHistoryService == nil)
        #expect(app.composition.lifecycleScheduler.latestDisposition == .complete)
    }

    @Test func hostedAppInfoPlistContainsResolvedContainingAppAccessGroup() {
        let key = OpenAIAPIKeyKeychainStorage
            .applicationIdentifierAccessGroupInfoKey
        let value = IOSContainingAppComposition
            .applicationIdentifierAccessGroup(in: .main)

        #expect(key == "HoldTypeApplicationIdentifierAccessGroup")
        #expect(value != nil)
        #expect(value?.contains("$(") == false)
        #expect(
            value?.hasSuffix(".app.holdtype.HoldType.ios") == true
        )
        #expect(value != "group.app.holdtype.HoldType.shared")
    }
}

private enum CompositionFixtureError: Error {
    case storageUnavailable
    case unexpectedFactoryCall
}

private func compositionTemporaryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ios-containing-app-composition-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    return root
}
