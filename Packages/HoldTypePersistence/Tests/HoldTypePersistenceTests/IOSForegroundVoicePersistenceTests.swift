import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSForegroundVoicePersistenceTests {
    @Test func namedPreparationSealsTheAppOnlyPolicyAndRedactsText()
        throws {
        let preparation = try makeForegroundPreparation(
            rawAcceptedText: "  accepted text  "
        )

        #expect(preparation.deliveryPreparation.acceptedText == "accepted text")
        #expect(
            !preparation.deliveryPreparation
                .automaticInsertionPreferenceEnabled
        )
        #expect(preparation.deliveryPreparation.historyWrite == nil)
        #expect(preparation.deliveryPreparation.historyCapture == nil)
        #expect(
            String(describing: preparation)
                == "IOSForegroundVoiceAcceptedOutputPreparation(redacted)"
        )
        #expect(preparation.customMirror.children.isEmpty)
    }

    @Test func happyPathCommitsGenerationZeroThenRetiresExactPending()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)

        let result = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        )
        let record = try result.requireReady()

        #expect(record.deliveryState == .pending)
        #expect(record.publicationGeneration == 0)
        #expect(!record.automaticInsertionPreferenceEnabled)
        #expect(record.historyWrite == nil)
        #expect(record.failedRetryID == nil)
        #expect(fixture.pendingJournal.recording == nil)
        #expect(!fixture.audio.isPresent)
        #expect(fixture.executor.callCount == 1)
        #expect(
            try await fixture.facade.loadLatestResult()
                == .resultReady(record)
        )
    }

    @Test func invisibleDeliveryFailureBecomesSavingAndRetriesWithoutProvider()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        fixture.deliveryJournal.failNextCreate(
            .writeFailed,
            commitBeforeThrowing: false
        )

        let first = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        )
        let saving = try first.requireSaving()
        #expect(fixture.pendingJournal.recording == output)
        #expect(fixture.audio.isPresent)
        #expect(fixture.deliveryJournal.record == nil)
        #expect(
            try await fixture.facade.loadLatestResult()
                == .savingResult(saving)
        )

        let retried = try await fixture.facade.retrySavingResult(
            expected: saving
        )
        _ = try retried.requireReady()
        #expect(fixture.executor.callCount == 1)
        #expect(fixture.pendingJournal.recording == nil)
        #expect(!fixture.audio.isPresent)
    }

    @Test func visibleUncertainDeliveryCommitReconcilesIdenticalBytes()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        fixture.deliveryJournal.failNextCreate(
            .commitUncertain,
            commitBeforeThrowing: true
        )

        let first = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        )
        let saving = try first.requireSaving()
        #expect(fixture.deliveryJournal.record?.acceptedText == "accepted")
        #expect(fixture.pendingJournal.recording == output)

        let retried = try await fixture.facade.retrySavingResult(
            expected: saving
        )
        _ = try retried.requireReady()
        #expect(fixture.deliveryJournal.createCallCount == 1)
        #expect(fixture.executor.callCount == 1)
    }

    @Test func audioRemovalFailureCannotFallBackToProviderRecovery()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        fixture.audio.failNextRemove = .removeFailed

        let first = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        )
        let saving = try first.requireSaving()
        #expect(fixture.pendingJournal.recording == output)
        #expect(fixture.deliveryJournal.record?.acceptedText == "accepted")

        await #expect(throws: IOSAcceptedOutputDeliveryError.invalidTransition) {
            _ = try await fixture.facade
                .recoverRecordingFromSavingResult(expected: saving)
        }

        _ = try await fixture.facade.retrySavingResult(expected: saving)
            .requireReady()
        #expect(fixture.executor.callCount == 1)
    }

    @Test func journalRetirementFailureRetriesOnlyLocalCheckpoints()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        fixture.pendingJournal.failNextRemove(
            .journalRemoveFailed,
            commitBeforeThrowing: false
        )

        let first = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        )
        let saving = try first.requireSaving()
        #expect(fixture.pendingJournal.recording == output)
        #expect(!fixture.audio.isPresent)

        _ = try await fixture.facade.retrySavingResult(expected: saving)
            .requireReady()
        #expect(fixture.pendingJournal.removeCallCount == 2)
        #expect(fixture.executor.callCount == 1)
    }

    @Test func processSharedStateLetsAnotherSceneRetryTheSameWork()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        fixture.audio.failNextRemove = .removeFailed
        let saving = try await fixture.facade.accept(
            try fixture.preparation(for: output),
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        ).requireSaving()

        let secondSceneFacade = fixture.makeAdditionalFacade()
        _ = try await secondSceneFacade.retrySavingResult(
            expected: saving
        ).requireReady()
        #expect(fixture.pendingJournal.recording == nil)
        #expect(fixture.executor.callCount == 1)
    }

    @Test func uncertainJournalRemovalThatAlreadyCommittedReconcilesAbsence()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        fixture.pendingJournal.failNextRemove(
            .journalRemoveFailed,
            commitBeforeThrowing: true
        )

        let first = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        )
        let saving = try first.requireSaving()
        #expect(fixture.pendingJournal.recording == nil)
        #expect(!fixture.audio.isPresent)

        _ = try await fixture.facade.retrySavingResult(expected: saving)
            .requireReady()
        #expect(fixture.executor.callCount == 1)
    }

    @Test func exactNoDestinationRecoveryMovesOutputToAwaitingRecovery()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        fixture.deliveryJournal.failNextCreate(
            .commitUncertain,
            commitBeforeThrowing: false
        )

        let first = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        )
        let saving = try first.requireSaving()
        let recovered = try await fixture.facade
            .recoverRecordingFromSavingResult(expected: saving)

        #expect(recovered.phase == .awaitingRecovery)
        #expect(recovered.transcriptionID == nil)
        #expect(recovered.attemptID == output.attemptID)
        #expect(recovered.audioRelativeIdentifier == output.audioRelativeIdentifier)
        #expect(fixture.audio.isPresent)
        #expect(fixture.deliveryJournal.record == nil)
        #expect(fixture.executor.callCount == 1)
        await #expect(throws: IOSForegroundVoicePersistenceError.noSavingResult) {
            _ = try await fixture.facade.retrySavingResult(expected: saving)
        }
    }

    @Test func noDestinationRecoveryPreservesLegitimateRetryIdentityReuse()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let sessionID = UUID()
        let attemptID = UUID()
        let firstOutput = try await fixture.makeOutputDelivery(
            attemptID: attemptID,
            transcriptionID: UUID()
        )
        let first = try await fixture.facade.accept(
            try makeForegroundPreparation(
                sessionID: sessionID,
                attemptID: attemptID,
                transcriptID: try #require(firstOutput.transcriptionID),
                rawAcceptedText: "first"
            ),
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: firstOutput
            )
        ).requireReady()

        let secondOutput = try await fixture.makeOutputDelivery(
            attemptID: attemptID,
            transcriptionID: UUID()
        )
        let secondPreparation = try makeForegroundPreparation(
            sessionID: sessionID,
            attemptID: attemptID,
            transcriptID: try #require(secondOutput.transcriptionID),
            rawAcceptedText: "second"
        )
        fixture.deliveryJournal.failNextReplace(
            .commitUncertain,
            commitBeforeThrowing: false
        )
        let saving = try await fixture.facade.accept(
            secondPreparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: secondOutput
            )
        ).requireSaving()

        let recovered = try await fixture.facade
            .recoverRecordingFromSavingResult(expected: saving)
        #expect(recovered.phase == .awaitingRecovery)
        #expect(fixture.deliveryJournal.record == first)
        #expect(fixture.audio.isPresent)
        #expect(fixture.executor.callCount == 2)
    }

    @Test func recoveryReconcilesAVisibleUncertainAwaitingRecoveryCommit()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        fixture.deliveryJournal.failNextCreate(
            .writeFailed,
            commitBeforeThrowing: false
        )
        let first = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        )
        let saving = try first.requireSaving()
        fixture.pendingJournal.failNextReplace(
            .journalCommitUncertain,
            commitBeforeThrowing: true
        )

        await #expect(throws: IOSPendingRecordingError.journalCommitUncertain) {
            _ = try await fixture.facade
                .recoverRecordingFromSavingResult(expected: saving)
        }
        #expect(fixture.pendingJournal.recording?.phase == .awaitingRecovery)

        let recovered = try await fixture.facade
            .recoverRecordingFromSavingResult(expected: saving)
        #expect(recovered.phase == .awaitingRecovery)
        #expect(recovered.transcriptionID == nil)
    }

    @Test func loadAndCASClearExposeOnlyTheAppOnlyLatestResult()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        let accepted = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        ).requireReady()

        let stale = try IOSAcceptedOutputDeliveryRecord(
            revision: accepted.revision + 1,
            deliveryID: accepted.deliveryID,
            sessionID: accepted.sessionID,
            attemptID: accepted.attemptID,
            transcriptID: accepted.transcriptID,
            acceptedText: accepted.acceptedText,
            outputIntent: accepted.outputIntent,
            createdAt: accepted.createdAt,
            updatedAt: accepted.updatedAt,
            expiresAt: accepted.expiresAt,
            deliveryState: accepted.deliveryState,
            automaticInsertionPreferenceEnabled: false,
            keepLatestResult: accepted.keepLatestResult,
            publicationGeneration: 0,
            historyWrite: nil
        )
        await #expect(
            throws: IOSAcceptedOutputDeliveryError.compareAndSwapFailed
        ) {
            _ = try await fixture.facade.clearLatestResult(
                expected: IOSAcceptedOutputDeliveryExpectation(record: stale)
            )
        }

        #expect(
            try await fixture.facade.clearLatestResult(
                expected: IOSAcceptedOutputDeliveryExpectation(
                    record: accepted
                )
            ) == .cleared
        )
        #expect(try await fixture.facade.loadLatestResult() == .absent)
    }

    @Test func confirmedClearTombstoneHidesTextWhileCleanupRetries()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let accepted = try await fixture.facade.accept(
            try fixture.preparation(for: output),
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        ).requireReady()
        fixture.deliveryJournal.removeError = .removeFailed

        #expect(
            try await fixture.facade.clearLatestResult(
                expected: IOSAcceptedOutputDeliveryExpectation(
                    record: accepted
                )
            ) == .clearedCleanupPending
        )
        #expect(fixture.deliveryJournal.record?.deliveryState == .discarded)
        #expect(fixture.deliveryJournal.record?.acceptedText == nil)
        #expect(
            try await fixture.facade.loadLatestResult()
                == .clearedCleanupPending
        )
    }

    @Test func clearIsBlockedUntilExactPendingRetirementFinishes()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let output = try await fixture.makeOutputDelivery()
        let preparation = try fixture.preparation(for: output)
        fixture.audio.failNextRemove = .removeFailed
        let saving = try await fixture.facade.accept(
            preparation,
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: output
            )
        ).requireSaving()
        let delivery = try #require(fixture.deliveryJournal.record)

        await #expect(
            throws: IOSForegroundVoicePersistenceError.savingResultPending
        ) {
            _ = try await fixture.facade.clearLatestResult(
                expected: IOSAcceptedOutputDeliveryExpectation(
                    record: delivery
                )
            )
        }
        _ = try await fixture.facade.retrySavingResult(expected: saving)
            .requireReady()
    }

    @Test func replacementIsAtomicAndKeepsOnlyTheNewP4Result()
        async throws {
        let fixture = ForegroundVoicePersistenceFixture()
        let firstOutput = try await fixture.makeOutputDelivery()
        let first = try await fixture.facade.accept(
            try fixture.preparation(
                for: firstOutput,
                acceptedText: "first"
            ),
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: firstOutput
            )
        ).requireReady()

        let secondOutput = try await fixture.makeOutputDelivery()
        let second = try await fixture.facade.accept(
            try fixture.preparation(
                for: secondOutput,
                acceptedText: "second"
            ),
            expectedPending: IOSPendingRecordingCASExpectation(
                recording: secondOutput
            )
        ).requireReady()

        #expect(first.deliveryID != second.deliveryID)
        #expect(second.acceptedText == "second")
        #expect(fixture.deliveryJournal.record == second)
        #expect(!fixture.deliveryJournal.replacedWithDiscardedBeforeLatest)
        #expect(fixture.executor.callCount == 2)
    }

    @Test func resultAndErrorsAreContentFreeInDescriptions() throws {
        let preparation = try makeForegroundPreparation(
            rawAcceptedText: "P4-SENSITIVE-CANARY"
        )
        let expectation = IOSForegroundVoiceSavingResultExpectation(
            preparation: preparation.deliveryPreparation
        )
        let result = IOSForegroundVoiceAcceptanceResult.savingResult(
            expectation
        )

        #expect(!String(describing: expectation).contains("P4-SENSITIVE"))
        #expect(!String(reflecting: result).contains("P4-SENSITIVE"))
        #expect(result.customMirror.children.isEmpty)
        let fixture = ForegroundVoicePersistenceFixture()
        #expect(
            String(describing: fixture.facade)
                == "IOSForegroundVoicePersistence(redacted)"
        )
        #expect(fixture.facade.customMirror.children.isEmpty)
        #expect(
            String(describing: IOSForegroundVoicePersistenceError
                .localRecoveryPending)
                == "IOSForegroundVoicePersistenceError(redacted)"
        )
    }
}

