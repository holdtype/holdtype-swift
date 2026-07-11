import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryRetryAudioTests {
    @Test func exactDispatchTakesDescriptorAudioOnlyOnce() async throws {
        let fixture = try RetryAudioFixture(namespace: "take")
        let row = try failedHistoryTestEntry(index: 201)
        try fixture.install(row: row)

        let output = try await fixture.prepareAudioAndDispatch(row: row)

        #expect(fixture.audio.acquireCount == 1)
        #expect(fixture.audio.releaseCount == 0)
        #expect(
            String(describing: output.source)
                == "IOSFailedHistoryRetryAudioSource(redacted)"
        )
        #expect(output.source.customMirror.children.isEmpty)
        #expect(
            String(describing: output.source.validationReceipt)
                == "IOSFailedHistoryRetryAudioValidationReceipt(redacted)"
        )
        #expect(
            output.source.validationReceipt.customMirror.children.isEmpty
        )

        let audio = try output.source.take(
            using: output.dispatchReceipt,
            registration: output.registration
        )
        #expect(audio.format == .m4a)
        #expect(audio.durationMilliseconds == row.durationMilliseconds)
        #expect(audio.byteCount == row.byteCount)
        #expect(
            try await audio.read(atOffset: 0, maximumByteCount: 8)
                == Data(repeating: 0x52, count: 8)
        )
        #expect(fixture.audio.releaseCount == 0)

        #expect(throws: IOSPendingRecordingError.dispatchAlreadyCommitted) {
            _ = try output.source.take(
                using: output.dispatchReceipt,
                registration: output.registration
            )
        }
        output.source.invalidate()
        #expect(fixture.audio.releaseCount == 0)
        audio.invalidate()
        #expect(fixture.audio.releaseCount == 1)
    }

    @Test func unrelatedDispatchCannotConsumeTheSource() async throws {
        let first = try RetryAudioFixture(namespace: "first")
        let second = try RetryAudioFixture(namespace: "second")
        let firstRow = try failedHistoryTestEntry(index: 202)
        let secondRow = try failedHistoryTestEntry(index: 203)
        try first.install(row: firstRow)
        try second.install(row: secondRow)
        let firstOutput = try await first.prepareAudioAndDispatch(
            row: firstRow
        )
        let secondOutput = try await second.prepareAudioAndDispatch(
            row: secondRow
        )
        defer { secondOutput.source.invalidate() }

        #expect(throws: IOSPendingRecordingError.localRecoveryPending) {
            _ = try firstOutput.source.take(
                using: secondOutput.dispatchReceipt,
                registration: secondOutput.registration
            )
        }
        #expect(first.audio.releaseCount == 0)

        let audio = try firstOutput.source.take(
            using: firstOutput.dispatchReceipt,
            registration: firstOutput.registration
        )
        audio.invalidate()
        #expect(first.audio.releaseCount == 1)
    }

    @Test func invalidationAndDeinitReleaseUnconsumedAudio() async throws {
        let invalidated = try RetryAudioFixture(namespace: "invalidate")
        let invalidatedRow = try failedHistoryTestEntry(index: 204)
        try invalidated.install(row: invalidatedRow)
        let invalidatedOutput = try await invalidated.prepareAudioAndDispatch(
            row: invalidatedRow
        )

        invalidatedOutput.source.invalidate()
        invalidatedOutput.source.invalidate()
        #expect(invalidated.audio.releaseCount == 1)

        let deinitialized = try RetryAudioFixture(namespace: "deinit")
        let deinitializedRow = try failedHistoryTestEntry(index: 205)
        try deinitialized.install(row: deinitializedRow)
        var source: IOSFailedHistoryRetryAudioSource? = try await deinitialized
            .prepareAudioAndDispatch(row: deinitializedRow).source
        #expect(deinitialized.audio.releaseCount == 0)
        source = nil
        #expect(source == nil)
        #expect(deinitialized.audio.releaseCount == 1)
    }

    @Test func livePendingOwnerRejectsBeforePendingOrAudioIO() async throws {
        let fixture = try RetryAudioFixture(namespace: "pending-owner")
        let row = try failedHistoryTestEntry(index: 206)
        try fixture.install(row: row)
        let policy = try await fixture.policyReceipt()

        try await fixture.gate.perform { lease in
            let authorization = try retryAudioReservationAuthorization(
                try await fixture.failedStore.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: .defaults,
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            )
            fixture.pendingJournal.resetLoadCount()
            fixture.audio.resetCounts()
            fixture.pendingLiveOwners.register(
                attemptID: failedHistoryTestUUID(
                    namespace: 0x61,
                    index: 1
                ),
                transcriptionID: failedHistoryTestUUID(
                    namespace: 0x62,
                    index: 1
                )
            )
            defer {
                fixture.pendingLiveOwners.retire(
                    attemptID: failedHistoryTestUUID(
                        namespace: 0x61,
                        index: 1
                    ),
                    transcriptionID: failedHistoryTestUUID(
                        namespace: 0x62,
                        index: 1
                    )
                )
            }

            await #expect(
                throws: IOSPendingRecordingError.localRecoveryPending
            ) {
                _ = try await fixture.pendingStore
                    .acquireValidatedFailedHistoryRetryAudio(
                        using: authorization,
                        operationLeaseAuthorization: lease
                    )
            }
            #expect(fixture.pendingJournal.loadCount == 0)
            #expect(fixture.audio.namespaceValidationCount == 0)
            #expect(fixture.audio.acquireCount == 0)
        }
    }

    @Test func pendingSourceChangeAfterOpenFailsClosedAndReleases()
        async throws {
        let fixture = try RetryAudioFixture(namespace: "source-change")
        let row = try failedHistoryTestEntry(index: 207)
        try fixture.install(row: row)
        let changedPending = try retryAudioPendingRecording(index: 208)
        fixture.audio.onAcquire {
            fixture.pendingJournal.recording = changedPending
        }
        let policy = try await fixture.policyReceipt()

        try await fixture.gate.perform { lease in
            let authorization = try retryAudioReservationAuthorization(
                try await fixture.failedStore.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: .defaults,
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            )
            await #expect(
                throws: IOSPendingRecordingError.localRecoveryPending
            ) {
                _ = try await fixture.pendingStore
                    .acquireValidatedFailedHistoryRetryAudio(
                        using: authorization,
                        operationLeaseAuthorization: lease
                    )
            }
        }

        #expect(fixture.audio.acquireCount == 1)
        #expect(fixture.audio.releaseCount == 1)
    }

    @Test func invalidatedDescriptorProofCannotCommitReservation()
        async throws {
        let fixture = try RetryAudioFixture(namespace: "invalid-proof")
        let row = try failedHistoryTestEntry(index: 209)
        try fixture.install(row: row)
        let policy = try await fixture.policyReceipt()

        try await fixture.gate.perform { lease in
            let authorization = try retryAudioReservationAuthorization(
                try await fixture.failedStore.prepareRetryReservation(
                    attemptID: row.attemptID,
                    transcriptionConfiguration: .defaults,
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            )
            let source = try await fixture.pendingStore
                .acquireValidatedFailedHistoryRetryAudio(
                    using: authorization,
                    operationLeaseAuthorization: lease
                )
            source.invalidate()

            await #expect(
                throws: IOSFailedHistoryError.compareAndSwapFailed
            ) {
                _ = try await fixture.failedStore.commitRetryReservation(
                    using: authorization,
                    validatedAudio: source.validationReceipt
                )
            }
        }

        #expect(try await fixture.failedStore.load()?.entries == [row])
        #expect(fixture.audio.releaseCount == 1)
    }
}

