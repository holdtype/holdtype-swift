import Darwin
import Foundation
import HoldTypeDomain
import Testing
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence

struct IOSCaptureTransferStoreTests {
    @Test func normalDoneCommitsFrozenReadyJournalAndRetiresSource()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        let configuration = TranscriptionConfiguration(
            model: "frozen-model",
            language: .french
        )

        let recording = try await fixture.store.prepareCompletedCapture(
            completed,
            transcriptionConfiguration: configuration
        )

        #expect(recording.phase == .readyForTranscription)
        #expect(recording.transcriptionModel == "frozen-model")
        #expect(recording.transcriptionLanguageCode == "fr")
        #expect(recording.createdAt == fixture.captureDate)
        #expect(recording.updatedAt == fixture.storeDate)
        #expect(fixture.journal.recording == recording)
        #expect(fixture.journal.replaceCount == 1)
        #expect(fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])
        #expect(
            fixture.adapter.pendingArtifactAttribute(
                named: fixture.finalPendingName,
                attributeName: "com.holdtype.ios.capture-source-transfer"
            )?.count == 51
        )
    }

    @Test(arguments: [
        IOSForegroundVoiceCaptureRecoveryStatus.activeNeedsRecovery,
        .finalizingNeedsRecovery,
        .completedNeedsPendingHandoff,
    ])
    func explicitRecoveryFinalizesAndCreatesAwaitingJournal(
        status: IOSForegroundVoiceCaptureRecoveryStatus
    ) async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let lease = try await fixture.activeCapture()
        switch status {
        case .activeNeedsRecovery:
            lease.release()
        case .finalizingNeedsRecovery:
            try await lease.beginFinalizing()
            lease.release()
        case .completedNeedsPendingHandoff:
            let result = try await fixture.complete(lease)
            result.release()
        default:
            Issue.record("Unsupported recovery fixture status")
            return
        }

        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == status)
        let capability = try #require(observation.recoveryCapability)
        let result = try await fixture.store.recoverCapture(
            capability,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "current-recovery-model",
                language: .german
            )
        )

        guard case let .pending(recording) = result else {
            Issue.record("Expected recovered Pending recording")
            return
        }
        #expect(recording.phase == .awaitingRecovery)
        #expect(recording.transcriptionModel == "current-recovery-model")
        #expect(recording.transcriptionLanguageCode == "de")
        #expect(recording.createdAt == fixture.captureDate)
        #expect(fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])
    }

    @Test func invalidActiveRecoveryIsTypedDiscardAndCreatesNoPendingOwner()
        async throws {
        let fixture = try CaptureTransferStoreFixture(
            captureDurationMilliseconds: 299
        )
        defer { fixture.close() }
        let lease = try await fixture.activeCapture()
        lease.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .activeNeedsRecovery)
        let capability = try #require(observation.recoveryCapability)

        let result = try await fixture.store.recoverCapture(
            capability,
            transcriptionConfiguration: .defaults
        )

        #expect(result == .discarded(.tooShort))
        #expect(fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames.isEmpty)
        #expect(fixture.journal.recording == nil)
    }

    @Test func finalAudioWithoutJournalIsAdoptedOnExplicitRecovery()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        _ = try await fixture.publishAudioOnly(from: completed)
        completed.release()

        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .preparingPendingNeedsRecovery)
        let capability = try #require(observation.recoveryCapability)
        let result = try await fixture.store.recoverCapture(
            capability,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "adopted-model",
                language: .italian
            )
        )

        guard case let .pending(recording) = result else {
            Issue.record("Expected adopted Pending recording")
            return
        }
        #expect(recording.phase == .awaitingRecovery)
        #expect(recording.transcriptionModel == "adopted-model")
        #expect(fixture.journal.recording == recording)
        #expect(fixture.adapter.captureNames.isEmpty)
    }

    @Test func matchingJournalWithoutFinalAudioRecopiesAndPreservesSettings()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        let source = try await fixture.publishAudioOnly(from: completed)
        let retained = try fixture.recording(
            source: source,
            phase: .awaitingRecovery,
            model: "retained-model",
            languageCode: "es"
        )
        fixture.journal.recording = retained
        fixture.adapter.removePendingArtifact(named: fixture.finalPendingName)
        completed.release()

        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .preparingPendingNeedsRecovery)
        #expect(fixture.adapter.pendingNames.isEmpty)
        #expect(fixture.journal.replaceCount == 0)
        let capability = try #require(observation.recoveryCapability)
        let result = try await fixture.store.recoverCapture(
            capability,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "must-not-replace",
                language: .japanese
            )
        )

        #expect(result == .pending(retained))
        #expect(fixture.journal.recording == retained)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])
        #expect(fixture.adapter.captureNames.isEmpty)
        #expect(fixture.journal.replaceCount == 1)
    }

    @Test func passiveLaunchPreservesIncompleteBoundStagingUntilRecover()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        let source = try await fixture.publishAudioOnly(from: completed)
        let retained = try fixture.recording(
            source: source,
            phase: .awaitingRecovery,
            model: "retained-staging-model",
            languageCode: nil
        )
        fixture.journal.recording = retained
        let stagingName = fixture.captureStagingName
        fixture.adapter.movePublishedPendingToCaptureStaging(
            stagingName: stagingName,
            retainingByteCount: 12
        )
        completed.release()

        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)

        #expect(observation.status == .preparingPendingNeedsRecovery)
        #expect(fixture.adapter.pendingNames == [stagingName])
        #expect(
            fixture.adapter.pendingArtifactBytes(named: stagingName)?.count
                == 12
        )
        #expect(fixture.journal.replaceCount == 0)

        let capability = try #require(observation.recoveryCapability)
        #expect(
            try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            ) == .pending(retained)
        )
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])
        #expect(fixture.adapter.captureNames.isEmpty)
    }

    @Test func matchingJournalAndFinalAreConfirmedBeforeSourceRetirement()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        let source = try await fixture.publishAudioOnly(from: completed)
        let retained = try fixture.recording(
            source: source,
            phase: .readyForTranscription,
            model: "frozen-normal-model",
            languageCode: nil
        )
        fixture.journal.recording = retained
        completed.release()

        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .cleanupPerformed)
        #expect(fixture.journal.replaceCount == 1)
        #expect(fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])
    }

    @Test func preparingDiscardRequiresUnambiguousPendingAbsence()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        fixture.adapter.installFinalAudio(
            named: "ambiguous.bin",
            bytes: [1],
            configured: false
        )
        await #expect(throws: (any Error).self) {
            _ = try await fixture.store.prepareCompletedCapture(
                completed,
                transcriptionConfiguration: .defaults
            )
        }
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .preparingPendingNeedsRecovery)
        let capability = try #require(observation.recoveryCapability)

        await #expect(throws: (any Error).self) {
            try await fixture.store.discardCapture(capability)
        }
        #expect(!fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == ["ambiguous.bin"])

        fixture.adapter.removePendingArtifact(named: "ambiguous.bin")
        try await fixture.store.discardCapture(capability)
        #expect(fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames.isEmpty)
    }

    @Test func invalidExistingFinalBlocksRecoveryAndPreservesBothOwners()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        _ = try await fixture.publishAudioOnly(from: completed)
        fixture.adapter.setPendingArtifactAttribute(
            named: fixture.finalPendingName,
            attributeName: "com.holdtype.ios.capture-source-transfer",
            value: [UInt8](repeating: 0xA5, count: 51)
        )
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)

        await #expect(throws: IOSPendingRecordingError.linkedAudioInvalid) {
            _ = try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            )
        }

        #expect(!fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])
        #expect(fixture.journal.recording == nil)
    }

    @Test func journalCreateFailureLeavesPreparingSourceAndAdoptableFinal()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        fixture.journal.createError = .journalWriteFailed

        await #expect(throws: IOSPendingRecordingError.journalWriteFailed) {
            _ = try await fixture.store.prepareCompletedCapture(
                completed,
                transcriptionConfiguration: .defaults
            )
        }
        completed.release()
        #expect(fixture.journal.recording == nil)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .preparingPendingNeedsRecovery)

        fixture.journal.createError = nil
        let capability = try #require(observation.recoveryCapability)
        let recovered = try await fixture.store.recoverCapture(
            capability,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "post-crash-model",
                language: .portuguese
            )
        )
        guard case let .pending(recording) = recovered else {
            Issue.record("Expected adopted Pending after journal failure")
            return
        }
        #expect(recording.phase == .awaitingRecovery)
        #expect(recording.transcriptionModel == "post-crash-model")
        #expect(fixture.adapter.captureNames.isEmpty)
    }

    @Test func newJournalMustConfirmBeforeSourceCanTransfer() async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        fixture.journal.replaceError = .journalWriteFailed

        await #expect(throws: IOSPendingRecordingError.journalWriteFailed) {
            _ = try await fixture.store.prepareCompletedCapture(
                completed,
                transcriptionConfiguration: .defaults
            )
        }
        completed.release()
        #expect(fixture.journal.recording != nil)
        #expect(!fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])

        fixture.journal.replaceError = nil
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .cleanupPerformed)
        #expect(fixture.journal.replaceCount == 1)
        #expect(fixture.adapter.captureNames.isEmpty)
    }

    @Test func visibleJournalCreateUncertaintyIsPassivelyConfirmed()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        fixture.journal.createError = .journalCommitUncertain
        fixture.journal.createCommitsBeforeError = true

        await #expect(throws: IOSPendingRecordingError.journalCommitUncertain) {
            _ = try await fixture.store.prepareCompletedCapture(
                completed,
                transcriptionConfiguration: TranscriptionConfiguration(
                    model: "visible-model",
                    language: .english
                )
            )
        }
        completed.release()
        #expect(fixture.journal.recording?.transcriptionModel == "visible-model")
        #expect(!fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])
        fixture.adapter.resetEvents()

        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)

        #expect(observation.status == .cleanupPerformed)
        #expect(fixture.journal.replaceCount == 1)
        #expect(fixture.adapter.captureNames.isEmpty)
        #expect(!fixture.adapter.events.contains {
            $0.hasPrefix("pread:") || $0.hasPrefix("write:")
        })
    }

    @Test func journalConfirmationFailurePreventsSourceTransferUntilRetry()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        let source = try await fixture.publishAudioOnly(from: completed)
        let retained = try fixture.recording(
            source: source,
            phase: .awaitingRecovery,
            model: "retained-confirmation-model",
            languageCode: nil
        )
        fixture.journal.recording = retained
        fixture.journal.replaceError = .journalWriteFailed
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)

        await #expect(throws: IOSPendingRecordingError.journalWriteFailed) {
            _ = try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            )
        }
        #expect(!fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == [fixture.finalPendingName])

        fixture.journal.replaceError = nil
        #expect(
            try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            ) == .pending(retained)
        )
        #expect(fixture.adapter.captureNames.isEmpty)
    }

    @Test func operationGateReentrancyFailsBeforeCompletedPhaseMutation()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()

        await #expect(throws: IOSPendingRecordingError.reentrantOperation) {
            try await fixture.context.operationGate.perform { _ in
                _ = try await fixture.store.prepareCompletedCapture(
                    completed,
                    transcriptionConfiguration: .defaults
                )
            }
        }
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .completedNeedsPendingHandoff)
        #expect(fixture.adapter.pendingNames.isEmpty)
    }

    @Test func invalidNormalConfigurationFailsBeforeSourceOrPendingMutation()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        let invalid = TranscriptionConfiguration(
            language: .custom,
            customLanguageCode: "invalid-code"
        )

        await #expect(
            throws: IOSPendingRecordingError.invalidTranscriptionConfiguration
        ) {
            _ = try await fixture.store.prepareCompletedCapture(
                completed,
                transcriptionConfiguration: invalid
            )
        }
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(observation.status == .completedNeedsPendingHandoff)
        #expect(fixture.adapter.pendingNames.isEmpty)
        #expect(fixture.journal.recording == nil)
    }

    @Test func invalidRecoveryConfigurationFailsBeforeActiveSourceMutation()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let lease = try await fixture.activeCapture()
        lease.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)

        await #expect(
            throws: IOSPendingRecordingError.invalidTranscriptionConfiguration
        ) {
            _ = try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: TranscriptionConfiguration(
                    language: .custom,
                    customLanguageCode: "invalid-code"
                )
            )
        }
        let retained = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(retained.status == .completedNeedsPendingHandoff)
        #expect(fixture.adapter.pendingNames.isEmpty)
    }

    @Test func invalidSettingsDoNotBlockTypedInvalidActiveCleanup()
        async throws {
        let fixture = try CaptureTransferStoreFixture(
            captureDurationMilliseconds: 299
        )
        defer { fixture.close() }
        let lease = try await fixture.activeCapture()
        lease.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)

        let result = try await fixture.store.recoverCapture(
            capability,
            transcriptionConfiguration: TranscriptionConfiguration(
                language: .custom,
                customLanguageCode: "invalid-code"
            )
        )

        #expect(result == .discarded(.tooShort))
        #expect(fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames.isEmpty)
        #expect(fixture.journal.recording == nil)
    }

    @Test func normalDoneRejectsSameAttemptIncompatibleJournalBeforeMutation()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        fixture.journal.recording = try IOSPendingRecording(
            attemptID: fixture.attemptID,
            audioRelativeIdentifier:
                IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
                    for: fixture.attemptID,
                    format: .wav
                ),
            createdAt: fixture.captureDate,
            updatedAt: fixture.storeDate,
            phase: .awaitingRecovery,
            outputIntent: .standard,
            transcriptionID: nil,
            transcriptionModel: "incompatible",
            transcriptionLanguageCode: nil,
            durationMilliseconds: 1_500,
            byteCount: 96
        )

        await #expect(throws: IOSPendingRecordingError.localRecoveryPending) {
            _ = try await fixture.store.prepareCompletedCapture(
                completed,
                transcriptionConfiguration: .defaults
            )
        }
        completed.release()
        fixture.journal.recording = nil
        let retained = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(retained.status == .completedNeedsPendingHandoff)
        #expect(fixture.adapter.pendingNames.isEmpty)
    }

    @Test func foreignRepositoryCapabilityCannotCrossStoreBoundary()
        async throws {
        let sourceFixture = try CaptureTransferStoreFixture()
        let foreignFixture = try CaptureTransferStoreFixture()
        defer {
            sourceFixture.close()
            foreignFixture.close()
        }
        let completed = try await sourceFixture.completedCapture()
        completed.release()
        let observation = await sourceFixture.store
            .reconcileCaptureSourcesAtLaunch(owner: sourceFixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)

        await #expect(throws: (any Error).self) {
            _ = try await foreignFixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            )
        }

        let retained = await sourceFixture.store
            .reconcileCaptureSourcesAtLaunch(owner: sourceFixture.captureOwner)
        #expect(retained.status == .completedNeedsPendingHandoff)
        #expect(sourceFixture.adapter.pendingNames.isEmpty)
        #expect(foreignFixture.adapter.pendingNames.isEmpty)
    }

    @Test func unrelatedPendingJournalBlocksBeforeSourcePhaseMutation()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)
        let unrelatedAttempt = UUID()
        fixture.journal.recording = try IOSPendingRecording(
            attemptID: unrelatedAttempt,
            audioRelativeIdentifier:
                IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
                    for: unrelatedAttempt,
                    format: .wav
                ),
            createdAt: fixture.captureDate,
            updatedAt: fixture.storeDate,
            phase: .awaitingRecovery,
            outputIntent: .standard,
            transcriptionID: nil,
            transcriptionModel: "unrelated",
            transcriptionLanguageCode: nil,
            durationMilliseconds: 1_500,
            byteCount: 96
        )

        await #expect(throws: IOSPendingRecordingError.pendingSlotOccupied) {
            _ = try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            )
        }
        fixture.journal.recording = nil
        let retained = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(retained.status == .completedNeedsPendingHandoff)
        #expect(fixture.adapter.pendingNames.isEmpty)
    }

    @Test func invalidActiveRecoveryPreservesSourceWhenPendingIsAmbiguous()
        async throws {
        let fixture = try CaptureTransferStoreFixture(
            captureDurationMilliseconds: 299
        )
        defer { fixture.close() }
        let lease = try await fixture.activeCapture()
        lease.release()
        fixture.adapter.installFinalAudio(
            named: "foreign.bin",
            bytes: [1],
            configured: false
        )
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)

        await #expect(throws: (any Error).self) {
            _ = try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            )
        }
        #expect(!fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames == ["foreign.bin"])

        fixture.adapter.removePendingArtifact(named: "foreign.bin")
        let retained = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(retained.status == .activeNeedsRecovery)
        #expect(
            try await fixture.store.recoverCapture(
                try #require(retained.recoveryCapability),
                transcriptionConfiguration: .defaults
            ) == .discarded(.tooShort)
        )
    }

    @Test func sameAttemptIncompatibleJournalBlocksBeforeSourceMutation()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)
        fixture.journal.recording = try IOSPendingRecording(
            attemptID: fixture.attemptID,
            audioRelativeIdentifier:
                IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
                    for: fixture.attemptID,
                    format: .wav
                ),
            createdAt: fixture.captureDate,
            updatedAt: fixture.storeDate,
            phase: .awaitingRecovery,
            outputIntent: .standard,
            transcriptionID: nil,
            transcriptionModel: "incompatible",
            transcriptionLanguageCode: nil,
            durationMilliseconds: 1_500,
            byteCount: 96
        )

        await #expect(throws: IOSPendingRecordingError.localRecoveryPending) {
            _ = try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            )
        }
        fixture.journal.recording = nil
        let retained = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(retained.status == .completedNeedsPendingHandoff)
        #expect(fixture.adapter.pendingNames.isEmpty)
    }

    @Test func passiveRetirementReportsDurableTransferredCleanupPending()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        let source = try await fixture.publishAudioOnly(from: completed)
        fixture.journal.recording = try fixture.recording(
            source: source,
            phase: .awaitingRecovery,
            model: "retained",
            languageCode: nil
        )
        completed.release()
        fixture.adapter.failNext("unlink", errors: [EIO])

        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)

        #expect(observation.status == .transferredCleanupPending)
        #expect(observation.removedEntryCount == 0)
        #expect(observation.removedLogicalByteCount == 0)
        #expect(!fixture.adapter.captureNames.isEmpty)

        let cleanup = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(cleanup.status == .cleanupPerformed)
        #expect(fixture.adapter.captureNames.isEmpty)
    }

    @Test func staleCompletedCapabilityCannotRecoverChangedCompletion()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)
        try fixture.replaceCaptureCompletionDuration(with: 1_600)

        await #expect(
            throws: IOSForegroundVoiceCaptureSourceError.sourceChanged
        ) {
            _ = try await fixture.store.recoverCapture(
                capability,
                transcriptionConfiguration: .defaults
            )
        }
        let retained = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(retained.status == .completedNeedsPendingHandoff)
        #expect(!fixture.adapter.captureNames.isEmpty)
        #expect(fixture.adapter.pendingNames.isEmpty)
    }

    @Test func stalePreparingCapabilityCannotDiscardChangedCompletion()
        async throws {
        let fixture = try CaptureTransferStoreFixture()
        defer { fixture.close() }
        let completed = try await fixture.completedCapture()
        fixture.adapter.installFinalAudio(
            named: "ambiguous.bin",
            bytes: [1],
            configured: false
        )
        await #expect(throws: (any Error).self) {
            _ = try await fixture.store.prepareCompletedCapture(
                completed,
                transcriptionConfiguration: .defaults
            )
        }
        completed.release()
        let observation = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        let capability = try #require(observation.recoveryCapability)
        fixture.adapter.removePendingArtifact(named: "ambiguous.bin")
        try fixture.replaceCaptureCompletionDuration(with: 1_600)

        await #expect(
            throws: IOSForegroundVoiceCaptureSourceError.sourceChanged
        ) {
            try await fixture.store.discardCapture(capability)
        }
        let retained = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(retained.status == .preparingPendingNeedsRecovery)
        #expect(!fixture.adapter.captureNames.isEmpty)
    }

    @Test func cancelledTransferRetainsSourceLeaseUntilLateWorkerFinishes()
        async throws {
        let validator = CaptureTransferBlockingMediaValidator()
        let fixture = try CaptureTransferStoreFixture(
            pendingMediaValidator: validator
        )
        defer { fixture.close() }

        try await runCancelledTransferAndDropCapture(
            fixture: fixture,
            validator: validator
        )
        let locked = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(locked.status == .blockedUnknown)
        #expect(locked.recoveryCapability == nil)
        validator.resume()

        var observed: IOSForegroundVoiceCaptureRecoveryObservation?
        for _ in 0..<100 {
            let candidate = await fixture.store
                .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
            if candidate.status == .preparingPendingNeedsRecovery {
                observed = candidate
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(observed?.status == .preparingPendingNeedsRecovery)
    }

    @Test func timedOutTransferRetainsSourceLeaseUntilLateWorkerFinishes()
        async throws {
        let validator = CaptureTransferBlockingMediaValidator()
        let fixture = try CaptureTransferStoreFixture(
            pendingMediaValidator: validator,
            operationDeadlineNanoseconds: 20_000_000
        )
        defer { fixture.close() }

        try await runTimedOutTransferAndDropCapture(
            fixture: fixture,
            validator: validator
        )
        let locked = await fixture.store
            .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
        #expect(locked.status == .blockedUnknown)
        #expect(locked.recoveryCapability == nil)
        validator.resume()

        var observed: IOSForegroundVoiceCaptureRecoveryObservation?
        for _ in 0..<100 {
            let candidate = await fixture.store
                .reconcileCaptureSourcesAtLaunch(owner: fixture.captureOwner)
            if candidate.status == .preparingPendingNeedsRecovery {
                observed = candidate
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(observed?.status == .preparingPendingNeedsRecovery)
    }
}

private final class CaptureTransferStoreFixture: @unchecked Sendable {
    let captureDate = Date(timeIntervalSince1970: 1_750_000_000.123)
    let storeDate = Date(timeIntervalSince1970: 1_750_000_005.456)
    let attemptID = UUID(
        uuidString: "01234567-89AB-CDEF-7123-456789ABCDEF"
    )!
    let parentURL: URL
    let rootURL: URL
    let registry: IOSAcceptedHistoryCoordinatorProcessContextRegistry
    let context: IOSAcceptedHistoryCoordinatorProcessContext
    let adapter: SimulatedPendingRecordingPOSIXAdapter
    let audioFileSystem: FoundationIOSPendingRecordingAudioFileSystem
    let journal = CaptureTransferPendingJournal()
    let store: IOSPendingRecordingStore
    let captureOwner: IOSForegroundVoiceCaptureSourceOwner

    var finalPendingName: String {
        "recording-v1-\(attemptID.uuidString.lowercased()).wav"
    }
    var captureStagingName: String {
        ".capture-transfer-v1-\(attemptID.uuidString.lowercased()).wav"
    }

    init(
        captureDurationMilliseconds: Int64 = 1_500,
        pendingMediaValidator:
            (any IOSPendingRecordingMediaValidating)? = nil,
        operationDeadlineNanoseconds: UInt64 =
            FoundationIOSPendingRecordingAudioFileSystem
                .copyDeadlineNanoseconds
    ) throws {
        parentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "holdtype-capture-store-\(UUID().uuidString)",
                isDirectory: true
            )
        rootURL = parentURL.appendingPathComponent(
            "ApplicationSupport",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        var rootStatus = stat()
        let readStatus = rootURL.withUnsafeFileSystemRepresentation { path in
            path.map { Darwin.lstat($0, &rootStatus) == 0 } ?? false
        }
        guard readStatus else { throw CaptureTransferStoreTestError.setup }
        registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        context = registry.context(for: rootURL)
        adapter = SimulatedPendingRecordingPOSIXAdapter(
            sourceBytes: [],
            applicationSupportPath: rootURL.path,
            applicationSupportDevice: rootStatus.st_dev,
            applicationSupportInode: rootStatus.st_ino
        )
        audioFileSystem = FoundationIOSPendingRecordingAudioFileSystem(
            applicationSupportDirectoryURL: rootURL,
            adapter: adapter,
            mediaValidator: pendingMediaValidator
                ?? CaptureTransferStoreMediaValidator(
                    durationMilliseconds: captureDurationMilliseconds
                ),
            monotonicClock: { 1 },
            operationDeadlineNanoseconds: operationDeadlineNanoseconds,
            expectedRepositoryRoot:
                context.repositoryBinding.physicalRootIdentity,
            queue: DispatchQueue(label: "capture-transfer-store-audio")
        )
        store = IOSPendingRecordingStore(
            journal: journal,
            audioFileSystem: audioFileSystem,
            operationGate: context.operationGate,
            liveOwnerRegistry: context.pendingRecordingLiveOwnerRegistry,
            capabilityOwnerIdentity: context.ownerIdentity,
            storeIdentity: context.pendingRecordingStoreIdentity,
            repositoryGuard: context.repositoryGuard,
            failedHistoryMutationInterlock:
                context.failedHistoryMutationInterlock,
            failedOwnershipInspector: context.failedHistoryStore,
            now: { [storeDate] in storeDate }
        )
        captureOwner = IOSForegroundVoiceCaptureSourceOwner(
            applicationSupportDirectoryURL: rootURL,
            adapter: adapter,
            mediaValidator: CaptureTransferStoreMediaValidator(
                durationMilliseconds: captureDurationMilliseconds
            ),
            now: { [captureDate] in captureDate },
            monotonicClock: { 1 },
            queue: DispatchQueue(label: "capture-transfer-store-source")
        )
    }

    func activeCapture() async throws -> IOSForegroundVoiceCaptureSourceLease {
        let lease = try await captureOwner.createCapture(
            attemptID: attemptID,
            outputIntent: .translate,
            format: .wav
        )
        adapter.writeCaptureBytes([UInt8](repeating: 0x5A, count: 96))
        return lease
    }

    func completedCapture() async throws -> IOSForegroundVoiceCompletedCapture {
        try await complete(activeCapture())
    }

    func complete(
        _ lease: IOSForegroundVoiceCaptureSourceLease
    ) async throws -> IOSForegroundVoiceCompletedCapture {
        try await lease.beginFinalizing()
        switch try await lease.completeAfterRecorderClose() {
        case let .completed(capture): return capture
        case .discarded: throw CaptureTransferStoreTestError.setup
        }
    }

    func publishAudioOnly(
        from capture: IOSForegroundVoiceCompletedCapture
    ) async throws -> IOSPendingRecordingCaptureTransferSource {
        try await store.publishCaptureAudioOnlyForTesting(capture)
    }

    func recording(
        source: IOSPendingRecordingCaptureTransferSource,
        phase: IOSPendingRecordingPhase,
        model: String,
        languageCode: String?
    ) throws -> IOSPendingRecording {
        try IOSPendingRecording(
            attemptID: source.attemptID,
            audioRelativeIdentifier:
                IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
                    for: source.attemptID,
                    format: source.format
                ),
            createdAt: captureDate,
            updatedAt: storeDate,
            phase: phase,
            outputIntent: source.outputIntent,
            transcriptionID: nil,
            transcriptionModel: model,
            transcriptionLanguageCode: languageCode,
            durationMilliseconds: source.durationMilliseconds,
            byteCount: source.byteCount
        )
    }

    func replaceCaptureCompletionDuration(
        with durationMilliseconds: UInt32
    ) throws {
        let bytes = try #require(
            adapter.captureAttribute(
                named: IOSForegroundVoiceCaptureSourceFileSystem.completionName
            )
        )
        let existing = try #require(
            IOSForegroundVoiceCaptureSourceWireCodec
                .decodeCompletion(bytes)
        )
        let changed = IOSForegroundVoiceCaptureCompletion(
            durationMilliseconds: durationMilliseconds,
            byteCount: existing.byteCount,
            modificationSeconds: existing.modificationSeconds,
            modificationNanoseconds: existing.modificationNanoseconds
        )
        adapter.setCaptureAttribute(
            named: IOSForegroundVoiceCaptureSourceFileSystem.completionName,
            value: IOSForegroundVoiceCaptureSourceWireCodec
                .completion(changed)
        )
    }

    func close() {
        try? FileManager.default.removeItem(at: parentURL)
    }
}