private extension IOSForegroundVoiceAcceptanceResult {
    func requireReady() throws -> IOSAcceptedOutputDeliveryRecord {
        guard case .resultReady(let record) = self else {
            throw ForegroundVoiceTestError.unexpectedResult
        }
        return record
    }

    func requireSaving() throws
        -> IOSForegroundVoiceSavingResultExpectation {
        guard case .savingResult(let expectation) = self else {
            throw ForegroundVoiceTestError.unexpectedResult
        }
        return expectation
    }
}

private enum ForegroundVoiceTestError: Error {
    case unexpectedResult
}

private func makeForegroundPreparation(
    deliveryID: UUID = UUID(),
    sessionID: UUID = UUID(),
    attemptID: UUID = UUID(),
    transcriptID: UUID = UUID(),
    rawAcceptedText: String = "accepted",
    outputIntent: DictationOutputIntent = .standard
) throws -> IOSForegroundVoiceAcceptedOutputPreparation {
    try IOSForegroundVoiceAcceptedOutputPreparation(
        deliveryID: deliveryID,
        sessionID: sessionID,
        attemptID: attemptID,
        transcriptID: transcriptID,
        rawAcceptedText: rawAcceptedText,
        outputIntent: outputIntent,
        keepLatestResult: true
    )
}

