import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSFailedHistoryRetryRecoveryTests {
    @Test func emptyFailedRootClearsColdStartBarrier() async throws {
        let fixture = try FailedRetryRecoveryFixture()

        #expect(fixture.mutationInterlock.requiresRetryRecoveryScan)
        #expect(try await fixture.recover() == .noWork)
        #expect(!fixture.mutationInterlock.requiresRetryRecoveryScan)
        #expect(!fixture.mutationInterlock.isBlocked)
        #expect(fixture.failedFileSystem.events == ["load"])
        #expect(fixture.deliveryJournal.events.isEmpty)
    }

    @Test func preAcceptanceRelaunchCancelsReservedAndDispatchedExactly()
        async throws {
        for (offset, state) in [
            (1, IOSFailedHistoryRetryOperationState.reserved),
            (2, IOSFailedHistoryRetryOperationState.providerDispatched),
        ] {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: 100 + offset,
                state: state,
                revision: 40 + Int64(offset)
            )

            #expect(try await fixture.recover() == .retryCancelled)
            let durable = try #require(
                try await fixture.failedHistoryStore.load()
            )
            let retained = try #require(durable.entries.first)
            expectRetryRecoveryRowPreserved(source, retained)
            #expect(retained.retryOperation == nil)
            #expect(durable.revision == 41 + Int64(offset))
            #expect(durable.audioCleanup.isEmpty)
            #expect(!fixture.mutationInterlock.isBlocked)
            #expect(fixture.deliveryJournal.events == ["load"])
        }
    }

    @Test func rollbackAmbiguousPreAcceptanceRetryKeepsColdBarrier()
        async throws {
        for (offset, state) in [
            (0, IOSFailedHistoryRetryOperationState.reserved),
            (1, IOSFailedHistoryRetryOperationState.providerDispatched),
        ] {
            let fixture = try FailedRetryRecoveryFixture()
            _ = try fixture.installRetryRow(
                index: 120 + offset,
                state: state,
                revision: 50 + Int64(offset),
                operationCreatedAt: fixture.now.addingTimeInterval(60)
            )
            let failedBytes = try #require(fixture.failedFileSystem.file?.data)

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.failedFileSystem.file?.data == failedBytes)
            #expect(fixture.mutationInterlock.requiresRetryRecoveryScan)
            #expect(!fixture.mutationInterlock.hasRetryDeliveryProtection)
            #expect(fixture.deliveryJournal.events.isEmpty)
        }
    }

    @Test func acceptingOutputWithoutExactDeliveryCancelsAndKeepsAudioRow()
        async throws {
        for installUnrelated in [false, true] {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: installUnrelated ? 202 : 201,
                state: .acceptingOutput,
                revision: 70
            )
            if installUnrelated {
                fixture.deliveryJournal.install(
                    try fixture.unrelatedDeliveryRecord(index: 800)
                )
            }

            #expect(try await fixture.recover() == .retryCancelled)
            let durable = try #require(
                try await fixture.failedHistoryStore.load()
            )
            let retained = try #require(durable.entries.first)
            expectRetryRecoveryRowPreserved(source, retained)
            #expect(retained.retryOperation == nil)
            #expect(durable.audioCleanup.isEmpty)
            #expect(!fixture.mutationInterlock.isBlocked)
        }
    }

    @Test func rollbackAmbiguousUnrelatedPredecessorStaysProtected()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        _ = try fixture.installRetryRow(
            index: 203,
            state: .acceptingOutput,
            revision: 71
        )
        let failedBytes = try #require(fixture.failedFileSystem.file?.data)
        fixture.deliveryJournal.install(
            try fixture.unrelatedDeliveryRecord(
                index: 801,
                createdAt: fixture.now.addingTimeInterval(60)
            )
        )
        let deliveryBefore = try #require(fixture.deliveryJournal.current())

        #expect(try await fixture.recover() == .pendingLocalRecovery)
        #expect(fixture.failedFileSystem.file?.data == failedBytes)
        #expect(fixture.deliveryJournal.current() == deliveryBefore)
        #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
        #expect(fixture.mutationInterlock.isBlocked)
    }

    @Test func partialDeliveryIdentityCollisionFailsClosedAndChangesNoBytes()
        async throws {
        for matchingMask in 1...14 {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: 300 + matchingMask,
                state: .acceptingOutput,
                revision: 90 + Int64(matchingMask)
            )
            let sourceBytes = try #require(
                fixture.failedFileSystem.file?.data
            )
            fixture.deliveryJournal.install(
                try fixture.partialCollisionRecord(
                    for: source,
                    matchingMask: matchingMask
                )
            )
            let deliveryBefore = try #require(
                fixture.deliveryJournal.current()
            )

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.failedFileSystem.file?.data == sourceBytes)
            #expect(fixture.deliveryJournal.current() == deliveryBefore)
            #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
            #expect(fixture.mutationInterlock.isBlocked)

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.failedFileSystem.file?.data == sourceBytes)
            #expect(fixture.deliveryJournal.current() == deliveryBefore)
        }
    }

    @Test func matchingRetryTagWithSetDisjointIdentitiesFailsClosed()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 299,
            state: .acceptingOutput,
            revision: 89
        )
        let failedBefore = try #require(fixture.failedFileSystem.file?.data)
        fixture.deliveryJournal.install(
            try fixture.provenanceOnlyCollisionRecord(for: source)
        )
        let deliveryBefore = try #require(
            fixture.deliveryJournal.current()
        )

        #expect(try await fixture.recover() == .pendingLocalRecovery)
        #expect(fixture.failedFileSystem.file?.data == failedBefore)
        #expect(fixture.deliveryJournal.current() == deliveryBefore)
        #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
    }

    @Test func crossFieldDeliveryIdentityCollisionAlsoFailsClosed()
        async throws {
        for currentField in 0..<4 {
            for retryField in 0..<4 where currentField != retryField {
                let fixture = try FailedRetryRecoveryFixture()
                let index = 330 + currentField * 10 + retryField
                let source = try fixture.installRetryRow(
                    index: index,
                    state: .acceptingOutput,
                    revision: 130 + Int64(currentField * 10 + retryField)
                )
                let sourceBytes = try #require(
                    fixture.failedFileSystem.file?.data
                )
                fixture.deliveryJournal.install(
                    try fixture.crossFieldCollisionRecord(
                        for: source,
                        currentField: currentField,
                        retryField: retryField
                    )
                )
                let deliveryBefore = try #require(
                    fixture.deliveryJournal.current()
                )

                #expect(
                    try await fixture.recover() == .pendingLocalRecovery
                )
                #expect(
                    fixture.failedFileSystem.file?.data == sourceBytes
                )
                #expect(
                    fixture.deliveryJournal.current() == deliveryBefore
                )
                #expect(
                    fixture.mutationInterlock.hasRetryDeliveryRelation
                )
            }
        }
    }

    @Test func exactIdentityWithoutExactRetryProvenanceFailsClosed()
        async throws {
        for (offset, variant) in [
            (0, FailedRetryRecoveryDeliveryVariant.untagged),
            (1, FailedRetryRecoveryDeliveryVariant.wrongRetryTag),
        ] {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: 320 + offset,
                state: .acceptingOutput,
                revision: 100 + Int64(offset)
            )
            let failedBytes = try #require(fixture.failedFileSystem.file?.data)
            fixture.deliveryJournal.install(
                try fixture.retryDeliveryRecord(
                    for: source,
                    variant: variant
                )
            )
            let deliveryBefore = try #require(
                fixture.deliveryJournal.current()
            )

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.failedFileSystem.file?.data == failedBytes)
            #expect(fixture.deliveryJournal.current() == deliveryBefore)
            #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
        }
    }

    @Test func semanticallyInvalidExactRetryDeliveryFailsClosed()
        async throws {
        let variants: [FailedRetryRecoveryDeliveryVariant] = [
            .pendingReplacement,
            .missingHistoryMarker,
            .automaticInsertionEnabled,
            .wrongOutputIntent,
            .wrongHistoryGeneration,
            .wrongHistoryModel,
            .wrongHistoryLanguage,
            .wrongHistoryDuration,
            .wrongKeepLatest,
            .discarded,
            .published,
        ]
        for (offset, variant) in variants.enumerated() {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: 340 + offset,
                state: .acceptingOutput,
                revision: 110 + Int64(offset)
            )
            let failedBytes = try #require(fixture.failedFileSystem.file?.data)
            fixture.deliveryJournal.install(
                try fixture.retryDeliveryRecord(
                    for: source,
                    variant: variant
                )
            )
            let deliveryBefore = try #require(
                fixture.deliveryJournal.current()
            )

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.failedFileSystem.file?.data == failedBytes)
            #expect(fixture.deliveryJournal.current() == deliveryBefore)
            #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
        }
    }

    @Test func unavailableOrUnreadableDeliveryRootFailsClosed()
        async throws {
        for (offset, error) in [
            (0, IOSAcceptedOutputDeliveryError.malformedData),
            (1, IOSAcceptedOutputDeliveryError.unsupportedSchemaVersion),
            (2, IOSAcceptedOutputDeliveryError.dataProtectionUnavailable),
            (3, IOSAcceptedOutputDeliveryError.readFailed),
        ] {
            let fixture = try FailedRetryRecoveryFixture()
            _ = try fixture.installRetryRow(
                index: 360 + offset,
                state: .acceptingOutput,
                revision: 120 + Int64(offset)
            )
            let failedBytes = try #require(fixture.failedFileSystem.file?.data)
            fixture.deliveryJournal.install(
                try fixture.unrelatedDeliveryRecord(index: 960 + offset)
            )
            let deliveryBefore = try #require(
                fixture.deliveryJournal.current()
            )
            fixture.deliveryJournal.failLoads(with: error)

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.failedFileSystem.file?.data == failedBytes)
            #expect(fixture.deliveryJournal.current() == deliveryBefore)
            #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
            #expect(fixture.deliveryJournal.events == ["load"])
        }
    }

    @Test func preAcceptanceCollisionCannotCancelReservedOrDispatchedRetry()
        async throws {
        for (offset, state, tagged) in [
            (0, IOSFailedHistoryRetryOperationState.reserved, false),
            (1, IOSFailedHistoryRetryOperationState.providerDispatched, true),
        ] {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: 380 + offset,
                state: state,
                revision: 140 + Int64(offset)
            )
            let failedBytes = try #require(fixture.failedFileSystem.file?.data)
            let collision = if tagged {
                try fixture.retryDeliveryRecord(
                    for: source,
                    variant: .exact
                )
            } else {
                try fixture.partialCollisionRecord(
                    for: source,
                    matchingMask: 1
                )
            }
            fixture.deliveryJournal.install(collision)
            let deliveryBefore = try #require(
                fixture.deliveryJournal.current()
            )

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.failedFileSystem.file?.data == failedBytes)
            #expect(fixture.deliveryJournal.current() == deliveryBefore)
            #expect(fixture.mutationInterlock.requiresRetryRecoveryScan)
            #expect(!fixture.mutationInterlock.hasRetryDeliveryProtection)
        }
    }

    @Test func pendingAcceptedOutputRecoversHistoryAndTombstonesFailure()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 401,
            state: .acceptingOutput,
            revision: 120,
            retryCount: 7,
            outputIntent: .translate
        )
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .pending,
                acceptedText: "Recovered accepted output"
            )
        )

        #expect(try await fixture.recover() == .acceptedOutputRecovered)
        let failed = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(failed.entries.isEmpty)
        let tombstone = try #require(failed.audioCleanup.first)
        #expect(tombstone.attemptID == source.attemptID)
        #expect(
            tombstone.audioRelativeIdentifier
                == source.audioRelativeIdentifier
        )
        #expect(tombstone.byteCount == source.byteCount)

        let accepted = try #require(
            try await fixture.acceptedHistoryStore.load()
        )
        let historyRow = try #require(accepted.entries.first)
        #expect(historyRow.deliveryID == source.retryOperation?.deliveryID)
        #expect(historyRow.acceptedText == "Recovered accepted output")
        #expect(historyRow.outputIntent == source.outputIntent)
        #expect(historyRow.policyGeneration == source.policyGeneration)

        let delivery = try #require(fixture.deliveryJournal.current())
        #expect(delivery.record.historyWrite?.state == .committed)
        #expect(!fixture.mutationInterlock.isBlocked)
    }

    @Test func terminalAcceptedOutputSkipsHistoryReplayAndTombstonesFailure()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 402,
            state: .acceptingOutput,
            revision: 130
        )
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .committed,
                acceptedText: "Already terminal"
            )
        )

        #expect(try await fixture.recover() == .acceptedOutputRecovered)
        let failed = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(failed.entries.isEmpty)
        #expect(failed.audioCleanup.count == 1)
        #expect(try await fixture.acceptedHistoryStore.load() == nil)
        #expect(!fixture.mutationInterlock.isBlocked)
    }

    @Test func rollbackAmbiguousExactTerminalRetryStaysProtected()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 404,
            state: .acceptingOutput,
            revision: 134
        )
        let failedBytes = try #require(fixture.failedFileSystem.file?.data)
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .committed,
                acceptedText: "Future terminal retry",
                createdAt: fixture.now.addingTimeInterval(60)
            )
        )
        let deliveryBefore = try #require(fixture.deliveryJournal.current())

        #expect(try await fixture.recover() == .pendingLocalRecovery)
        #expect(fixture.failedFileSystem.file?.data == failedBytes)
        #expect(fixture.deliveryJournal.current() == deliveryBefore)
        #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
        #expect(fixture.mutationInterlock.isBlocked)
    }

    @Test func expiredExactRetryStillFinishesOnlyItsProtectedRelation()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 403,
            state: .acceptingOutput,
            revision: 135
        )
        let createdAt = fixture.now.addingTimeInterval(-172_800)
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .pending,
                acceptedText: "Expired but protected",
                createdAt: createdAt
            )
        )

        #expect(try await fixture.recover() == .acceptedOutputRecovered)
        let delivery = try #require(fixture.deliveryJournal.current()?.record)
        #expect(delivery.historyWrite?.state == .committed)
        #expect(delivery.updatedAt == delivery.expiresAt)
        let failed = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(failed.entries.isEmpty)
        #expect(failed.audioCleanup.count == 1)
    }

    @Test func cutoverModeStopsAfterOneHistoryTransitionThenFinishes()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 501,
            state: .acceptingOutput,
            revision: 150
        )
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .pending,
                acceptedText: "One action per cutover call"
            )
        )

        #expect(
            try await fixture.recover(stopAfterHistoryTransition: true)
                == .pendingLocalRecovery
        )
        let retained = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(retained.entries == [source])
        #expect(retained.audioCleanup.isEmpty)
        #expect(
            fixture.deliveryJournal.current()?.record.historyWrite?.state
                == .committed
        )
        #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)

        #expect(
            try await fixture.recover(stopAfterHistoryTransition: true)
                == .acceptedOutputRecovered
        )
        let completed = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(completed.entries.isEmpty)
        #expect(completed.audioCleanup.count == 1)
        #expect(!fixture.mutationInterlock.isBlocked)
    }

    @Test func recoveredClearUncertaintyReconcilesSourceAndOutcome()
        async throws {
        for outcomeVisible in [false, true] {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: outcomeVisible ? 602 : 601,
                state: .providerDispatched,
                revision: outcomeVisible ? 181 : 180
            )
            fixture.failedFileSystem.replaceFailure = .init(
                error: .commitUncertain,
                commitBeforeThrowing: outcomeVisible
            )
            fixture.failedFileSystem.readErrorAfterNextReplace = .readFailed

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.mutationInterlock.isBlocked)

            #expect(try await fixture.recover() == .retryCancelled)
            #expect(fixture.failedFileSystem.readError == .readFailed)
            fixture.failedFileSystem.readError = nil
            let durable = try #require(
                try await fixture.failedHistoryStore.load()
            )
            let retained = try #require(durable.entries.first)
            expectRetryRecoveryRowPreserved(source, retained)
            #expect(retained.retryOperation == nil)
            #expect(!fixture.mutationInterlock.isBlocked)
        }
    }

    @Test func recoveredSuccessUncertaintyReconcilesSourceAndOutcome()
        async throws {
        for outcomeVisible in [false, true] {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: outcomeVisible ? 604 : 603,
                state: .acceptingOutput,
                revision: outcomeVisible ? 183 : 182
            )
            fixture.deliveryJournal.install(
                try fixture.exactRetryDeliveryRecord(
                    for: source,
                    historyState: .committed,
                    acceptedText: "Durable success uncertainty"
                )
            )
            fixture.failedFileSystem.replaceFailure = .init(
                error: .commitUncertain,
                commitBeforeThrowing: outcomeVisible
            )
            fixture.failedFileSystem.readErrorAfterNextReplace = .readFailed

            #expect(try await fixture.recover() == .pendingLocalRecovery)
            #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
            #expect(try await fixture.recover() == .acceptedOutputRecovered)
            #expect(fixture.failedFileSystem.readError == .readFailed)
            fixture.failedFileSystem.readError = nil
            let failed = try #require(
                try await fixture.failedHistoryStore.load()
            )
            #expect(failed.entries.isEmpty)
            #expect(failed.audioCleanup.count == 1)
            #expect(!fixture.mutationInterlock.isBlocked)
        }
    }

    @Test func ordinaryDeliveryReadStaysBlockedUntilRecoveryRetiresRelation()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 701,
            state: .acceptingOutput,
            revision: 210
        )
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .committed,
                acceptedText: "Protected accepted output"
            )
        )

        await #expect(
            throws: IOSAcceptedOutputDeliveryError.commitUncertain
        ) {
            _ = try await fixture.deliveryStore.load()
        }
        #expect(try await fixture.recover() == .acceptedOutputRecovered)
        guard case .active(let visible)? = try await fixture.deliveryStore.load()
        else {
            Issue.record("Expected recovered delivery to become readable")
            return
        }
        #expect(visible.acceptedText == "Protected accepted output")
    }

    @Test func productionRegistrySharesColdStartBarrierUntilStrictScan()
        async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "failed-retry-production-barrier-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry(
            retryRecoveryScanRequiredOnContextCreation: true
        )
        let context = registry.context(for: root)
        let sameContext = registry.context(
            for: root.appendingPathComponent("..").appendingPathComponent(
                root.lastPathComponent
            )
        )
        #expect(context === sameContext)
        #expect(
            context.failedHistoryMutationInterlock
                === sameContext.failedHistoryMutationInterlock
        )
        #expect(
            context.failedHistoryMutationInterlock
                .requiresRetryRecoveryScan
        )
        await #expect(
            throws: IOSAcceptedOutputDeliveryError.commitUncertain
        ) {
            _ = try await context.deliveryStore.load()
        }
        await #expect(
            throws: IOSPendingRecordingError.localRecoveryPending
        ) {
            _ = try await context.pendingRecordingStore.load()
        }
        await #expect(
            throws: IOSFailedHistoryError.commitUncertain
        ) {
            _ = try await context.operationGate.perform { lease in
                try await context.failedHistoryStore.prepareDelete(
                    attemptID: failedHistoryTestUUID(
                        namespace: 0xdf,
                        index: 1
                    ),
                    operationLeaseAuthorization: lease
                )
            }
        }

        let coordinator = IOSAcceptedHistoryCoordinator(
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
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.localRecoveryPending
        ) {
            _ = try await coordinator.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(
            try await coordinator.recoverInterruptedFailedHistoryRetry()
                == .noWork
        )
        #expect(
            !context.failedHistoryMutationInterlock
                .requiresRetryRecoveryScan
        )
        #expect(try await context.deliveryStore.load() == nil)
        #expect(try await context.pendingRecordingStore.load() == nil)
    }

    @Test func corruptFailedRootPreservesBytesAndColdStartBarrier()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let corrupt = Data([0xff, 0x00, 0x7f])
        fixture.failedFileSystem.install(corrupt)
        fixture.failedFileSystem.resetEvents()

        #expect(try await fixture.recover() == .pendingLocalRecovery)
        #expect(fixture.failedFileSystem.file?.data == corrupt)
        #expect(fixture.mutationInterlock.requiresRetryRecoveryScan)
        #expect(fixture.deliveryJournal.events.isEmpty)
    }

    @Test func refreshedTerminalCannotSubstituteAcceptedBytes() async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 702,
            state: .acceptingOutput,
            revision: 220
        )
        let pending = try fixture.exactRetryDeliveryRecord(
            for: source,
            historyState: .pending,
            acceptedText: "Original accepted bytes"
        )
        fixture.deliveryJournal.install(pending)
        fixture.deliveryJournal.substituteNextReplace(
            with: try fixture.replacingDeliveryRecord(
                pending,
                acceptedText: "Substituted accepted bytes",
                historyState: .committed
            ),
            afterSuccessfulReplaces: 1
        )

        #expect(try await fixture.recover() == .pendingLocalRecovery)
        let failed = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(failed.entries == [source])
        #expect(failed.audioCleanup.isEmpty)
        #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
        #expect(
            fixture.deliveryJournal.current()?.record.acceptedText
                == "Substituted accepted bytes"
        )
    }

    @Test func policyCutoverUsesNewGenerationAndOneRetryActionPerCall()
        async throws {
        for (offset, command) in FailedRetryRecoveryPolicyCommand
            .allCases.enumerated() {
            let fixture = try FailedRetryRecoveryFixture()
            if command.startsDisabled {
                fixture.policyJournal.install(
                    try IOSHistoryPolicyState(
                        revision: 2,
                        historyEnabled: false,
                        policyGeneration: 2
                    )
                )
            }
            let policyBefore = try #require(
                try await fixture.policyStore.load()
            )
            let source = try fixture.installRetryRow(
                index: 801 + offset,
                state: .acceptingOutput,
                revision: 240 + Int64(offset)
            )
            fixture.deliveryJournal.install(
                try fixture.exactRetryDeliveryRecord(
                    for: source,
                    historyState: .pending,
                    acceptedText: "Invalidate under a newer generation"
                )
            )

            #expect(
                try await command.perform(on: fixture.coordinator)
                    == .pendingLocalRecovery
            )
            let policyAfterFirst = try #require(
                try await fixture.policyStore.load()
            )
            #expect(
                policyAfterFirst.policyGeneration
                    == policyBefore.policyGeneration + 1
            )
            #expect(
                policyAfterFirst.historyEnabled
                    == command.resultingEnabled
            )
            let failedAfterFirst = try #require(
                try await fixture.failedHistoryStore.load()
            )
            #expect(failedAfterFirst.entries == [source])
            #expect(failedAfterFirst.audioCleanup.isEmpty)
            #expect(
                fixture.deliveryJournal.current()?.record.historyWrite?.state
                    == .cancelled
            )

            #expect(
                try await command.perform(on: fixture.coordinator)
                    == .pendingLocalRecovery
            )
            let policyAfterSecond = try #require(
                try await fixture.policyStore.load()
            )
            #expect(policyAfterSecond == policyAfterFirst)
            let failedAfterSecond = try #require(
                try await fixture.failedHistoryStore.load()
            )
            #expect(failedAfterSecond.entries.isEmpty)
            #expect(failedAfterSecond.audioCleanup.count == 1)
        }
    }

    @Test func stateChangingPolicyCommandsRecoverPreAcceptanceRetries()
        async throws {
        for (commandOffset, command) in FailedRetryRecoveryPolicyCommand
            .allCases.enumerated() {
            for (stateOffset, state) in [
                IOSFailedHistoryRetryOperationState.reserved,
                .providerDispatched,
            ].enumerated() {
                let fixture = try FailedRetryRecoveryFixture()
                if command.startsDisabled {
                    fixture.policyJournal.install(
                        try IOSHistoryPolicyState(
                            revision: 2,
                            historyEnabled: false,
                            policyGeneration: 2
                        )
                    )
                }
                let policyBefore = try #require(
                    try await fixture.policyStore.load()
                )
                let source = try fixture.installRetryRow(
                    index: 840 + commandOffset * 10 + stateOffset,
                    state: state,
                    revision: 270
                        + Int64(commandOffset * 10 + stateOffset)
                )

                #expect(
                    try await command.perform(on: fixture.coordinator)
                        == .pendingLocalRecovery
                )
                let changedPolicy = try #require(
                    try await fixture.policyStore.load()
                )
                #expect(
                    changedPolicy.policyGeneration
                        == policyBefore.policyGeneration + 1
                )
                #expect(
                    changedPolicy.historyEnabled
                        == command.resultingEnabled
                )
                let failed = try #require(
                    try await fixture.failedHistoryStore.load()
                )
                let retained = try #require(failed.entries.first)
                expectRetryRecoveryRowPreserved(source, retained)
                #expect(retained.retryOperation == nil)
                #expect(failed.audioCleanup.isEmpty)
                #expect(!fixture.mutationInterlock.isBlocked)

                #expect(
                    try await fixture.coordinator
                        .recoverHistoryPolicyCleanup()
                        == .pendingLocalRecovery
                )
                #expect(
                    try await fixture.policyStore.load() == changedPolicy
                )
                #expect(await fixture.cutoverState.current() != nil)
            }
        }
    }

    @Test func confirmedPolicyNoopPreservesCurrentRetryBytes() async throws {
        for initiallyEnabled in [true, false] {
            let fixture = try FailedRetryRecoveryFixture()
            if !initiallyEnabled {
                fixture.policyJournal.install(
                    try IOSHistoryPolicyState(
                        revision: 2,
                        historyEnabled: false,
                        policyGeneration: 2
                    )
                )
            }
            _ = try fixture.installRetryRow(
                index: initiallyEnabled ? 802 : 803,
                state: .reserved,
                revision: initiallyEnabled ? 250 : 251
            )
            let failedBytes = try #require(
                fixture.failedFileSystem.file?.data
            )

            #expect(
                try await fixture.coordinator.setHistoryEnabled(
                    initiallyEnabled
                ) == .pendingLocalRecovery
            )
            let policy = try #require(
                try await fixture.policyStore.load()
            )
            #expect(policy.historyEnabled == initiallyEnabled)
            #expect(fixture.failedFileSystem.file?.data == failedBytes)
            #expect(fixture.mutationInterlock.requiresRetryRecoveryScan)
            #expect(await fixture.cutoverState.current() == nil)

            #expect(
                try await fixture.coordinator
                    .recoverInterruptedFailedHistoryRetry()
                    == .retryCancelled
            )
            #expect(try await fixture.policyStore.load() == policy)
            let recovered = try #require(
                try await fixture.failedHistoryStore.load()
            )
            #expect(recovered.entries.first?.retryOperation == nil)
            #expect(recovered.audioCleanup.isEmpty)
            #expect(!fixture.mutationInterlock.isBlocked)
        }
    }

    @Test func standaloneRecoveryDefersToEveryRetainedPolicyCutoverBoundary()
        async throws {
        for (offset, postBoundary) in [(0, false), (1, true)] {
            let fixture = try FailedRetryRecoveryFixture()
            let source = try fixture.installRetryRow(
                index: 820 + offset,
                state: .acceptingOutput,
                revision: 255 + Int64(offset)
            )
            fixture.deliveryJournal.install(
                try fixture.exactRetryDeliveryRecord(
                    for: source,
                    historyState: .pending,
                    acceptedText: "Policy cutover owns recovery"
                )
            )
            let failedBytes = try #require(fixture.failedFileSystem.file?.data)
            let deliveryBefore = try #require(
                fixture.deliveryJournal.current()
            )
            let policy = try await fixture.confirmedPolicyReceipt()
            let work = IOSHistoryPolicyCutoverWork(
                ownerIdentity: fixture.context.ownerIdentity,
                command: .setEnabled(false),
                phase: postBoundary
                    ? .reconcilingFailedHistory(policy)
                    : .policyCaptured(policy),
                policyChanged: postBoundary ? true : nil
            )
            await fixture.cutoverState.store(work)

            #expect(
                try await fixture.coordinator
                    .recoverInterruptedFailedHistoryRetry()
                    == .pendingLocalRecovery
            )
            #expect(await fixture.cutoverState.current() == work)
            #expect(fixture.failedFileSystem.file?.data == failedBytes)
            #expect(fixture.deliveryJournal.current() == deliveryBefore)
            #expect(fixture.failedFileSystem.events.isEmpty)
            #expect(fixture.deliveryJournal.events.isEmpty)
            #expect(fixture.mutationInterlock.requiresRetryRecoveryScan)
            #expect(!fixture.mutationInterlock.hasRetryDeliveryProtection)
        }
    }

    @Test func policyCutoverRefreshesPendingRelaunchReservationAcrossGeneration()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 824,
            state: .acceptingOutput,
            revision: 259
        )
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .pending,
                acceptedText: "Resume under the newer policy"
            )
        )
        fixture.deliveryJournal.failLoads(with: .readFailed)

        #expect(
            try await fixture.coordinator
                .recoverInterruptedFailedHistoryRetry()
                == .pendingLocalRecovery
        )
        #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
        fixture.deliveryJournal.clearLoadFailure()

        #expect(
            try await fixture.coordinator.setHistoryEnabled(false)
                == .pendingLocalRecovery
        )
        let changedPolicy = try #require(
            try await fixture.policyStore.load()
        )
        #expect(changedPolicy.policyGeneration == 2)
        #expect(!changedPolicy.historyEnabled)

        #expect(
            try await fixture.coordinator.recoverHistoryPolicyCleanup()
                == .pendingLocalRecovery
        )
        #expect(try await fixture.policyStore.load() == changedPolicy)
        let failed = try IOSFailedHistoryWireCodec.decode(
            try #require(fixture.failedFileSystem.file?.data)
        )
        #expect(failed.entries.isEmpty)
        #expect(failed.audioCleanup.count == 1)
        #expect(!fixture.mutationInterlock.requiresRetryRecoveryScan)
        #expect(!fixture.mutationInterlock.hasRetryDeliveryProtection)
        #expect(await fixture.cutoverState.current() != nil)
    }

    @Test func retainedRelaunchReservationRejectsPolicyEquivocationAndRollback()
        async throws {
        let retainedPolicy = try IOSHistoryPolicyState(
            revision: 2,
            historyEnabled: false,
            policyGeneration: 2
        )
        let rejectedPolicies = [
            try IOSHistoryPolicyState(
                revision: 2,
                historyEnabled: true,
                policyGeneration: 2
            ),
            IOSHistoryPolicyState.baseline,
        ]

        for (offset, rejectedPolicy) in rejectedPolicies.enumerated() {
            let fixture = try FailedRetryRecoveryFixture()
            fixture.policyJournal.install(retainedPolicy)
            let source = try fixture.installRetryRow(
                index: 860 + offset,
                state: .acceptingOutput,
                revision: 300 + Int64(offset),
                policyGeneration: 1
            )
            fixture.deliveryJournal.install(
                try fixture.exactRetryDeliveryRecord(
                    for: source,
                    historyState: .pending,
                    acceptedText: "Policy receipt must stay monotonic"
                )
            )
            fixture.deliveryJournal.failLoads(with: .readFailed)

            #expect(
                try await fixture.coordinator
                    .recoverInterruptedFailedHistoryRetry()
                    == .pendingLocalRecovery
            )
            #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
            fixture.deliveryJournal.clearLoadFailure()
            let failedBefore = try #require(
                fixture.failedFileSystem.file?.data
            )
            let deliveryBefore = try #require(
                fixture.deliveryJournal.current()
            )
            fixture.policyJournal.install(rejectedPolicy)

            #expect(
                try await fixture.coordinator
                    .recoverInterruptedFailedHistoryRetry()
                    == .pendingLocalRecovery
            )
            #expect(fixture.failedFileSystem.file?.data == failedBefore)
            #expect(fixture.deliveryJournal.current() == deliveryBefore)
            #expect(fixture.mutationInterlock.hasRetryDeliveryRelation)
        }
    }

    @Test func futureFailedGenerationFailsBeforeEveryPolicyCommand()
        async throws {
        for (commandOffset, command) in FailedRetryRecoveryPolicyCommand
            .allCases.enumerated() {
            for sourceIsTombstone in [false, true] {
                let fixture = try FailedRetryRecoveryFixture()
                if command.startsDisabled {
                    fixture.policyJournal.install(
                        try IOSHistoryPolicyState(
                            revision: 1,
                            historyEnabled: false,
                            policyGeneration: 1
                        )
                    )
                }
                let policyBefore = try #require(
                    try await fixture.policyStore.load()
                )
                let index = 870 + commandOffset * 10
                    + (sourceIsTombstone ? 1 : 0)
                if sourceIsTombstone {
                    fixture.failedFileSystem.install(
                        try IOSFailedHistoryWireCodec.encode(
                            IOSFailedHistoryEnvelope(
                                revision: 310 + Int64(index),
                                entries: [],
                                audioCleanup: [
                                    try failedHistoryTestAudioCleanup(
                                        index: index,
                                        policyGeneration:
                                            policyBefore.policyGeneration + 1
                                    ),
                                ]
                            )
                        )
                    )
                    fixture.failedFileSystem.resetEvents()
                } else {
                    _ = try fixture.installRetryRow(
                        index: index,
                        state: .reserved,
                        revision: 310 + Int64(index),
                        policyGeneration:
                            policyBefore.policyGeneration + 1
                    )
                }
                let failedBefore = try #require(
                    fixture.failedFileSystem.file?.data
                )

                await #expect(
                    throws: IOSFailedHistoryError.stalePolicyGeneration
                ) {
                    _ = try await command.perform(on: fixture.coordinator)
                }
                #expect(
                    try await fixture.policyStore.load() == policyBefore
                )
                #expect(fixture.failedFileSystem.file?.data == failedBefore)
                #expect(await fixture.cutoverState.current() == nil)
                #expect(fixture.mutationInterlock.requiresRetryRecoveryScan)
            }
        }
    }

    @Test func policyRetryMarkerUncertaintyResumesWithoutGenerationNPlusTwo()
        async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 803,
            state: .acceptingOutput,
            revision: 260
        )
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .pending,
                acceptedText: "Visible cancellation uncertainty"
            )
        )
        fixture.deliveryJournal.failNextReplace(
            .commitUncertain,
            commitBeforeThrowing: true,
            afterSuccessfulReplaces: 2
        )

        #expect(
            try await fixture.coordinator.clearHistoryPolicy()
                == .pendingLocalRecovery
        )
        #expect(
            try await fixture.policyStore.load()?.policyGeneration == 2
        )
        #expect(
            fixture.deliveryJournal.current()?.record.historyWrite?.state
                == .cancelled
        )
        #expect(
            try await fixture.coordinator.clearHistoryPolicy()
                == .pendingLocalRecovery
        )
        #expect(
            try await fixture.policyStore.load()?.policyGeneration == 2
        )
        let failed = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(failed.entries.isEmpty)
        #expect(failed.audioCleanup.count == 1)
        #expect(await fixture.acceptanceState.current() == nil)
    }

    @Test func concurrentRecoveryCommitsOnlyOneTerminalOutcome() async throws {
        let fixture = try FailedRetryRecoveryFixture()
        let source = try fixture.installRetryRow(
            index: 804,
            state: .acceptingOutput,
            revision: 270
        )
        fixture.deliveryJournal.install(
            try fixture.exactRetryDeliveryRecord(
                for: source,
                historyState: .committed,
                acceptedText: "One concurrent recovery"
            )
        )

        async let first = fixture.recover()
        async let second = fixture.recover()
        let resolutions = try await [first, second]
        #expect(
            resolutions.filter { $0 == .acceptedOutputRecovered }.count == 1
        )
        #expect(resolutions.filter { $0 == .noWork }.count == 1)
        let failed = try #require(
            try await fixture.failedHistoryStore.load()
        )
        #expect(failed.revision == 271)
        #expect(failed.entries.isEmpty)
        #expect(failed.audioCleanup.count == 1)
    }

    @Test func everyRelaunchCapabilityUsesRedactedReflection() async throws {
        let preAcceptance = try FailedRetryRecoveryFixture()
        _ = try preAcceptance.installRetryRow(
            index: 901,
            state: .reserved,
            revision: 280
        )
        try await preAcceptance.gate.perform { lease in
            let policy = try await preAcceptance.confirmedPolicyReceipt()
            let directive = try await preAcceptance.failedHistoryStore
                .prepareRetryRelaunchDirective(
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            guard case .cancel(let inspection) = directive,
                  let reservation = await preAcceptance.retryState
                    .reserveRelaunchRecovery(
                        of: inspection,
                        operationLeaseAuthorization: lease
                    ) else {
                Issue.record("Expected reserved relaunch capabilities")
                return
            }
            let proof = try await preAcceptance.deliveryStore
                .proveFailedRetryPreAcceptanceAbsence(
                    reservation: reservation,
                    operationLeaseAuthorization: lease
                )
            let preparation = try await preAcceptance.failedHistoryStore
                .prepareRecoveredRetryClear(
                    reservation: reservation,
                    preAcceptanceAbsenceProof: proof,
                    operationLeaseAuthorization: lease
                )
            expectRetryRecoveryRedacted(directive)
            expectRetryRecoveryRedacted(inspection)
            expectRetryRecoveryRedacted(reservation.reservationID)
            expectRetryRecoveryRedacted(reservation)
            expectRetryRecoveryRedacted(proof.observedSlot)
            expectRetryRecoveryRedacted(proof)
            expectRetryRecoveryRedacted(preparation)
            if case .commit(let authorization) = preparation {
                expectRetryRecoveryRedacted(authorization)
                let receipt = try await preAcceptance.failedHistoryStore
                    .commitRecoveredRetryClear(using: authorization)
                expectRetryRecoveryRedacted(receipt)
            }
        }

        let absentAcceptedOutput = try FailedRetryRecoveryFixture()
        _ = try absentAcceptedOutput.installRetryRow(
            index: 902,
            state: .acceptingOutput,
            revision: 285
        )
        try await absentAcceptedOutput.gate.perform { lease in
            let policy = try await absentAcceptedOutput
                .confirmedPolicyReceipt()
            let directive = try await absentAcceptedOutput.failedHistoryStore
                .prepareRetryRelaunchDirective(
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            guard case .inspectAcceptingOutput(let inspection) = directive,
                  let reservation = await absentAcceptedOutput.retryState
                    .reserveRelaunchRecovery(
                        of: inspection,
                        operationLeaseAuthorization: lease
                    ) else {
                Issue.record("Expected absent accepted-output inspection")
                return
            }
            let acceptingInspection = try await absentAcceptedOutput
                .failedHistoryStore.installRetryAcceptingRecoveryRelation(
                    reservation: reservation,
                    operationLeaseAuthorization: lease
                )
            let classification = try await absentAcceptedOutput.deliveryStore
                .classifyFailedRetryRelaunchDelivery(
                    acceptingInspection: acceptingInspection,
                    operationLeaseAuthorization: lease
                )
            guard case .missing(let proof) = classification else {
                Issue.record("Expected accepted-output absence proof")
                return
            }
            expectRetryRecoveryRedacted(proof.observedSlot)
            expectRetryRecoveryRedacted(proof)
        }

        let accepting = try FailedRetryRecoveryFixture()
        let source = try accepting.installRetryRow(
            index: 903,
            state: .acceptingOutput,
            revision: 290
        )
        accepting.deliveryJournal.install(
            try accepting.exactRetryDeliveryRecord(
                for: source,
                historyState: .committed,
                acceptedText: "Redacted relation text"
            )
        )
        try await accepting.gate.perform { lease in
            let policy = try await accepting.confirmedPolicyReceipt()
            let directive = try await accepting.failedHistoryStore
                .prepareRetryRelaunchDirective(
                    using: policy,
                    operationLeaseAuthorization: lease
                )
            guard case .inspectAcceptingOutput(let inspection) = directive,
                  let reservation = await accepting.retryState
                    .reserveRelaunchRecovery(
                        of: inspection,
                        operationLeaseAuthorization: lease
                    ) else {
                Issue.record("Expected accepting relaunch capabilities")
                return
            }
            let acceptingInspection = try await accepting.failedHistoryStore
                .installRetryAcceptingRecoveryRelation(
                    reservation: reservation,
                    operationLeaseAuthorization: lease
                )
            let classification = try await accepting.deliveryStore
                .classifyFailedRetryRelaunchDelivery(
                    acceptingInspection: acceptingInspection,
                    operationLeaseAuthorization: lease
                )
            guard case .matching(let relation) = classification else {
                Issue.record("Expected exact recovered relation")
                return
            }
            let terminal = try await accepting.deliveryStore
                .confirmFailedRetryRecoveredTerminalDelivery(
                    relation: relation,
                    operationLeaseAuthorization: lease
                )
            let success = try await accepting.failedHistoryStore
                .prepareRecoveredRetrySuccess(
                    terminalProof: terminal,
                    operationLeaseAuthorization: lease
                )
            expectRetryRecoveryRedacted(acceptingInspection)
            expectRetryRecoveryRedacted(classification)
            expectRetryRecoveryRedacted(relation)
            expectRetryRecoveryRedacted(
                IOSFailedHistoryRetryDeliveryRelationReceipt
                    .relaunched(relation)
            )
            expectRetryRecoveryRedacted(terminal)
            expectRetryRecoveryRedacted(success)
            if case .commit(let authorization) = success {
                expectRetryRecoveryRedacted(authorization)
                let receipt = try await accepting.failedHistoryStore
                    .commitRecoveredRetrySuccess(using: authorization)
                expectRetryRecoveryRedacted(receipt)
            }
        }
        expectRetryRecoveryRedacted(
            IOSFailedHistoryRetryRecoveryResolution.pendingLocalRecovery
        )
    }
}

private func expectRetryRecoveryRedacted<Value>(_ value: Value) {
    #expect(String(describing: value).contains("redacted"))
    #expect(String(reflecting: value).contains("redacted"))
    #expect(Mirror(reflecting: value).children.isEmpty)
}

private func expectRetryRecoveryRowPreserved(
    _ source: IOSFailedHistoryEntry,
    _ target: IOSFailedHistoryEntry
) {
    #expect(target.attemptID == source.attemptID)
    #expect(target.createdAt == source.createdAt)
    #expect(target.updatedAt == source.updatedAt)
    #expect(target.policyGeneration == source.policyGeneration)
    #expect(target.failureCategory == source.failureCategory)
    #expect(target.pipelineStage == source.pipelineStage)
    #expect(target.retryCount == source.retryCount)
    #expect(target.outputIntent == source.outputIntent)
    #expect(target.transcriptionModel == source.transcriptionModel)
    #expect(
        target.transcriptionLanguageCode
            == source.transcriptionLanguageCode
    )
    #expect(target.durationMilliseconds == source.durationMilliseconds)
    #expect(target.byteCount == source.byteCount)
    #expect(
        target.audioRelativeIdentifier
            == source.audioRelativeIdentifier
    )
    #expect(target.ownershipState == source.ownershipState)
}