private func retryAudioReservationAuthorization(
    _ preparation: IOSFailedHistoryRetryReservationPreparation
) throws -> IOSFailedHistoryRetryReservationAuthorization {
    guard case .commit(let authorization) = preparation else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return authorization
}

private func retryAudioDispatchAuthorization(
    _ preparation: IOSFailedHistoryRetryDispatchPreparation
) throws -> IOSFailedHistoryRetryDispatchAuthorization {
    guard case .commit(let authorization) = preparation else {
        throw IOSFailedHistoryError.invalidTransition
    }
    return authorization
}

private func retryAudioPendingRecording(
    index: Int
) throws -> IOSPendingRecording {
    let attemptID = failedHistoryTestUUID(namespace: 0x63, index: index)
    let date = try failedHistoryTestDate(
        offsetMilliseconds: Int64(index * 10)
    )
    return try IOSPendingRecording(
        attemptID: attemptID,
        audioRelativeIdentifier:
            IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
                for: attemptID,
                format: .m4a
            ),
        createdAt: date,
        updatedAt: date,
        phase: .readyForTranscription,
        outputIntent: .standard,
        transcriptionID: nil,
        transcriptionModel: "gpt-4o-mini-transcribe",
        transcriptionLanguageCode: "en",
        durationMilliseconds: 900,
        byteCount: 2_048
    )
}