private func runCancelledTransferAndDropCapture(
    fixture: CaptureTransferStoreFixture,
    validator: CaptureTransferBlockingMediaValidator
) async throws {
    let capture = try await fixture.completedCapture()
    try await fixture.context.operationGate.perform { authorization in
        let inventory = IOSProtectedAudioNamespaceInventory(
            testingRepositoryBinding: fixture.context.repositoryBinding,
            operationLeaseAuthorization: authorization,
            artifacts: []
        )
        let source = try await capture.beginPendingTransferSource(
            inventory: inventory,
            mode: .normalDone
        )
        let task = Task {
            try await fixture.audioFileSystem.publishOrRecoverCaptureTransfer(
                from: source,
                inventory: inventory
            )
        }
        let entered = await Task.detached {
            validator.waitUntilEntered()
        }.value
        #expect(entered)
        task.cancel()
        await #expect(
            throws: IOSPendingRecordingAudioFileSystemError.operationCancelled
        ) {
            _ = try await task.value
        }
        capture.release()
    }
}

private func runTimedOutTransferAndDropCapture(
    fixture: CaptureTransferStoreFixture,
    validator: CaptureTransferBlockingMediaValidator
) async throws {
    let capture = try await fixture.completedCapture()
    try await fixture.context.operationGate.perform { authorization in
        let inventory = IOSProtectedAudioNamespaceInventory(
            testingRepositoryBinding: fixture.context.repositoryBinding,
            operationLeaseAuthorization: authorization,
            artifacts: []
        )
        let source = try await capture.beginPendingTransferSource(
            inventory: inventory,
            mode: .normalDone
        )
        let task = Task {
            try await fixture.audioFileSystem.publishOrRecoverCaptureTransfer(
                from: source,
                inventory: inventory
            )
        }
        let entered = await Task.detached {
            validator.waitUntilEntered()
        }.value
        #expect(entered)
        await #expect(
            throws: IOSPendingRecordingAudioFileSystemError.operationTimedOut
        ) {
            _ = try await task.value
        }
        capture.release()
    }
}

