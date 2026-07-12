import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryRetryStoreTests {
    @Test func reservationAndDispatchCommitExactDurableBoundaries()
        async throws {
        let fixture = try RetryStoreFixture()
        let row = try failedHistoryTestEntry(
            index: 1,
            failureCategory: .rateLimited,
            retryCount: 2
        )
        try fixture.install(row: row, revision: 7)
        let policy = try await fixture.policyReceipt()

        let receipts = try await fixture.gate.perform { lease in
            let authorization = try reservationAuthorization(
                try await fixture.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: TranscriptionConfiguration(
                        model: " fresh-model ",
                        language: .french
                    ),
                    keepLatestResult: false,
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            )
            #expect(authorization.candidate == row)
            #expect(
                authorization.failedInventory.failedSource
                    == authorization.failedSource
            )
            let operation = authorization.retryOperation
            #expect(operation.state == .reserved)
            #expect(operation.createdAt == fixture.now)
            #expect(operation.keepLatestResult == false)
            #expect(Set([
                operation.retryID,
                operation.transcriptionID,
                operation.deliveryID,
                operation.sessionID,
                operation.transcriptID,
            ]).count == 5)
            #expect(authorization.reservedRow.retryCount == 3)
            #expect(
                authorization.reservedRow.failureCategory
                    == row.failureCategory
            )
            #expect(
                authorization.reservedRow.pipelineStage
                    == row.pipelineStage
            )
            #expect(
                authorization.reservedRow.transcriptionModel
                    == "fresh-model"
            )
            #expect(
                authorization.reservedRow.transcriptionLanguageCode
                    == "fr"
            )
            let reservationReceipt = try await fixture.store
                .commitRetryReservation(
                using: authorization,
                validatedAudio: try validatedRetryAudio(authorization)
            )
            let dispatchAuthorization = try dispatchAuthorization(
                try await fixture.store.prepareRetryDispatch(
                    using: reservationReceipt,
                    operationLeaseAuthorization: lease
                )
            )
            #expect(
                dispatchAuthorization.retryOperation.state
                    == .providerDispatched
            )
            #expect(
                dispatchAuthorization.retryOperation.retryID
                    == reservationReceipt.retryOperation.retryID
            )
            #expect(
                dispatchAuthorization.retryOperation.keepLatestResult == false
            )
            #expect(
                dispatchAuthorization.dispatchedRow.updatedAt
                    == reservationReceipt.row.updatedAt
            )
            #expect(
                dispatchAuthorization.dispatchedRow.retryCount
                    == reservationReceipt.row.retryCount
            )
            #expect(
                dispatchAuthorization.dispatchedRow.failureCategory
                    == reservationReceipt.row.failureCategory
            )
            let dispatchReceipt = try await fixture.store.commitRetryDispatch(
                using: dispatchAuthorization
            )
            let registration = try #require(
                await fixture.store.retryLiveOwnerState.registerLiveOwner(
                    dispatchReceipt.liveOwnerToken
                )
            )
            return (reservationReceipt, dispatchReceipt, registration)
        }

        let dispatchReceipt = receipts.1
        let registration = receipts.2
        let dispatched = try #require(try await fixture.store.load())
        #expect(dispatched.revision == 9)
        #expect(dispatched.entries == [dispatchReceipt.row])
        #expect(
            dispatchReceipt.liveOwnerToken.retryOperation
                == dispatchReceipt.retryOperation
        )
        #expect(String(describing: dispatchReceipt).contains("redacted"))
        #expect(dispatchReceipt.customMirror.children.isEmpty)
        #expect(registration.provesProviderDispatch(dispatchReceipt))
        #expect(await fixture.store.retryLiveOwnerState.hasLiveOwner())
    }

    @Test func reservationAdmissionFailsWithoutChangingTheRow()
        async throws {
        let fixture = try RetryStoreFixture()
        let row = try failedHistoryTestEntry(index: 2)
        let enabled = try await fixture.policyReceipt()

        try fixture.install(
            row: row,
            revision: 1,
            cleanup: try (10...14).map {
                try failedHistoryTestAudioCleanup(index: $0)
            }
        )
        await #expect(throws: IOSFailedHistoryError.capacityExceeded) {
            try await fixture.gate.perform { lease in
                _ = try await fixture.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: .defaults,
                    keepLatestResult: true,
                    using: enabled,
                    operationLeaseAuthorization: lease
                )
            }
        }
        #expect(try await fixture.store.load()?.entries == [row])
        #expect(!fixture.fileSystem.events.contains("replace"))

        let overflow = try failedHistoryTestEntry(
            index: 3,
            retryCount: Int32.max
        )
        try fixture.install(row: overflow, revision: 2)
        await #expect(throws: IOSFailedHistoryError.retryCountOverflow) {
            try await fixture.gate.perform { lease in
                _ = try await fixture.store.prepareRetryReservation(
                    attemptID: overflow.attemptID,
                    transcriptionConfiguration: .defaults,
                    keepLatestResult: true,
                    using: enabled,
                    operationLeaseAuthorization: lease
                )
            }
        }
        #expect(try await fixture.store.load()?.entries == [overflow])

        try fixture.install(row: row, revision: Int64.max)
        await #expect(throws: IOSFailedHistoryError.revisionOverflow) {
            try await fixture.gate.perform { lease in
                _ = try await fixture.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: .defaults,
                    keepLatestResult: true,
                    using: enabled,
                    operationLeaseAuthorization: lease
                )
            }
        }

        try fixture.install(row: row, revision: 3)
        await #expect(throws: IOSFailedHistoryError.invalidEntry) {
            try await fixture.gate.perform { lease in
                _ = try await fixture.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: TranscriptionConfiguration(
                        language: .custom,
                        customLanguageCode: "invalid"
                    ),
                    keepLatestResult: true,
                    using: enabled,
                    operationLeaseAuthorization: lease
                )
            }
        }
        #expect(try await fixture.store.load()?.entries == [row])

        let disabled = try await fixture.policyReceipt(enabled: false)
        await #expect(throws: IOSFailedHistoryError.stalePolicyGeneration) {
            try await fixture.gate.perform { lease in
                _ = try await fixture.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: .defaults,
                    keepLatestResult: true,
                    using: disabled,
                    operationLeaseAuthorization: lease
                )
            }
        }
        #expect(!fixture.fileSystem.events.contains("replace"))

        let foreignState = try IOSHistoryPolicyState(
            revision: 1,
            historyEnabled: true,
            policyGeneration: 1
        )
        let foreignPolicy = try await IOSHistoryPolicyStore(
            journal: RetryPolicyJournal(state: foreignState),
            capabilityOwnerIdentity:
                IOSAcceptedHistoryCapabilityOwnerIdentity()
        ).confirm(expected: IOSHistoryPolicyExpectation(state: foreignState))
        await #expect(throws: IOSFailedHistoryError.compareAndSwapFailed) {
            try await fixture.gate.perform { lease in
                _ = try await fixture.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: .defaults,
                    keepLatestResult: true,
                    using: foreignPolicy,
                    operationLeaseAuthorization: lease
                )
            }
        }
    }

    @Test func reservationUncertaintyRetainsFrozenIdentities()
        async throws {
        for outcomeVisible in [false, true] {
            let fixture = try RetryStoreFixture(
                namespace: outcomeVisible ? "outcome" : "source"
            )
            let row = try failedHistoryTestEntry(
                index: outcomeVisible ? 5 : 4
            )
            try fixture.install(row: row, revision: 4)
            let policy = try await fixture.policyReceipt()
            let frozenOperation = RetryOperationBox()
            fixture.fileSystem.replaceFailure = .init(
                error: .commitUncertain,
                commitBeforeThrowing: outcomeVisible
            )
            await #expect(throws: IOSFailedHistoryError.commitUncertain) {
                try await fixture.gate.perform { lease in
                    let authorization = try reservationAuthorization(
                        try await fixture.store.prepareRetryReservation(
                            attemptID: row.attemptID,
                            transcriptionConfiguration: .defaults,
                            keepLatestResult: true,
                            using: policy,
                            operationLeaseAuthorization: lease
                        )
                    )
                    frozenOperation.set(authorization.retryOperation)
                    _ = try await fixture.store.commitRetryReservation(
                        using: authorization,
                        validatedAudio: try validatedRetryAudio(
                            authorization
                        )
                    )
                }
            }
            await #expect(throws: IOSFailedHistoryError.commitUncertain) {
                try await fixture.gate.perform { lease in
                    _ = try await fixture.store.prepareRetryReservation(
                        attemptID: row.attemptID,
                        transcriptionConfiguration: .defaults,
                        keepLatestResult: false,
                        using: policy,
                        operationLeaseAuthorization: lease
                    )
                }
            }

            let recovered = try await fixture.gate.perform { lease in
                let preparation = try await fixture.store
                    .prepareRetryReservation(
                        attemptID: row.attemptID,
                        transcriptionConfiguration: .defaults,
                        keepLatestResult: true,
                        using: policy,
                        operationLeaseAuthorization: lease
                    )
                switch preparation {
                case .commit(let authorization):
                    #expect(!outcomeVisible)
                    #expect(
                        authorization.retryOperation
                            == frozenOperation.value()
                    )
                    return try await fixture.store.commitRetryReservation(
                        using: authorization,
                        validatedAudio: try validatedRetryAudio(
                            authorization
                        )
                    )
                case .completed(let receipt):
                    #expect(outcomeVisible)
                    return receipt
                }
            }
            #expect(recovered.retryOperation == frozenOperation.value())
            #expect(recovered.row.retryCount == row.retryCount + 1)
            #expect(!fixture.mutationInterlock.isBlocked)
        }
    }

    @Test func exactCancellationClearsOnlyTheMatchingOperation()
        async throws {
        for cancelDispatched in [false, true] {
            let fixture = try RetryStoreFixture(
                namespace: cancelDispatched ? "dispatch" : "reserve"
            )
            let row = try failedHistoryTestEntry(
                index: cancelDispatched ? 7 : 6,
                failureCategory: .providerUnavailable,
                pipelineStage: .translation,
                retryCount: 1,
                outputIntent: .translate
            )
            try fixture.install(row: row, revision: 10)
            let policy = try await fixture.policyReceipt()
            let reservation: IOSFailedHistoryRetryReservationReceipt
            let dispatch: IOSFailedHistoryRetryDispatchReceipt?
            let registration:
                IOSFailedHistoryRetryProviderRegistration?
            if cancelDispatched {
                let receipts = try await fixture.reserveAndDispatch(
                    row: row,
                    policy: policy
                )
                reservation = receipts.reservation
                dispatch = receipts.dispatch
                registration = receipts.registration
                #expect(
                    receipts.registration.provesProviderDispatch(
                        receipts.dispatch
                    )
                )
            } else {
                reservation = try await fixture.reserve(
                    row: row,
                    policy: policy
                )
                dispatch = nil
                registration = nil
                await #expect(
                    throws: IOSFailedHistoryError.compareAndSwapFailed
                ) {
                    try await fixture.gate.perform { lease in
                        _ = try await fixture.store.prepareRetryDispatch(
                            using: reservation,
                            operationLeaseAuthorization: lease
                        )
                    }
                }
            }

            let cancellationClaim:
                IOSFailedHistoryRetryProviderCancellationClaim?
            if let registration {
                cancellationClaim = try providerCancellationClaim(
                    try #require(
                        await fixture.store.retryLiveOwnerState
                            .claimProviderCancellation(registration)
                    )
                )
                #expect(
                    await fixture.store.retryLiveOwnerState
                        .hasLiveOwner()
                )
                #expect(
                    try providerCancellationClaim(
                        try #require(
                            await fixture.store.retryLiveOwnerState
                                .claimProviderCancellation(registration)
                        )
                    ) == cancellationClaim
                )
            } else {
                cancellationClaim = nil
                #expect(
                    await fixture.store.retryLiveOwnerState
                        .hasLiveOwner() == false
                )
            }

            let receipt = try await fixture.gate.perform { lease in
                let preparation:
                    IOSFailedHistoryRetryCancellationPreparation
                if cancelDispatched {
                    preparation = try await fixture.store
                        .prepareRetryCancellation(
                            using: try #require(dispatch),
                            providerCancellationClaim:
                                try #require(cancellationClaim),
                            operationLeaseAuthorization: lease
                        )
                } else {
                    preparation = try await fixture.store
                        .prepareRetryCancellation(
                            using: reservation,
                            operationLeaseAuthorization: lease
                        )
                }
                let authorization = try cancellationAuthorization(
                    preparation
                )
                #expect(
                    authorization.providerCancellationClaim
                        == cancellationClaim
                )
                let durableReceipt = try await fixture.store
                    .commitRetryCancellation(using: authorization)
                if registration != nil {
                    #expect(
                        await fixture.store.retryLiveOwnerState
                            .hasLiveOwner()
                    )
                    #expect(
                        await fixture.store.retryLiveOwnerState
                            .consumeProviderCancellation(
                                using: durableReceipt
                            )
                    )
                    #expect(
                        await fixture.store.retryLiveOwnerState
                            .consumeProviderCancellation(
                                using: durableReceipt
                            ) == false
                    )
                }
                return durableReceipt
            }
            #expect(
                await fixture.store.retryLiveOwnerState.hasLiveOwner()
                    == false
            )
            #expect(receipt.row.retryOperation == nil)
            #expect(receipt.row.retryCount == reservation.row.retryCount)
            #expect(receipt.row.failureCategory == row.failureCategory)
            #expect(receipt.row.pipelineStage == row.pipelineStage)
            #expect(
                receipt.row.audioRelativeIdentifier
                    == row.audioRelativeIdentifier
            )
            #expect(receipt.row.updatedAt == fixture.now)

            await #expect(throws: IOSFailedHistoryError.compareAndSwapFailed) {
                try await fixture.gate.perform { lease in
                    _ = try await fixture.store.prepareRetryCancellation(
                        using: reservation,
                        operationLeaseAuthorization: lease
                    )
                }
            }
        }
    }

    @Test func dispatchUncertaintyRefreshesLeaseWithoutChangingIdentity()
        async throws {
        for outcomeVisible in [false, true] {
            let fixture = try RetryStoreFixture(
                namespace: outcomeVisible
                    ? "dispatch-outcome"
                    : "dispatch-source"
            )
            let row = try failedHistoryTestEntry(
                index: outcomeVisible ? 9 : 8,
                retryCount: 2
            )
            try fixture.install(row: row, revision: 20)
            let policy = try await fixture.policyReceipt()
            let reservationBox = RetryReservationReceiptBox()
            let operationBox = RetryOperationBox()

            await #expect(throws: IOSFailedHistoryError.commitUncertain) {
                try await fixture.gate.perform { lease in
                    let reservationAuthorization = try
                        reservationAuthorization(
                            try await fixture.store
                                .prepareRetryReservation(
                                    attemptID: row.attemptID,
                                    transcriptionConfiguration: .defaults,
                                    keepLatestResult: true,
                                    using: policy,
                                    operationLeaseAuthorization: lease
                                )
                        )
                    let reservation = try await fixture.store
                        .commitRetryReservation(
                            using: reservationAuthorization,
                            validatedAudio: try validatedRetryAudio(
                                reservationAuthorization
                            )
                        )
                    reservationBox.set(reservation)
                    let dispatch = try dispatchAuthorization(
                        try await fixture.store.prepareRetryDispatch(
                            using: reservation,
                            operationLeaseAuthorization: lease
                        )
                    )
                    operationBox.set(dispatch.retryOperation)
                    fixture.fileSystem.replaceFailure = .init(
                        error: .commitUncertain,
                        commitBeforeThrowing: outcomeVisible
                    )
                    _ = try await fixture.store.commitRetryDispatch(
                        using: dispatch
                    )
                }
            }

            let recovered = try await fixture.gate.perform { lease in
                let preparation = try await fixture.store
                    .prepareRetryDispatch(
                        using: try #require(reservationBox.value()),
                        operationLeaseAuthorization: lease
                    )
                let receipt: IOSFailedHistoryRetryDispatchReceipt
                switch preparation {
                case .commit(let authorization):
                    #expect(!outcomeVisible)
                    receipt = try await fixture.store.commitRetryDispatch(
                        using: authorization
                    )
                case .completed(let completedReceipt):
                    #expect(outcomeVisible)
                    receipt = completedReceipt
                }
                let registration = try #require(
                    await fixture.store.retryLiveOwnerState
                        .registerLiveOwner(receipt.liveOwnerToken)
                )
                return (receipt, registration)
            }

            #expect(
                recovered.0.retryOperation == operationBox.value()
            )
            #expect(recovered.0.row.retryCount == row.retryCount + 1)
            #expect(recovered.0.row.updatedAt == fixture.now)
            #expect(recovered.1.provesProviderDispatch(recovered.0))
            #expect(
                await fixture.store.retryLiveOwnerState.hasLiveOwner()
            )
            #expect(!fixture.mutationInterlock.isBlocked)
        }
    }

    @Test func cancellationUncertaintyRetainsExactSourceAndOutcome()
        async throws {
        for cancelDispatched in [false, true] {
            for outcomeVisible in [false, true] {
                let fixture = try RetryStoreFixture(
                    namespace: "cancel-\(cancelDispatched)-\(outcomeVisible)"
                )
                let row = try failedHistoryTestEntry(
                    index: cancelDispatched ? 11 : 10,
                    failureCategory: .networkUnavailable,
                    pipelineStage: .translation,
                    retryCount: 3,
                    outputIntent: .translate
                )
                try fixture.install(row: row, revision: 30)
                let policy = try await fixture.policyReceipt()
                let source: IOSFailedHistoryRetryCancellationSource
                let registration:
                    IOSFailedHistoryRetryProviderRegistration?
                if cancelDispatched {
                    let dispatched = try await fixture.reserveAndDispatch(
                        row: row,
                        policy: policy
                    )
                    source = .dispatch(dispatched.dispatch)
                    registration = dispatched.registration
                } else {
                    source = .reservation(
                        try await fixture.reserve(row: row, policy: policy)
                    )
                    registration = nil
                }
                let cancellationClaim:
                    IOSFailedHistoryRetryProviderCancellationClaim?
                if let registration {
                    cancellationClaim = try providerCancellationClaim(
                        try #require(
                            await fixture.store.retryLiveOwnerState
                                .claimProviderCancellation(registration)
                        )
                    )
                    #expect(
                        await fixture.store.retryLiveOwnerState
                            .hasLiveOwner()
                    )
                } else {
                    cancellationClaim = nil
                    #expect(
                        await fixture.store.retryLiveOwnerState
                            .hasLiveOwner() == false
                    )
                }

                fixture.fileSystem.replaceFailure = .init(
                    error: .commitUncertain,
                    commitBeforeThrowing: outcomeVisible
                )
                await #expect(throws: IOSFailedHistoryError.commitUncertain) {
                    try await fixture.gate.perform { lease in
                        let preparation = try await
                            retryCancellationPreparation(
                                store: fixture.store,
                                source: source,
                                providerCancellationClaim:
                                    cancellationClaim,
                                operationLeaseAuthorization: lease
                            )
                        let authorization = try cancellationAuthorization(
                            preparation
                        )
                        #expect(
                            authorization.providerCancellationClaim
                                == cancellationClaim
                        )
                        _ = try await fixture.store
                            .commitRetryCancellation(
                                using: authorization
                            )
                    }
                }
                if let registration {
                    #expect(
                        await fixture.store.retryLiveOwnerState
                            .hasLiveOwner()
                    )
                    #expect(
                        try providerCancellationClaim(
                            try #require(
                                await fixture.store.retryLiveOwnerState
                                    .claimProviderCancellation(registration)
                            )
                        ) == cancellationClaim
                    )
                } else {
                    #expect(
                        await fixture.store.retryLiveOwnerState
                            .hasLiveOwner() == false
                    )
                }

                let recovered = try await fixture.gate.perform { lease in
                    let preparation = try await retryCancellationPreparation(
                        store: fixture.store,
                        source: source,
                        providerCancellationClaim: cancellationClaim,
                        operationLeaseAuthorization: lease
                    )
                    let durableReceipt:
                        IOSFailedHistoryRetryCancellationReceipt
                    switch preparation {
                    case .commit(let authorization):
                        #expect(!outcomeVisible)
                        #expect(
                            authorization.providerCancellationClaim
                                == cancellationClaim
                        )
                        durableReceipt = try await fixture.store
                            .commitRetryCancellation(using: authorization)
                    case .completed(let receipt):
                        #expect(outcomeVisible)
                        #expect(
                            receipt.authorization.providerCancellationClaim
                                == cancellationClaim
                        )
                        durableReceipt = receipt
                    }
                    if registration != nil {
                        #expect(
                            await fixture.store.retryLiveOwnerState
                                .hasLiveOwner()
                        )
                        #expect(
                            await fixture.store.retryLiveOwnerState
                                .consumeProviderCancellation(
                                    using: durableReceipt
                                )
                        )
                    }
                    return durableReceipt
                }

                #expect(
                    await fixture.store.retryLiveOwnerState.hasLiveOwner()
                        == false
                )
                #expect(recovered.row.retryOperation == nil)
                #expect(recovered.row.retryCount == row.retryCount + 1)
                #expect(recovered.row.failureCategory == row.failureCategory)
                #expect(recovered.row.pipelineStage == row.pipelineStage)
                #expect(!fixture.mutationInterlock.isBlocked)
            }
        }
    }
}