private final class RetryAudioFixture: @unchecked Sendable {
    let gate: IOSPersistenceOperationGate
    let failedStore: IOSFailedHistoryStore
    let pendingStore: IOSPendingRecordingStore
    let pendingJournal = RetryAudioPendingJournal()
    let audio = RetryAudioFileSystem()
    let pendingLiveOwners: IOSPendingRecordingLiveOwnerRegistry
    let retryState: IOSFailedHistoryRetryLiveOwnerState

    private let ownerIdentity: IOSAcceptedHistoryCapabilityOwnerIdentity
    private let failedFileSystem = FailedHistoryFakeFileSystem()
    private let rootURL: URL

    init(namespace: String) throws {
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "failed-retry-audio-\(namespace)-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: false
        )
        let context = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
            .context(for: rootURL)
        gate = context.operationGate
        ownerIdentity = context.ownerIdentity
        pendingLiveOwners = context.pendingRecordingLiveOwnerRegistry
        let retryState = IOSFailedHistoryRetryLiveOwnerState()
        self.retryState = retryState
        let failedStore = IOSFailedHistoryStore(
            journal: FoundationIOSFailedHistoryJournalRepository(
                fileSystem: failedFileSystem
            ),
            capabilityOwnerIdentity: context.ownerIdentity,
            operationGateIdentity: context.operationGate.identity,
            expectedPendingStoreIdentity:
                context.pendingRecordingStoreIdentity,
            retryLiveOwnerState: retryState,
            repositoryGuard: context.repositoryGuard,
            mutationInterlock: context.failedHistoryMutationInterlock,
            now: { try! failedHistoryTestDate(
                offsetMilliseconds: 99_999
            ) }
        )
        self.failedStore = failedStore
        guard let physicalRootIdentity = context.repositoryBinding
                .physicalRootIdentity,
              retryState.bindProviderRegistration(
                  failedStoreIdentity: failedStore.storeIdentity,
                  ownerIdentity: context.ownerIdentity,
                  physicalRootIdentity: physicalRootIdentity
              ) else {
            throw IOSFailedHistoryError.repositoryIdentityConflict
        }
        pendingStore = IOSPendingRecordingStore(
            journal: pendingJournal,
            audioFileSystem: audio,
            operationGate: context.operationGate,
            liveOwnerRegistry: context.pendingRecordingLiveOwnerRegistry,
            failedHistoryRetryState: retryState,
            capabilityOwnerIdentity: context.ownerIdentity,
            storeIdentity: context.pendingRecordingStoreIdentity,
            repositoryGuard: context.repositoryGuard,
            failedHistoryMutationInterlock:
                context.failedHistoryMutationInterlock,
            failedOwnershipInspector: failedStore
        )
    }

    deinit { try? FileManager.default.removeItem(at: rootURL) }

    func install(row: IOSFailedHistoryEntry) throws {
        failedFileSystem.install(
            try IOSFailedHistoryWireCodec.encode(
                IOSFailedHistoryEnvelope(
                    revision: 1,
                    entries: [row],
                    audioCleanup: []
                )
            )
        )
    }

    func policyReceipt() async throws -> IOSHistoryPolicyReceipt {
        let state = try IOSHistoryPolicyState(
            revision: 1,
            historyEnabled: true,
            policyGeneration: 1
        )
        return try await IOSHistoryPolicyStore(
            journal: RetryAudioPolicyJournal(state: state),
            capabilityOwnerIdentity: ownerIdentity
        ).confirm(expected: IOSHistoryPolicyExpectation(state: state))
    }

    func prepareAudioAndDispatch(
        row: IOSFailedHistoryEntry
    ) async throws -> (
        source: IOSFailedHistoryRetryAudioSource,
        dispatchReceipt: IOSFailedHistoryRetryDispatchReceipt,
        registration: IOSFailedHistoryRetryProviderRegistration
    ) {
        let policy = try await policyReceipt()
        return try await gate.perform { lease in
            let reservationAuthorization = try
                retryAudioReservationAuthorization(
                    try await self.failedStore.prepareRetryReservation(
                        attemptID: row.attemptID,
                        transcriptionConfiguration: .defaults,
                        using: policy,
                        operationLeaseAuthorization: lease
                    )
                )
            let source = try await self.pendingStore
                .acquireValidatedFailedHistoryRetryAudio(
                    using: reservationAuthorization,
                    operationLeaseAuthorization: lease
                )
            let reservationReceipt = try await self.failedStore
                .commitRetryReservation(
                    using: reservationAuthorization,
                    validatedAudio: source.validationReceipt
                )
            let dispatchAuthorization = try
                retryAudioDispatchAuthorization(
                    try await self.failedStore.prepareRetryDispatch(
                        using: reservationReceipt,
                        operationLeaseAuthorization: lease
                    )
                )
            let dispatchReceipt = try await self.failedStore.commitRetryDispatch(
                using: dispatchAuthorization
            )
            let registration = try #require(
                await self.retryState.registerLiveOwner(
                    dispatchReceipt.liveOwnerToken
                )
            )
            return (source, dispatchReceipt, registration)
        }
    }
}

