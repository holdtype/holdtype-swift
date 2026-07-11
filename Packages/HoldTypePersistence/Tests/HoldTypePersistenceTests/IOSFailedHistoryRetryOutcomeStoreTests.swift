import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryRetryOutcomeStoreTests {
    @Test func mappedFailureRetainsExactRowAndConsumesExactCompletion()
        async throws {
        let fixture = try RetryOutcomeStoreFixture(namespace: "mapped")
        let row = try failedHistoryTestEntry(
            index: 1,
            failureCategory: .rateLimited,
            pipelineStage: .transcription,
            retryCount: 2,
            outputIntent: .translate
        )
        let cleanup = try failedHistoryTestAudioCleanup(index: 20)
        try fixture.install(row: row, revision: 7, cleanup: [cleanup])
        let dispatched = try await fixture.reserveAndDispatch(row: row)
        let completion = try await providerCompletionClaim(
            state: fixture.store.retryLiveOwnerState,
            registration: dispatched.registration
        )
        let completionTime = try failedHistoryTestDate(
            offsetMilliseconds: 12_000
        )
        fixture.setNow(completionTime)
        let disposition = IOSFailedHistoryRetryFailureDisposition.mapped(
            category: .providerUnavailable,
            stage: .translation
        )

        let receipt = try await fixture.gate.perform { lease in
            let authorization = try retryFailureAuthorization(
                try await fixture.store.prepareRetryFailure(
                    using: dispatched.dispatch,
                    providerCompletionClaim: completion,
                    disposition: disposition,
                    operationLeaseAuthorization: lease
                )
            )
            #expect(authorization.retryingRow == dispatched.dispatch.row)
            #expect(
                authorization.retryOperation
                    == dispatched.dispatch.retryOperation
            )
            #expect(authorization.retainedRow.retryOperation == nil)
            #expect(
                authorization.retainedRow.retryCount
                    == dispatched.dispatch.row.retryCount
            )
            #expect(
                authorization.retainedRow.failureCategory
                    == .providerUnavailable
            )
            #expect(
                authorization.retainedRow.pipelineStage == .translation
            )
            #expect(
                authorization.retainedRow.updatedAt
                    == completionTime
            )
            let receipt = try await fixture.store.commitRetryFailure(
                using: authorization
            )
            #expect(
                await fixture.store.retryLiveOwnerState.hasLiveOwner()
            )
            #expect(
                await fixture.store.retryLiveOwnerState
                    .consumeProviderFailure(using: receipt)
            )
            return receipt
        }

        let durable = try #require(try await fixture.store.load())
        #expect(durable.revision == 10)
        #expect(durable.entries == [receipt.row])
        #expect(durable.audioCleanup == [cleanup])
        #expect(receipt.row.retryOperation == nil)
        #expect(receipt.row.retryCount == row.retryCount + 1)
        #expect(
            receipt.row.transcriptionModel
                == dispatched.dispatch.row.transcriptionModel
        )
        #expect(
            receipt.row.transcriptionLanguageCode
                == dispatched.dispatch.row.transcriptionLanguageCode
        )
        #expect(
            receipt.row.audioRelativeIdentifier
                == dispatched.dispatch.row.audioRelativeIdentifier
        )
        #expect(receipt.row.outputIntent == dispatched.dispatch.row.outputIntent)
        #expect(
            await fixture.store.retryLiveOwnerState.hasLiveOwner() == false
        )
        #expect(
            await fixture.store.retryLiveOwnerState
                .consumeProviderFailure(using: receipt) == false
        )

        #expect(String(describing: disposition).contains("redacted"))
        #expect(String(describing: receipt.authorization).contains("redacted"))
        #expect(String(describing: receipt).contains("redacted"))
        #expect(receipt.customMirror.children.isEmpty)
        requireFailedHistorySendable(
            IOSFailedHistoryRetryFailureDisposition.self
        )
        requireFailedHistorySendable(
            IOSFailedHistoryRetryFailurePreparation.self
        )
        requireFailedHistorySendable(
            IOSFailedHistoryRetryFailureAuthorization.self
        )
        requireFailedHistorySendable(
            IOSFailedHistoryRetryFailureReceipt.self
        )
    }

    @Test func preserveFailureRejectsForeignClaimAndForeignConsumer()
        async throws {
        let fixture = try RetryOutcomeStoreFixture(namespace: "preserve")
        let foreign = try RetryOutcomeStoreFixture(namespace: "foreign")
        let row = try failedHistoryTestEntry(
            index: 2,
            failureCategory: .echoRejected,
            pipelineStage: .translation,
            retryCount: 4,
            outputIntent: .translate
        )
        let foreignRow = try failedHistoryTestEntry(index: 3)
        try fixture.install(row: row, revision: 3)
        try foreign.install(row: foreignRow, revision: 1)
        let dispatched = try await fixture.reserveAndDispatch(row: row)
        let foreignDispatched = try await foreign.reserveAndDispatch(
            row: foreignRow
        )
        let completion = try await providerCompletionClaim(
            state: fixture.store.retryLiveOwnerState,
            registration: dispatched.registration
        )
        let foreignCompletion = try await providerCompletionClaim(
            state: foreign.store.retryLiveOwnerState,
            registration: foreignDispatched.registration
        )

        await #expect(throws: IOSFailedHistoryError.compareAndSwapFailed) {
            try await fixture.gate.perform { lease in
                _ = try await fixture.store.prepareRetryFailure(
                    using: dispatched.dispatch,
                    providerCompletionClaim: foreignCompletion,
                    disposition: .preservePrevious,
                    operationLeaseAuthorization: lease
                )
            }
        }
        #expect(
            try await fixture.store.load()?.entries
                == [dispatched.dispatch.row]
        )

        let receipt = try await fixture.gate.perform { lease in
            let authorization = try retryFailureAuthorization(
                try await fixture.store.prepareRetryFailure(
                    using: dispatched.dispatch,
                    providerCompletionClaim: completion,
                    disposition: .preservePrevious,
                    operationLeaseAuthorization: lease
                )
            )
            #expect(
                authorization.retainedRow.failureCategory
                    == dispatched.dispatch.row.failureCategory
            )
            #expect(
                authorization.retainedRow.pipelineStage
                    == dispatched.dispatch.row.pipelineStage
            )
            let receipt = try await fixture.store.commitRetryFailure(
                using: authorization
            )
            #expect(
                await foreign.store.retryLiveOwnerState
                    .consumeProviderFailure(using: receipt) == false
            )
            #expect(await fixture.store.retryLiveOwnerState.hasLiveOwner())
            #expect(
                await fixture.store.retryLiveOwnerState
                    .consumeProviderFailure(using: receipt)
            )
            return receipt
        }
        #expect(receipt.row.failureCategory == row.failureCategory)
        #expect(receipt.row.pipelineStage == row.pipelineStage)
        #expect(receipt.row.retryCount == row.retryCount + 1)
        #expect(receipt.row.retryOperation == nil)
    }

    @Test func failureCommitUncertaintyReusesExactOutcomeAndCount()
        async throws {
        for outcomeVisible in [false, true] {
            let fixture = try RetryOutcomeStoreFixture(
                namespace: outcomeVisible
                    ? "uncertain-outcome"
                    : "uncertain-source"
            )
            let row = try failedHistoryTestEntry(
                index: outcomeVisible ? 5 : 4,
                failureCategory: .networkFailure,
                retryCount: 6
            )
            try fixture.install(row: row, revision: 11)
            let dispatched = try await fixture.reserveAndDispatch(row: row)
            let completion = try await providerCompletionClaim(
                state: fixture.store.retryLiveOwnerState,
                registration: dispatched.registration
            )
            let disposition = IOSFailedHistoryRetryFailureDisposition.mapped(
                category: .timedOut,
                stage: .transcription
            )
            let completionTime = try failedHistoryTestDate(
                offsetMilliseconds: outcomeVisible ? 13_000 : 12_000
            )
            fixture.setNow(completionTime)
            let retained = RetryFailureAuthorizationBox()
            fixture.fileSystem.replaceFailure = .init(
                error: .commitUncertain,
                commitBeforeThrowing: outcomeVisible
            )

            await #expect(throws: IOSFailedHistoryError.commitUncertain) {
                try await fixture.gate.perform { lease in
                    let authorization = try retryFailureAuthorization(
                        try await fixture.store.prepareRetryFailure(
                            using: dispatched.dispatch,
                            providerCompletionClaim: completion,
                            disposition: disposition,
                            operationLeaseAuthorization: lease
                        )
                    )
                    retained.set(authorization)
                    _ = try await fixture.store.commitRetryFailure(
                        using: authorization
                    )
                }
            }
            let first = try #require(retained.value())
            #expect(first.retainedRow.updatedAt == completionTime)
            #expect(fixture.mutationInterlock.isBlocked)
            #expect(await fixture.store.retryLiveOwnerState.hasLiveOwner())
            #expect(
                await fixture.store.retryLiveOwnerState
                    .retainedProviderCompletion(dispatched.registration)
                    == completion
            )
            fixture.setNow(
                try failedHistoryTestDate(offsetMilliseconds: 20_000)
            )

            let receipt = try await fixture.gate.perform { lease in
                let preparation = try await fixture.store.prepareRetryFailure(
                    using: dispatched.dispatch,
                    providerCompletionClaim: completion,
                    disposition: disposition,
                    operationLeaseAuthorization: lease
                )
                let receipt: IOSFailedHistoryRetryFailureReceipt
                switch preparation {
                case .commit(let refreshed):
                    #expect(outcomeVisible == false)
                    #expect(refreshed.outcome == first.outcome)
                    #expect(refreshed.retainedRow == first.retainedRow)
                    #expect(
                        refreshed.retryOperation == first.retryOperation
                    )
                    receipt = try await fixture.store.commitRetryFailure(
                        using: refreshed
                    )
                case .completed(let completed):
                    #expect(outcomeVisible)
                    #expect(completed.authorization.outcome == first.outcome)
                    #expect(completed.row == first.retainedRow)
                    receipt = completed
                }
                #expect(
                    await fixture.store.retryLiveOwnerState
                        .consumeProviderFailure(using: receipt)
                )
                return receipt
            }

            let durable = try #require(try await fixture.store.load())
            #expect(durable.revision == 14)
            #expect(durable.entries == [receipt.row])
            #expect(receipt.row == first.retainedRow)
            #expect(receipt.row.updatedAt == completionTime)
            #expect(receipt.row.retryCount == row.retryCount + 1)
            #expect(receipt.row.retryOperation == nil)
            #expect(!fixture.mutationInterlock.isBlocked)
            #expect(
                await fixture.store.retryLiveOwnerState.hasLiveOwner()
                    == false
            )
        }
    }
}