private func reservationAuthorization(
    _ preparation: IOSFailedHistoryRetryReservationPreparation
) throws -> IOSFailedHistoryRetryReservationAuthorization {
    guard case .commit(let authorization) = preparation else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return authorization
}

private func validatedRetryAudio(
    _ authorization: IOSFailedHistoryRetryReservationAuthorization
) throws -> IOSFailedHistoryRetryAudioValidationReceipt {
    try #require(
        IOSFailedHistoryRetryAudioValidationReceipt(
            testingAuthorization: authorization
        )
    )
}

private func dispatchAuthorization(
    _ preparation: IOSFailedHistoryRetryDispatchPreparation
) throws -> IOSFailedHistoryRetryDispatchAuthorization {
    guard case .commit(let authorization) = preparation else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return authorization
}

private func cancellationAuthorization(
    _ preparation: IOSFailedHistoryRetryCancellationPreparation
) throws -> IOSFailedHistoryRetryCancellationAuthorization {
    guard case .commit(let authorization) = preparation else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return authorization
}

private func providerCancellationClaim(
    _ terminalClaim: IOSFailedHistoryRetryProviderTerminalClaim
) throws -> IOSFailedHistoryRetryProviderCancellationClaim {
    guard case .cancellation(let claim) = terminalClaim else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return claim
}