private final class ForegroundVoicePersistenceFixture: @unchecked Sendable {
    let operationGate = IOSPersistenceOperationGate()
    let ownerIdentity = IOSAcceptedHistoryCapabilityOwnerIdentity()
    let pendingJournal = ForegroundVoicePendingJournal()
    let audio = ForegroundVoiceAudioFileSystem()
    let deliveryJournal = ForegroundVoiceDeliveryJournal()
    let executor = ForegroundVoiceExecutor()
    let state = IOSForegroundVoicePersistenceOperationState()
    lazy var pendingStore = IOSPendingRecordingStore(
        journal: pendingJournal,
        audioFileSystem: audio,
        operationGate: operationGate,
        capabilityOwnerIdentity: ownerIdentity,
        now: { Date(timeIntervalSince1970: 1_800_000_000) }
    )
    lazy var deliveryStore = IOSAcceptedOutputDeliveryStore(
        journal: deliveryJournal,
        now: { Date(timeIntervalSince1970: 1_800_000_000) },
        monotonicNowNanoseconds: { 0 },
        capabilityOwnerIdentity: ownerIdentity,
        operationGateIdentity: operationGate.identity
    )
    lazy var facade = IOSForegroundVoicePersistence(
        operationGate: operationGate,
        pendingRecordingStore: pendingStore,
        deliveryStore: deliveryStore,
        state: state
    )