private enum FailedRetryRecoveryDeliveryVariant: Equatable {
    case exact
    case untagged
    case wrongRetryTag
    case pendingReplacement
    case missingHistoryMarker
    case automaticInsertionEnabled
    case wrongOutputIntent
    case wrongHistoryGeneration
    case wrongHistoryModel
    case wrongHistoryLanguage
    case wrongHistoryDuration
    case wrongKeepLatest
    case discarded
    case published
}

private enum FailedRetryRecoveryPolicyCommand: CaseIterable {
    case clear
    case disable
    case enable

    var startsDisabled: Bool { self == .enable }

    var resultingEnabled: Bool {
        switch self {
        case .clear, .enable: true
        case .disable: false
        }
    }

    func perform(
        on coordinator: IOSAcceptedHistoryCoordinator
    ) async throws -> IOSHistoryPolicyCleanupDisposition {
        switch self {
        case .clear:
            try await coordinator.clearHistoryPolicy()
        case .disable:
            try await coordinator.setHistoryEnabled(false)
        case .enable:
            try await coordinator.setHistoryEnabled(true)
        }
    }
}

private final class FailedRetryRecoveryFixture: @unchecked Sendable {
    let rootURL: URL
    let registry: IOSAcceptedHistoryCoordinatorProcessContextRegistry
    let context: IOSAcceptedHistoryCoordinatorProcessContext
    let gate: IOSPersistenceOperationGate
    let mutationInterlock = IOSFailedHistoryMutationInterlock(
        retryRecoveryScanRequired: true
    )
    let failedFileSystem = FailedHistoryFakeFileSystem()
    let deliveryJournal = FailedRetryRecoveryDeliveryJournal()
    let policyJournal = FailedRetryRecoveryPolicyJournal()
    let acceptedHistoryJournal = FailedRetryRecoveryAcceptedHistoryJournal()
    let retryState = IOSFailedHistoryRetryLiveOwnerState()
    let policyStore: IOSHistoryPolicyStore
    let acceptedHistoryStore: IOSAcceptedHistoryStore
    let failedHistoryStore: IOSFailedHistoryStore
    let deliveryStore: IOSAcceptedOutputDeliveryStore
    let outboxStore: IOSAcceptedHistoryOutboxStore
    let acceptanceState = IOSAcceptedHistoryAcceptanceOperationState()
    let pendingReplacementState =
        IOSAcceptedHistoryPendingReplacementOperationState()
    let workerState = IOSAcceptedHistoryOutboxWorkerOperationState()
    let cutoverState = IOSHistoryPolicyCutoverOperationState()
    let failedTransferState = IOSFailedHistoryTransferOperationState()
    let failedAudioCleanupState =
        IOSFailedHistoryAudioCleanupOperationState()
    let coordinator: IOSAcceptedHistoryCoordinator
    let now: Date