private func retryFailureAuthorization(
    _ preparation: IOSFailedHistoryRetryFailurePreparation
) throws -> IOSFailedHistoryRetryFailureAuthorization {
    guard case .commit(let authorization) = preparation else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return authorization
}

private func providerCompletionClaim(
    state: IOSFailedHistoryRetryLiveOwnerState,
    registration: IOSFailedHistoryRetryProviderRegistration
) async throws -> IOSFailedHistoryRetryProviderCompletionClaim {
    let launch = try #require(await state.claimProviderLaunch(registration))
    #expect(launch.installRunningCancellation {})
    #expect(launch.launch())
    let terminal = try #require(await state.claimProviderCompletion(launch))
    guard case .completion(let completion) = terminal else {
        throw IOSFailedHistoryError.invalidTransition
    }
    #expect(
        await state.retainedProviderCompletion(registration) == completion
    )
    return completion
}

private final class RetryOutcomeStoreFixture: @unchecked Sendable {
    let clock: RetryOutcomeClock
    let gate: IOSPersistenceOperationGate
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let pendingStoreIdentity = IOSPendingRecordingStoreIdentity()
    let mutationInterlock = IOSFailedHistoryMutationInterlock()
    let fileSystem = FailedHistoryFakeFileSystem()
    let store: IOSFailedHistoryStore
    private let rootURL: URL