    private var sequence: UInt8 = 1

    func makeOutputDelivery(
        outputIntent: DictationOutputIntent = .standard,
        attemptID suppliedAttemptID: UUID? = nil,
        transcriptionID suppliedTranscriptionID: UUID? = nil
    ) async throws -> IOSPendingRecording {
        let value = sequence
        sequence &+= 1
        let attemptID = suppliedAttemptID ?? UUID(
            uuid: (
                value, 0, 0, 0, 0, 0x40, 0x40, 0x40,
                0x80, 0, 0, 0, 0, 0, 0, value
            )
        )
        let transcriptionID = suppliedTranscriptionID ?? UUID(
            uuid: (
                value, 1, 0, 0, 0, 0x40, 0x40, 0x40,
                0x80, 0, 0, 0, 0, 0, 1, value
            )
        )
        let pending = try await pendingStore.prepare(
            IOSPendingRecordingPreparation(
                attemptID: attemptID,
                sourceArtifact: AudioRecordingArtifact(
                    fileURL: URL(
                        fileURLWithPath: "/runtime/\(value).m4a"
                    ),
                    duration: 1.25,
                    byteCount: 32
                ),
                initialState: .readyForTranscription,
                outputIntent: outputIntent,
                transcriptionConfiguration: TranscriptionConfiguration(
                    model: "gpt-4o-transcribe",
                    language: .english
                )
            )
        )
        let handoff = try await pendingStore.beginTranscription(
            expected: IOSPendingRecordingCASExpectation(recording: pending),
            transcriptionID: transcriptionID
        )
        _ = try await handoff.execute(using: executor)
        let postProcessing = try await pendingStore.markPostProcessing(
            expected: IOSPendingRecordingCASExpectation(
                recording: try #require(
                    pendingJournal.recording
                )
            )
        )
        return try await pendingStore.markOutputDelivery(
            expected: IOSPendingRecordingCASExpectation(
                recording: postProcessing
            )
        )
    }

    func preparation(
        for pending: IOSPendingRecording,
        acceptedText: String = "accepted"
    ) throws -> IOSForegroundVoiceAcceptedOutputPreparation {
        try makeForegroundPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: pending.attemptID,
            transcriptID: try #require(pending.transcriptionID),
            rawAcceptedText: acceptedText,
            outputIntent: pending.outputIntent
        )
    }

    func makeAdditionalFacade() -> IOSForegroundVoicePersistence {
        IOSForegroundVoicePersistence(
            operationGate: operationGate,
            pendingRecordingStore: pendingStore,
            deliveryStore: deliveryStore,
            state: state
        )
    }
}

