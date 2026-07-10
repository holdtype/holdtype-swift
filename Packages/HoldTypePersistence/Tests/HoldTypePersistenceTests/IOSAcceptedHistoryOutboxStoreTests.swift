import Darwin
import Foundation
import Testing
@testable import HoldTypePersistence

struct IOSAcceptedHistoryOutboxStoreTests {
    @Test func missingReadAndFirstTransferAreStrictAndReceiptIsIdentityBound() async throws {
        let fixture = OutboxStoreFixture(now: outboxStoreDate())
        #expect(try await fixture.store.load() == nil)
        #expect(fixture.journal.events == ["load"])
        fixture.journal.resetEvents()
        let capabilities = try await outboxCapabilities(index: 1)

        let receipt = try await fixture.store.transfer(
            delivery: capabilities.delivery,
            policy: capabilities.policy
        )
        #expect(
            receipt.provesMembershipForDeliveryRemoval(
                for: capabilities.delivery
            )
        )
        let confirmedEntry = try #require(
            receipt.confirmedEntryForAcceptedDecision()
        )
        #expect(
            confirmedEntry.hasSameImmutableBytes(
                as: try outboxEntry(from: capabilities.delivery)
            )
        )
        #expect(
            String(describing: receipt)
                == "IOSAcceptedHistoryOutboxReceipt(redacted)"
        )
        #expect(receipt.customMirror.children.isEmpty)
        #expect(fixture.journal.currentEnvelope?.revision == 1)
        #expect(fixture.journal.currentEnvelope?.entries.count == 1)
        #expect(fixture.journal.events == ["load", "create:1"])

        let wrong = try outboxDeliveryAuthorization(index: 2)
        #expect(!receipt.provesMembershipForDeliveryRemoval(for: wrong))
        let wrongFileRevision = try outboxDeliveryAuthorization(
            index: 1,
            fileRevisionToken: 10_001
        )
        #expect(
            !receipt.provesMembershipForDeliveryRemoval(
                for: wrongFileRevision
            )
        )
    }

    @Test func transferUsesOneTemporalSnapshotAndExactBoundaries() async throws {
        let createdAt = outboxStoreDate()
        let rollbackFixture = OutboxStoreFixture(
            now: createdAt.addingTimeInterval(-0.001)
        )
        let capabilities = try await outboxCapabilities(
            index: 10,
            createdAt: createdAt
        )
        await #expect(
            throws: IOSAcceptedHistoryOutboxError.clockRollbackAmbiguous
        ) {
            try await rollbackFixture.store.transfer(
                delivery: capabilities.delivery,
                policy: capabilities.policy
            )
        }

        let liveFixture = OutboxStoreFixture(now: createdAt)
        _ = try await liveFixture.store.transfer(
            delivery: capabilities.delivery,
            policy: capabilities.policy
        )

        let expiredFixture = OutboxStoreFixture(
            now: createdAt.addingTimeInterval(86_400)
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.expired) {
            try await expiredFixture.store.transfer(
                delivery: capabilities.delivery,
                policy: capabilities.policy
            )
        }

        let submillisecondCreatedAtFixture = OutboxStoreFixture(
            now: createdAt.addingTimeInterval(-0.0004)
        )
        _ = try await submillisecondCreatedAtFixture.store.transfer(
            delivery: capabilities.delivery,
            policy: capabilities.policy
        )

        let submillisecondExpiryFixture = OutboxStoreFixture(
            now: createdAt.addingTimeInterval(86_400 - 0.0004)
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.expired) {
            try await submillisecondExpiryFixture.store.transfer(
                delivery: capabilities.delivery,
                policy: capabilities.policy
            )
        }
        #expect(rollbackFixture.clock.readCount == 1)
        #expect(liveFixture.clock.readCount == 1)
        #expect(expiredFixture.clock.readCount == 1)
        #expect(submillisecondCreatedAtFixture.clock.readCount == 1)
        #expect(submillisecondExpiryFixture.clock.readCount == 1)
    }

    @Test func sealedTransferRequiresPendingEnabledMatchingGeneration() async throws {
        let fixture = OutboxStoreFixture(now: outboxStoreDate())
        let capabilities = try await outboxCapabilities(
            index: 20,
            generation: 2
        )
        let disabled = try await outboxPolicyReceipt(
            generation: 2,
            enabled: false
        )
        await #expect(
            throws: IOSAcceptedHistoryOutboxError.stalePolicyGeneration
        ) {
            try await fixture.store.transfer(
                delivery: capabilities.delivery,
                policy: disabled
            )
        }
        let wrongGeneration = try await outboxPolicyReceipt(
            generation: 3,
            enabled: true
        )
        await #expect(
            throws: IOSAcceptedHistoryOutboxError.stalePolicyGeneration
        ) {
            try await fixture.store.transfer(
                delivery: capabilities.delivery,
                policy: wrongGeneration
            )
        }
        let terminal = try outboxDeliveryAuthorization(
            index: 21,
            generation: 2,
            historyState: .committed
        )
        await #expect(
            throws: IOSAcceptedHistoryOutboxError.stalePolicyGeneration
        ) {
            try await fixture.store.transfer(
                delivery: terminal,
                policy: capabilities.policy
            )
        }
    }

    @Test func duplicateConfirmsWithoutPruningOrRevisionChange() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let capabilities = try await outboxCapabilities(
            index: 30,
            generation: 2,
            createdAt: now.addingTimeInterval(-10)
        )
        let duplicate = try outboxEntry(from: capabilities.delivery)
        let expired = try outboxStoredEntry(
            index: 31,
            generation: 1,
            createdAt: now.addingTimeInterval(-100_000)
        )
        fixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(
                revision: 7,
                entries: [expired, duplicate]
            )
        )

        let receipt = try await fixture.store.transfer(
            delivery: capabilities.delivery,
            policy: capabilities.policy
        )
        #expect(
            receipt.provesMembershipForDeliveryRemoval(
                for: capabilities.delivery
            )
        )
        #expect(fixture.journal.currentEnvelope?.revision == 7)
        #expect(fixture.journal.currentEnvelope?.entries == [expired, duplicate])
        #expect(fixture.journal.events.suffix(2) == ["load", "replace:7"])
    }

    @Test func collisionScanIncludesExpiredAndStaleEntriesAndUsesBytes() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let capabilities = try await outboxCapabilities(
            index: 40,
            generation: 2,
            acceptedText: "e\u{301}",
            createdAt: now.addingTimeInterval(-10)
        )
        let colliding = try outboxStoredEntry(
            index: 40,
            generation: 1,
            acceptedText: "é",
            createdAt: now.addingTimeInterval(-100_000)
        )
        fixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(
                revision: 3,
                entries: [colliding]
            )
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.collision) {
            try await fixture.store.transfer(
                delivery: capabilities.delivery,
                policy: capabilities.policy
            )
        }

        let transcriptFixture = OutboxStoreFixture(now: now)
        let candidate = try await outboxCapabilities(
            index: 41,
            createdAt: now.addingTimeInterval(-10)
        )
        let transcriptCollision = try outboxStoredEntry(
            index: 42,
            transcriptID: candidate.delivery.record.transcriptID,
            createdAt: now.addingTimeInterval(-20)
        )
        transcriptFixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(
                revision: 1,
                entries: [transcriptCollision]
            )
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.collision) {
            try await transcriptFixture.store.transfer(
                delivery: candidate.delivery,
                policy: candidate.policy
            )
        }
    }

    @Test func transferAtomicallyPrunesExpiredAndStaleRows() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let stale = try outboxStoredEntry(
            index: 50,
            generation: 1,
            createdAt: now.addingTimeInterval(-100)
        )
        let expired = try outboxStoredEntry(
            index: 51,
            generation: 2,
            createdAt: now.addingTimeInterval(-100_000)
        )
        let current = try outboxStoredEntry(
            index: 52,
            generation: 2,
            createdAt: now.addingTimeInterval(-50)
        )
        fixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(
                revision: 4,
                entries: [expired, stale, current]
            )
        )
        let candidate = try await outboxCapabilities(
            index: 53,
            generation: 2,
            createdAt: now.addingTimeInterval(-10)
        )

        _ = try await fixture.store.transfer(
            delivery: candidate.delivery,
            policy: candidate.policy
        )
        #expect(fixture.journal.currentEnvelope?.revision == 5)
        #expect(fixture.journal.currentEnvelope?.entries.map(\.deliveryID) == [
            current.deliveryID,
            candidate.delivery.record.deliveryID,
        ])
    }

    @Test func futureGenerationFailsClosedWithoutPruning() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let future = try outboxStoredEntry(
            index: 60,
            generation: 3,
            createdAt: now.addingTimeInterval(-100)
        )
        fixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(
                revision: 2,
                entries: [future]
            )
        )
        let candidate = try await outboxCapabilities(
            index: 61,
            generation: 2,
            createdAt: now.addingTimeInterval(-10)
        )
        await #expect(
            throws: IOSAcceptedHistoryOutboxError.stalePolicyGeneration
        ) {
            try await fixture.store.transfer(
                delivery: candidate.delivery,
                policy: candidate.policy
            )
        }
        #expect(fixture.journal.currentEnvelope?.entries == [future])
    }

    @Test func twentyLiveEntriesNeverEvictForAnotherTransfer() async throws {
        let now = outboxStoreDate()
        let entries = try (0..<20).map { offset in
            try outboxStoredEntry(
                index: 100 + offset,
                createdAt: now.addingTimeInterval(Double(-100 + offset))
            )
        }
        let source = try IOSAcceptedHistoryOutboxEnvelope(
            revision: 9,
            entries: entries
        )
        let fixture = OutboxStoreFixture(now: now)
        fixture.journal.install(source)
        let candidate = try await outboxCapabilities(
            index: 200,
            createdAt: now.addingTimeInterval(-10)
        )

        await #expect(throws: IOSAcceptedHistoryOutboxError.capacityExceeded) {
            try await fixture.store.transfer(
                delivery: candidate.delivery,
                policy: candidate.policy
            )
        }
        #expect(fixture.journal.currentEnvelope == source)
        #expect(!fixture.journal.events.contains(where: { $0.hasPrefix("replace") }))
    }

    @Test func encodedByteCapacityNeverEvictsLiveEntries() async throws {
        let now = outboxStoreDate()
        let hugeText = "a" + String(repeating: "\t", count: 131_070) + "b"
        let entries = try (0..<15).map { offset in
            try outboxStoredEntry(
                index: 300 + offset,
                acceptedText: hugeText,
                createdAt: now.addingTimeInterval(Double(-100 + offset))
            )
        }
        let source = try IOSAcceptedHistoryOutboxEnvelope(
            revision: 1,
            entries: entries
        )
        _ = try IOSAcceptedHistoryOutboxWireCodec.encode(source)
        let fixture = OutboxStoreFixture(now: now)
        fixture.journal.install(source)
        let candidate = try await outboxCapabilities(
            index: 399,
            acceptedText: hugeText,
            createdAt: now.addingTimeInterval(-10)
        )

        await #expect(throws: IOSAcceptedHistoryOutboxError.capacityExceeded) {
            try await fixture.store.transfer(
                delivery: candidate.delivery,
                policy: candidate.policy
            )
        }
        #expect(fixture.journal.currentEnvelope == source)
    }

    @Test func insufficientExpiredPruningDoesNotCommitPartialCleanup() async throws {
        let now = outboxStoreDate()
        let hugeText = "a" + String(repeating: "\t", count: 131_070) + "b"
        let expired = try outboxStoredEntry(
            index: 380,
            createdAt: now.addingTimeInterval(-100_000)
        )
        let live = try (0..<15).map { offset in
            try outboxStoredEntry(
                index: 381 + offset,
                acceptedText: hugeText,
                createdAt: now.addingTimeInterval(Double(-100 + offset))
            )
        }
        let source = try IOSAcceptedHistoryOutboxEnvelope(
            revision: 8,
            entries: [expired] + live
        )
        _ = try IOSAcceptedHistoryOutboxWireCodec.encode(source)
        let fixture = OutboxStoreFixture(now: now)
        fixture.journal.install(source)
        let candidate = try await outboxCapabilities(
            index: 398,
            acceptedText: hugeText,
            createdAt: now.addingTimeInterval(-10)
        )

        await #expect(throws: IOSAcceptedHistoryOutboxError.capacityExceeded) {
            try await fixture.store.transfer(
                delivery: candidate.delivery,
                policy: candidate.policy
            )
        }
        #expect(fixture.journal.currentEnvelope == source)
        #expect(
            fixture.journal.currentEnvelope?.entries.first?.deliveryID
                == expired.deliveryID
        )
    }

    @Test func rollbackInAnyPersistedEntryBlocksTransferWithoutMutation() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let future = try outboxStoredEntry(
            index: 400,
            createdAt: now.addingTimeInterval(1)
        )
        fixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(
                revision: 1,
                entries: [future]
            )
        )
        let candidate = try await outboxCapabilities(
            index: 401,
            createdAt: now
        )
        await #expect(
            throws: IOSAcceptedHistoryOutboxError.clockRollbackAmbiguous
        ) {
            try await fixture.store.transfer(
                delivery: candidate.delivery,
                policy: candidate.policy
            )
        }
        #expect(fixture.journal.currentEnvelope?.entries == [future])
    }

    @Test func confirmationRecoversExactExpiredOrRollbackMembership() async throws {
        let now = outboxStoreDate()
        for createdAt in [
            now.addingTimeInterval(-100_000),
            now.addingTimeInterval(1),
        ] {
            let fixture = OutboxStoreFixture(now: now)
            let capabilities = try await outboxCapabilities(
                index: createdAt < now ? 410 : 411,
                createdAt: createdAt
            )
            let entry = try outboxEntry(from: capabilities.delivery)
            fixture.journal.install(
                try IOSAcceptedHistoryOutboxEnvelope(
                    revision: 4,
                    entries: [entry]
                )
            )

            let receipt = try await fixture.store.confirmMembership(
                delivery: capabilities.delivery
            )
            #expect(
                receipt.provesMembershipForDeliveryRemoval(
                    for: capabilities.delivery
                )
            )
            #expect(fixture.journal.currentEnvelope?.revision == 4)
        }
    }

    @Test func duplicateAtMaximumSucceedsButNewMembershipOverflows() async throws {
        let now = outboxStoreDate()
        let duplicate = try await outboxCapabilities(
            index: 420,
            createdAt: now.addingTimeInterval(-10)
        )
        let entry = try outboxEntry(from: duplicate.delivery)
        let fixture = OutboxStoreFixture(now: now)
        fixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(
                revision: Int64.max,
                entries: [entry]
            )
        )
        _ = try await fixture.store.transfer(
            delivery: duplicate.delivery,
            policy: duplicate.policy
        )

        let other = try await outboxCapabilities(
            index: 421,
            createdAt: now.addingTimeInterval(-5)
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.revisionOverflow) {
            try await fixture.store.transfer(
                delivery: other.delivery,
                policy: other.policy
            )
        }
        #expect(fixture.journal.currentEnvelope?.entries == [entry])
    }

    @Test func uncertaintyBlocksOtherTransferAndConfirmsExactRetry() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let first = try await outboxCapabilities(index: 430, createdAt: now)
        fixture.journal.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: true
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await fixture.store.transfer(
                delivery: first.delivery,
                policy: first.policy
            )
        }
        let other = try await outboxCapabilities(index: 431, createdAt: now)
        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await fixture.store.transfer(
                delivery: other.delivery,
                policy: other.policy
            )
        }
        let receipt = try await fixture.store.transfer(
            delivery: first.delivery,
            policy: first.policy
        )
        #expect(
            receipt.provesMembershipForDeliveryRemoval(for: first.delivery)
        )
        #expect(fixture.journal.events.suffix(2) == ["load", "replace:1"])
    }

    @Test func prepublicationReplacementUncertaintyIsAStoreWideGate() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        fixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(revision: 1, entries: [])
        )
        let first = try await outboxCapabilities(index: 435, createdAt: now)
        fixture.journal.failNextReplace(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await fixture.store.transfer(
                delivery: first.delivery,
                policy: first.policy
            )
        }
        let other = try await outboxCapabilities(index: 436, createdAt: now)
        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await fixture.store.transfer(
                delivery: other.delivery,
                policy: other.policy
            )
        }

        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await fixture.store.confirmMembership(delivery: first.delivery)
        }
        #expect(fixture.journal.currentEnvelope?.revision == 1)
        #expect(fixture.journal.currentEnvelope?.entries.isEmpty == true)

        let receipt = try await fixture.store.transfer(
            delivery: first.delivery,
            policy: first.policy
        )
        #expect(
            receipt.provesMembershipForDeliveryRemoval(for: first.delivery)
        )
        #expect(fixture.journal.currentEnvelope?.revision == 2)
    }

    @Test func prepublicationCreateConfirmationNeverInsertsMembership() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let capabilities = try await outboxCapabilities(
            index: 437,
            createdAt: now
        )
        fixture.journal.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await fixture.store.transfer(
                delivery: capabilities.delivery,
                policy: capabilities.policy
            )
        }

        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await fixture.store.confirmMembership(
                delivery: capabilities.delivery
            )
        }
        #expect(fixture.journal.currentEnvelope == nil)
        #expect(fixture.journal.events.filter { $0 == "create:1" }.count == 1)
    }

    @Test func invisibleUncertainTransferRevalidatesTimeBeforePublishing() async throws {
        let now = outboxStoreDate()
        let createFixture = OutboxStoreFixture(now: now)
        let createCapabilities = try await outboxCapabilities(
            index: 438,
            createdAt: now
        )
        createFixture.journal.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await createFixture.store.transfer(
                delivery: createCapabilities.delivery,
                policy: createCapabilities.policy
            )
        }
        createFixture.clock.set(now.addingTimeInterval(86_400))
        await #expect(throws: IOSAcceptedHistoryOutboxError.expired) {
            try await createFixture.store.transfer(
                delivery: createCapabilities.delivery,
                policy: createCapabilities.policy
            )
        }
        #expect(createFixture.journal.currentEnvelope == nil)
        #expect(
            createFixture.journal.events.filter { $0 == "create:1" }.count == 1
        )
        let nextCapabilities = try await outboxCapabilities(
            index: 446,
            createdAt: now.addingTimeInterval(86_400)
        )
        let nextReceipt = try await createFixture.store.transfer(
            delivery: nextCapabilities.delivery,
            policy: nextCapabilities.policy
        )
        #expect(
            nextReceipt.provesMembershipForDeliveryRemoval(
                for: nextCapabilities.delivery
            )
        )

        let replaceFixture = OutboxStoreFixture(now: now)
        replaceFixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(revision: 1, entries: [])
        )
        let replaceCapabilities = try await outboxCapabilities(
            index: 439,
            createdAt: now
        )
        replaceFixture.journal.failNextReplace(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await replaceFixture.store.transfer(
                delivery: replaceCapabilities.delivery,
                policy: replaceCapabilities.policy
            )
        }
        replaceFixture.clock.set(now.addingTimeInterval(-0.001))
        await #expect(
            throws: IOSAcceptedHistoryOutboxError.clockRollbackAmbiguous
        ) {
            try await replaceFixture.store.transfer(
                delivery: replaceCapabilities.delivery,
                policy: replaceCapabilities.policy
            )
        }
        #expect(replaceFixture.journal.currentEnvelope?.revision == 1)
        #expect(replaceFixture.journal.currentEnvelope?.entries.isEmpty == true)
        #expect(
            replaceFixture.journal.events.filter { $0 == "replace:2" }.count
                == 1
        )

        replaceFixture.clock.set(now)
        let recovered = try await replaceFixture.store.transfer(
            delivery: replaceCapabilities.delivery,
            policy: replaceCapabilities.policy
        )
        #expect(
            recovered.provesMembershipForDeliveryRemoval(
                for: replaceCapabilities.delivery
            )
        )
        #expect(replaceFixture.journal.currentEnvelope?.revision == 2)
    }

    @Test func visibleUncertaintyRemainsConfirmableAcrossTimeBoundaries() async throws {
        let now = outboxStoreDate()
        for (index, confirmationTime) in [
            (442, now.addingTimeInterval(86_400)),
            (443, now.addingTimeInterval(-0.001)),
        ] {
            let fixture = OutboxStoreFixture(now: now)
            let capabilities = try await outboxCapabilities(
                index: index,
                createdAt: now
            )
            fixture.journal.failNextCreate(
                with: .commitUncertain,
                commitBeforeThrowing: true
            )
            await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
                try await fixture.store.transfer(
                    delivery: capabilities.delivery,
                    policy: capabilities.policy
                )
            }
            fixture.clock.set(confirmationTime)

            let receipt = try await fixture.store.confirmMembership(
                delivery: capabilities.delivery
            )
            #expect(
                receipt.provesMembershipForDeliveryRemoval(
                    for: capabilities.delivery
                )
            )
            #expect(fixture.journal.currentEnvelope?.revision == 1)
            #expect(fixture.clock.readCount == 1)
        }
    }

    @Test func snapshotObservationRecoversAfterRelaunchWithoutDelivery() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let capabilities = try await outboxCapabilities(
            index: 444,
            createdAt: now
        )
        _ = try await fixture.store.transfer(
            delivery: capabilities.delivery,
            policy: capabilities.policy
        )
        fixture.clock.set(now.addingTimeInterval(86_400))
        let relaunchedStore = fixture.makeStore()
        let observations = try #require(try await relaunchedStore.observe())
        let observation = try #require(observations.first)
        #expect(
            String(describing: observation)
                == "IOSAcceptedHistoryOutboxObservation(redacted)"
        )
        #expect(observation.customMirror.children.isEmpty)

        let receipt = try await relaunchedStore.confirmMembership(
            observation: observation
        )
        #expect(receipt.provesMembership(for: observation))
        #expect(
            !receipt.provesMembershipForDeliveryRemoval(
                for: capabilities.delivery
            )
        )
        #expect(receipt.confirmedEntryForAcceptedDecision() != nil)
        #expect(
            String(reflecting: receipt)
                == "IOSAcceptedHistoryOutboxReceipt(redacted)"
        )
        #expect(receipt.customMirror.children.isEmpty)

        let differentObservations = try #require(
            try await fixture.makeStore().observe()
        )
        let differentObservation = try #require(differentObservations.first)
        #expect(!receipt.provesMembership(for: differentObservation))

        let staleObservations = try #require(
            try await fixture.makeStore().observe()
        )
        let staleObservation = try #require(staleObservations.first)
        let other = try await outboxCapabilities(
            index: 445,
            createdAt: now.addingTimeInterval(86_400)
        )
        _ = try await fixture.makeStore().transfer(
            delivery: other.delivery,
            policy: other.policy
        )
        await #expect(
            throws: IOSAcceptedHistoryOutboxError.compareAndSwapFailed
        ) {
            try await fixture.makeStore().confirmMembership(
                observation: staleObservation
            )
        }
    }

    @Test func staleObservationCannotResolveVisibleUncertainty() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        let capabilities = try await outboxCapabilities(
            index: 447,
            createdAt: now
        )
        _ = try await fixture.store.transfer(
            delivery: capabilities.delivery,
            policy: capabilities.policy
        )
        let observations = try #require(try await fixture.store.observe())
        let staleObservation = try #require(observations.first)
        fixture.journal.failNextReplace(
            with: .commitUncertain,
            commitBeforeThrowing: true
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.commitUncertain) {
            try await fixture.store.transfer(
                delivery: capabilities.delivery,
                policy: capabilities.policy
            )
        }

        await #expect(
            throws: IOSAcceptedHistoryOutboxError.compareAndSwapFailed
        ) {
            try await fixture.store.confirmMembership(
                observation: staleObservation
            )
        }
        let receipt = try await fixture.store.confirmMembership(
            delivery: capabilities.delivery
        )
        #expect(
            receipt.provesMembershipForDeliveryRemoval(
                for: capabilities.delivery
            )
        )
    }

    @Test func twoStoresUsePhysicalCASWithoutLostMembership() async throws {
        let now = outboxStoreDate()
        let fixture = OutboxStoreFixture(now: now)
        fixture.journal.install(
            try IOSAcceptedHistoryOutboxEnvelope(revision: 1, entries: [])
        )
        fixture.journal.delayNextLoads(2)
        let first = try await outboxCapabilities(index: 440, createdAt: now)
        let second = try await outboxCapabilities(index: 441, createdAt: now)
        let firstTask = Task {
            try await fixture.store.transfer(
                delivery: first.delivery,
                policy: first.policy
            )
        }
        let secondTask = Task {
            try await fixture.makeStore().transfer(
                delivery: second.delivery,
                policy: second.policy
            )
        }
        let firstResult = await firstTask.result
        let secondResult = await secondTask.result
        #expect([firstResult, secondResult].filter {
            if case .success = $0 { return true }
            return false
        }.count == 1)
        let loser = if case .failure = firstResult { first } else { second }
        _ = try await fixture.store.transfer(
            delivery: loser.delivery,
            policy: loser.policy
        )
        #expect(fixture.journal.currentEnvelope?.revision == 3)
        #expect(fixture.journal.currentEnvelope?.entries.count == 2)
    }

    @Test func liveRepositoryUsesExactProtectionBackupAndMarker() async throws {
        let base = FileManager.default.temporaryDirectory.appendingPathComponent(
            "accepted-history-outbox-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: base,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: base) }
        let now = outboxStoreDate()
        let store = IOSAcceptedHistoryOutboxStore(
            journal: FoundationIOSAcceptedHistoryOutboxJournalRepository(
                applicationSupportDirectoryURL: base
            ),
            now: { now }
        )
        let capabilities = try await outboxCapabilities(index: 450, createdAt: now)
        _ = try await store.transfer(
            delivery: capabilities.delivery,
            policy: capabilities.policy
        )

        let rootURL = base.appendingPathComponent("HoldType", isDirectory: true)
        let fileURL = IOSAcceptedHistoryOutboxStorageLocation.fileURL(in: base)
        let rootAttributes = try FileManager.default.attributesOfItem(
            atPath: rootURL.path
        )
        let attributes = try FileManager.default.attributesOfItem(
            atPath: fileURL.path
        )
        #expect(
            (rootAttributes[.posixPermissions] as? NSNumber)?.intValue == 0o700
        )
        #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
        #expect(
            try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
                .isExcludedFromBackup == true
        )
        #if os(iOS) && !targetEnvironment(simulator)
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
        #else
        if let protection = attributes[.protectionKey] as? FileProtectionType {
            #expect(protection == .complete)
        }
        #endif

        let descriptor = Darwin.open(fileURL.path, O_RDWR | O_CLOEXEC)
        let validDescriptor = try #require(descriptor >= 0 ? descriptor : nil)
        defer { Darwin.close(validDescriptor) }
        let marker = try #require(
            IOSStrictProtectedRecordConfiguration.acceptedHistoryOutbox.marker
        )
        var bytes = [UInt8](repeating: 0, count: marker.value.count + 1)
        let byteCount = marker.name.withCString { name in
            bytes.withUnsafeMutableBytes {
                Darwin.fgetxattr(
                    validDescriptor,
                    name,
                    $0.baseAddress,
                    $0.count,
                    0,
                    0
                )
            }
        }
        #expect(byteCount == marker.value.count)
        #expect(Array(bytes.prefix(marker.value.count)) == marker.value)
        let preserved = try Data(contentsOf: fileURL)
        #expect(
            marker.name.withCString {
                Darwin.fremovexattr(validDescriptor, $0, 0)
            } == 0
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.readFailed) {
            _ = try await store.load()
        }
        #expect(try Data(contentsOf: fileURL) == preserved)

        let wrongMarker = Array("v2".utf8)
        #expect(
            marker.name.withCString { name in
                wrongMarker.withUnsafeBytes {
                    Darwin.fsetxattr(
                        validDescriptor,
                        name,
                        $0.baseAddress,
                        $0.count,
                        0,
                        Int32(XATTR_CREATE)
                    )
                }
            } == 0
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.readFailed) {
            _ = try await store.load()
        }
        #expect(try Data(contentsOf: fileURL) == preserved)
    }
}