private final class CaptureTransferPendingJournal:
    IOSPendingRecordingJournalStoring,
    @unchecked Sendable {
    private let lock = NSLock()
    private var storedRecording: IOSPendingRecording?
    private var revision: UInt64 = 1
    private var storedReplaceCount = 0
    private var storedCreateError: IOSPendingRecordingError?
    private var storedReplaceError: IOSPendingRecordingError?
    private var storedCreateCommitsBeforeError = false

    var recording: IOSPendingRecording? {
        get { lock.withLock { storedRecording } }
        set {
            lock.withLock {
                storedRecording = newValue
                revision &+= 1
            }
        }
    }

    var replaceCount: Int { lock.withLock { storedReplaceCount } }
    var createError: IOSPendingRecordingError? {
        get { lock.withLock { storedCreateError } }
        set { lock.withLock { storedCreateError = newValue } }
    }
    var replaceError: IOSPendingRecordingError? {
        get { lock.withLock { storedReplaceError } }
        set { lock.withLock { storedReplaceError = newValue } }
    }
    var createCommitsBeforeError: Bool {
        get { lock.withLock { storedCreateCommitsBeforeError } }
        set { lock.withLock { storedCreateCommitsBeforeError = newValue } }
    }

    func load() throws -> IOSPendingRecording? { recording }

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
            if let storedCreateError {
                if storedCreateCommitsBeforeError {
                    guard storedRecording == nil else {
                        throw IOSPendingRecordingError.pendingSlotOccupied
                    }
                    storedRecording = recording
                    revision &+= 1
                }
                throw storedCreateError
            }
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
            if let storedReplaceError { throw storedReplaceError }
            guard storedRecording == expected else {
                throw IOSPendingRecordingError.compareAndSwapFailed
            }
            storedRecording = recording
            storedReplaceCount += 1
            revision &+= 1
        }
    }

    func remove(expected: IOSPendingRecording) throws -> Bool {
        try lock.withLock {
            guard storedRecording == expected else {
                throw IOSPendingRecordingError.compareAndSwapFailed
            }
            storedRecording = nil
            revision &+= 1
            return true
        }
    }
}