private final class ForegroundVoiceExecutor:
    IOSPendingTranscriptionExecutor,
    @unchecked Sendable {
    private let lock = NSLock()
    private var storedCallCount = 0

    var callCount: Int { lock.withLock { storedCallCount } }

    func transcribe(
        recording: IOSPendingRecording,
        audio: IOSPendingTranscriptionAudio
    ) async throws -> String {
        _ = recording
        _ = audio
        lock.withLock { storedCallCount += 1 }
        return "provider result"
    }
}

private final class ForegroundVoicePendingJournal:
    IOSPendingRecordingJournalStoring,
    @unchecked Sendable {
    private struct Failure {
        let error: IOSPendingRecordingError
        let commits: Bool
    }

    private let lock = NSLock()
    private var storedRecording: IOSPendingRecording?
    private var revision: UInt64 = 1
    private var nextReplaceFailure: Failure?
    private var nextRemoveFailure: Failure?
    private var storedRemoveCallCount = 0

    var recording: IOSPendingRecording? {
        lock.withLock { storedRecording }
    }
    var removeCallCount: Int { lock.withLock { storedRemoveCallCount } }

    func failNextReplace(
        _ error: IOSPendingRecordingError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            nextReplaceFailure = Failure(
                error: error,
                commits: commitBeforeThrowing
            )
        }
    }

    func failNextRemove(
        _ error: IOSPendingRecordingError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            nextRemoveFailure = Failure(
                error: error,
                commits: commitBeforeThrowing
            )
        }
    }

    func load() throws -> IOSPendingRecording? {
        lock.withLock { storedRecording }
    }

    func loadMetadataSnapshot(
        authorization: IOSPendingRecordingMetadataRetirementAuthorization
    ) throws -> IOSPendingRecordingJournalMetadataSnapshot? {
        _ = authorization
        return lock.withLock {
            storedRecording.map {
                IOSPendingRecordingJournalMetadataSnapshot(
                    testingRecording: $0,
                    testingRevision: revision
                )
            }
        }
    }

    func create(_ recording: IOSPendingRecording) throws {
        try lock.withLock {
            guard storedRecording == nil else {
                throw IOSPendingRecordingError.pendingSlotOccupied
            }
            storedRecording = recording
            revision &+= 1
        }
    }

    func replace(
        _ recording: IOSPendingRecording,
        expected: IOSPendingRecording
    ) throws {
        try lock.withLock {
            guard storedRecording == expected else {
                throw IOSPendingRecordingError.compareAndSwapFailed
            }
            if let failure = nextReplaceFailure {
                nextReplaceFailure = nil
                if failure.commits {
                    storedRecording = recording
                    revision &+= 1
                }
                throw failure.error
            }
            storedRecording = recording
            revision &+= 1
        }
    }

    func remove(expected: IOSPendingRecording) throws -> Bool {
        try lock.withLock {
            storedRemoveCallCount += 1
            guard let storedRecording else { return false }
            guard storedRecording == expected else {
                throw IOSPendingRecordingError.compareAndSwapFailed
            }
            if let failure = nextRemoveFailure {
                nextRemoveFailure = nil
                if failure.commits {
                    self.storedRecording = nil
                    revision &+= 1
                }
                throw failure.error
            }
            self.storedRecording = nil
            revision &+= 1
            return true
        }
    }
}