    init(namespace: String) throws {
        clock = RetryOutcomeClock(
            try failedHistoryTestDate(offsetMilliseconds: 9_999)
        )
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "failed-retry-outcome-\(namespace)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: false
        )
        let context = IOSAcceptedHistoryCoordinatorProcessContextRegistry
            .shared.context(for: rootURL)
        gate = context.operationGate
        ownerIdentity = context.ownerIdentity
        store = IOSFailedHistoryStore(
            journal: FoundationIOSFailedHistoryJournalRepository(
                fileSystem: fileSystem
            ),
            capabilityOwnerIdentity: ownerIdentity,
            operationGateIdentity: gate.identity,
            expectedPendingStoreIdentity: pendingStoreIdentity,
            repositoryGuard: context.repositoryGuard,
            mutationInterlock: mutationInterlock,
            now: { [clock] in clock.value() }
        )
        guard let physicalRootIdentity = context.repositoryBinding
                .physicalRootIdentity,
              store.retryLiveOwnerState.bindProviderRegistration(
                  failedStoreIdentity: store.storeIdentity,
                  ownerIdentity: ownerIdentity,
                  physicalRootIdentity: physicalRootIdentity
              ) else {
            throw IOSFailedHistoryError.repositoryIdentityConflict
        }
    }

    deinit { try? FileManager.default.removeItem(at: rootURL) }

    func setNow(_ date: Date) {
        clock.set(date)
    }

    func install(
        row: IOSFailedHistoryEntry,
        revision: Int64,
        cleanup: [IOSFailedHistoryAudioCleanup] = []
    ) throws {
        fileSystem.install(
            try IOSFailedHistoryWireCodec.encode(
                IOSFailedHistoryEnvelope(
                    revision: revision,
                    entries: [row],
                    audioCleanup: cleanup
                )
            )
        )
        fileSystem.resetEvents()
    }

    func reserveAndDispatch(
        row: IOSFailedHistoryEntry
    ) async throws -> (
        dispatch: IOSFailedHistoryRetryDispatchReceipt,
        registration: IOSFailedHistoryRetryProviderRegistration
    ) {
        let policy = try await policyReceipt()
        return try await gate.perform { lease in
            let reservation = try retryReservationAuthorization(
                try await self.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: TranscriptionConfiguration(
                        model: "retry-model",
                        language: .german
                    ),
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            )
            let reservationReceipt = try await self.store
                .commitRetryReservation(
                    using: reservation,
                    validatedAudio: try #require(
                        IOSFailedHistoryRetryAudioValidationReceipt(
                            testingAuthorization: reservation
                        )
                    )
                )
            let dispatch = try retryDispatchAuthorization(
                try await self.store.prepareRetryDispatch(
                    using: reservationReceipt,
                    operationLeaseAuthorization: lease
                )
            )
            let dispatchReceipt = try await self.store.commitRetryDispatch(
                using: dispatch
            )
            let registration = try #require(
                await self.store.retryLiveOwnerState.registerLiveOwner(
                    dispatchReceipt.liveOwnerToken
                )
            )
            return (dispatchReceipt, registration)
        }
    }

    private func policyReceipt() async throws -> IOSHistoryPolicyReceipt {
        let state = try IOSHistoryPolicyState(
            revision: 1,
            historyEnabled: true,
            policyGeneration: 1
        )
        return try await IOSHistoryPolicyStore(
            journal: RetryOutcomePolicyJournal(state: state),
            capabilityOwnerIdentity: ownerIdentity
        ).confirm(expected: IOSHistoryPolicyExpectation(state: state))
    }
}