    init() throws {
        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "failed-retry-recovery-\(UUID().uuidString)",
                isDirectory: true
            )
        try FileManager.default.createDirectory(
            at: rootURL,
            withIntermediateDirectories: true
        )
        registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        context = registry.context(for: rootURL)
        gate = context.operationGate
        now = try failedHistoryTestDate(offsetMilliseconds: 50_000)

        policyStore = IOSHistoryPolicyStore(
            journal: policyJournal,
            capabilityOwnerIdentity: context.ownerIdentity,
            now: { [now] in now }
        )
        acceptedHistoryStore = IOSAcceptedHistoryStore(
            journal: acceptedHistoryJournal,
            now: { [now] in now },
            capabilityOwnerIdentity: context.ownerIdentity
        )
        let outboxStoreIdentity = IOSAcceptedHistoryOutboxStoreIdentity()
        deliveryStore = IOSAcceptedOutputDeliveryStore(
            journal: deliveryJournal,
            now: { [now] in now },
            monotonicNowNanoseconds: { 1_000_000 },
            outboxStoreIdentity: outboxStoreIdentity,
            capabilityOwnerIdentity: context.ownerIdentity,
            operationGateIdentity: gate.identity,
            failedHistoryMutationInterlock: mutationInterlock
        )
        failedHistoryStore = IOSFailedHistoryStore(
            journal: FoundationIOSFailedHistoryJournalRepository(
                fileSystem: failedFileSystem
            ),
            capabilityOwnerIdentity: context.ownerIdentity,
            operationGateIdentity: gate.identity,
            expectedPendingStoreIdentity:
                context.pendingRecordingStoreIdentity,
            expectedDeliveryStoreIdentity: deliveryStore.storeIdentity,
            retryLiveOwnerState: retryState,
            repositoryGuard: context.repositoryGuard,
            mutationInterlock: mutationInterlock,
            now: { [now] in now }
        )
        outboxStore = IOSAcceptedHistoryOutboxStore(
            applicationSupportDirectoryURL: rootURL,
            deliveryStoreIdentity: deliveryStore.storeIdentity,
            storeIdentity: outboxStoreIdentity,
            capabilityOwnerIdentity: context.ownerIdentity,
            operationGateIdentity: gate.identity,
            repositoryGuard: context.repositoryGuard
        )
        guard let physicalRootIdentity = context.repositoryBinding
                .physicalRootIdentity,
              retryState.bindProviderRegistration(
                  failedStoreIdentity: failedHistoryStore.storeIdentity,
                  ownerIdentity: context.ownerIdentity,
                  physicalRootIdentity: physicalRootIdentity
              ) else {
            throw IOSFailedHistoryError.repositoryIdentityConflict
        }
        coordinator = IOSAcceptedHistoryCoordinator(
            policyStore: policyStore,
            acceptedHistoryStore: acceptedHistoryStore,
            failedHistoryStore: failedHistoryStore,
            outboxStore: outboxStore,
            deliveryStore: deliveryStore,
            operationGate: gate,
            acceptanceState: acceptanceState,
            pendingReplacementState: pendingReplacementState,
            outboxWorkerState: workerState,
            policyCutoverState: cutoverState,
            failedHistoryTransferState: failedTransferState,
            failedHistoryAudioCleanupState: failedAudioCleanupState,
            failedHistoryRetryState: retryState,
            ownerIdentity: context.ownerIdentity,
            repositoryIdentityState: context.repositoryIdentityState,
            repositoryRegistration:
                IOSAcceptedHistoryCoordinatorRepositoryRegistration(
                    registry: registry,
                    context: context,
                    applicationSupportDirectoryURL: rootURL
                )
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: rootURL)
    }

    func installRetryRow(
        index: Int,
        state: IOSFailedHistoryRetryOperationState,
        revision: Int64,
        retryCount: Int32 = 4,
        outputIntent: DictationOutputIntent = .standard,
        operationCreatedAt: Date? = nil,
        policyGeneration: Int64 = 1
    ) throws -> IOSFailedHistoryEntry {
        let operation = try failedHistoryTestRetryOperation(
            index: index,
            createdAt: operationCreatedAt,
            state: state
        )
        let row = try failedHistoryTestEntry(
            index: index,
            updatedAt: operation.createdAt,
            policyGeneration: policyGeneration,
            retryCount: retryCount,
            outputIntent: outputIntent,
            retryOperation: operation
        )
        failedFileSystem.install(
            try IOSFailedHistoryWireCodec.encode(
                IOSFailedHistoryEnvelope(
                    revision: revision,
                    entries: [row],
                    audioCleanup: []
                )
            )
        )
        failedFileSystem.resetEvents()
        return row
    }

    func recover(
        stopAfterHistoryTransition: Bool = false
    ) async throws -> IOSFailedHistoryRetryRecoveryResolution {
        try await gate.perform { lease in
            let state = try #require(try await self.policyStore.load())
            let policy = try await self.policyStore.confirm(
                expected: IOSHistoryPolicyExpectation(state: state)
            )
            return await IOSAcceptedHistoryCoordinator
                .recoverInterruptedFailedHistoryRetryWithinLease(
                    policyReceipt: policy,
                    policyStore: self.policyStore,
                    acceptedHistoryStore: self.acceptedHistoryStore,
                    failedStore: self.failedHistoryStore,
                    deliveryStore: self.deliveryStore,
                    retryState: self.retryState,
                    acceptanceState: self.acceptanceState,
                    pendingReplacementState:
                        self.pendingReplacementState,
                    ownerIdentity: self.context.ownerIdentity,
                    operationLeaseAuthorization: lease,
                    stopAfterHistoryTransition:
                        stopAfterHistoryTransition
                )
        }
    }

    func confirmedPolicyReceipt() async throws -> IOSHistoryPolicyReceipt {
        let state = try #require(try await policyStore.load())
        return try await policyStore.confirm(
            expected: IOSHistoryPolicyExpectation(state: state)
        )
    }

    func exactRetryDeliveryRecord(
        for row: IOSFailedHistoryEntry,
        historyState: IOSAcceptedOutputHistoryWriteState,
        acceptedText: String,
        createdAt explicitCreatedAt: Date? = nil
    ) throws -> IOSAcceptedOutputDeliveryRecord {
        let operation = try #require(row.retryOperation)
        let createdAt = explicitCreatedAt ?? now
        return try IOSAcceptedOutputDeliveryRecord(
            revision: 1,
            deliveryID: operation.deliveryID,
            sessionID: operation.sessionID,
            attemptID: row.attemptID,
            transcriptID: operation.transcriptID,
            failedRetryID: operation.retryID,
            acceptedText: acceptedText,
            outputIntent: row.outputIntent,
            createdAt: createdAt,
            updatedAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(86_400),
            deliveryState: .pending,
            automaticInsertionPreferenceEnabled: false,
            keepLatestResult: operation.keepLatestResult,
            publicationGeneration: 0,
            historyWrite: try IOSAcceptedOutputHistoryWrite(
                state: historyState,
                policyGeneration: row.policyGeneration,
                transcriptionModel: row.transcriptionModel,
                transcriptionLanguageCode:
                    row.transcriptionLanguageCode,
                durationMilliseconds: row.durationMilliseconds
            )
        )
    }

    func retryDeliveryRecord(
        for row: IOSFailedHistoryEntry,
        variant: FailedRetryRecoveryDeliveryVariant
    ) throws -> IOSAcceptedOutputDeliveryRecord {
        let operation = try #require(row.retryOperation)
        let failedRetryID: UUID?
        switch variant {
        case .untagged, .discarded:
            failedRetryID = nil
        case .wrongRetryTag:
            failedRetryID = failedHistoryTestUUID(
                namespace: 0xf0,
                index: 1
            )
        case .exact, .pendingReplacement, .missingHistoryMarker,
             .automaticInsertionEnabled, .wrongOutputIntent,
             .wrongHistoryGeneration, .wrongHistoryModel,
             .wrongHistoryLanguage, .wrongHistoryDuration,
             .wrongKeepLatest, .published:
            failedRetryID = operation.retryID
        }

        let historyWrite: IOSAcceptedOutputHistoryWrite?
        if variant == .missingHistoryMarker || variant == .discarded {
            historyWrite = nil
        } else {
            historyWrite = try IOSAcceptedOutputHistoryWrite(
                state: variant == .pendingReplacement
                    ? .pendingReplacement
                    : .pending,
                policyGeneration: variant == .wrongHistoryGeneration
                    ? row.policyGeneration + 1
                    : row.policyGeneration,
                transcriptionModel: variant == .wrongHistoryModel
                    ? "wrong-recovery-model"
                    : row.transcriptionModel,
                transcriptionLanguageCode: variant == .wrongHistoryLanguage
                    ? (row.transcriptionLanguageCode == "fr" ? "de" : "fr")
                    : row.transcriptionLanguageCode,
                durationMilliseconds: variant == .wrongHistoryDuration
                    ? (row.durationMilliseconds == 2_000 ? 2_001 : 2_000)
                    : row.durationMilliseconds
            )
        }

        return try IOSAcceptedOutputDeliveryRecord(
            revision: 1,
            deliveryID: operation.deliveryID,
            sessionID: operation.sessionID,
            attemptID: row.attemptID,
            transcriptID: operation.transcriptID,
            failedRetryID: failedRetryID,
            acceptedText: variant == .discarded
                ? nil
                : "Retry-shaped delivery",
            outputIntent: variant == .wrongOutputIntent
                ? .translate
                : row.outputIntent,
            createdAt: now,
            updatedAt: now,
            expiresAt: now.addingTimeInterval(86_400),
            deliveryState: variant == .discarded
                ? .discarded
                : .pending,
            automaticInsertionPreferenceEnabled:
                variant == .automaticInsertionEnabled,
            keepLatestResult: variant == .wrongKeepLatest
                ? !operation.keepLatestResult
                : operation.keepLatestResult,
            publicationGeneration: variant == .published ? 1 : 0,
            historyWrite: historyWrite
        )
    }

    func replacingDeliveryRecord(
        _ source: IOSAcceptedOutputDeliveryRecord,
        acceptedText: String,
        historyState: IOSAcceptedOutputHistoryWriteState
    ) throws -> IOSAcceptedOutputDeliveryRecord {
        try IOSAcceptedOutputDeliveryRecord(
            revision: source.revision + 1,
            deliveryID: source.deliveryID,
            sessionID: source.sessionID,
            attemptID: source.attemptID,
            transcriptID: source.transcriptID,
            failedRetryID: source.failedRetryID,
            acceptedText: acceptedText,
            outputIntent: source.outputIntent,
            createdAt: source.createdAt,
            updatedAt: source.updatedAt,
            expiresAt: source.expiresAt,
            deliveryState: source.deliveryState,
            automaticInsertionPreferenceEnabled:
                source.automaticInsertionPreferenceEnabled,
            keepLatestResult: source.keepLatestResult,
            publicationGeneration: source.publicationGeneration,
            historyWrite: try #require(source.historyWrite)
                .replacingState(historyState)
        )
    }

    func partialCollisionRecord(
        for row: IOSFailedHistoryEntry,
        matchingMask: Int
    ) throws -> IOSAcceptedOutputDeliveryRecord {
        let operation = try #require(row.retryOperation)
        guard (1...14).contains(matchingMask) else {
            throw IOSAcceptedOutputDeliveryError.invalidRecord
        }
        return try deliveryRecord(
            index: 900 + matchingMask,
            deliveryID: matchingMask & 1 == 0
                ? nil : operation.deliveryID,
            sessionID: matchingMask & 2 == 0
                ? nil : operation.sessionID,
            attemptID: matchingMask & 4 == 0
                ? nil : row.attemptID,
            transcriptID: matchingMask & 8 == 0
                ? nil : operation.transcriptID
        )
    }

    func provenanceOnlyCollisionRecord(
        for row: IOSFailedHistoryEntry
    ) throws -> IOSAcceptedOutputDeliveryRecord {
        let operation = try #require(row.retryOperation)
        return try deliveryRecord(
            index: 899,
            failedRetryID: operation.retryID
        )
    }

    func crossFieldCollisionRecord(
        for row: IOSFailedHistoryEntry,
        currentField: Int,
        retryField: Int
    ) throws -> IOSAcceptedOutputDeliveryRecord {
        let operation = try #require(row.retryOperation)
        let retryIdentities = [
            operation.deliveryID,
            operation.sessionID,
            row.attemptID,
            operation.transcriptID,
        ]
        guard (0..<4).contains(currentField),
              (0..<4).contains(retryField),
              currentField != retryField else {
            throw IOSAcceptedOutputDeliveryError.invalidRecord
        }
        let collision = retryIdentities[retryField]
        return try deliveryRecord(
            index: 950 + currentField * 10 + retryField,
            deliveryID: currentField == 0 ? collision : nil,
            sessionID: currentField == 1 ? collision : nil,
            attemptID: currentField == 2 ? collision : nil,
            transcriptID: currentField == 3 ? collision : nil
        )
    }

    func unrelatedDeliveryRecord(
        index: Int,
        createdAt: Date? = nil
    ) throws -> IOSAcceptedOutputDeliveryRecord {
        try deliveryRecord(index: index, createdAt: createdAt)
    }

    private func deliveryRecord(
        index: Int,
        deliveryID: UUID? = nil,
        sessionID: UUID? = nil,
        attemptID: UUID? = nil,
        transcriptID: UUID? = nil,
        failedRetryID: UUID? = nil,
        createdAt explicitCreatedAt: Date? = nil
    ) throws -> IOSAcceptedOutputDeliveryRecord {
        let createdAt = explicitCreatedAt ?? now
        return try IOSAcceptedOutputDeliveryRecord(
            revision: 1,
            deliveryID: deliveryID
                ?? failedHistoryTestUUID(namespace: 0xa0, index: index),
            sessionID: sessionID
                ?? failedHistoryTestUUID(namespace: 0xa1, index: index),
            attemptID: attemptID
                ?? failedHistoryTestUUID(namespace: 0xa2, index: index),
            transcriptID: transcriptID
                ?? failedHistoryTestUUID(namespace: 0xa3, index: index),
            failedRetryID: failedRetryID,
            acceptedText: "Unrelated \(index)",
            outputIntent: .standard,
            createdAt: createdAt,
            updatedAt: createdAt,
            expiresAt: createdAt.addingTimeInterval(86_400),
            deliveryState: .pending,
            automaticInsertionPreferenceEnabled: false,
            keepLatestResult: true,
            publicationGeneration: 0,
            historyWrite: nil
        )
    }
}

