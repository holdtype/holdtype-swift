import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSContainingAppRecoveryTests {
    @Test func onlyLaunchRecoversOneProcessLostPendingProviderPhase()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let transcribing = try await seedProcessLostPendingRecording(in: root)
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.foreground)
                == .complete
        )
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == transcribing
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .complete
        )
        let recovered = try #require(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load()
        )
        #expect(recovered.phase == .awaitingRecovery)
        #expect(recovered.transcriptionID == nil)

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .complete
        )
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == recovered
        )
    }

    @Test func pendingHistoryPrerequisiteDoesNotRecoverPendingProviderPhase()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let transcribing = try await seedProcessLostPendingRecording(in: root)
        let failedURL = IOSFailedHistoryStorageLocation.fileURL(in: root)
        let corrupt = Data("{\"schemaVersion\":99}".utf8)
        try corrupt.write(to: failedURL, options: .atomic)
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .pendingLocalRecovery
        )
        #expect(try Data(contentsOf: failedURL) == corrupt)
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == transcribing
        )
    }

    @Test func launchRetiresOutputDeliveryWithExactAcceptedDestination()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let transcriptionID = try #require(outputDelivery.transcriptionID)
        let audioURL = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier:
                    outputDelivery.audioRelativeIdentifier,
                in: root
            )
        )
        let accepted = try seedAcceptedOutputDestination(
            for: outputDelivery,
            transcriptID: transcriptionID,
            in: root
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .complete
        )
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == nil
        )
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
        #expect(
            try FoundationIOSAcceptedOutputDeliveryJournalRepository(
                applicationSupportDirectoryURL: root
            ).load()?.record == accepted
        )
        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .complete
        )
    }

    @Test(arguments: [
        IOSAcceptedOutputHistoryWriteState.pending,
        .pendingReplacement,
        .committed,
        .cancelled,
    ])
    func launchRetiresCapturedDestinationAcrossHistoryMarkerStates(
        markerState: IOSAcceptedOutputHistoryWriteState
    ) async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let transcriptionID = try #require(outputDelivery.transcriptionID)
        let audioURL = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier:
                    outputDelivery.audioRelativeIdentifier,
                in: root
            )
        )
        _ = try seedAcceptedOutputDestination(
            for: outputDelivery,
            transcriptID: transcriptionID,
            historyWrite: try containingAppRecoveryHistoryWrite(
                for: outputDelivery,
                state: markerState
            ),
            in: root
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        _ = await coordinator.recoverContainingAppLifecycle(.processLaunch)

        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == nil
        )
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
        let remainingDestination = try #require(
            try FoundationIOSAcceptedOutputDeliveryJournalRepository(
                applicationSupportDirectoryURL: root
            ).load()?.record
        )
        #expect(remainingDestination.attemptID == outputDelivery.attemptID)
        #expect(remainingDestination.transcriptID == transcriptionID)
    }

    @Test func capturedDestinationRetiresBeforePendingAcceptedHistoryRecovery()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let transcriptionID = try #require(outputDelivery.transcriptionID)
        let audioURL = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier:
                    outputDelivery.audioRelativeIdentifier,
                in: root
            )
        )
        _ = try seedAcceptedOutputDestination(
            for: outputDelivery,
            transcriptID: transcriptionID,
            historyWrite: try containingAppRecoveryHistoryWrite(
                for: outputDelivery,
                state: .pending
            ),
            in: root
        )
        let acceptedHistoryURL = IOSAcceptedHistoryStorageLocation.fileURL(
            in: root
        )
        let corruptAcceptedHistory = Data(
            "{\"schemaVersion\":99,\"private\":true}".utf8
        )
        try corruptAcceptedHistory.write(
            to: acceptedHistoryURL,
            options: .atomic
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .pendingLocalRecovery
        )
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == nil
        )
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
        #expect(
            try Data(contentsOf: acceptedHistoryURL)
                == corruptAcceptedHistory
        )
        #expect(
            try FoundationIOSAcceptedOutputDeliveryJournalRepository(
                applicationSupportDirectoryURL: root
            ).load()?.record.attemptID == outputDelivery.attemptID
        )
    }

    @Test(arguments: [
        CapturedDestinationMetadataMismatch.model,
        .language,
        .duration,
    ])
    func capturedDestinationMetadataMismatchFailsClosed(
        mismatch: CapturedDestinationMetadataMismatch
    ) async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let transcriptionID = try #require(outputDelivery.transcriptionID)
        let audioURL = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier:
                    outputDelivery.audioRelativeIdentifier,
                in: root
            )
        )
        _ = try seedAcceptedOutputDestination(
            for: outputDelivery,
            transcriptID: transcriptionID,
            historyWrite: try containingAppRecoveryHistoryWrite(
                for: outputDelivery,
                state: .pending,
                mismatch: mismatch
            ),
            in: root
        )
        let deliveryURL = IOSAcceptedOutputDeliveryStorageLocation.fileURL(
            in: root
        )
        let deliveryBytes = try Data(contentsOf: deliveryURL)
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .pendingLocalRecovery
        )
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == outputDelivery
        )
        #expect(FileManager.default.fileExists(atPath: audioURL.path))
        #expect(try Data(contentsOf: deliveryURL) == deliveryBytes)
    }

    @Test func partialAcceptedDestinationIdentityFailsClosed()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let audioURL = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier:
                    outputDelivery.audioRelativeIdentifier,
                in: root
            )
        )
        _ = try seedAcceptedOutputDestination(
            for: outputDelivery,
            transcriptID: UUID(),
            in: root
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .pendingLocalRecovery
        )
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == outputDelivery
        )
        #expect(FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test func exactExpiredDestinationRetiresPendingBeforeGenericExpiry()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let transcriptionID = try #require(outputDelivery.transcriptionID)
        let audioURL = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier:
                    outputDelivery.audioRelativeIdentifier,
                in: root
            )
        )
        _ = try seedAcceptedOutputDestination(
            for: outputDelivery,
            transcriptID: transcriptionID,
            createdAt: Date(timeIntervalSinceNow: -172_800),
            in: root
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .pendingLocalRecovery
        )
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == nil
        )
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
        #expect(
            try FoundationIOSAcceptedOutputDeliveryJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() != nil
        )
    }

    @Test func discardedExactDestinationNeverRetiresPendingRecording()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let transcriptionID = try #require(outputDelivery.transcriptionID)
        let audioURL = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier:
                    outputDelivery.audioRelativeIdentifier,
                in: root
            )
        )
        _ = try seedAcceptedOutputDestination(
            for: outputDelivery,
            transcriptID: transcriptionID,
            deliveryState: .discarded,
            in: root
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        _ = await coordinator.recoverContainingAppLifecycle(.processLaunch)

        let remaining = try #require(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load()
        )
        #expect(remaining.attemptID == outputDelivery.attemptID)
        #expect(FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test func retainedCutoverCannotExpireExactPendingDestination()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let transcriptionID = try #require(outputDelivery.transcriptionID)
        let audioURL = try #require(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier:
                    outputDelivery.audioRelativeIdentifier,
                in: root
            )
        )
        _ = try seedAcceptedOutputDestination(
            for: outputDelivery,
            transcriptID: transcriptionID,
            createdAt: Date(timeIntervalSinceNow: -172_800),
            in: root
        )
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )
        await context.policyCutoverState.store(
            IOSHistoryPolicyCutoverWork(
                ownerIdentity: context.ownerIdentity,
                command: nil,
                phase: .establishingPolicy
            )
        )

        _ = await coordinator.recoverContainingAppLifecycle(.processLaunch)

        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == nil
        )
        #expect(!FileManager.default.fileExists(atPath: audioURL.path))
    }

    @Test func corruptAcceptedDestinationPreservesPendingOutputAndBytes()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let outputDelivery = try await seedProcessLostPendingRecording(
            in: root,
            endingAt: .outputDelivery
        )
        let deliveryURL = IOSAcceptedOutputDeliveryStorageLocation.fileURL(
            in: root
        )
        let corrupt = Data("{\"schemaVersion\":99,\"text\":\"private\"}".utf8)
        try corrupt.write(to: deliveryURL, options: .atomic)
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let coordinator = containingAppRecoveryCoordinator(
            context: context,
            registry: registry,
            root: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .pendingLocalRecovery
        )
        #expect(try Data(contentsOf: deliveryURL) == corrupt)
        #expect(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load() == outputDelivery
        )
    }

    @Test func cleanLaunchAndForegroundAreBoundedAndRedacted()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = IOSAcceptedHistoryCoordinator(
            applicationSupportDirectoryURL: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .complete
        )
        #expect(
            await coordinator.recoverContainingAppLifecycle(.foreground)
                == .complete
        )
        #expect(
            String(describing: IOSContainingAppRecoveryOpportunity.processLaunch)
                == "IOSContainingAppRecoveryOpportunity(redacted)"
        )
        #expect(
            String(describing: IOSContainingAppRecoveryDisposition.complete)
                == "IOSContainingAppRecoveryDisposition(redacted)"
        )
        #expect(
            IOSContainingAppRecoveryDisposition.complete.customMirror
                .children.isEmpty
        )
    }

    @Test func corruptFailedRootStaysByteExactAndPending() async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let failedURL = IOSFailedHistoryStorageLocation.fileURL(
            in: root
        )
        try FileManager.default.createDirectory(
            at: failedURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let corrupt = Data("{\"schemaVersion\":99,\"secret\":true}".utf8)
        try corrupt.write(to: failedURL, options: .atomic)
        let coordinator = IOSAcceptedHistoryCoordinator(
            applicationSupportDirectoryURL: root
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .pendingLocalRecovery
        )
        #expect(try Data(contentsOf: failedURL) == corrupt)
    }

    @Test func retainedCutoverResumesBeforeLaterLifecycleRecovery()
        async throws {
        let root = try containingAppRecoveryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let coordinator = IOSAcceptedHistoryCoordinator(
            applicationSupportDirectoryURL: root
        )
        let cutoverState = await coordinator.policyCutoverState
        let ownerIdentity = await coordinator.ownerIdentity
        await cutoverState.store(
            IOSHistoryPolicyCutoverWork(
                ownerIdentity: ownerIdentity,
                command: nil,
                phase: .establishingPolicy
            )
        )

        #expect(
            await coordinator.recoverContainingAppLifecycle(.processLaunch)
                == .complete
        )
        #expect(await cutoverState.current() == nil)
    }
}

