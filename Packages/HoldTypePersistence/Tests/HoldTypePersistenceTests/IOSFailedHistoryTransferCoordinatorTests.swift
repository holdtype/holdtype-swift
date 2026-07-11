import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryTransferCoordinatorTests {
    @Test func happyPathRetiresOnlyPendingMetadataAndPreservesExactAudio()
        async throws {
        let fixture = try FailedTransferCoordinatorFixture()
        let coordinator = fixture.makeCoordinator()
        try await fixture.establishEnabledPolicy(using: coordinator)
        let recording = try await fixture.prepareAwaitingRecoveryRecording()
        let audioIdentityBefore = try fixture.audioIdentity(for: recording)

        let result = try await coordinator.transferPendingRecordingFailure(
            expected: IOSPendingRecordingCASExpectation(recording: recording),
            failure: .recoverableNetworkFailure
        )

        #expect(result == .transferred)
        let envelope = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        let row = try #require(envelope.entries.first)
        #expect(envelope.revision == 2)
        #expect(envelope.entries.count == 1)
        #expect(row.attemptID == recording.attemptID)
        #expect(row.ownershipState == .ready)
        #expect(row.audioRelativeIdentifier == recording.audioRelativeIdentifier)
        #expect(row.byteCount == recording.byteCount)
        #expect(try fixture.rawPendingRecording() == nil)
        #expect(try fixture.audioIdentity(for: recording) == audioIdentityBefore)
    }

    @Test func relaunchReconcilesDurablePendingRetirementWithoutProviderWork()
        async throws {
        let fixture = try FailedTransferCoordinatorFixture()
        let coordinator = fixture.makeCoordinator()
        try await fixture.establishEnabledPolicy(using: coordinator)
        let recording = try await fixture.prepareAwaitingRecoveryRecording()
        let audioIdentityBefore = try fixture.audioIdentity(for: recording)

        try await fixture.stagePendingJournalRetirement(for: recording)

        let stagedEnvelope = try #require(
            try await fixture.context.failedHistoryStore.load()
        )
        #expect(stagedEnvelope.revision == 1)
        #expect(stagedEnvelope.entries.first?.ownershipState == .pendingJournalRetirement)
        #expect(try fixture.rawPendingRecording() == recording)

        let relaunchedRegistry =
            IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let relaunchedContext = relaunchedRegistry.context(
            for: fixture.applicationSupportDirectoryURL
        )
        let relaunchedCoordinator = fixture.makeCoordinator(
            context: relaunchedContext,
            registry: relaunchedRegistry
        )

        #expect(
            try await relaunchedCoordinator.reconcileFailedHistoryTransfer()
                == .reconciled
        )
        let recoveredEnvelope = try #require(
            try await relaunchedContext.failedHistoryStore.load()
        )
        #expect(recoveredEnvelope.revision == 2)
        #expect(recoveredEnvelope.entries.count == 1)
        #expect(recoveredEnvelope.entries.first?.ownershipState == .ready)
        #expect(try fixture.rawPendingRecording() == nil)
        #expect(try fixture.audioIdentity(for: recording) == audioIdentityBefore)
    }

    @Test func readyTerminalRequiresPendingAbsenceAndPreservesRecreatedConflict()
        async throws {
        let absent = try FailedTransferCoordinatorFixture()
        let absentCoordinator = absent.makeCoordinator()
        try await absent.establishEnabledPolicy(using: absentCoordinator)
        let absentRecording = try await absent
            .prepareAwaitingRecoveryRecording()
        #expect(
            try await absentCoordinator.transferPendingRecordingFailure(
                expected: IOSPendingRecordingCASExpectation(
                    recording: absentRecording
                ),
                failure: .recoverableNetworkFailure
            ) == .transferred
        )
        #expect(
            try await absent.makeCoordinator()
                .reconcileFailedHistoryTransfer() == .noWork
        )

        let present = try FailedTransferCoordinatorFixture()
        let presentCoordinator = present.makeCoordinator()
        try await present.establishEnabledPolicy(using: presentCoordinator)
        let presentRecording = try await present
            .prepareAwaitingRecoveryRecording()
        #expect(
            try await presentCoordinator.transferPendingRecordingFailure(
                expected: IOSPendingRecordingCASExpectation(
                    recording: presentRecording
                ),
                failure: .recoverableNetworkFailure
            ) == .transferred
        )
        try present.recreatePendingMetadata(presentRecording)
        let failedBytesBefore = try Data(
            contentsOf: IOSFailedHistoryStorageLocation.fileURL(
                in: present.applicationSupportDirectoryURL
            )
        )
        let pendingBytesBefore = try Data(
            contentsOf: IOSPendingRecordingStorageLocation.journalFileURL(
                in: present.applicationSupportDirectoryURL
            )
        )
        let audioIdentityBefore = try present.audioIdentity(
            for: presentRecording
        )

        await #expect(throws: IOSPendingRecordingError.localRecoveryPending) {
            _ = try await present.makeCoordinator()
                .reconcileFailedHistoryTransfer()
        }

        #expect(
            try Data(
                contentsOf: IOSFailedHistoryStorageLocation.fileURL(
                    in: present.applicationSupportDirectoryURL
                )
            ) == failedBytesBefore
        )
        #expect(
            try Data(
                contentsOf: IOSPendingRecordingStorageLocation.journalFileURL(
                    in: present.applicationSupportDirectoryURL
                )
            ) == pendingBytesBefore
        )
        #expect(
            try present.audioIdentity(for: presentRecording)
                == audioIdentityBefore
        )
    }
}

private final class FailedTransferCoordinatorFixture: @unchecked Sendable {
    struct AudioIdentity: Equatable {
        let fileNumber: UInt64
        let byteCount: UInt64
    }