private func retryCancellationPreparation(
    store: IOSFailedHistoryStore,
    source: IOSFailedHistoryRetryCancellationSource,
    providerCancellationClaim:
        IOSFailedHistoryRetryProviderCancellationClaim?,
    operationLeaseAuthorization:
        IOSPersistenceOperationLeaseAuthorization
) async throws -> IOSFailedHistoryRetryCancellationPreparation {
    switch source {
    case .reservation(let receipt):
        guard providerCancellationClaim == nil else {
            throw IOSFailedHistoryError.invalidTransition
        }
        return try await store.prepareRetryCancellation(
            using: receipt,
            operationLeaseAuthorization: operationLeaseAuthorization
        )
    case .dispatch(let receipt):
        guard let providerCancellationClaim else {
            throw IOSFailedHistoryError.invalidTransition
        }
        return try await store.prepareRetryCancellation(
            using: receipt,
            providerCancellationClaim: providerCancellationClaim,
            operationLeaseAuthorization: operationLeaseAuthorization
        )
    }
}

private final class RetryStoreFixture: @unchecked Sendable {
    let now: Date
    let gate: IOSPersistenceOperationGate
    let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    let pendingStoreIdentity = IOSPendingRecordingStoreIdentity()
    let mutationInterlock = IOSFailedHistoryMutationInterlock()
    let fileSystem = FailedHistoryFakeFileSystem()
    let store: IOSFailedHistoryStore
    private let rootURL: URL