private struct OutboxCapabilities {
    let delivery: IOSAcceptedOutputDeliveryAuthorization
    let policy: IOSHistoryPolicyReceipt
}

private func outboxCapabilities(
    index: Int,
    generation: Int64 = 1,
    acceptedText: String = "Accepted text",
    createdAt: Date = outboxStoreDate()
) async throws -> OutboxCapabilities {
    OutboxCapabilities(
        delivery: try outboxDeliveryAuthorization(
            index: index,
            generation: generation,
            acceptedText: acceptedText,
            createdAt: createdAt
        ),
        policy: try await outboxPolicyReceipt(
            generation: generation,
            enabled: true
        )
    )
}

private func outboxDeliveryAuthorization(
    index: Int,
    generation: Int64 = 1,
    acceptedText: String = "Accepted text",
    createdAt: Date = outboxStoreDate(),
    historyState: IOSAcceptedOutputHistoryWriteState = .pending,
    fileRevisionToken: UInt64? = nil
) throws -> IOSAcceptedOutputDeliveryAuthorization {
    let marker = try IOSAcceptedOutputHistoryWrite(
        state: historyState,
        policyGeneration: generation,
        transcriptionModel: "gpt-4o-mini-transcribe",
        transcriptionLanguageCode: "en",
        durationMilliseconds: 1_250
    )
    let record = try IOSAcceptedOutputDeliveryRecord(
        revision: 1,
        deliveryID: outboxUUID(prefix: 0, index: index),
        sessionID: outboxUUID(prefix: 1, index: index),
        attemptID: outboxUUID(prefix: 2, index: index),
        transcriptID: outboxUUID(prefix: 3, index: index),
        acceptedText: acceptedText,
        outputIntent: .standard,
        createdAt: createdAt,
        updatedAt: createdAt,
        expiresAt: createdAt.addingTimeInterval(86_400),
        deliveryState: .pending,
        automaticInsertionPreferenceEnabled: true,
        keepLatestResult: false,
        publicationGeneration: 0,
        historyWrite: marker
    )
    return IOSAcceptedOutputDeliveryAuthorization(
        snapshot: IOSAcceptedOutputDeliveryJournalSnapshot(
            record: record,
            fileRevision: IOSStrictProtectedRecordFileRevision(
                testingToken: fileRevisionToken ?? UInt64(index + 1)
            )
        )
    )
}