private final class RetryOutcomeClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ current: Date) {
        self.current = current
    }

    func set(_ date: Date) {
        lock.withLock { current = date }
    }

    func value() -> Date {
        lock.withLock { current }
    }
}

private func retryReservationAuthorization(
    _ preparation: IOSFailedHistoryRetryReservationPreparation
) throws -> IOSFailedHistoryRetryReservationAuthorization {
    guard case .commit(let authorization) = preparation else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return authorization
}

private func retryDispatchAuthorization(
    _ preparation: IOSFailedHistoryRetryDispatchPreparation
) throws -> IOSFailedHistoryRetryDispatchAuthorization {
    guard case .commit(let authorization) = preparation else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return authorization
}

private final class RetryFailureAuthorizationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var authorization: IOSFailedHistoryRetryFailureAuthorization?

    func set(_ authorization: IOSFailedHistoryRetryFailureAuthorization) {
        lock.withLock { self.authorization = authorization }
    }

    func value() -> IOSFailedHistoryRetryFailureAuthorization? {
        lock.withLock { authorization }
    }
}

private final class RetryOutcomePolicyJournal:
    IOSHistoryPolicyJournalStoring,
    @unchecked Sendable {
    private var snapshot: IOSHistoryPolicyJournalSnapshot

    init(state: IOSHistoryPolicyState) {
        snapshot = IOSHistoryPolicyJournalSnapshot(
            state: state,
            fileRevision: IOSStrictProtectedRecordFileRevision(
                testingToken: 1
            )
        )
    }

    func load() throws -> IOSHistoryPolicyJournalSnapshot? { snapshot }

    func replace(
        _ state: IOSHistoryPolicyState,
        expected: IOSHistoryPolicyJournalSnapshot
    ) throws -> IOSHistoryPolicyJournalSnapshot {
        guard snapshot == expected else {
            throw IOSHistoryPolicyError.compareAndSwapFailed
        }
        snapshot = IOSHistoryPolicyJournalSnapshot(
            state: state,
            fileRevision: IOSStrictProtectedRecordFileRevision(
                testingToken: 2
            )
        )
        return snapshot
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport {
        _ = now
        return .empty
    }
}