private final class ForegroundVoiceAudioFileSystem:
    IOSPendingRecordingAudioFileSystem,
    @unchecked Sendable {
    private let lock = NSLock()
    private var present = false
    private var relativeIdentifier: String?
    private var byteCount: Int64 = 0
    private var durationMilliseconds: Int64 = 0
    private var storedFailNextRemove:
        IOSPendingRecordingAudioFileSystemError?

    var isPresent: Bool { lock.withLock { present } }
    var failNextRemove: IOSPendingRecordingAudioFileSystemError? {
        get { lock.withLock { storedFailNextRemove } }
        set { lock.withLock { storedFailNextRemove = newValue } }
    }

    func requireEmptyNamespace() async throws {
        guard !isPresent else {
            throw IOSPendingRecordingAudioFileSystemError.namespaceNotEmpty
        }
    }

    func validateProtectedAudioNamespace(
        _ inventory: IOSProtectedAudioNamespaceInventory
    ) async throws {
        _ = inventory
    }

    func reconcileProtectedAudioCleanup(
        using authorization:
            IOSPendingRecordingProtectedAudioCleanupAuthorization
    ) async throws -> IOSPendingRecordingProtectedAudioCleanupEvidence {
        IOSPendingRecordingProtectedAudioCleanupEvidence(
            testingAlreadyAbsent: authorization.cleanupAuthorization
        )
    }

    func publishProtectedCopy(
        from source: AudioRecordingArtifact,
        attemptID: UUID,
        format: IOSPendingRecordingAudioFormat,
        durationMilliseconds: Int64
    ) async throws -> any IOSPendingRecordingPublishedAudioLease {
        let identifier = IOSPendingRecordingStorageLocation
            .relativeAudioIdentifier(for: attemptID, format: format)
        lock.withLock {
            present = true
            relativeIdentifier = identifier
            byteCount = source.byteCount
            self.durationMilliseconds = durationMilliseconds
        }
        return ForegroundVoiceAudioLease(
            relativeIdentifier: identifier,
            durationMilliseconds: durationMilliseconds,
            byteCount: source.byteCount
        )
    }

    func publishProtectedCopy(
        from source: AudioRecordingArtifact,
        attemptID: UUID,
        format: IOSPendingRecordingAudioFormat,
        durationMilliseconds: Int64,
        inventory: IOSProtectedAudioNamespaceInventory
    ) async throws -> any IOSPendingRecordingPublishedAudioLease {
        _ = inventory
        return try await publishProtectedCopy(
            from: source,
            attemptID: attemptID,
            format: format,
            durationMilliseconds: durationMilliseconds
        )
    }

    func validatePublishedAudio(
        relativeIdentifier: String,
        attemptID: UUID,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) async throws -> AudioRecordingArtifact {
        _ = attemptID
        let valid = lock.withLock {
            present
                && self.relativeIdentifier == relativeIdentifier
                && self.byteCount == byteCount
                && self.durationMilliseconds == durationMilliseconds
        }
        guard valid else {
            throw IOSPendingRecordingAudioFileSystemError
                .protectedAudioMissing
        }
        return AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/protected/audio.m4a"),
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
        _ = try await validatePublishedAudio(
            relativeIdentifier: relativeIdentifier,
            attemptID: attemptID,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount
        )
        return ForegroundVoiceAudioLease(
            relativeIdentifier: relativeIdentifier,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount
        )
    }

    func removePublishedAudioIfPresent(
        relativeIdentifier: String,
        attemptID: UUID,
        expectedByteCount: Int64
    ) async throws -> Bool {
        _ = attemptID
        return try lock.withLock {
            if let error = storedFailNextRemove {
                storedFailNextRemove = nil
                throw error
            }
            guard present else { return false }
            guard self.relativeIdentifier == relativeIdentifier,
                  byteCount == expectedByteCount else {
                throw IOSPendingRecordingAudioFileSystemError.sourceChanged
            }
            present = false
            return true
        }
    }
}

