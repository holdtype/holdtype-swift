import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryAudioCleanupStoreTests {
    @Test func lifecycleRetiresOnlyCanonicalHeadInOneRevision() async throws {
        let fixture = try AudioCleanupStoreFixture()
        let rows = try [
            failedHistoryTestEntry(index: 301),
            failedHistoryTestEntry(index: 302),
        ]
        let tombstones = try (311...313).map {
            try failedHistoryTestAudioCleanup(index: $0)
        }
        try fixture.install(
            IOSFailedHistoryEnvelope(
                revision: 8,
                entries: IOSFailedHistoryValidation.sortedEntries(rows),
                audioCleanup: IOSFailedHistoryValidation.sortedAudioCleanup(
                    tombstones
                )
            )
        )

        try await fixture.gate.perform { lease in
            let authorization = try #require(
                try await fixture.store.prepareNextAudioCleanup(
                    operationLeaseAuthorization: lease
                )
            )
            #expect(authorization.tombstone == tombstones[0])
            #expect(authorization.purpose == .nextHead)
            #expect(fixture.mutationInterlock.isBlocked)
            #expect(
                try await fixture.store.hasRetainedAudioCleanup(
                    matching: authorization,
                    operationLeaseAuthorization: lease
                )
            )

            let receipt = try fixture.receipt(for: authorization)
            try await fixture.store.commitAudioCleanup(using: receipt)
            let completion = try await fixture.store.completeAudioCleanup(
                using: authorization,
                operationLeaseAuthorization: lease
            )
            #expect(
                fixture.mutationInterlock.clearAudioCleanup(
                    using: completion,
                    operationLeaseAuthorization: lease
                )
            )
        }

        let outcome = try #require(try await fixture.store.load())
        #expect(outcome.revision == 9)
        #expect(outcome.entries == IOSFailedHistoryValidation.sortedEntries(rows))
        #expect(outcome.audioCleanup == Array(tombstones.dropFirst()))
        #expect(
            fixture.failedFileSystem.events.filter { $0 == "replace" }.count
                == 1
        )
        #expect(!fixture.mutationInterlock.isBlocked)
    }

    @Test func explicitDeleteRetiresOnlyItsNonHeadTombstone() async throws {
        let fixture = try AudioCleanupStoreFixture()
        let existing = try [
            failedHistoryTestAudioCleanup(index: 321),
            failedHistoryTestAudioCleanup(index: 322),
        ]
        let selected = try failedHistoryTestEntry(index: 323)
        try fixture.install(
            IOSFailedHistoryEnvelope(
                revision: 4,
                entries: [selected],
                audioCleanup: existing
            )
        )

        let retained = try await fixture.gate.perform { lease in
            let deleteAuthorization = try await fixture.store.prepareDelete(
                attemptID: selected.attemptID,
                operationLeaseAuthorization: lease
            )
            let deleteReceipt = try await fixture.store.commitDelete(
                using: fixture.validatedAudio(for: deleteAuthorization)
            )
            let cleanupAuthorization = try await fixture.store
                .prepareAudioCleanup(
                    using: deleteReceipt,
                    operationLeaseAuthorization: lease
                )

            #expect(cleanupAuthorization.tombstone == deleteReceipt.tombstone)
            #expect(
                cleanupAuthorization.failedSource.envelope.audioCleanup.first
                    == existing[0]
            )
            #expect(
                cleanupAuthorization.purpose
                    == .explicitDelete(deleteReceipt)
            )
            return cleanupAuthorization
        }

        try await fixture.gate.perform { lease in
            #expect(
                !fixture.mutationInterlock.hasRetainedAudioCleanup(
                    using: retained,
                    operationLeaseAuthorization: lease
                )
            )
            let cleanupAuthorization = try #require(
                try await fixture.store.refreshAudioCleanupAuthorization(
                    retained,
                    operationLeaseAuthorization: lease
                )
            )
            #expect(cleanupAuthorization.operationID == retained.operationID)
            #expect(
                cleanupAuthorization.operationLeaseAuthorization
                    .provesSameActiveLease(as: lease)
            )
            #expect(
                fixture.mutationInterlock.hasRetainedAudioCleanup(
                    using: cleanupAuthorization,
                    operationLeaseAuthorization: lease
                )
            )
            try await fixture.store.commitAudioCleanup(
                using: fixture.receipt(for: cleanupAuthorization)
            )
            let completion = try await fixture.store.completeAudioCleanup(
                using: cleanupAuthorization,
                operationLeaseAuthorization: lease
            )
            #expect(
                fixture.mutationInterlock.clearAudioCleanup(
                    using: completion,
                    operationLeaseAuthorization: lease
                )
            )
        }

        let outcome = try #require(try await fixture.store.load())
        #expect(outcome.revision == 6)
        #expect(outcome.entries.isEmpty)
        #expect(outcome.audioCleanup == existing)
    }

    @Test func retirementUncertaintyReconcilesSourceAndOutcomeVisible()
        async throws {
        for outcomeVisible in [false, true] {
            let fixture = try AudioCleanupStoreFixture()
            let tombstone = try failedHistoryTestAudioCleanup(
                index: outcomeVisible ? 332 : 331
            )
            try fixture.install(
                IOSFailedHistoryEnvelope(
                    revision: 12,
                    entries: [try failedHistoryTestEntry(index: 330)],
                    audioCleanup: [tombstone]
                )
            )
            fixture.failedFileSystem.replaceFailure = .init(
                error: .commitUncertain,
                commitBeforeThrowing: outcomeVisible
            )

            let retained = try await fixture.gate.perform { lease in
                let authorization = try #require(
                    try await fixture.store.prepareNextAudioCleanup(
                        operationLeaseAuthorization: lease
                    )
                )
                await #expect(throws: IOSFailedHistoryError.commitUncertain) {
                    try await fixture.store.commitAudioCleanup(
                        using: fixture.receipt(for: authorization)
                    )
                }
                return authorization
            }
            #expect(fixture.mutationInterlock.isBlocked)

            try await fixture.gate.perform { lease in
                let refreshed = try await fixture.store
                    .refreshAudioCleanupAuthorization(
                        retained,
                        operationLeaseAuthorization: lease
                    )
                if outcomeVisible {
                    #expect(refreshed == nil)
                    try await fixture.store.reconcileAudioCleanupCommit(
                        receipt: nil,
                        operationLeaseAuthorization: lease
                    )
                } else {
                    let refreshed = try #require(refreshed)
                    await #expect(
                        throws: IOSFailedHistoryError.invalidTransition
                    ) {
                        try await fixture.store.reconcileAudioCleanupCommit(
                            receipt: nil,
                            operationLeaseAuthorization: lease
                        )
                    }
                    try await fixture.store.reconcileAudioCleanupCommit(
                        receipt: fixture.receipt(for: refreshed),
                        operationLeaseAuthorization: lease
                    )
                }
                let completion = try await fixture.store.completeAudioCleanup(
                    using: refreshed ?? retained,
                    operationLeaseAuthorization: lease
                )
                #expect(
                    fixture.mutationInterlock.clearAudioCleanup(
                        using: completion,
                        operationLeaseAuthorization: lease
                    )
                )
            }

            let outcome = try #require(try await fixture.store.load())
            #expect(outcome.revision == 13)
            #expect(outcome.audioCleanup.isEmpty)
            #expect(!fixture.mutationInterlock.isBlocked)
        }
    }

    @Test func definitiveWriteFailureRefreshesAndRetriesExactSource()
        async throws {
        let fixture = try AudioCleanupStoreFixture()
        let tombstone = try failedHistoryTestAudioCleanup(index: 341)
        try fixture.install(
            IOSFailedHistoryEnvelope(
                revision: 2,
                entries: [],
                audioCleanup: [tombstone]
            )
        )
        fixture.failedFileSystem.replaceFailure = .init(
            error: .writeFailed,
            commitBeforeThrowing: false
        )

        let retained = try await fixture.gate.perform { lease in
            let authorization = try #require(
                try await fixture.store.prepareNextAudioCleanup(
                    operationLeaseAuthorization: lease
                )
            )
            await #expect(throws: IOSFailedHistoryError.writeFailed) {
                try await fixture.store.commitAudioCleanup(
                    using: fixture.receipt(for: authorization)
                )
            }
            return authorization
        }
        #expect(fixture.mutationInterlock.isBlocked)

        try await fixture.gate.perform { lease in
            let refreshed = try #require(
                try await fixture.store.refreshAudioCleanupAuthorization(
                    retained,
                    operationLeaseAuthorization: lease
                )
            )
            try await fixture.store.commitAudioCleanup(
                using: fixture.receipt(
                    for: refreshed,
                    alreadyAbsent: true
                )
            )
            let completion = try await fixture.store.completeAudioCleanup(
                using: refreshed,
                operationLeaseAuthorization: lease
            )
            #expect(
                fixture.mutationInterlock.clearAudioCleanup(
                    using: completion,
                    operationLeaseAuthorization: lease
                )
            )
        }
        #expect((try await fixture.store.load())?.audioCleanup.isEmpty == true)
    }

    @Test func foreignAndStaleCleanupCapabilitiesFailClosedAndAreRedacted()
        async throws {
        let fixture = try AudioCleanupStoreFixture()
        let foreign = try AudioCleanupStoreFixture()
        try fixture.install(
            IOSFailedHistoryEnvelope(
                revision: 1,
                entries: [],
                audioCleanup: [
                    try failedHistoryTestAudioCleanup(index: 351),
                ]
            )
        )
        try foreign.install(
            IOSFailedHistoryEnvelope(
                revision: 1,
                entries: [],
                audioCleanup: [
                    try failedHistoryTestAudioCleanup(index: 352),
                ]
            )
        )

        let (retained, staleReceipt) = try await fixture.gate.perform { lease in
            let authorization = try #require(
                try await fixture.store.prepareNextAudioCleanup(
                    operationLeaseAuthorization: lease
                )
            )
            return (
                authorization,
                try fixture.receipt(for: authorization)
            )
        }
        try await foreign.gate.perform { foreignLease in
            let foreignAuthorization = try #require(
                try await foreign.store.prepareNextAudioCleanup(
                    operationLeaseAuthorization: foreignLease
                )
            )
            try await foreign.store.commitAudioCleanup(
                using: foreign.receipt(for: foreignAuthorization)
            )
            let foreignCompletion = try await foreign.store
                .completeAudioCleanup(
                    using: foreignAuthorization,
                    operationLeaseAuthorization: foreignLease
                )

            try await fixture.gate.perform { lease in
                await #expect(
                    throws: IOSFailedHistoryError.compareAndSwapFailed
                ) {
                    try await fixture.store.commitAudioCleanup(
                        using: staleReceipt
                    )
                }
                await #expect(
                    throws: IOSFailedHistoryError.commitUncertain
                ) {
                    _ = try await fixture.store
                        .refreshAudioCleanupAuthorization(
                            foreignAuthorization,
                            operationLeaseAuthorization: lease
                        )
                }
                #expect(
                    !fixture.mutationInterlock.clearAudioCleanup(
                        using: foreignCompletion,
                        operationLeaseAuthorization: lease
                    )
                )
                let refreshed = try #require(
                    try await fixture.store.refreshAudioCleanupAuthorization(
                        retained,
                        operationLeaseAuthorization: lease
                    )
                )
                #expect(String(describing: refreshed).contains("redacted"))
                #expect(
                    String(describing: refreshed.operationID)
                        .contains("redacted")
                )
                #expect(String(describing: refreshed.purpose).contains("redacted"))
                let receipt = try fixture.receipt(for: refreshed)
                #expect(String(describing: receipt).contains("redacted"))
                #expect(String(describing: receipt.outcome).contains("redacted"))

                try await fixture.store.commitAudioCleanup(using: receipt)
                let completion = try await fixture.store.completeAudioCleanup(
                    using: refreshed,
                    operationLeaseAuthorization: lease
                )
                #expect(String(describing: completion).contains("redacted"))
                #expect(
                    fixture.mutationInterlock.clearAudioCleanup(
                        using: completion,
                        operationLeaseAuthorization: lease
                    )
                )
            }
            #expect(
                foreign.mutationInterlock.clearAudioCleanup(
                    using: foreignCompletion,
                    operationLeaseAuthorization: foreignLease
                )
            )
        }
    }
}