    init(namespace: String = "default") throws {
        now = try failedHistoryTestDate(offsetMilliseconds: 9_999)
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "failed-retry-\(namespace)-\(UUID().uuidString)",
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
            now: { [now] in now }
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

    func policyReceipt(
        enabled: Bool = true
    ) async throws -> IOSHistoryPolicyReceipt {
        let state = try IOSHistoryPolicyState(
            revision: 1,
            historyEnabled: enabled,
            policyGeneration: 1
        )
        return try await IOSHistoryPolicyStore(
            journal: RetryPolicyJournal(state: state),
            capabilityOwnerIdentity: ownerIdentity
        ).confirm(expected: IOSHistoryPolicyExpectation(state: state))
    }

    func reserve(
        row: IOSFailedHistoryEntry,
        policy: IOSHistoryPolicyReceipt
    ) async throws -> IOSFailedHistoryRetryReservationReceipt {
        try await gate.perform { lease in
            let authorization = try reservationAuthorization(
                try await self.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: TranscriptionConfiguration(
                        model: "retry-model",
                        language: .german
                    ),
                    keepLatestResult: true,
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            )
            return try await self.store.commitRetryReservation(
                using: authorization,
                validatedAudio: try validatedRetryAudio(authorization)
            )
        }
    }

    func reserveAndDispatch(
        row: IOSFailedHistoryEntry,
        policy: IOSHistoryPolicyReceipt
    ) async throws -> (
        reservation: IOSFailedHistoryRetryReservationReceipt,
        dispatch: IOSFailedHistoryRetryDispatchReceipt,
        registration: IOSFailedHistoryRetryProviderRegistration
    ) {
        try await gate.perform { lease in
            let reservationAuthorization = try reservationAuthorization(
                try await self.store.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: TranscriptionConfiguration(
                        model: "retry-model",
                        language: .german
                    ),
                    keepLatestResult: true,
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            )
            let reservation = try await self.store.commitRetryReservation(
                using: reservationAuthorization,
                validatedAudio: try validatedRetryAudio(
                    reservationAuthorization
                )
            )
            let authorization = try dispatchAuthorization(
                try await self.store.prepareRetryDispatch(
                    using: reservation,
                    operationLeaseAuthorization: lease
                )
            )
            let dispatch = try await self.store.commitRetryDispatch(
                using: authorization
            )
            let registration = try #require(
                await self.store.retryLiveOwnerState.registerLiveOwner(
                    dispatch.liveOwnerToken
                )
            )
            return (reservation, dispatch, registration)
        }
    }
}

private final class RetryOperationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var operation: IOSFailedHistoryRetryOperation?

    func set(_ operation: IOSFailedHistoryRetryOperation) {
        lock.withLock { self.operation = operation }
    }

    func value() -> IOSFailedHistoryRetryOperation? {
        lock.withLock { operation }
    }
}

private final class RetryReservationReceiptBox: @unchecked Sendable {
    private let lock = NSLock()
    private var receipt: IOSFailedHistoryRetryReservationReceipt?

    func set(_ receipt: IOSFailedHistoryRetryReservationReceipt) {
        lock.withLock { self.receipt = receipt }
    }

    func value() -> IOSFailedHistoryRetryReservationReceipt? {
        lock.withLock { receipt }
    }
}

private final class RetryPolicyJournal:
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