private final class FailedRetryRecoveryPolicyJournal:
    IOSHistoryPolicyJournalStoring,
    @unchecked Sendable {
    private let lock = NSLock()
    private var nextToken: UInt64 = 2
    private var snapshot = IOSHistoryPolicyJournalSnapshot(
        state: .baseline,
        fileRevision: IOSStrictProtectedRecordFileRevision(testingToken: 1)
    )

    func install(_ state: IOSHistoryPolicyState) {
        lock.withLock {
            snapshot = IOSHistoryPolicyJournalSnapshot(
                state: state,
                fileRevision: IOSStrictProtectedRecordFileRevision(
                    testingToken: nextToken
                )
            )
            nextToken += 1
        }
    }

    func load() throws -> IOSHistoryPolicyJournalSnapshot? {
        lock.withLock { snapshot }
    }

    func replace(
        _ state: IOSHistoryPolicyState,
        expected: IOSHistoryPolicyJournalSnapshot
    ) throws -> IOSHistoryPolicyJournalSnapshot {
        try lock.withLock {
            guard snapshot == expected else {
                throw IOSHistoryPolicyError.compareAndSwapFailed
            }
            let replacement = IOSHistoryPolicyJournalSnapshot(
                state: state,
                fileRevision: IOSStrictProtectedRecordFileRevision(
                    testingToken: nextToken
                )
            )
            nextToken += 1
            snapshot = replacement
            return replacement
        }
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport {
        _ = now
        return .empty
    }
}

private final class FailedRetryRecoveryAcceptedHistoryJournal:
    IOSAcceptedHistoryJournalStoring,
    @unchecked Sendable {
    private let lock = NSLock()
    private var nextToken: UInt64 = 1
    private var snapshot: IOSAcceptedHistoryJournalSnapshot?

    func load() throws -> IOSAcceptedHistoryJournalSnapshot? {
        lock.withLock { snapshot }
    }

    func create(
        _ envelope: IOSAcceptedHistoryEnvelope,
        authorization: IOSAcceptedHistoryJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryJournalSnapshot {
        _ = authorization
        return try lock.withLock {
            guard snapshot == nil else {
                throw IOSAcceptedHistoryError.slotOccupied
            }
            let created = IOSAcceptedHistoryJournalSnapshot(
                envelope: envelope,
                fileRevision: makeRevisionLocked()
            )
            snapshot = created
            return created
        }
    }

    func replace(
        _ envelope: IOSAcceptedHistoryEnvelope,
        expected: IOSAcceptedHistoryJournalSnapshot,
        authorization: IOSAcceptedHistoryJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryJournalSnapshot {
        _ = authorization
        return try lock.withLock {
            guard snapshot?.fileRevision == expected.fileRevision else {
                throw IOSAcceptedHistoryError.compareAndSwapFailed
            }
            let replacement = IOSAcceptedHistoryJournalSnapshot(
                envelope: envelope,
                fileRevision: makeRevisionLocked()
            )
            snapshot = replacement
            return replacement
        }
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport {
        _ = now
        return .empty
    }

    private func makeRevisionLocked()
        -> IOSStrictProtectedRecordFileRevision {
        defer { nextToken += 1 }
        return IOSStrictProtectedRecordFileRevision(
            testingToken: nextToken
        )
    }
}

private final class FailedRetryRecoveryDeliveryJournal:
    IOSAcceptedOutputDeliveryJournalStoring,
    @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: IOSAcceptedOutputDeliveryJournalSnapshot?
    private var nextToken: UInt64 = 1
    private var nextReplaceFailure:
        (
            remaining: Int,
            error: IOSAcceptedOutputDeliveryError,
            commitBeforeThrowing: Bool
        )?
    private var nextReplaceSubstitution:
        (remaining: Int, record: IOSAcceptedOutputDeliveryRecord)?
    private var loadError: IOSAcceptedOutputDeliveryError?
    private(set) var events: [String] = []

    func install(_ record: IOSAcceptedOutputDeliveryRecord) {
        lock.withLock {
            snapshot = IOSAcceptedOutputDeliveryJournalSnapshot(
                record: record,
                fileRevision: makeRevisionLocked()
            )
            events = []
        }
    }

    func current() -> IOSAcceptedOutputDeliveryJournalSnapshot? {
        lock.withLock { snapshot }
    }

    func failLoads(with error: IOSAcceptedOutputDeliveryError) {
        lock.withLock { loadError = error }
    }

    func clearLoadFailure() {
        lock.withLock { loadError = nil }
    }

    func failNextReplace(
        _ error: IOSAcceptedOutputDeliveryError,
        commitBeforeThrowing: Bool,
        afterSuccessfulReplaces: Int = 0
    ) {
        lock.withLock {
            nextReplaceFailure = (
                max(0, afterSuccessfulReplaces),
                error,
                commitBeforeThrowing
            )
        }
    }

    func substituteNextReplace(
        with record: IOSAcceptedOutputDeliveryRecord,
        afterSuccessfulReplaces: Int = 0
    ) {
        lock.withLock {
            nextReplaceSubstitution = (
                max(0, afterSuccessfulReplaces),
                record
            )
        }
    }

    func load() throws -> IOSAcceptedOutputDeliveryJournalSnapshot? {
        try lock.withLock {
            events.append("load")
            if let loadError { throw loadError }
            return snapshot
        }
    }

    func loadOpaque() throws -> IOSAcceptedOutputDeliveryOpaqueSnapshot? {
        nil
    }

    func create(
        _ record: IOSAcceptedOutputDeliveryRecord
    ) throws -> IOSAcceptedOutputDeliveryJournalSnapshot {
        try lock.withLock {
            events.append("create")
            guard snapshot == nil else {
                throw IOSAcceptedOutputDeliveryError.slotOccupied
            }
            let created = IOSAcceptedOutputDeliveryJournalSnapshot(
                record: record,
                fileRevision: makeRevisionLocked()
            )
            snapshot = created
            return created
        }
    }

    func replace(
        _ record: IOSAcceptedOutputDeliveryRecord,
        expected: IOSAcceptedOutputDeliveryJournalSnapshot
    ) throws -> IOSAcceptedOutputDeliveryJournalSnapshot {
        try lock.withLock {
            events.append("replace")
            guard snapshot?.fileRevision == expected.fileRevision else {
                throw IOSAcceptedOutputDeliveryError.compareAndSwapFailed
            }
            if var failure = nextReplaceFailure {
                if failure.remaining == 0 {
                    nextReplaceFailure = nil
                    if failure.commitBeforeThrowing {
                        snapshot = IOSAcceptedOutputDeliveryJournalSnapshot(
                            record: record,
                            fileRevision: makeRevisionLocked()
                        )
                    }
                    throw failure.error
                }
                failure.remaining -= 1
                nextReplaceFailure = failure
            }
            let committedRecord: IOSAcceptedOutputDeliveryRecord
            if var substitution = nextReplaceSubstitution {
                if substitution.remaining == 0 {
                    committedRecord = substitution.record
                    nextReplaceSubstitution = nil
                } else {
                    substitution.remaining -= 1
                    nextReplaceSubstitution = substitution
                    committedRecord = record
                }
            } else {
                committedRecord = record
            }
            let replacement = IOSAcceptedOutputDeliveryJournalSnapshot(
                record: committedRecord,
                fileRevision: makeRevisionLocked()
            )
            snapshot = replacement
            return replacement
        }
    }

    func remove(
        expected: IOSAcceptedOutputDeliveryJournalSnapshot
    ) throws {
        try lock.withLock {
            events.append("remove")
            guard snapshot?.fileRevision == expected.fileRevision else {
                throw IOSAcceptedOutputDeliveryError.compareAndSwapFailed
            }
            snapshot = nil
        }
    }

    func removeOpaque(
        expected: IOSAcceptedOutputDeliveryOpaqueSnapshot
    ) throws {
        _ = expected
        throw IOSAcceptedOutputDeliveryError.compareAndSwapFailed
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport {
        _ = now
        return .empty
    }

    private func makeRevisionLocked()
        -> IOSStrictProtectedRecordFileRevision {
        defer { nextToken += 1 }
        return IOSStrictProtectedRecordFileRevision(
            testingToken: nextToken
        )
    }
}