private func outboxPolicyReceipt(
    generation: Int64,
    enabled: Bool
) async throws -> IOSHistoryPolicyReceipt {
    let state = try IOSHistoryPolicyState(
        revision: generation,
        historyEnabled: enabled,
        policyGeneration: generation
    )
    let journal = OutboxPolicyFakeJournal(state: state)
    return try await IOSHistoryPolicyStore(journal: journal).confirm(
        expected: IOSHistoryPolicyExpectation(state: state)
    )
}

private func outboxEntry(
    from authorization: IOSAcceptedOutputDeliveryAuthorization
) throws -> IOSAcceptedHistoryOutboxEntry {
    let record = authorization.record
    let marker = try #require(record.historyWrite)
    return try IOSAcceptedHistoryOutboxEntry(
        deliveryID: record.deliveryID,
        transcriptID: record.transcriptID,
        acceptedText: try #require(record.acceptedText),
        outputIntent: record.outputIntent,
        createdAt: record.createdAt,
        expiresAt: record.expiresAt,
        policyGeneration: marker.policyGeneration,
        transcriptionModel: marker.transcriptionModel,
        transcriptionLanguageCode: marker.transcriptionLanguageCode,
        durationMilliseconds: marker.durationMilliseconds
    )
}

private func outboxStoredEntry(
    index: Int,
    generation: Int64 = 1,
    transcriptID: UUID? = nil,
    acceptedText: String = "Accepted text",
    createdAt: Date = outboxStoreDate()
) throws -> IOSAcceptedHistoryOutboxEntry {
    try IOSAcceptedHistoryOutboxEntry(
        deliveryID: outboxUUID(prefix: 0, index: index),
        transcriptID: transcriptID ?? outboxUUID(prefix: 3, index: index),
        acceptedText: acceptedText,
        outputIntent: .standard,
        createdAt: createdAt,
        expiresAt: createdAt.addingTimeInterval(86_400),
        policyGeneration: generation,
        transcriptionModel: "gpt-4o-mini-transcribe",
        transcriptionLanguageCode: "en",
        durationMilliseconds: 1_250
    )
}

