import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryRetryCoordinatorTests {
    @Test func dispatchRegistersBeforeGateReleaseAndExecutesOnlyOnce()
        async throws {
        let fixture = try RetryCoordinatorFixture()
        let row = try await fixture.prepareReadyFailure()
        let handoff = try await fixture.coordinator
            .prepareFailedHistoryRetry(
                attemptID: row.attemptID,
                setup: try retryCoordinatorSetup(
                    transcriptionConfiguration: TranscriptionConfiguration(
                        model: "retry-model",
                        language: .french,
                        freeformPrompt: "secret-retry-prompt-canary"
                    )
                )
            )

        let dispatched = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        let dispatchedRow = try #require(dispatched.entries.first)
        #expect(dispatchedRow.retryCount == 1)
        #expect(dispatchedRow.retryOperation?.state == .providerDispatched)
        #expect(dispatchedRow.transcriptionModel == "retry-model")
        #expect(dispatchedRow.transcriptionLanguageCode == "fr")
        #expect(await fixture.context.failedHistoryRetryState.hasLiveOwner())

        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.localRecoveryPending
        ) {
            _ = try await fixture.coordinator.prepareFailedHistoryRetry(
                attemptID: row.attemptID,
                setup: try retryCoordinatorSetup()
            )
        }

        let completion = try await handoff.execute { audio, setup in
            let gateReleased = (try? await fixture.context.operationGate
                .perform { _ in true }) == true
            let bytes = try? await audio.read(
                atOffset: 0,
                maximumByteCount: 64
            )
            return gateReleased && bytes?.isEmpty == false
                && setup.keepLatestResult
                ? "secret-provider-result-canary"
                : "failed"
        }
        #expect(completion.outcome == "secret-provider-result-canary")
        #expect(
            completion.dispatchReceipt.retryOperation.state
                == .providerDispatched
        )
        #expect(
            String(describing: completion)
                == "IOSFailedHistoryRetryProviderCompletion(redacted)"
        )
        #expect(
            !String(describing: completion).contains(
                "secret-provider-result-canary"
            )
        )
        #expect(completion.customMirror.children.isEmpty)
        await #expect(throws: IOSPendingRecordingError.dispatchAlreadyCommitted) {
            _ = try await handoff.execute { _, _ in false }
        }
        #expect(await fixture.context.failedHistoryRetryState.hasLiveOwner())
    }

    @Test func setupIsFrozenAndRejectedBeforeDurableReservation()
        async throws {
        #expect(throws: IOSFailedHistoryError.invalidTransition) {
            _ = try IOSFailedHistoryRetrySetupSnapshot(
                credentialEligibility: .unavailable,
                transcriptionConfiguration: .defaults,
                translationConfiguration: nil,
                keepLatestResult: true
            )
        }

        let fixture = try RetryCoordinatorFixture()
        let row = try await fixture.prepareReadyFailure()
        let incompatible = try IOSFailedHistoryRetrySetupSnapshot(
            credentialEligibility: .available,
            transcriptionConfiguration: .defaults,
            translationConfiguration: TranslationConfiguration(
                targetLanguage: .english
            ),
            keepLatestResult: false
        )
        #expect(
            String(describing: incompatible)
                == "IOSFailedHistoryRetrySetupSnapshot(redacted)"
        )
        await #expect(throws: IOSFailedHistoryError.invalidTransition) {
            _ = try await fixture.coordinator.prepareFailedHistoryRetry(
                attemptID: row.attemptID,
                setup: incompatible
            )
        }
        let unchanged = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        #expect(unchanged.entries.first?.retryOperation == nil)
        #expect(unchanged.entries.first?.retryCount == 0)
        #expect(
            await fixture.context.failedHistoryRetryState.hasLiveOwner()
                == false
        )
    }

    @Test func pendingAndFailedProviderOwnersExcludeEachOtherAtRoot()
        async throws {
        do {
            let fixture = try RetryCoordinatorFixture()
            let failedRow = try await fixture.prepareReadyFailure()
            let pending = try await fixture.prepareReadyPending()
            let pendingHandoff = try await fixture.context
                .pendingRecordingStore.beginTranscription(
                    expected: IOSPendingRecordingCASExpectation(
                        recording: pending
                    ),
                    transcriptionID: UUID()
                )
            await #expect(throws: IOSPendingRecordingError.localRecoveryPending) {
                _ = try await fixture.coordinator.prepareFailedHistoryRetry(
                    attemptID: failedRow.attemptID,
                    setup: try retryCoordinatorSetup()
                )
            }
            let unchanged = try #require(
                try await fixture.context.failedHistoryStore.load()
            )
            #expect(unchanged.entries.first?.retryOperation == nil)
            #expect(unchanged.entries.first?.retryCount == 0)
            _ = pendingHandoff
        }

        do {
            let fixture = try RetryCoordinatorFixture()
            let failedRow = try await fixture.prepareReadyFailure()
            let retryHandoff = try await fixture.coordinator
                .prepareFailedHistoryRetry(
                    attemptID: failedRow.attemptID,
                    setup: try retryCoordinatorSetup()
                )
            do {
                _ = try await fixture.prepareReadyPending()
                Issue.record("A live failed Retry must exclude Pending work.")
            } catch is IOSPendingRecordingError {
                // The exact Pending surface remains typed and no Pending
                // journal is published while Retry owns the descriptor/root.
            }
            #expect(try fixture.rawPendingRecording() == nil)
            try await retryHandoff.cancel()
        }
    }

    @Test func exactCancellationMakesTheSameRowRetryableAgain()
        async throws {
        let fixture = try RetryCoordinatorFixture()
        let row = try await fixture.prepareReadyFailure()
        let first = try await fixture.coordinator.prepareFailedHistoryRetry(
            attemptID: row.attemptID,
            setup: try retryCoordinatorSetup()
        )

        try await first.cancel()
        try await first.cancel()
        var cancelled = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        var cancelledRow = try #require(cancelled.entries.first)
        #expect(cancelledRow.retryOperation == nil)
        #expect(cancelledRow.retryCount == 1)
        #expect(cancelledRow.failureCategory == row.failureCategory)
        #expect(cancelledRow.pipelineStage == row.pipelineStage)
        #expect(fixture.audioExists(for: cancelledRow))
        #expect(
            await fixture.context.failedHistoryRetryState.hasLiveOwner()
                == false
        )

        let second = try await fixture.coordinator.prepareFailedHistoryRetry(
            attemptID: row.attemptID,
            setup: try retryCoordinatorSetup(
                transcriptionConfiguration: TranscriptionConfiguration(
                    model: "second-model",
                    language: .german
                )
            )
        )
        try await second.cancel()
        cancelled = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        cancelledRow = try #require(cancelled.entries.first)
        #expect(cancelledRow.retryOperation == nil)
        #expect(cancelledRow.retryCount == 2)
        #expect(cancelledRow.transcriptionModel == "second-model")
        #expect(cancelledRow.transcriptionLanguageCode == "de")
    }

    @Test func cancellationDrainsNoncooperativeLateResultBeforeRowClears()
        async throws {
        let fixture = try RetryCoordinatorFixture()
        let row = try await fixture.prepareReadyFailure()
        let handoff = try await fixture.coordinator.prepareFailedHistoryRetry(
            attemptID: row.attemptID,
            setup: try retryCoordinatorSetup()
        )
        let started = RetryCoordinatorLatch()
        let release = RetryCoordinatorLatch()
        let execution = Task {
            try await handoff.execute { _, _ in
                await started.open()
                await release.wait()
                return "late-success"
            }
        }
        await started.wait()

        let cancellation = Task {
            try await handoff.cancel()
        }
        await Task.yield()
        let stillDispatched = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        #expect(
            stillDispatched.entries.first?.retryOperation?.state
                == .providerDispatched
        )
        #expect(await fixture.context.failedHistoryRetryState.hasLiveOwner())

        await release.open()
        try await cancellation.value
        await #expect(throws: CancellationError.self) {
            _ = try await execution.value
        }
        let cancelled = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        #expect(cancelled.entries.first?.retryOperation == nil)
        #expect(
            await fixture.context.failedHistoryRetryState.hasLiveOwner()
                == false
        )
    }

    @Test func callerCancellationUsesFreshCleanupTaskAndClearsExactRetry()
        async throws {
        let fixture = try RetryCoordinatorFixture()
        let row = try await fixture.prepareReadyFailure()
        let handoff = try await fixture.coordinator.prepareFailedHistoryRetry(
            attemptID: row.attemptID,
            setup: try retryCoordinatorSetup()
        )
        let started = RetryCoordinatorLatch()
        let execution = Task {
            try await handoff.execute { _, _ in
                await started.open()
                while !Task.isCancelled {
                    await Task.yield()
                }
                return "cancelled"
            }
        }
        await started.wait()

        execution.cancel()
        await #expect(throws: CancellationError.self) {
            _ = try await execution.value
        }
        try await retryCoordinatorEventually {
            let envelope = try await fixture.context.failedHistoryStore.load()
            let hasLiveOwner = await fixture.context
                .failedHistoryRetryState.hasLiveOwner()
            return envelope?.entries.first?.retryOperation == nil
                && !hasLiveOwner
        }
    }

    @Test func providerSelfCancellationDoesNotWaitForItsOwnDrain()
        async throws {
        let fixture = try RetryCoordinatorFixture()
        let row = try await fixture.prepareReadyFailure()
        let handoff = try await fixture.coordinator.prepareFailedHistoryRetry(
            attemptID: row.attemptID,
            setup: try retryCoordinatorSetup()
        )

        await #expect(throws: CancellationError.self) {
            _ = try await handoff.execute { _, _ in
                try? await handoff.cancel()
                return "late-self-result"
            }
        }
        try await retryCoordinatorEventually {
            let envelope = try await fixture.context.failedHistoryStore.load()
            let hasLiveOwner = await fixture.context
                .failedHistoryRetryState.hasLiveOwner()
            return envelope?.entries.first?.retryOperation == nil
                && !hasLiveOwner
        }
    }

    @Test func coordinatorReconcilesEveryLocalCommitUncertainty()
        async throws {
        for boundary in RetryCoordinatorUncertaintyBoundary.allCases {
            for outcomeVisible in [false, true] {
                let fixture = try RetryCoordinatorUncertaintyFixture()
                let row = try await fixture.prepareReadyFailure()
                let failure = FailedHistoryFakeFileSystem.Failure(
                    error: .commitUncertain,
                    commitBeforeThrowing: outcomeVisible
                )
                switch boundary {
                case .reservation:
                    fixture.failedFileSystem.replaceFailure = failure
                case .dispatch:
                    fixture.failedFileSystem
                        .replaceFailureAfterSuccessfulReplaces = (
                            remaining: 1,
                            failure: failure
                        )
                case .cancellation:
                    break
                }

                let handoff = try await fixture.coordinator
                    .prepareFailedHistoryRetry(
                        attemptID: row.attemptID,
                        setup: try retryCoordinatorSetup()
                    )
                let dispatched = try #require(
                    try await fixture.failedHistoryStore.load()
                )
                #expect(dispatched.entries.first?.retryCount == 1)
                #expect(
                    dispatched.entries.first?.retryOperation?.state
                        == .providerDispatched
                )
                #expect(await fixture.retryState.hasLiveOwner())

                if boundary == .cancellation {
                    fixture.failedFileSystem.replaceFailure = failure
                }
                try await handoff.cancel()
                let cancelled = try #require(
                    try await fixture.failedHistoryStore.load()
                )
                #expect(cancelled.entries.first?.retryOperation == nil)
                #expect(cancelled.entries.first?.retryCount == 1)
                #expect(await fixture.retryState.hasLiveOwner() == false)
                #expect(!fixture.mutationInterlock.isBlocked)
            }
        }
    }

    @Test func retryEntrypointResumesRetainedCleanupAfterDeinitExhaustion()
        async throws {
        let fixture = try RetryCoordinatorUncertaintyFixture()
        let row = try await fixture.prepareReadyFailure()
        var handoff: IOSFailedHistoryRetryHandoff? = try await fixture
            .coordinator.prepareFailedHistoryRetry(
                attemptID: row.attemptID,
                setup: try retryCoordinatorSetup()
            )
        fixture.failedFileSystem.persistentReplaceFailure = .init(
            error: .commitUncertain,
            commitBeforeThrowing: false
        )

        handoff = nil
        #expect(handoff == nil)
        #expect(await fixture.retryState.hasLiveOwner())
        try await retryCoordinatorEventually {
            fixture.mutationInterlock.isBlocked
        }

        fixture.failedFileSystem.persistentReplaceFailure = nil
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.localRecoveryPending
        ) {
            _ = try await fixture.coordinator.prepareFailedHistoryRetry(
                attemptID: row.attemptID,
                setup: try retryCoordinatorSetup()
            )
        }
        try await retryCoordinatorEventually {
            guard !fixture.mutationInterlock.isBlocked,
                  let envelope = try? await fixture.failedHistoryStore.load()
            else {
                return false
            }
            let hasLiveOwner = await fixture.retryState.hasLiveOwner()
            return envelope.entries.first?.retryOperation == nil
                && !hasLiveOwner
        }
        #expect(!fixture.mutationInterlock.isBlocked)

        let resumed = try await fixture.coordinator.prepareFailedHistoryRetry(
            attemptID: row.attemptID,
            setup: try retryCoordinatorSetup()
        )
        let retried = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(retried.entries.first?.retryCount == 2)
        try await resumed.cancel()
    }

    @Test func unconsumedHandoffDeinitUsesExactDurableCancellation()
        async throws {
        let fixture = try RetryCoordinatorFixture()
        let row = try await fixture.prepareReadyFailure()
        var handoff: IOSFailedHistoryRetryHandoff? = try await fixture
            .coordinator.prepareFailedHistoryRetry(
                attemptID: row.attemptID,
                setup: try retryCoordinatorSetup()
            )
        #expect(handoff != nil)
        #expect(await fixture.context.failedHistoryRetryState.hasLiveOwner())

        handoff = nil
        try await retryCoordinatorEventually {
            let envelope = try await fixture.context.failedHistoryStore.load()
            let hasLiveOwner = await fixture.context
                .failedHistoryRetryState.hasLiveOwner()
            return envelope?.entries.first?.retryOperation == nil
                && !hasLiveOwner
        }
        let cancelled = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        #expect(cancelled.entries.first?.retryCount == 1)
        #expect(fixture.audioExists(for: try #require(cancelled.entries.first)))
    }
}