private final class RetryAudioPendingJournal:
    IOSPendingRecordingJournalStoring,
    @unchecked Sendable {
    private let lock = NSLock()
    private var storedRecording: IOSPendingRecording?
    private var storedRevision: UInt64 = 1
    private var storedLoadCount = 0

    var recording: IOSPendingRecording? {
        get { lock.withLock { storedRecording } }
        set {
            lock.withLock {
                storedRecording = newValue
                storedRevision &+= 1
            }
        }
    }

    var loadCount: Int { lock.withLock { storedLoadCount } }

    func resetLoadCount() {
        lock.withLock { storedLoadCount = 0 }
    }

    func load() throws -> IOSPendingRecording? {
        lock.withLock { storedRecording }
    }

    func loadMetadataSnapshot(
        authorization: IOSPendingRecordingMetadataRetirementAuthorization
    ) throws -> IOSPendingRecordingJournalMetadataSnapshot? {
        _ = authorization
        return lock.withLock {
            storedLoadCount += 1
            return storedRecording.map {
                IOSPendingRecordingJournalMetadataSnapshot(
                    testingRecording: $0,
                    testingRevision: storedRevision
                )
            }
        }
    }

    func create(_ recording: IOSPendingRecording) throws {
        _ = recording
        throw IOSPendingRecordingError.journalWriteFailed
    }

    func replace(
        _ recording: IOSPendingRecording,
        expected: IOSPendingRecording
    ) throws {
        _ = recording
        _ = expected
        throw IOSPendingRecordingError.journalWriteFailed
    }

    func remove(expected: IOSPendingRecording) throws -> Bool {
        _ = expected
        throw IOSPendingRecordingError.journalRemoveFailed
    }
}