private func containingAppRecoveryRoot() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ios-containing-app-recovery-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: true
    )
    return root
}

private func seedProcessLostPendingRecording(
    in root: URL,
    endingAt phase: IOSPendingRecordingPhase = .transcribing
) async throws -> IOSPendingRecording {
    let sourceURL = root.appendingPathComponent(
        "containing-app-recovery-source-\(UUID().uuidString).wav"
    )
    let audio = containingAppRecoveryWAV()
    try audio.write(to: sourceURL)
    let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
    let context = registry.context(for: root)
    let prepared = try await context.pendingRecordingStore.prepare(
        IOSPendingRecordingPreparation(
            attemptID: UUID(),
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
    var handoff: IOSPendingTranscriptionHandoff? = try await context
        .pendingRecordingStore.beginTranscription(
        expected: IOSPendingRecordingCASExpectation(recording: prepared),
        transcriptionID: UUID()
    )
    #expect(handoff != nil)
    if phase == .postProcessing || phase == .outputDelivery {
        let transcribing = try #require(
            try FoundationIOSPendingRecordingJournalRepository(
                applicationSupportDirectoryURL: root
            ).load()
        )
        let postProcessing = try await context.pendingRecordingStore
            .markPostProcessing(
                expected: IOSPendingRecordingCASExpectation(
                    recording: transcribing
                )
            )
        if phase == .outputDelivery {
            _ = try await context.pendingRecordingStore.markOutputDelivery(
                expected: IOSPendingRecordingCASExpectation(
                    recording: postProcessing
                )
            )
        }
    }
    #expect(
        phase == .transcribing
            || phase == .postProcessing
            || phase == .outputDelivery
    )
    handoff = nil
    return try #require(
        try FoundationIOSPendingRecordingJournalRepository(
            applicationSupportDirectoryURL: root
        ).load()
    )
}