private enum RetryCoordinatorUncertaintyBoundary: CaseIterable {
    case reservation
    case dispatch
    case cancellation
}

private final class RetryCoordinatorFixture: @unchecked Sendable {
    let parentDirectoryURL: URL
    let applicationSupportDirectoryURL: URL
    let registry: IOSAcceptedHistoryCoordinatorProcessContextRegistry
    let context: IOSAcceptedHistoryCoordinatorProcessContext
    let coordinator: IOSAcceptedHistoryCoordinator

    init() throws {
        parentDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "failed-retry-coordinator-\(UUID().uuidString)",
                isDirectory: true
            )
        applicationSupportDirectoryURL = parentDirectoryURL
            .appendingPathComponent("ApplicationSupport", isDirectory: true)
        try FileManager.default.createDirectory(
            at: applicationSupportDirectoryURL,
            withIntermediateDirectories: true
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        self.registry = registry
        let context = registry.context(for: applicationSupportDirectoryURL)
        self.context = context
        coordinator = IOSAcceptedHistoryCoordinator(
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
                    applicationSupportDirectoryURL:
                        applicationSupportDirectoryURL
                )
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: parentDirectoryURL)
    }

    func prepareReadyFailure() async throws -> IOSFailedHistoryEntry {
        _ = try await coordinator.capture(
            transcriptionModel: "gpt-4o-mini-transcribe",
            transcriptionLanguageCode: "en",
            durationMilliseconds: 1_000
        )
        let attemptID = UUID()
        let sourceURL = parentDirectoryURL.appendingPathComponent(
            "source-\(attemptID.uuidString.lowercased()).wav",
            isDirectory: false
        )
        let audio = makeRetryCoordinatorWAV()
        try audio.write(to: sourceURL, options: .atomic)
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
                transcriptionConfiguration: TranscriptionConfiguration(
                    model: "gpt-4o-mini-transcribe",
                    language: .english
                )
            )
        )
        _ = try await coordinator.transferPendingRecordingFailure(
            expected: IOSPendingRecordingCASExpectation(recording: pending),
            failure: IOSFailedHistoryTransferFailure(
                category: .networkUnavailable,
                pipelineStage: .transcription
            )
        )
        let envelope = try #require(
            try await context.failedHistoryStore.load()
        )
        return try #require(envelope.entries.first)
    }

    func prepareReadyPending() async throws -> IOSPendingRecording {
        let attemptID = UUID()
        let sourceURL = parentDirectoryURL.appendingPathComponent(
            "pending-source-\(attemptID.uuidString.lowercased()).wav",
            isDirectory: false
        )
        let audio = makeRetryCoordinatorWAV()
        try audio.write(to: sourceURL, options: .atomic)
        return try await context.pendingRecordingStore.prepare(
            IOSPendingRecordingPreparation(
                attemptID: attemptID,
                sourceArtifact: AudioRecordingArtifact(
                    fileURL: sourceURL,
                    duration: 1,
                    byteCount: Int64(audio.count)
                ),
                initialState: .readyForTranscription,
                outputIntent: .standard,
                transcriptionConfiguration: .defaults
            )
        )
    }

    func audioExists(for row: IOSFailedHistoryEntry) -> Bool {
        guard let url = IOSPendingRecordingStorageLocation.audioFileURL(
            forRelativeIdentifier: row.audioRelativeIdentifier,
            in: applicationSupportDirectoryURL
        ) else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    func rawPendingRecording() throws -> IOSPendingRecording? {
        try FoundationIOSPendingRecordingJournalRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            repositoryGuard: context.repositoryGuard
        ).load()
    }
}