private func outboxStoreDate() -> Date {
    Date(timeIntervalSince1970: 1_800_000_000)
}

private func outboxUUID(prefix: Int, index: Int) -> UUID {
    UUID(
        uuidString: String(
            format: "%08x-0000-4000-8000-%012x",
            prefix,
            index
        )
    )!
}

private final class OutboxClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Date
    private var count = 0

    init(_ value: Date) { self.value = value }

    var readCount: Int { lock.withLock { count } }

    func set(_ value: Date) {
        lock.withLock { self.value = value }
    }

    func read() -> Date {
        lock.withLock { count += 1 }
        return value
    }
}

private final class OutboxPolicyFakeJournal:
    IOSHistoryPolicyJournalStoring,
    @unchecked Sendable {
    private let lock = NSLock()
    private var snapshot: IOSHistoryPolicyJournalSnapshot
    private var nextToken: UInt64 = 2

    init(state: IOSHistoryPolicyState) {
        snapshot = IOSHistoryPolicyJournalSnapshot(
            state: state,
            fileRevision: IOSStrictProtectedRecordFileRevision(testingToken: 1)
        )
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
    ) throws -> IOSStrictProtectedRecordMaintenanceReport { .empty }
}

private final class OutboxFakeJournal:
    IOSAcceptedHistoryOutboxJournalStoring,
    @unchecked Sendable {
    private struct Failure {
        let error: IOSAcceptedHistoryOutboxError
        let commitBeforeThrowing: Bool
    }

    private let lock = NSLock()
    private var snapshot: IOSAcceptedHistoryOutboxJournalSnapshot?
    private var nextToken: UInt64 = 1
    private var createFailure: Failure?
    private var replaceFailure: Failure?
    private var delayedLoadCount = 0
    private var storedEvents: [String] = []

    var events: [String] { lock.withLock { storedEvents } }
    var currentEnvelope: IOSAcceptedHistoryOutboxEnvelope? {
        lock.withLock { snapshot?.envelope }
    }

    func resetEvents() { lock.withLock { storedEvents = [] } }

    func install(_ envelope: IOSAcceptedHistoryOutboxEnvelope) {
        lock.withLock {
            snapshot = IOSAcceptedHistoryOutboxJournalSnapshot(
                envelope: envelope,
                fileRevision: makeRevisionLocked()
            )
        }
    }

    func failNextCreate(
        with error: IOSAcceptedHistoryOutboxError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            createFailure = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func failNextReplace(
        with error: IOSAcceptedHistoryOutboxError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            replaceFailure = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func delayNextLoads(_ count: Int) {
        lock.withLock { delayedLoadCount = count }
    }

    func load() throws -> IOSAcceptedHistoryOutboxJournalSnapshot? {
        let result: (IOSAcceptedHistoryOutboxJournalSnapshot?, Bool) =
            lock.withLock {
                storedEvents.append("load")
                let shouldDelay = delayedLoadCount > 0
                if shouldDelay { delayedLoadCount -= 1 }
                return (snapshot, shouldDelay)
            }
        if result.1 { Thread.sleep(forTimeInterval: 0.02) }
        return result.0
    }

    func create(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope,
        authorization: IOSAcceptedHistoryOutboxJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryOutboxJournalSnapshot {
        try lock.withLock {
            storedEvents.append("create:\(envelope.revision)")
            guard snapshot == nil else {
                throw IOSAcceptedHistoryOutboxError.slotOccupied
            }
            if let failure = createFailure {
                createFailure = nil
                if failure.commitBeforeThrowing {
                    snapshot = IOSAcceptedHistoryOutboxJournalSnapshot(
                        envelope: envelope,
                        fileRevision: makeRevisionLocked()
                    )
                }
                throw failure.error
            }
            let created = IOSAcceptedHistoryOutboxJournalSnapshot(
                envelope: envelope,
                fileRevision: makeRevisionLocked()
            )
            snapshot = created
            return created
        }
    }

    func replace(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope,
        expected: IOSAcceptedHistoryOutboxJournalSnapshot,
        authorization: IOSAcceptedHistoryOutboxJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryOutboxJournalSnapshot {
        try lock.withLock {
            storedEvents.append("replace:\(envelope.revision)")
            guard snapshot?.fileRevision == expected.fileRevision else {
                throw IOSAcceptedHistoryOutboxError.compareAndSwapFailed
            }
            if let failure = replaceFailure {
                replaceFailure = nil
                if failure.commitBeforeThrowing {
                    snapshot = IOSAcceptedHistoryOutboxJournalSnapshot(
                        envelope: envelope,
                        fileRevision: makeRevisionLocked()
                    )
                }
                throw failure.error
            }
            let replacement = IOSAcceptedHistoryOutboxJournalSnapshot(
                envelope: envelope,
                fileRevision: makeRevisionLocked()
            )
            snapshot = replacement
            return replacement
        }
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport { .empty }

    private func makeRevisionLocked()
        -> IOSStrictProtectedRecordFileRevision {
        defer { nextToken += 1 }
        return IOSStrictProtectedRecordFileRevision(testingToken: nextToken)
    }
}

private final class OutboxStoreFixture: @unchecked Sendable {
    let journal = OutboxFakeJournal()
    let clock: OutboxClock
    lazy var store = makeStore()

    init(now: Date) { clock = OutboxClock(now) }

    func makeStore() -> IOSAcceptedHistoryOutboxStore {
        IOSAcceptedHistoryOutboxStore(
            journal: journal,
            now: { [clock] in clock.read() }
        )
    }
}