private final class ForegroundVoiceAudioLease:
    IOSPendingRecordingPublishedAudioLease,
    @unchecked Sendable {
    let relativeIdentifier: String
    let audioArtifact: AudioRecordingArtifact
    let durationMilliseconds: Int64

    init(
        relativeIdentifier: String,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) {
        self.relativeIdentifier = relativeIdentifier
        self.durationMilliseconds = durationMilliseconds
        audioArtifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/protected/audio.m4a"),
            duration: TimeInterval(durationMilliseconds) / 1_000,
            byteCount: byteCount
        )
    }

    func revalidate() async throws -> AudioRecordingArtifact {
        audioArtifact
    }

    func read(
        atOffset offset: Int64,
        maximumByteCount: Int
    ) async throws -> Data {
        let count = min(
            maximumByteCount,
            max(0, Int(audioArtifact.byteCount - offset))
        )
        return Data(repeating: 0x41, count: count)
    }

    func release() {}
}

private final class ForegroundVoiceDeliveryJournal:
    IOSAcceptedOutputDeliveryJournalStoring,
    @unchecked Sendable {
    private struct Failure {
        let error: IOSAcceptedOutputDeliveryError
        let commits: Bool
    }

    private let lock = NSLock()
    private var snapshot: IOSAcceptedOutputDeliveryJournalSnapshot?
    private var revision: UInt64 = 1
    private var nextCreateFailure: Failure?
    private var nextReplacementFailure: Failure?
    private var storedCreateCallCount = 0
    private var storedReplacementRecords:
        [IOSAcceptedOutputDeliveryRecord] = []

    var removeError: IOSAcceptedOutputDeliveryError?
    var record: IOSAcceptedOutputDeliveryRecord? {
        lock.withLock { snapshot?.record }
    }
    var createCallCount: Int { lock.withLock { storedCreateCallCount } }
    var replacedWithDiscardedBeforeLatest: Bool {
        lock.withLock {
            guard storedReplacementRecords.count > 1 else { return false }
            return storedReplacementRecords.dropLast().contains(where: {
                $0.deliveryState == .discarded
            })
        }
    }

    func failNextCreate(
        _ error: IOSAcceptedOutputDeliveryError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            nextCreateFailure = Failure(
                error: error,
                commits: commitBeforeThrowing
            )
        }
    }

    func failNextReplace(
        _ error: IOSAcceptedOutputDeliveryError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            nextReplacementFailure = Failure(
                error: error,
                commits: commitBeforeThrowing
            )
        }
    }

    func load() throws -> IOSAcceptedOutputDeliveryJournalSnapshot? {
        lock.withLock { snapshot }
    }

    func loadOpaque() throws -> IOSAcceptedOutputDeliveryOpaqueSnapshot? {
        lock.withLock {
            snapshot.map {
                IOSAcceptedOutputDeliveryOpaqueSnapshot(
                    fileRevision: $0.fileRevision
                )
            }
        }
    }

    func create(
        _ record: IOSAcceptedOutputDeliveryRecord
    ) throws -> IOSAcceptedOutputDeliveryJournalSnapshot {
        try lock.withLock {
            storedCreateCallCount += 1
            guard snapshot == nil else {
                throw IOSAcceptedOutputDeliveryError.slotOccupied
            }
            if let failure = nextCreateFailure {
                nextCreateFailure = nil
                if failure.commits {
                    snapshot = makeSnapshot(record)
                }
                throw failure.error
            }
            let created = makeSnapshot(record)
            snapshot = created
            return created
        }
    }

    func replace(
        _ record: IOSAcceptedOutputDeliveryRecord,
        expected: IOSAcceptedOutputDeliveryJournalSnapshot
    ) throws -> IOSAcceptedOutputDeliveryJournalSnapshot {
        try lock.withLock {
            guard snapshot?.fileRevision == expected.fileRevision else {
                throw IOSAcceptedOutputDeliveryError.compareAndSwapFailed
            }
            storedReplacementRecords.append(record)
            if let failure = nextReplacementFailure {
                nextReplacementFailure = nil
                if failure.commits {
                    snapshot = makeSnapshot(record)
                }
                throw failure.error
            }
            let replacement = makeSnapshot(record)
            snapshot = replacement
            return replacement
        }
    }

    func remove(
        expected: IOSAcceptedOutputDeliveryJournalSnapshot
    ) throws {
        try lock.withLock {
            guard snapshot?.fileRevision == expected.fileRevision else {
                throw IOSAcceptedOutputDeliveryError.compareAndSwapFailed
            }
            if let removeError { throw removeError }
            snapshot = nil
        }
    }

    func removeOpaque(
        expected: IOSAcceptedOutputDeliveryOpaqueSnapshot
    ) throws {
        _ = expected
        lock.withLock { snapshot = nil }
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport {
        _ = now
        return .empty
    }

    private func makeSnapshot(
        _ record: IOSAcceptedOutputDeliveryRecord
    ) -> IOSAcceptedOutputDeliveryJournalSnapshot {
        defer { revision &+= 1 }
        return IOSAcceptedOutputDeliveryJournalSnapshot(
            record: record,
            fileRevision: IOSStrictProtectedRecordFileRevision(
                testingToken: revision
            )
        )
    }
}