private final class RetryCoordinatorUncertaintyFixture:
    @unchecked Sendable {
    let parentDirectoryURL: URL
    let applicationSupportDirectoryURL: URL
    let registry: IOSAcceptedHistoryCoordinatorProcessContextRegistry
    let context: IOSAcceptedHistoryCoordinatorProcessContext
    let failedFileSystem = FailedHistoryFakeFileSystem()
    let retryState = IOSFailedHistoryRetryLiveOwnerState()
    let mutationInterlock: IOSFailedHistoryMutationInterlock
    let failedHistoryStore: IOSFailedHistoryStore
    let pendingRecordingStore: IOSPendingRecordingStore
    let coordinator: IOSAcceptedHistoryCoordinator

    init() throws {
        parentDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "failed-retry-uncertainty-\(UUID().uuidString)",
                isDirectory: true
            )
        applicationSupportDirectoryURL = parentDirectoryURL
            .appendingPathComponent("ApplicationSupport", isDirectory: true)
        try FileManager.default.createDirectory(
            at: applicationSupportDirectoryURL,
            withIntermediateDirectories: true
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        self.registry = registry
        let context = registry.context(for: applicationSupportDirectoryURL)
        self.context = context
        mutationInterlock = context.failedHistoryMutationInterlock

        let failedHistoryStore = IOSFailedHistoryStore(
            journal: FoundationIOSFailedHistoryJournalRepository(
                fileSystem: failedFileSystem
            ),
            capabilityOwnerIdentity: context.ownerIdentity,
            operationGateIdentity: context.operationGate.identity,
            expectedPendingStoreIdentity:
                context.pendingRecordingStoreIdentity,
            retryLiveOwnerState: retryState,
            repositoryGuard: context.repositoryGuard,
            mutationInterlock: mutationInterlock
        )
        self.failedHistoryStore = failedHistoryStore
        guard let physicalRootIdentity = context.repositoryBinding
                .physicalRootIdentity,
              retryState.bindProviderRegistration(
                  failedStoreIdentity: failedHistoryStore.storeIdentity,
                  ownerIdentity: context.ownerIdentity,
                  physicalRootIdentity: physicalRootIdentity
              ) else {
            throw IOSFailedHistoryError.repositoryIdentityConflict
        }

        let pendingRecordingStore = IOSPendingRecordingStore(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            capabilityOwnerIdentity: context.ownerIdentity,
            storeIdentity: context.pendingRecordingStoreIdentity,
            operationGate: context.operationGate,
            liveOwnerRegistry: context.pendingRecordingLiveOwnerRegistry,
            failedHistoryRetryState: retryState,
            mediaValidationWorkerGate:
                context.pendingRecordingMediaValidationWorkerGate,
            repositoryGuard: context.repositoryGuard,
            failedHistoryMutationInterlock: mutationInterlock,
            failedOwnershipInspector: failedHistoryStore
        )
        self.pendingRecordingStore = pendingRecordingStore
        coordinator = IOSAcceptedHistoryCoordinator(
            policyStore: context.policyStore,
            acceptedHistoryStore: context.acceptedHistoryStore,
            failedHistoryStore: failedHistoryStore,
            pendingRecordingStore: pendingRecordingStore,
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
            failedHistoryRetryState: retryState,
            ownerIdentity: context.ownerIdentity,
            repositoryIdentityState: context.repositoryIdentityState,
            repositoryRegistration:
                IOSAcceptedHistoryCoordinatorRepositoryRegistration(
                    registry: registry,
                    context: context,
                    applicationSupportDirectoryURL:
                        applicationSupportDirectoryURL
                )
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: parentDirectoryURL)
    }

    func prepareReadyFailure() async throws -> IOSFailedHistoryEntry {
        _ = try await coordinator.capture(
            transcriptionModel: "gpt-4o-mini-transcribe",
            transcriptionLanguageCode: "en",
            durationMilliseconds: 1_000
        )
        let attemptID = UUID()
        let sourceURL = parentDirectoryURL.appendingPathComponent(
            "source-\(attemptID.uuidString.lowercased()).wav",
            isDirectory: false
        )
        let audio = makeRetryCoordinatorWAV()
        try audio.write(to: sourceURL, options: .atomic)
        let pending = try await pendingRecordingStore.prepare(
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
        _ = try await coordinator.transferPendingRecordingFailure(
            expected: IOSPendingRecordingCASExpectation(recording: pending),
            failure: IOSFailedHistoryTransferFailure(
                category: .networkUnavailable,
                pipelineStage: .transcription
            )
        )
        let envelope = try #require(try await failedHistoryStore.load())
        return try #require(envelope.entries.first)
    }
}

private actor RetryCoordinatorLatch {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { continuation in
            if isOpen {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
    }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let waiters = waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

private func retryCoordinatorSetup(
    transcriptionConfiguration: TranscriptionConfiguration = .defaults,
    keepLatestResult: Bool = true
) throws -> IOSFailedHistoryRetrySetupSnapshot {
    try IOSFailedHistoryRetrySetupSnapshot(
        credentialEligibility: .available,
        transcriptionConfiguration: transcriptionConfiguration,
        translationConfiguration: nil,
        keepLatestResult: keepLatestResult
    )
}

private func retryCoordinatorEventually(
    _ predicate: @escaping @Sendable () async throws -> Bool
) async throws {
    for _ in 0..<100 {
        if try await predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for Retry cancellation.")
}

private func makeRetryCoordinatorWAV() -> Data {
    let sampleRate: UInt32 = 8_000
    let channelCount: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let dataByteCount = sampleRate * UInt32(bitsPerSample / 8)
    let byteRate = sampleRate * UInt32(channelCount)
        * UInt32(bitsPerSample / 8)
    let blockAlign = channelCount * (bitsPerSample / 8)

    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.appendRetryCoordinatorLittleEndian(UInt32(36) + dataByteCount)
    data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8)
    data.appendRetryCoordinatorLittleEndian(UInt32(16))
    data.appendRetryCoordinatorLittleEndian(UInt16(1))
    data.appendRetryCoordinatorLittleEndian(channelCount)
    data.appendRetryCoordinatorLittleEndian(sampleRate)
    data.appendRetryCoordinatorLittleEndian(byteRate)
    data.appendRetryCoordinatorLittleEndian(blockAlign)
    data.appendRetryCoordinatorLittleEndian(bitsPerSample)
    data.append(contentsOf: "data".utf8)
    data.appendRetryCoordinatorLittleEndian(dataByteCount)
    data.append(Data(repeating: 0, count: Int(dataByteCount)))
    return data
}

private extension Data {
    mutating func appendRetryCoordinatorLittleEndian<
        Value: FixedWidthInteger
    >(_ value: Value) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