private final class AudioCleanupStoreFixture: @unchecked Sendable {
    let context: IOSAcceptedHistoryCoordinatorProcessContext
    let gate: IOSPersistenceOperationGate
    let pendingStoreIdentity = IOSPendingRecordingStoreIdentity()
    let mutationInterlock = IOSFailedHistoryMutationInterlock()
    let failedFileSystem = FailedHistoryFakeFileSystem()
    let store: IOSFailedHistoryStore
    private let rootURL: URL

    init() throws {
        let now = try failedHistoryTestDate(
            offsetMilliseconds: 9_000_000
        )
        rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "failed-audio-cleanup-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: false
        )
        context = IOSAcceptedHistoryCoordinatorProcessContextRegistry.shared
            .context(for: rootURL)
        gate = context.operationGate
        store = IOSFailedHistoryStore(
            journal: FoundationIOSFailedHistoryJournalRepository(
                fileSystem: failedFileSystem
            ),
            capabilityOwnerIdentity: context.ownerIdentity,
            operationGateIdentity: gate.identity,
            expectedPendingStoreIdentity: pendingStoreIdentity,
            repositoryGuard: context.repositoryGuard,
            mutationInterlock: mutationInterlock,
            now: { now }
        )
    }

    deinit { try? FileManager.default.removeItem(at: rootURL) }

    func install(_ envelope: IOSFailedHistoryEnvelope) throws {
        failedFileSystem.install(try IOSFailedHistoryWireCodec.encode(envelope))
        failedFileSystem.resetEvents()
    }

    func receipt(
        for authorization: IOSFailedHistoryAudioCleanupAuthorization,
        alreadyAbsent: Bool = false
    ) throws -> IOSFailedHistoryAudioCleanupReceipt {
        let evidence = alreadyAbsent
            ? IOSPendingRecordingProtectedAudioCleanupEvidence(
                testingAlreadyAbsent: authorization
            )
            : IOSPendingRecordingProtectedAudioCleanupEvidence(
                testingRemoved: authorization
            )
        let outcome: IOSFailedHistoryAudioCleanupReceipt.Outcome =
            alreadyAbsent
                ? .alreadyAbsent(evidence: evidence)
                : .removed(evidence: evidence)
        return try #require(
            IOSFailedHistoryAudioCleanupReceipt(
                mint: IOSFailedHistoryAudioCleanupReceiptMint(
                    testingToken: ()
                ),
                issuerStoreIdentity: pendingStoreIdentity,
                authorization: authorization,
                outcome: outcome
            )
        )
    }

    func validatedAudio(
        for authorization: IOSFailedHistoryRowAudioValidationAuthorization
    ) throws -> IOSFailedHistoryValidatedRowAudio {
        try #require(
            IOSFailedHistoryValidatedRowAudio(
                testingAuthorization: authorization,
                audioLease: AudioCleanupTestLease(
                    row: authorization.candidate
                )
            )
        )
    }
}

private final class AudioCleanupTestLease:
    IOSPendingRecordingPublishedAudioLease,
    @unchecked Sendable {
    let relativeIdentifier: String
    let audioArtifact: AudioRecordingArtifact
    let durationMilliseconds: Int64

    init(row: IOSFailedHistoryEntry) {
        relativeIdentifier = row.audioRelativeIdentifier
        durationMilliseconds = row.durationMilliseconds
        audioArtifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/failed-audio-cleanup.m4a"),
            duration: Double(row.durationMilliseconds) / 1_000,
            byteCount: row.byteCount
        )
    }

    func revalidate() async throws -> AudioRecordingArtifact { audioArtifact }
    func read(atOffset: Int64, maximumByteCount: Int) async throws -> Data {
        _ = atOffset
        _ = maximumByteCount
        return Data()
    }
    func release() {}
}