@discardableResult
private func seedAcceptedOutputDestination(
    for pending: IOSPendingRecording,
    transcriptID: UUID,
    createdAt sourceCreatedAt: Date = Date(),
    deliveryState: IOSAcceptedOutputDeliveryState = .pending,
    historyWrite: IOSAcceptedOutputHistoryWrite? = nil,
    in root: URL
) throws -> IOSAcceptedOutputDeliveryRecord {
    let createdAt = try IOSAcceptedOutputDeliveryTimestampCodec.canonicalDate(
        from: sourceCreatedAt
    )
    let expiresAt = Date(
        timeIntervalSince1970:
            createdAt.timeIntervalSince1970
                + TimeInterval(
                    IOSAcceptedOutputDeliveryValidation
                        .lifetimeMilliseconds
                ) / 1_000
    )
    let record = try IOSAcceptedOutputDeliveryRecord(
        revision: 1,
        deliveryID: UUID(),
        sessionID: UUID(),
        attemptID: pending.attemptID,
        transcriptID: transcriptID,
        acceptedText: deliveryState == .discarded
            ? nil
            : "Recovered accepted output",
        outputIntent: pending.outputIntent,
        createdAt: createdAt,
        updatedAt: createdAt,
        expiresAt: expiresAt,
        deliveryState: deliveryState,
        automaticInsertionPreferenceEnabled: false,
        keepLatestResult: true,
        publicationGeneration: 0,
        historyWrite: historyWrite
    )
    _ = try FoundationIOSAcceptedOutputDeliveryJournalRepository(
        applicationSupportDirectoryURL: root
    ).create(record)
    return record
}