private final class RetryAudioFileSystem:
    IOSPendingRecordingAudioFileSystem,
    @unchecked Sendable {
    private let lock = NSLock()
    private var storedAcquireCount = 0
    private var storedReleaseCount = 0
    private var storedNamespaceValidationCount = 0
    private var storedOnAcquire: (@Sendable () -> Void)?

    var acquireCount: Int { lock.withLock { storedAcquireCount } }
    var releaseCount: Int { lock.withLock { storedReleaseCount } }
    var namespaceValidationCount: Int {
        lock.withLock { storedNamespaceValidationCount }
    }

    func resetCounts() {
        lock.withLock {
            storedAcquireCount = 0
            storedReleaseCount = 0
            storedNamespaceValidationCount = 0
        }
    }

    func onAcquire(_ operation: @escaping @Sendable () -> Void) {
        lock.withLock { storedOnAcquire = operation }
    }

    func requireEmptyNamespace() async throws {}

    func validateProtectedAudioNamespace(
        _ inventory: IOSProtectedAudioNamespaceInventory
    ) async throws {
        _ = inventory
        lock.withLock { storedNamespaceValidationCount += 1 }
    }

    func validateProtectedAudioNamespace(
        _ inventory: IOSProtectedAudioNamespaceInventory,
        holding audioLeases:
            [any IOSPendingRecordingPublishedAudioLease]
    ) async throws {
        _ = inventory
        _ = audioLeases
        lock.withLock { storedNamespaceValidationCount += 1 }
    }

    func reconcileProtectedAudioCleanup(
        using authorization:
            IOSPendingRecordingProtectedAudioCleanupAuthorization
    ) async throws -> IOSPendingRecordingProtectedAudioCleanupEvidence {
        _ = authorization
        throw IOSPendingRecordingError.audioRemoveFailed
    }

    func publishProtectedCopy(
        from source: AudioRecordingArtifact,
        attemptID: UUID,
        format: IOSPendingRecordingAudioFormat,
        durationMilliseconds: Int64
    ) async throws -> any IOSPendingRecordingPublishedAudioLease {
        _ = source
        _ = attemptID
        _ = format
        _ = durationMilliseconds
        throw IOSPendingRecordingError.audioPublicationFailed
    }

    func publishProtectedCopy(
        from source: AudioRecordingArtifact,
        attemptID: UUID,
        format: IOSPendingRecordingAudioFormat,
        durationMilliseconds: Int64,
        inventory: IOSProtectedAudioNamespaceInventory
    ) async throws -> any IOSPendingRecordingPublishedAudioLease {
        _ = source
        _ = attemptID
        _ = format
        _ = durationMilliseconds
        _ = inventory
        throw IOSPendingRecordingError.audioPublicationFailed
    }

    func validatePublishedAudio(
        relativeIdentifier: String,
        attemptID: UUID,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) async throws -> AudioRecordingArtifact {
        _ = attemptID
        return AudioRecordingArtifact(
            fileURL: URL(
                fileURLWithPath: "/protected/\(relativeIdentifier)"
            ),
            duration: TimeInterval(durationMilliseconds) / 1_000,
            byteCount: byteCount
        )
    }

    func acquireValidatedPublishedAudio(
        relativeIdentifier: String,
        attemptID: UUID,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) async throws -> any IOSPendingRecordingPublishedAudioLease {
        let artifact = try await validatePublishedAudio(
            relativeIdentifier: relativeIdentifier,
            attemptID: attemptID,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount
        )
        let onAcquire = lock.withLock {
            storedAcquireCount += 1
            defer { storedOnAcquire = nil }
            return storedOnAcquire
        }
        onAcquire?()
        return RetryAudioLease(
            relativeIdentifier: relativeIdentifier,
            audioArtifact: artifact,
            durationMilliseconds: durationMilliseconds,
            onRelease: { [weak self] in
                guard let self else { return }
                self.lock.withLock { self.storedReleaseCount += 1 }
            }
        )
    }

    func removePublishedAudioIfPresent(
        relativeIdentifier: String,
        attemptID: UUID,
        expectedByteCount: Int64
    ) async throws -> Bool {
        _ = relativeIdentifier
        _ = attemptID
        _ = expectedByteCount
        throw IOSPendingRecordingError.audioRemoveFailed
    }
}

private final class RetryAudioLease:
    IOSPendingRecordingPublishedAudioLease,
    @unchecked Sendable {
    let relativeIdentifier: String
    let audioArtifact: AudioRecordingArtifact
    let durationMilliseconds: Int64

    private let lock = NSLock()
    private let onRelease: @Sendable () -> Void
    private var released = false

    init(
        relativeIdentifier: String,
        audioArtifact: AudioRecordingArtifact,
        durationMilliseconds: Int64,
        onRelease: @escaping @Sendable () -> Void
    ) {
        self.relativeIdentifier = relativeIdentifier
        self.audioArtifact = audioArtifact
        self.durationMilliseconds = durationMilliseconds
        self.onRelease = onRelease
    }

    func revalidate() async throws -> AudioRecordingArtifact {
        guard !lock.withLock({ released }) else {
            throw IOSPendingRecordingAudioFileSystemError.operationCancelled
        }
        return audioArtifact
    }

    func read(
        atOffset offset: Int64,
        maximumByteCount: Int
    ) async throws -> Data {
        guard !lock.withLock({ released }),
              offset >= 0,
              offset <= audioArtifact.byteCount,
              maximumByteCount > 0 else {
            throw IOSPendingRecordingAudioFileSystemError
                .protectedAudioInvalid
        }
        return Data(
            repeating: 0x52,
            count: min(
                maximumByteCount,
                Int(audioArtifact.byteCount - offset)
            )
        )
    }

    func release() {
        let shouldRelease = lock.withLock {
            guard !released else { return false }
            released = true
            return true
        }
        if shouldRelease { onRelease() }
    }
}

private final class RetryAudioPolicyJournal:
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