private final class CaptureTransferStoreMediaValidator:
    IOSPendingRecordingMediaValidating,
    @unchecked Sendable {
    let value: Int64
    init(durationMilliseconds: Int64) { value = durationMilliseconds }

    func durationMilliseconds(
        forFileDescriptor fileDescriptor: Int32,
        byteCount: Int64,
        format: IOSPendingRecordingAudioFormat,
        timeoutNanoseconds: UInt64
    ) throws -> Int64 {
        _ = fileDescriptor
        _ = byteCount
        _ = format
        _ = timeoutNanoseconds
        return value
    }
}

private final class CaptureTransferBlockingMediaValidator:
    IOSPendingRecordingMediaValidating,
    @unchecked Sendable {
    private let entered = DispatchSemaphore(value: 0)
    private let resumeGate = DispatchSemaphore(value: 0)

    func waitUntilEntered() -> Bool {
        entered.wait(timeout: .now() + 2) == .success
    }

    func resume() { resumeGate.signal() }

    func durationMilliseconds(
        forFileDescriptor fileDescriptor: Int32,
        byteCount: Int64,
        format: IOSPendingRecordingAudioFormat,
        timeoutNanoseconds: UInt64
    ) throws -> Int64 {
        _ = fileDescriptor
        _ = byteCount
        _ = format
        _ = timeoutNanoseconds
        entered.signal()
        _ = resumeGate.wait(timeout: .now() + 2)
        return 1_500
    }
}

private enum CaptureTransferStoreTestError: Error {
    case setup
}