enum CapturedDestinationMetadataMismatch: Sendable {
    case model
    case language
    case duration
}

private func containingAppRecoveryHistoryWrite(
    for pending: IOSPendingRecording,
    state: IOSAcceptedOutputHistoryWriteState,
    mismatch: CapturedDestinationMetadataMismatch? = nil
) throws -> IOSAcceptedOutputHistoryWrite {
    let model = mismatch == .model
        ? "mismatched-model"
        : pending.transcriptionModel
    let languageCode = mismatch == .language
        ? "fr"
        : pending.transcriptionLanguageCode
    let durationMilliseconds = mismatch == .duration
        ? pending.durationMilliseconds + 1
        : pending.durationMilliseconds
    return try IOSAcceptedOutputHistoryWrite(
        state: state,
        policyGeneration: 1,
        transcriptionModel: model,
        transcriptionLanguageCode: languageCode,
        durationMilliseconds: durationMilliseconds
    )
}

private func containingAppRecoveryCoordinator(
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

private func containingAppRecoveryWAV() -> Data {
    let sampleRate: UInt32 = 8_000
    let channelCount: UInt16 = 1
    let bitsPerSample: UInt16 = 16
    let dataByteCount = sampleRate * UInt32(bitsPerSample / 8)
    let byteRate = sampleRate * UInt32(channelCount)
        * UInt32(bitsPerSample / 8)
    let blockAlign = channelCount * (bitsPerSample / 8)

    var data = Data()
    data.append(contentsOf: "RIFF".utf8)
    data.appendContainingAppRecoveryLittleEndian(UInt32(36) + dataByteCount)
    data.append(contentsOf: "WAVE".utf8)
    data.append(contentsOf: "fmt ".utf8)
    data.appendContainingAppRecoveryLittleEndian(UInt32(16))
    data.appendContainingAppRecoveryLittleEndian(UInt16(1))
    data.appendContainingAppRecoveryLittleEndian(channelCount)
    data.appendContainingAppRecoveryLittleEndian(sampleRate)
    data.appendContainingAppRecoveryLittleEndian(byteRate)
    data.appendContainingAppRecoveryLittleEndian(blockAlign)
    data.appendContainingAppRecoveryLittleEndian(bitsPerSample)
    data.append(contentsOf: "data".utf8)
    data.appendContainingAppRecoveryLittleEndian(dataByteCount)
    data.append(Data(repeating: 0, count: Int(dataByteCount)))
    return data
}

private extension Data {
    mutating func appendContainingAppRecoveryLittleEndian<
        Value: FixedWidthInteger
    >(_ value: Value) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) {
            append(contentsOf: $0)
        }
    }
}