    let parentDirectoryURL: URL
    let applicationSupportDirectoryURL: URL
    let registry: IOSAcceptedHistoryCoordinatorProcessContextRegistry
    let context: IOSAcceptedHistoryCoordinatorProcessContext

    init() throws {
        parentDirectoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "failed-transfer-coordinator-\(UUID().uuidString)",
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
        context = registry.context(for: applicationSupportDirectoryURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: parentDirectoryURL)
    }

    func makeCoordinator(
        context: IOSAcceptedHistoryCoordinatorProcessContext? = nil,
        registry: IOSAcceptedHistoryCoordinatorProcessContextRegistry? = nil
    ) -> IOSAcceptedHistoryCoordinator {
        let context = context ?? self.context
        let registry = registry ?? self.registry
        return IOSAcceptedHistoryCoordinator(
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

    func establishEnabledPolicy(
        using coordinator: IOSAcceptedHistoryCoordinator
    ) async throws {
        let capture = try await coordinator.capture(
            transcriptionModel: "gpt-4o-mini-transcribe",
            transcriptionLanguageCode: "en",
            durationMilliseconds: 1_000
        )
        #expect(capture.historyWrite?.policyGeneration == 1)
    }

    func prepareAwaitingRecoveryRecording() async throws
        -> IOSPendingRecording {
        let attemptID = UUID()
        let sourceURL = parentDirectoryURL.appendingPathComponent(
            "source-\(attemptID.uuidString.lowercased()).wav",
            isDirectory: false
        )
        let data = makeFailedTransferOneSecondWAV()
        try data.write(to: sourceURL, options: .atomic)
        let preparation = try IOSPendingRecordingPreparation(
            attemptID: attemptID,
            sourceArtifact: AudioRecordingArtifact(
                fileURL: sourceURL,
                duration: 1,
                byteCount: Int64(data.count)
            ),
            initialState: .awaitingRecovery,
            outputIntent: .standard,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "gpt-4o-mini-transcribe",
                language: .english
            )
        )
        return try await context.pendingRecordingStore.prepare(preparation)
    }

    func stagePendingJournalRetirement(
        for recording: IOSPendingRecording
    ) async throws {
        try await context.operationGate.perform { lease in
            let source = try await context.pendingRecordingStore
                .prepareFailedHistoryTransferSource(
                    expected: IOSPendingRecordingCASExpectation(
                        recording: recording
                    ),
                    failedStoreIdentity:
                        context.failedHistoryStore.storeIdentity,
                    operationLeaseAuthorization: lease
                )
            defer { source.releaseAudioLease() }
            let policy = try #require(try await context.policyStore.load())
            let policyReceipt = try await context.policyStore.confirm(
                expected: IOSHistoryPolicyExpectation(state: policy)
            )
            let preparation = try await context.pendingRecordingStore
                .sealFailedHistoryTransfer(
                    source,
                    failure: .recoverableNetworkFailure,
                    transferDate: recording.updatedAt.addingTimeInterval(1),
                    policyReceipt: policyReceipt,
                    operationLeaseAuthorization: lease
                )
            defer { preparation.releaseAudioLease() }
            _ = try await context.failedHistoryStore
                .commitPendingJournalRetirement(preparation)
        }
    }

    func rawPendingRecording() throws -> IOSPendingRecording? {
        try FoundationIOSPendingRecordingJournalRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            repositoryGuard: context.repositoryGuard
        ).load()
    }

    func recreatePendingMetadata(_ recording: IOSPendingRecording) throws {
        try FoundationIOSPendingRecordingJournalRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            repositoryGuard: context.repositoryGuard
        ).create(
            recording,
            expectedRepositoryRoot:
                context.repositoryBinding.physicalRootIdentity
        )
    }

    func audioIdentity(
        for recording: IOSPendingRecording
    ) throws -> AudioIdentity {
        let url = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier: recording.audioRelativeIdentifier,
                in: applicationSupportDirectoryURL
            )
        )
        let attributes = try FileManager.default.attributesOfItem(
            atPath: url.path
        )
        return AudioIdentity(
            fileNumber: try #require(
                (attributes[.systemFileNumber] as? NSNumber)?.uint64Value
            ),
            byteCount: try #require(
                (attributes[.size] as? NSNumber)?.uint64Value
            )
        )
    }
}

private extension IOSFailedHistoryTransferFailure {
    static let recoverableNetworkFailure = Self(
        category: .networkUnavailable,
        pipelineStage: .transcription
    )
}

private func makeFailedTransferOneSecondWAV() -> Data {
    let sampleRate: UInt32 = 8_000
    let channelCount: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let dataByteCount = sampleRate * UInt32(bitsPerSample / 8)
    let byteRate = sampleRate * UInt32(channelCount)
        * UInt32(bitsPerSample / 8)
    let blockAlign = channelCount * (bitsPerSample / 8)

    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.appendFailedTransferLittleEndian(UInt32(36) + dataByteCount)
    data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8)
    data.appendFailedTransferLittleEndian(UInt32(16))
    data.appendFailedTransferLittleEndian(UInt16(1))
    data.appendFailedTransferLittleEndian(channelCount)
    data.appendFailedTransferLittleEndian(sampleRate)
    data.appendFailedTransferLittleEndian(byteRate)
    data.appendFailedTransferLittleEndian(blockAlign)
    data.appendFailedTransferLittleEndian(bitsPerSample)
    data.append(contentsOf: "data".utf8)
    data.appendFailedTransferLittleEndian(dataByteCount)
    data.append(Data(repeating: 0, count: Int(dataByteCount)))
    return data
}

private extension Data {
    mutating func appendFailedTransferLittleEndian<T: FixedWidthInteger>(
        _ value: T
    ) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
