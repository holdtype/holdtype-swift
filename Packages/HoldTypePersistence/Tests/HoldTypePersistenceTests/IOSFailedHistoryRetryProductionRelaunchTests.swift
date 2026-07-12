import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryRetryProductionRelaunchTests {
    @Test func freshProductionContextRecoversEveryDurableRetryState()
        async throws {
        let states: [IOSFailedHistoryRetryOperationState] = [
            .reserved,
            .providerDispatched,
            .acceptingOutput,
        ]

        for (index, state) in states.enumerated() {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "failed-retry-real-relaunch-\(UUID().uuidString)",
                    isDirectory: true
                )
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )
            defer { try? FileManager.default.removeItem(at: root) }

            let seedRegistry =
                IOSAcceptedHistoryCoordinatorProcessContextRegistry()
            let seedContext = seedRegistry.context(for: root)
            let seedCoordinator = productionRelaunchCoordinator(
                context: seedContext,
                registry: seedRegistry,
                root: root
            )
            _ = try await seedCoordinator.capture(
                transcriptionModel: "gpt-4o-mini-transcribe",
                transcriptionLanguageCode: "en",
                durationMilliseconds: 1_000
            )

            let operationCreatedAt = try IOSFailedHistoryTimestampCodec
                .canonicalDate(from: Date().addingTimeInterval(-60))
            let operation = try failedHistoryTestRetryOperation(
                index: 900 + index,
                createdAt: operationCreatedAt,
                state: state,
                keepLatestResult: index.isMultiple(of: 2)
            )
            let row = try failedHistoryTestEntry(
                index: 900 + index,
                createdAt: operationCreatedAt.addingTimeInterval(-1),
                updatedAt: operation.createdAt,
                retryCount: 3,
                retryOperation: operation
            )
            _ = try FoundationIOSFailedHistoryJournalRepository(
                applicationSupportDirectoryURL: root
            ).create(
                IOSFailedHistoryEnvelope(
                    revision: 40 + Int64(index),
                    entries: [row],
                    audioCleanup: []
                ),
                authorization: IOSFailedHistoryJournalMutationAuthorization(
                    testingToken: ()
                )
            )

            if state == .acceptingOutput {
                _ = try FoundationIOSAcceptedOutputDeliveryJournalRepository(
                    applicationSupportDirectoryURL: root
                ).create(
                    try productionRelaunchDelivery(
                        row: row,
                        operation: operation
                    )
                )
            }

            let relaunchedRegistry =
                IOSAcceptedHistoryCoordinatorProcessContextRegistry(
                    retryRecoveryScanRequiredOnContextCreation: true
                )
            let relaunchedContext = relaunchedRegistry.context(for: root)
            let relaunchedCoordinator = productionRelaunchCoordinator(
                context: relaunchedContext,
                registry: relaunchedRegistry,
                root: root
            )

            #expect(seedContext.ownerIdentity != relaunchedContext.ownerIdentity)
            #expect(
                seedContext.failedHistoryStore.storeIdentity
                    != relaunchedContext.failedHistoryStore.storeIdentity
            )
            #expect(
                seedContext.deliveryStore.storeIdentity
                    != relaunchedContext.deliveryStore.storeIdentity
            )
            #expect(
                relaunchedContext.failedHistoryMutationInterlock
                    .requiresRetryRecoveryScan
            )

            let resolution = try await relaunchedCoordinator
                .recoverInterruptedFailedHistoryRetry()
            let failed = try #require(
                try await relaunchedContext.failedHistoryStore.load()
            )

            switch state {
            case .reserved, .providerDispatched:
                #expect(resolution == .retryCancelled)
                let retained = try #require(failed.entries.first)
                #expect(retained.retryOperation == nil)
                #expect(failed.audioCleanup.isEmpty)

            case .acceptingOutput:
                #expect(resolution == .acceptedOutputRecovered)
                #expect(failed.entries.isEmpty)
                #expect(failed.audioCleanup.count == 1)
                let accepted = try #require(
                    try await relaunchedContext.acceptedHistoryStore.load()
                )
                #expect(accepted.entries.count == 1)
                guard case .active(let delivery)? = try await
                        relaunchedContext.deliveryStore.load() else {
                    Issue.record("Expected recovered accepted delivery")
                    continue
                }
                #expect(delivery.historyWrite?.state == .committed)
                #expect(
                    delivery.keepLatestResult == operation.keepLatestResult
                )
            }
        }
    }
}

private func productionRelaunchCoordinator(
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

private func productionRelaunchDelivery(
    row: IOSFailedHistoryEntry,
    operation: IOSFailedHistoryRetryOperation
) throws -> IOSAcceptedOutputDeliveryRecord {
    try IOSAcceptedOutputDeliveryRecord(
        revision: 1,
        deliveryID: operation.deliveryID,
        sessionID: operation.sessionID,
        attemptID: row.attemptID,
        transcriptID: operation.transcriptID,
        failedRetryID: operation.retryID,
        acceptedText: "Recovered after a real context relaunch",
        outputIntent: row.outputIntent,
        createdAt: operation.createdAt,
        updatedAt: operation.createdAt,
        expiresAt: operation.createdAt.addingTimeInterval(86_400),
        deliveryState: .pending,
        automaticInsertionPreferenceEnabled: false,
        keepLatestResult: operation.keepLatestResult,
        publicationGeneration: 0,
        historyWrite: try IOSAcceptedOutputHistoryWrite(
            policyGeneration: row.policyGeneration,
            transcriptionModel: row.transcriptionModel,
            transcriptionLanguageCode: row.transcriptionLanguageCode,
            durationMilliseconds: row.durationMilliseconds
        )
    )
}
