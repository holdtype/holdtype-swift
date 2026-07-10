import Darwin
import Foundation
import Testing
import HoldTypeDomain
@testable import HoldTypePersistence

struct IOSAcceptedHistoryCoordinatorTests {
    @Test func productionContextRegistrySharesOnlyOnePhysicalRoot() async throws {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-coordinator-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = parent.appendingPathComponent("root", isDirectory: true)
        let alias = parent.appendingPathComponent("alias", isDirectory: true)
        let equivalentRoot = root
            .appendingPathComponent("..")
            .appendingPathComponent("root")
        let otherRoot = parent.appendingPathComponent("other", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: otherRoot,
            withIntermediateDirectories: false
        )
        try FileManager.default.createSymbolicLink(
            at: alias,
            withDestinationURL: root
        )
        defer { try? FileManager.default.removeItem(at: parent) }

        let first = registry.context(for: root)
        let sameRoot = registry.context(for: equivalentRoot)
        let symlinkAlias = registry.context(for: alias)
        let differentRoot = registry.context(for: otherRoot)
        let binding = registry.revalidate(context: first, for: root)

        #expect(first === sameRoot)
        #expect(first === symlinkAlias)
        #expect(first.policyStore === sameRoot.policyStore)
        #expect(first.acceptedHistoryStore === sameRoot.acceptedHistoryStore)
        #expect(first.outboxStore === sameRoot.outboxStore)
        #expect(first.deliveryStore === sameRoot.deliveryStore)
        #expect(first.baselineRecoveryState === sameRoot.baselineRecoveryState)
        #expect(first.acceptanceState === sameRoot.acceptanceState)
        #expect(first.ownerIdentity == sameRoot.ownerIdentity)
        #expect(first !== differentRoot)
        #expect(first.ownerIdentity != differentRoot.ownerIdentity)
        let renderedBinding = String(describing: binding)
            + String(reflecting: binding)
            + String(describing: Mirror(reflecting: binding))
        #expect(renderedBinding.contains("redacted"))
        #expect(!renderedBinding.contains(parent.path))
        #expect(
            first.baselineRecoveryState
                !== differentRoot.baselineRecoveryState
        )

        try FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        #expect(first === registry.context(for: root))

        let missingRoot = parent.appendingPathComponent(
            "initially-missing",
            isDirectory: true
        )
        let missing = registry.context(for: missingRoot)
        try FileManager.default.createDirectory(
            at: missingRoot,
            withIntermediateDirectories: false
        )
        #expect(missing === registry.context(for: missingRoot))
        #expect(missing.repositoryIdentityState.isConflicted)

        let caseAlias = parent.appendingPathComponent("ROOT", isDirectory: true)
        if coordinatorFileIdentity(root) == coordinatorFileIdentity(caseAlias) {
            #expect(first === registry.context(for: caseAlias))
        }

        let renameSource = parent.appendingPathComponent(
            "rename-source",
            isDirectory: true
        )
        let renameDestination = parent.appendingPathComponent(
            "rename-destination",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: renameSource,
            withIntermediateDirectories: false
        )
        let sourceContext = registry.context(for: renameSource)
        await sourceContext.baselineRecoveryState.requireRecovery()
        try FileManager.default.moveItem(
            at: renameSource,
            to: renameDestination
        )
        let destinationContext = registry.context(for: renameDestination)
        #expect(sourceContext !== destinationContext)
        #expect(sourceContext.repositoryIdentityState.isConflicted)
        #expect(destinationContext.repositoryIdentityState.isConflicted)

        let destinationRegistration =
            IOSAcceptedHistoryCoordinatorRepositoryRegistration(
                registry: registry,
                context: destinationContext,
                applicationSupportDirectoryURL: renameDestination
            )
        let destinationFixture = CoordinatorFixture(
            repositoryIdentityState:
                destinationContext.repositoryIdentityState,
            repositoryRegistration: destinationRegistration
        )
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await destinationFixture.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(destinationFixture.policy.loadCount == 0)
        #expect(destinationFixture.accepted.loadCount == 0)
        #expect(destinationFixture.outbox.loadCount == 0)
        #expect(destinationFixture.delivery.loadCount == 0)
    }

    @Test func retargetedAliasNeverReusesItsPathPinnedContext() throws {
        for destinationWasRegistered in [false, true] {
            let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
            let parent = FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "holdtype-coordinator-retarget-\(UUID().uuidString)",
                    isDirectory: true
                )
            let firstRoot = parent.appendingPathComponent("first", isDirectory: true)
            let secondRoot = parent.appendingPathComponent("second", isDirectory: true)
            let alias = parent.appendingPathComponent("alias", isDirectory: true)
            try FileManager.default.createDirectory(
                at: firstRoot,
                withIntermediateDirectories: true
            )
            try FileManager.default.createDirectory(
                at: secondRoot,
                withIntermediateDirectories: false
            )
            try FileManager.default.createSymbolicLink(
                at: alias,
                withDestinationURL: firstRoot
            )
            defer { try? FileManager.default.removeItem(at: parent) }

            let first = registry.context(for: alias)
            let registeredSecond = destinationWasRegistered
                ? registry.context(for: secondRoot)
                : nil
            try FileManager.default.removeItem(at: alias)
            try FileManager.default.createSymbolicLink(
                at: alias,
                withDestinationURL: secondRoot
            )
            let second = registry.context(for: alias)

            #expect(first !== second)
            #expect(first.repositoryIdentityState.isConflicted)
            #expect(!second.repositoryIdentityState.isConflicted)
            if let registeredSecond {
                #expect(second === registeredSecond)
            }
        }
    }

    @Test func incompatibleRootOwnersFailBeforeStorageIO() async throws {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-coordinator-conflict-\(UUID().uuidString)",
            isDirectory: true
        )
        let firstRoot = parent.appendingPathComponent("first", isDirectory: true)
        let secondRoot = parent.appendingPathComponent("second", isDirectory: true)
        try FileManager.default.createDirectory(
            at: secondRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: parent) }

        let first = registry.context(for: firstRoot)
        let second = registry.context(for: secondRoot)
        let registration = IOSAcceptedHistoryCoordinatorRepositoryRegistration(
            registry: registry,
            context: first,
            applicationSupportDirectoryURL: firstRoot
        )
        try FileManager.default.createSymbolicLink(
            at: firstRoot,
            withDestinationURL: secondRoot
        )

        let fixture = CoordinatorFixture(
            repositoryIdentityState: first.repositoryIdentityState,
            repositoryRegistration: registration
        )
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await fixture.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(fixture.policy.loadCount == 0)
        #expect(fixture.accepted.loadCount == 0)
        #expect(fixture.outbox.loadCount == 0)
        #expect(fixture.delivery.loadCount == 0)
        #expect(first.repositoryIdentityState.isConflicted)
        #expect(second.repositoryIdentityState.isConflicted)
    }

    @Test func distinctRootsConvergingOnUnregisteredRootFailBeforeStorageIO() async throws {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-coordinator-third-root-\(UUID().uuidString)",
            isDirectory: true
        )
        let firstRoot = parent.appendingPathComponent("first", isDirectory: true)
        let secondRoot = parent.appendingPathComponent("second", isDirectory: true)
        let destinationRoot = parent.appendingPathComponent(
            "destination",
            isDirectory: true
        )
        for root in [firstRoot, secondRoot, destinationRoot] {
            try FileManager.default.createDirectory(
                at: root,
                withIntermediateDirectories: true
            )
        }
        defer { try? FileManager.default.removeItem(at: parent) }

        let first = registry.context(for: firstRoot)
        let second = registry.context(for: secondRoot)
        let registration = IOSAcceptedHistoryCoordinatorRepositoryRegistration(
            registry: registry,
            context: first,
            applicationSupportDirectoryURL: firstRoot
        )
        for root in [firstRoot, secondRoot] {
            try FileManager.default.removeItem(at: root)
            try FileManager.default.createSymbolicLink(
                at: root,
                withDestinationURL: destinationRoot
            )
        }
        let fixture = CoordinatorFixture(
            repositoryIdentityState: first.repositoryIdentityState,
            repositoryRegistration: registration
        )

        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await fixture.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(first.repositoryIdentityState.isConflicted)
        #expect(second.repositoryIdentityState.isConflicted)
        #expect(fixture.policy.loadCount == 0)
        #expect(fixture.accepted.loadCount == 0)
        #expect(fixture.outbox.loadCount == 0)
        #expect(fixture.delivery.loadCount == 0)
    }

    @Test func missingRegisteredRootFailsBeforeStorageIO() async throws {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-coordinator-missing-\(UUID().uuidString)",
            isDirectory: true
        )
        let context = registry.context(for: root)
        let registration = IOSAcceptedHistoryCoordinatorRepositoryRegistration(
            registry: registry,
            context: context,
            applicationSupportDirectoryURL: root
        )
        let fixture = CoordinatorFixture(
            repositoryIdentityState: context.repositoryIdentityState,
            repositoryRegistration: registration
        )

        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await fixture.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(fixture.policy.loadCount == 0)
        #expect(fixture.accepted.loadCount == 0)
        #expect(fixture.outbox.loadCount == 0)
        #expect(fixture.delivery.loadCount == 0)
    }

    @Test func namespaceIdentityChangeDuringLeaseCannotIssueCapture() async throws {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-coordinator-linearization-\(UUID().uuidString)",
            isDirectory: true
        )
        let root = parent.appendingPathComponent("root", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: parent) }

        let context = registry.context(for: root)
        let registration = IOSAcceptedHistoryCoordinatorRepositoryRegistration(
            registry: registry,
            context: context,
            applicationSupportDirectoryURL: root
        )
        let fixture = CoordinatorFixture(
            repositoryIdentityState: context.repositoryIdentityState,
            repositoryRegistration: registration
        )
        let blocker = CoordinatorBoundaryBlocker()
        fixture.policy.loadBlocker = blocker
        let capture = Task {
            try await fixture.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(blocker.waitUntilBlocked())
        try FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        blocker.open()

        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await capture.value
        }
        #expect(context.repositoryIdentityState.isConflicted)
        #expect(fixture.policy.loadCount > 0)
    }

    @Test func identityChangeOverridesCommitUncertainAndTombstonesDestination() async throws {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-coordinator-error-linearization-\(UUID().uuidString)",
            isDirectory: true
        )
        let sourceRoot = parent.appendingPathComponent("source", isDirectory: true)
        let destinationRoot = parent.appendingPathComponent(
            "destination",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: sourceRoot,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: destinationRoot,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: parent) }

        let sourceContext = registry.context(for: sourceRoot)
        let sourceRegistration =
            IOSAcceptedHistoryCoordinatorRepositoryRegistration(
                registry: registry,
                context: sourceContext,
                applicationSupportDirectoryURL: sourceRoot
            )
        let sourceFixture = CoordinatorFixture(
            repositoryIdentityState: sourceContext.repositoryIdentityState,
            repositoryRegistration: sourceRegistration
        )
        let createBlocker = CoordinatorBoundaryBlocker()
        sourceFixture.policy.createBlocker = createBlocker
        sourceFixture.policy.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: true
        )
        let firstCapture = Task {
            try await sourceFixture.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(createBlocker.waitUntilBlocked())
        try FileManager.default.removeItem(at: sourceRoot)
        try FileManager.default.createSymbolicLink(
            at: sourceRoot,
            withDestinationURL: destinationRoot
        )
        createBlocker.open()

        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await firstCapture.value
        }
        #expect(sourceFixture.policy.currentState == .baseline)

        let destinationContext = registry.context(for: destinationRoot)
        #expect(destinationContext.repositoryIdentityState.isConflicted)
        let destinationRegistration =
            IOSAcceptedHistoryCoordinatorRepositoryRegistration(
                registry: registry,
                context: destinationContext,
                applicationSupportDirectoryURL: destinationRoot
            )
        let destinationFixture = CoordinatorFixture(
            repositoryIdentityState:
                destinationContext.repositoryIdentityState,
            repositoryRegistration: destinationRegistration
        )
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await destinationFixture.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(destinationFixture.policy.loadCount == 0)
        #expect(destinationFixture.accepted.loadCount == 0)
        #expect(destinationFixture.outbox.loadCount == 0)
        #expect(destinationFixture.delivery.loadCount == 0)
    }

    @Test func everyMissingAndEmptyOwnerCombinationCreatesPhysicalBaseline() async throws {
        for mask in 0..<8 {
            let fixture = CoordinatorFixture()
            if mask & 1 != 0 {
                fixture.accepted.install(
                    try IOSAcceptedHistoryEnvelope(revision: 1, entries: [])
                )
            }
            if mask & 2 != 0 {
                fixture.outbox.install(
                    try IOSAcceptedHistoryOutboxEnvelope(
                        revision: 1,
                        entries: []
                    )
                )
            }
            if mask & 4 != 0 {
                fixture.delivery.install(
                    try coordinatorDeliveryRecord(historyWrite: nil)
                )
            }

            let capture = try await fixture.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: "en",
                durationMilliseconds: 10
            )

            #expect(fixture.policy.currentState == .baseline)
            #expect(fixture.policy.createCount == 1)
            #expect(capture.historyWrite?.state == .pending)
            #expect(capture.historyWrite?.policyGeneration == 1)
            #expect(fixture.accepted.loadCount == 1)
            #expect(fixture.outbox.loadCount == 1)
            #expect(fixture.delivery.loadCount == 1)
        }
    }

    @Test func eachOccupiedOwnerBlocksPolicyCreation() async throws {
        let accepted = CoordinatorFixture()
        accepted.accepted.install(
            try IOSAcceptedHistoryEnvelope(
                revision: 1,
                entries: [try coordinatorHistoryEntry()]
            )
        )
        await #expect(throws: IOSAcceptedHistoryError.compareAndSwapFailed) {
            _ = try await accepted.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(accepted.policy.createCount == 0)

        let outbox = CoordinatorFixture()
        outbox.outbox.install(
            try IOSAcceptedHistoryOutboxEnvelope(
                revision: 1,
                entries: [try coordinatorOutboxEntry()]
            )
        )
        await #expect(throws: IOSAcceptedHistoryOutboxError.compareAndSwapFailed) {
            _ = try await outbox.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(outbox.policy.createCount == 0)

        let delivery = CoordinatorFixture()
        delivery.delivery.install(
            try coordinatorDeliveryRecord(
                historyWrite: IOSAcceptedOutputHistoryWrite(
                    policyGeneration: 1,
                    transcriptionModel: "model",
                    transcriptionLanguageCode: nil,
                    durationMilliseconds: nil
                )
            )
        )
        await #expect(
            throws: IOSAcceptedOutputDeliveryError.compareAndSwapFailed
        ) {
            _ = try await delivery.coordinator().capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(delivery.policy.createCount == 0)
    }

    @Test func existingPolicyBypassesOwnerProbesAndConfirmsIdentically() async throws {
        let fixture = CoordinatorFixture()
        let existing = try IOSHistoryPolicyState(
            revision: 2,
            historyEnabled: false,
            policyGeneration: 2
        )
        fixture.policy.install(existing)

        let capture = try await fixture.coordinator().capture(
            transcriptionModel: "model",
            transcriptionLanguageCode: "en",
            durationMilliseconds: 1
        )

        #expect(fixture.policy.currentState == existing)
        #expect(capture.historyWrite == nil)
        #expect(fixture.accepted.loadCount == 0)
        #expect(fixture.outbox.loadCount == 0)
        #expect(fixture.delivery.loadCount == 0)
        #expect(fixture.policy.replaceCount == 1)
    }

    @Test func firstCaptureCreatesOneOneAndNextMutationCreatesTwoTwo() async throws {
        let fixture = CoordinatorFixture()
        let capture = try await fixture.coordinator().capture(
            transcriptionModel: "model",
            transcriptionLanguageCode: nil,
            durationMilliseconds: nil
        )
        let mutationStore = IOSHistoryPolicyStore(
            journal: fixture.policy,
            capabilityOwnerIdentity: fixture.ownerIdentity
        )
        let confirmed = try await mutationStore.confirm(
            expected: IOSHistoryPolicyExpectation(state: .baseline)
        )
        let cleared = try await mutationStore.clear(
            using: confirmed
        )

        #expect(capture.historyWrite?.policyGeneration == 1)
        #expect(cleared.state.revision == 2)
        #expect(cleared.state.policyGeneration == 2)
        #expect(cleared.state.historyEnabled)
    }

    @Test func visibleAndInvisibleBaselineUncertaintyAlwaysReprobe() async throws {
        for visible in [true, false] {
            let fixture = CoordinatorFixture()
            let coordinator = fixture.coordinator()
            fixture.policy.failNextCreate(
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )

            await #expect(throws: IOSHistoryPolicyError.commitUncertain) {
                _ = try await coordinator.capture(
                    transcriptionModel: "model",
                    transcriptionLanguageCode: nil,
                    durationMilliseconds: nil
                )
            }
            _ = try await coordinator.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )

            #expect(fixture.policy.currentState == .baseline)
            #expect(fixture.accepted.loadCount == 2)
            #expect(fixture.outbox.loadCount == 2)
            #expect(fixture.delivery.loadCount == 2)
        }
    }

    @Test func queuedCaptureObservesRecoveryStateBeforeItsLeaseRuns() async throws {
        let gateProbe = CoordinatorGateProbe()
        let gate = IOSPersistenceOperationGate { event in
            gateProbe.record(event)
        }
        let fixture = CoordinatorFixture(gate: gate)
        let coordinator = fixture.coordinator()
        let createBlocker = CoordinatorBoundaryBlocker()
        fixture.policy.createBlocker = createBlocker
        fixture.policy.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: true
        )

        let first = Task {
            try await coordinator.capture(
                transcriptionModel: "first",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(createBlocker.waitUntilBlocked())
        let second = Task {
            try await coordinator.capture(
                transcriptionModel: "second",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(gateProbe.waitUntilEnqueued())
        createBlocker.open()

        await #expect(throws: IOSHistoryPolicyError.commitUncertain) {
            _ = try await first.value
        }
        let recovered = try await second.value
        #expect(recovered.historyWrite?.transcriptionModel == "second")
        #expect(fixture.accepted.loadCount == 2)
        #expect(fixture.outbox.loadCount == 2)
        #expect(fixture.delivery.loadCount == 2)
    }

    @Test func recoveryFlagSurvivesProbeFailureAndClearsOnDefinitiveWinner() async throws {
        let retryFixture = CoordinatorFixture()
        let retryCoordinator = retryFixture.coordinator()
        retryFixture.policy.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        await #expect(throws: IOSHistoryPolicyError.commitUncertain) {
            _ = try await retryCoordinator.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        retryFixture.accepted.failNextLoad(with: .readFailed)
        await #expect(throws: IOSAcceptedHistoryError.readFailed) {
            _ = try await retryCoordinator.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        _ = try await retryCoordinator.capture(
            transcriptionModel: "model",
            transcriptionLanguageCode: nil,
            durationMilliseconds: nil
        )
        #expect(retryFixture.accepted.loadCount == 3)
        #expect(retryFixture.outbox.loadCount == 2)

        let winnerFixture = CoordinatorFixture()
        let winnerCoordinator = winnerFixture.coordinator()
        winnerFixture.policy.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        await #expect(throws: IOSHistoryPolicyError.commitUncertain) {
            _ = try await winnerCoordinator.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        let winner = try IOSHistoryPolicyState(
            revision: 2,
            historyEnabled: true,
            policyGeneration: 2
        )
        winnerFixture.policy.install(winner)
        await #expect(throws: IOSHistoryPolicyError.compareAndSwapFailed) {
            _ = try await winnerCoordinator.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        let probeCount = winnerFixture.accepted.loadCount
        _ = try await winnerCoordinator.capture(
            transcriptionModel: "model",
            transcriptionLanguageCode: nil,
            durationMilliseconds: nil
        )
        #expect(winnerFixture.policy.currentState == winner)
        #expect(winnerFixture.accepted.loadCount == probeCount)
    }

    @Test func baselineReplaceCASKeepsRecoveryAndReprobes() async throws {
        let fixture = CoordinatorFixture()
        let coordinator = fixture.coordinator()
        fixture.policy.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: true
        )
        await #expect(throws: IOSHistoryPolicyError.commitUncertain) {
            _ = try await coordinator.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }

        fixture.policy.raceNextReplace(with: .baseline)
        await #expect(throws: IOSHistoryPolicyError.compareAndSwapFailed) {
            _ = try await coordinator.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(fixture.accepted.loadCount == 2)

        let recovered = try await coordinator.capture(
            transcriptionModel: "model",
            transcriptionLanguageCode: nil,
            durationMilliseconds: nil
        )
        #expect(recovered.historyWrite?.policyGeneration == 1)
        #expect(fixture.accepted.loadCount == 3)
        #expect(fixture.outbox.loadCount == 3)
        #expect(fixture.delivery.loadCount == 3)
    }

    @Test func recoveryStateIsIsolatedAcrossRepositories() async throws {
        let sharedGate = IOSPersistenceOperationGate()
        let first = CoordinatorFixture(gate: sharedGate)
        let second = CoordinatorFixture(gate: sharedGate)
        let firstCoordinator = first.coordinator()
        let secondCoordinator = second.coordinator()
        first.policy.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        await #expect(throws: IOSHistoryPolicyError.commitUncertain) {
            _ = try await firstCoordinator.capture(
                transcriptionModel: "first",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }

        second.policy.install(
            try IOSHistoryPolicyState(
                revision: 2,
                historyEnabled: true,
                policyGeneration: 2
            )
        )
        _ = try await secondCoordinator.capture(
            transcriptionModel: "second",
            transcriptionLanguageCode: nil,
            durationMilliseconds: nil
        )
        #expect(second.accepted.loadCount == 0)

        _ = try await firstCoordinator.capture(
            transcriptionModel: "first",
            transcriptionLanguageCode: nil,
            durationMilliseconds: nil
        )
        #expect(first.accepted.loadCount == 2)
    }

    @Test func twoCoordinatorsSharingAGateNeverInterleavePolicyConfirmation() async throws {
        let gateProbe = CoordinatorGateProbe()
        let gate = IOSPersistenceOperationGate { event in
            gateProbe.record(event)
        }
        let fixture = CoordinatorFixture(gate: gate)
        fixture.policy.install(.baseline)
        let firstCoordinator = fixture.coordinator()
        let secondCoordinator = fixture.coordinator()
        let loadBlocker = CoordinatorBoundaryBlocker()
        fixture.policy.loadBlocker = loadBlocker

        let first = Task {
            try await firstCoordinator.capture(
                transcriptionModel: "first",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(loadBlocker.waitUntilBlocked())
        let second = Task {
            try await secondCoordinator.capture(
                transcriptionModel: "second",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(gateProbe.waitUntilEnqueued())
        #expect(fixture.policy.loadCount == 1)
        loadBlocker.open()

        #expect(try await first.value.historyWrite?.transcriptionModel == "first")
        #expect(try await second.value.historyWrite?.transcriptionModel == "second")
        #expect(gateProbe.grantedCount == 2)
        #expect(gateProbe.releasedCount == 2)
    }

    @Test func cancellationBeforeLeaseDoesNoWorkAndAfterLeaseCannotInterrupt() async throws {
        let gateProbe = CoordinatorGateProbe()
        let gate = IOSPersistenceOperationGate { event in
            gateProbe.record(event)
        }
        let fixture = CoordinatorFixture(gate: gate)
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let loadBlocker = CoordinatorBoundaryBlocker()
        fixture.policy.loadBlocker = loadBlocker

        let active = Task {
            try await coordinator.capture(
                transcriptionModel: "active",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(loadBlocker.waitUntilBlocked())
        let cancelled = Task {
            try await coordinator.capture(
                transcriptionModel: "cancelled",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        #expect(gateProbe.waitUntilEnqueued())
        cancelled.cancel()
        active.cancel()
        loadBlocker.open()

        #expect(try await active.value.historyWrite?.transcriptionModel == "active")
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.cancelledBeforeOperation
        ) {
            _ = try await cancelled.value
        }
        #expect(fixture.policy.loadCount == 2)
        #expect(fixture.accepted.loadCount == 0)
        #expect(gateProbe.grantedCount == 1)
        #expect(gateProbe.releasedCount == 1)
    }

    @Test func enabledDisabledAndMetadataBoundariesAreExactAndRedacted() async throws {
        let enabled = CoordinatorFixture()
        enabled.policy.install(
            try IOSHistoryPolicyState(
                revision: 2,
                historyEnabled: true,
                policyGeneration: 2
            )
        )
        let enabledCoordinator = enabled.coordinator()
        let capture = try await enabledCoordinator.capture(
            transcriptionModel: "  model  ",
            transcriptionLanguageCode: "eng",
            durationMilliseconds: 299_999
        )
        #expect(capture.historyWrite?.state == .pending)
        #expect(capture.historyWrite?.policyGeneration == 2)
        #expect(capture.historyWrite?.transcriptionModel == "model")
        #expect(capture.historyWrite?.transcriptionLanguageCode == "eng")
        #expect(capture.historyWrite?.durationMilliseconds == 299_999)

        let disabled = CoordinatorFixture()
        disabled.policy.install(
            try IOSHistoryPolicyState(
                revision: 2,
                historyEnabled: false,
                policyGeneration: 2
            )
        )
        let disabledCapture = try await disabled.coordinator().capture(
            transcriptionModel: String(repeating: "m", count: 256),
            transcriptionLanguageCode: "en",
            durationMilliseconds: 1
        )
        #expect(disabledCapture.historyWrite == nil)
        #expect(disabled.policy.currentState?.historyEnabled == false)

        let readsBefore = enabled.policy.loadCount
        for invalid in [
            ("", Optional<String>.none, Optional<Int64>.none),
            (String(repeating: "m", count: 257), nil, nil),
            ("model", "e", nil),
            ("model", nil, 0),
            ("model", nil, 300_000),
        ] {
            await #expect(throws: IOSAcceptedOutputDeliveryError.invalidPreparation) {
                _ = try await enabledCoordinator.capture(
                    transcriptionModel: invalid.0,
                    transcriptionLanguageCode: invalid.1,
                    durationMilliseconds: invalid.2
                )
            }
        }
        #expect(enabled.policy.loadCount == readsBefore)

        let rendered = String(describing: capture)
            + String(reflecting: capture)
            + String(describing: Mirror(reflecting: capture))
            + String(describing: IOSAcceptedHistoryCoordinatorError.reentrantOperation)
        #expect(rendered.contains("redacted"))
        #expect(!rendered.contains("model"))
    }

    @Test func normalAcceptanceCommitsInRequiredOrderAndReturnsRecord() async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)
        let eventStart = fixture.events.events.count

        let result = try await coordinator.accept(preparation)

        #expect(result.resolution == .committed)
        #expect(result.deliveryRecord.historyWrite?.state == .committed)
        #expect(fixture.delivery.currentRecord == result.deliveryRecord)
        #expect(fixture.accepted.currentEnvelope?.entries.count == 1)
        #expect(
            Array(fixture.events.events.dropFirst(eventStart)) == [
                "delivery.load",
                "delivery.create",
                "delivery.load",
                "delivery.replace",
                "policy.load",
                "policy.replace",
                "accepted.load",
                "accepted.create",
                "policy.load",
                "policy.replace",
                "delivery.load",
                "delivery.replace",
            ]
        )
        let rendered = String(describing: result)
            + String(reflecting: result)
            + String(describing: result.resolution)
            + String(
                describing: IOSAcceptedOutputDeliveryAcceptance(
                    record: result.deliveryRecord,
                    provenance: .freshCurrentProcess
                )
            )
            + String(
                reflecting:
                    IOSAcceptedOutputDeliveryAcceptanceProvenance.preexisting
            )
        #expect(rendered.contains("redacted"))
        #expect(!rendered.contains(preparation.acceptedText))
    }

    @Test func disabledCaptureReturnsNotRequestedWithoutHistoryIO() async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(
            try IOSHistoryPolicyState(
                revision: 2,
                historyEnabled: false,
                policyGeneration: 2
            )
        )
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)

        let result = try await coordinator.accept(preparation)

        #expect(result.resolution == .notRequested)
        #expect(result.deliveryRecord.historyWrite == nil)
        #expect(fixture.accepted.loadCount == 0)
        #expect(fixture.accepted.createCount == 0)
        #expect(fixture.delivery.replaceCount == 0)
    }

    @Test func ownerMismatchAndRawPreparationFailBeforeDeliveryIO() async throws {
        let first = CoordinatorFixture()
        first.policy.install(.baseline)
        let firstCoordinator = first.coordinator()
        let captured = try await coordinatorPreparation(using: firstCoordinator)
        let second = CoordinatorFixture()
        second.policy.install(.baseline)
        let secondCoordinator = second.coordinator()

        await #expect(throws: IOSAcceptedOutputDeliveryError.invalidPreparation) {
            _ = try await secondCoordinator.accept(captured)
        }
        #expect(second.delivery.loadCount == 0)
        #expect(second.delivery.createCount == 0)

        let raw = try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: UUID(),
            transcriptID: UUID(),
            rawAcceptedText: "raw",
            outputIntent: .standard,
            automaticInsertionPreferenceEnabled: true,
            keepLatestResult: true,
            historyWrite: captured.historyWrite
        )
        await #expect(throws: IOSAcceptedOutputDeliveryError.invalidPreparation) {
            _ = try await firstCoordinator.accept(raw)
        }
        #expect(first.delivery.loadCount == 0)
        #expect(first.delivery.createCount == 0)
    }

    @Test func mixedCapabilityOwnerCoordinatorIsPoisonedBeforeAnyStoreIO()
        async throws {
        let first = CoordinatorFixture()
        first.policy.install(
            try IOSHistoryPolicyState(
                revision: 2,
                historyEnabled: false,
                policyGeneration: 2
            )
        )
        let validCoordinator = first.coordinator()
        let disabledPreparation = try await coordinatorPreparation(
            using: validCoordinator
        )
        let second = CoordinatorFixture()
        let identityState =
            IOSAcceptedHistoryCoordinatorRepositoryIdentityState()
        let mixed = IOSAcceptedHistoryCoordinator(
            policyStore: first.policyStore,
            acceptedHistoryStore: first.acceptedHistoryStore,
            outboxStore: first.outboxStore,
            deliveryStore: second.deliveryStore,
            operationGate: IOSPersistenceOperationGate(),
            acceptanceState: IOSAcceptedHistoryAcceptanceOperationState(),
            ownerIdentity: first.ownerIdentity,
            repositoryIdentityState: identityState
        )
        let policyLoads = first.policy.loadCount
        let acceptedLoads = first.accepted.loadCount
        let outboxLoads = first.outbox.loadCount
        let deliveryLoads = second.delivery.loadCount

        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await mixed.capture(
                transcriptionModel: "model",
                transcriptionLanguageCode: nil,
                durationMilliseconds: nil
            )
        }
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await mixed.accept(disabledPreparation)
        }
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.repositoryIdentityConflict
        ) {
            _ = try await mixed.recoverAcceptedHistory()
        }

        #expect(identityState.isConflicted)
        #expect(first.policy.loadCount == policyLoads)
        #expect(first.accepted.loadCount == acceptedLoads)
        #expect(first.outbox.loadCount == outboxLoads)
        #expect(second.delivery.loadCount == deliveryLoads)
        #expect(second.delivery.createCount == 0)
    }

    @Test func mixedGuardedBaselineEvidenceCannotComposeAuthority()
        async throws {
        let first = CoordinatorFixture()
        let second = CoordinatorFixture()
        let accepted = try await first.acceptedHistoryStore
            .proveGuardedBaseline()
        let outbox = try await second.outboxStore.proveGuardedBaseline()
        let delivery = try await first.deliveryStore.proveGuardedBaseline()
        let firstAcceptedLoads = first.accepted.loadCount
        let secondOutboxLoads = second.outbox.loadCount
        let firstDeliveryLoads = first.delivery.loadCount

        #expect(throws: IOSHistoryPolicyError.compareAndSwapFailed) {
            _ = try IOSHistoryPolicyBaselineAuthorization(
                acceptedHistory: accepted,
                outbox: outbox,
                delivery: delivery
            )
        }

        #expect(first.accepted.loadCount == firstAcceptedLoads)
        #expect(second.outbox.loadCount == secondOutboxLoads)
        #expect(first.delivery.loadCount == firstDeliveryLoads)
    }

    @Test func deliveryFailureBeforeBoundaryRemainsTypedAndRetryable() async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)
        fixture.delivery.failNextCreate(
            with: .writeFailed,
            commitBeforeThrowing: false
        )

        await #expect(throws: IOSAcceptedOutputDeliveryError.writeFailed) {
            _ = try await coordinator.accept(preparation)
        }
        #expect(fixture.accepted.loadCount == 0)

        let retried = try await coordinator.accept(preparation)
        #expect(retried.resolution == .committed)
        #expect(fixture.delivery.createCount == 2)
    }

    @Test func rowUncertaintyResumesExactPhaseAcrossCoordinators() async throws {
        for visible in [false, true] {
            let fixture = CoordinatorFixture()
            fixture.policy.install(.baseline)
            let first = fixture.coordinator()
            let preparation = try await coordinatorPreparation(using: first)
            fixture.accepted.failNextCreate(
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )

            let pending = try await first.accept(preparation)
            #expect(pending.resolution == .pendingLocalRecovery)
            #expect(fixture.delivery.createCount == 1)
            #expect(fixture.delivery.replaceCount == 1)

            let recovered = try await fixture.coordinator().accept(preparation)
            #expect(recovered.resolution == .committed)
            #expect(fixture.delivery.createCount == 1)
            #expect(fixture.delivery.replaceCount == 2)
            #expect(fixture.accepted.currentEnvelope?.entries.count == 1)
        }
    }

    @Test func policyAndMarkerUncertaintyRetainExactPostDeliveryPhase() async throws {
        for visible in [false, true] {
            let policyFixture = CoordinatorFixture()
            policyFixture.policy.install(.baseline)
            let policyCoordinator = policyFixture.coordinator()
            let policyPreparation = try await coordinatorPreparation(
                using: policyCoordinator
            )
            let failingPolicyCall = policyFixture.policy.replaceCount + 2
            policyFixture.policy.failReplace(
                onCall: failingPolicyCall,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )

            let policyPending = try await policyCoordinator.accept(
                policyPreparation
            )
            #expect(policyPending.resolution == .pendingLocalRecovery)
            #expect(policyFixture.accepted.createCount == 1)
            #expect(policyFixture.delivery.replaceCount == 1)
            let policyRecovered = try await policyFixture.coordinator().accept(
                policyPreparation
            )
            #expect(policyRecovered.resolution == .committed)
            #expect(policyFixture.accepted.createCount == 1)
            #expect(policyFixture.delivery.createCount == 1)
            #expect(policyFixture.delivery.replaceCount == 2)

            let markerFixture = CoordinatorFixture()
            markerFixture.policy.install(.baseline)
            let markerCoordinator = markerFixture.coordinator()
            let markerPreparation = try await coordinatorPreparation(
                using: markerCoordinator
            )
            markerFixture.delivery.failReplace(
                onCall: markerFixture.delivery.replaceCount + 2,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )

            let markerPending = try await markerCoordinator.accept(
                markerPreparation
            )
            #expect(markerPending.resolution == .pendingLocalRecovery)
            let policyCount = markerFixture.policy.replaceCount
            let acceptedCount = markerFixture.accepted.createCount
            let markerRecovered = try await markerFixture.coordinator().accept(
                markerPreparation
            )
            #expect(markerRecovered.resolution == .committed)
            #expect(markerFixture.policy.replaceCount == policyCount)
            #expect(markerFixture.accepted.createCount == acceptedCount)
            #expect(markerFixture.delivery.createCount == 1)
            #expect(markerFixture.delivery.replaceCount == 3)
        }
    }

    @Test func policyCutoverCancelsBeforeOrAfterRowDecision() async throws {
        let before = CoordinatorFixture()
        before.policy.install(.baseline)
        let beforeCoordinator = before.coordinator()
        let beforePreparation = try await coordinatorPreparation(
            using: beforeCoordinator
        )
        let disabled = try IOSHistoryPolicyState(
            revision: 2,
            historyEnabled: false,
            policyGeneration: 2
        )
        before.policy.raceNextReplace(with: disabled)

        let cancelledBefore = try await beforeCoordinator.accept(
            beforePreparation
        )
        #expect(cancelledBefore.resolution == .cancelled)
        #expect(cancelledBefore.deliveryRecord.historyWrite?.state == .cancelled)
        #expect(before.accepted.createCount == 0)

        let after = CoordinatorFixture()
        after.policy.install(.baseline)
        let afterCoordinator = after.coordinator()
        let afterPreparation = try await coordinatorPreparation(
            using: afterCoordinator
        )
        after.policy.raceReplace(
            onCall: after.policy.replaceCount + 2,
            with: disabled
        )

        let cancelledAfter = try await afterCoordinator.accept(afterPreparation)
        #expect(cancelledAfter.resolution == .cancelled)
        #expect(cancelledAfter.deliveryRecord.historyWrite?.state == .cancelled)
        #expect(after.accepted.createCount == 1)
        #expect(after.accepted.currentEnvelope?.entries.count == 1)
    }

    @Test func providerFreeRelaunchConfirmsMembershipButNeverInserts() async throws {
        let present = CoordinatorFixture()
        present.policy.install(.baseline)
        let presentCoordinator = present.coordinator()
        let presentPreparation = try await coordinatorPreparation(
            using: presentCoordinator
        )
        present.delivery.failReplace(
            onCall: present.delivery.replaceCount + 2,
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await presentCoordinator.accept(presentPreparation).resolution
                == .pendingLocalRecovery
        )
        #expect(present.accepted.currentEnvelope?.entries.count == 1)

        let recovered = try await present.relaunchedCoordinator()
            .recoverAcceptedHistory()
        #expect(recovered == .committed)
        #expect(present.delivery.currentRecord?.historyWrite?.state == .committed)

        let absent = CoordinatorFixture()
        absent.policy.install(.baseline)
        let absentCoordinator = absent.coordinator()
        let absentPreparation = try await coordinatorPreparation(
            using: absentCoordinator
        )
        absent.accepted.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await absentCoordinator.accept(absentPreparation).resolution
                == .pendingLocalRecovery
        )
        let createCount = absent.accepted.createCount
        let relaunched = absent.relaunchedCoordinator()
        #expect(
            try await relaunched.recoverAcceptedHistory()
                == .pendingLocalRecovery
        )
        #expect(absent.accepted.createCount == createCount)
        #expect(absent.accepted.currentEnvelope == nil)
        #expect(absent.delivery.currentRecord?.historyWrite?.state == .pending)
    }

    @Test func committedMarkerIsTerminalEvenWhenRowIsAbsent() async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)
        #expect(
            try await coordinator.accept(preparation).resolution == .committed
        )
        fixture.accepted.install(
            try IOSAcceptedHistoryEnvelope(revision: 2, entries: [])
        )
        let acceptedLoads = fixture.accepted.loadCount

        let recovered = try await fixture.relaunchedCoordinator()
            .recoverAcceptedHistory()

        #expect(recovered == .committed)
        #expect(fixture.accepted.loadCount == acceptedLoads)
        #expect(fixture.accepted.currentEnvelope?.entries.isEmpty == true)
    }

    @Test func expiryAbandonsWithoutRowWorkAndRollbackMutatesNothing() async throws {
        let expired = CoordinatorFixture()
        expired.policy.install(.baseline)
        let expiredCoordinator = expired.coordinator()
        let expiredPreparation = try await coordinatorPreparation(
            using: expiredCoordinator
        )
        expired.accepted.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await expiredCoordinator.accept(expiredPreparation).resolution
                == .pendingLocalRecovery
        )
        let acceptedLoads = expired.accepted.loadCount
        let markerReplaces = expired.delivery.replaceCount
        expired.clock.advance(seconds: 86_400)

        #expect(
            try await expired.relaunchedCoordinator().recoverAcceptedHistory()
                == nil
        )
        #expect(expired.delivery.currentRecord == nil)
        #expect(expired.delivery.removeCount == 1)
        #expect(expired.accepted.loadCount == acceptedLoads)
        #expect(expired.delivery.replaceCount == markerReplaces + 1)

        let rollback = CoordinatorFixture()
        rollback.policy.install(.baseline)
        let rollbackCoordinator = rollback.coordinator()
        let rollbackPreparation = try await coordinatorPreparation(
            using: rollbackCoordinator
        )
        rollback.accepted.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await rollbackCoordinator.accept(rollbackPreparation).resolution
                == .pendingLocalRecovery
        )
        let rollbackAcceptedLoads = rollback.accepted.loadCount
        let rollbackDeliveryReplaces = rollback.delivery.replaceCount
        rollback.clock.rollBack(seconds: 1)

        #expect(
            try await rollback.relaunchedCoordinator()
                .recoverAcceptedHistory() == .pendingLocalRecovery
        )
        #expect(rollback.accepted.loadCount == rollbackAcceptedLoads)
        #expect(rollback.delivery.replaceCount == rollbackDeliveryReplaces)
        #expect(rollback.delivery.removeCount == 0)
        #expect(rollback.delivery.currentRecord?.historyWrite?.state == .pending)
    }

    @Test func expiredRemovalFailureStaysPendingAndDifferentWorkCannotClobberPhase()
        async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let first = try await coordinatorPreparation(
            using: coordinator,
            text: "first"
        )
        fixture.accepted.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await coordinator.accept(first).resolution
                == .pendingLocalRecovery
        )
        let second = try await coordinatorPreparation(
            using: coordinator,
            text: "second"
        )
        let deliveryLoads = fixture.delivery.loadCount
        await #expect(throws: IOSAcceptedOutputDeliveryError.commitUncertain) {
            _ = try await fixture.coordinator().accept(second)
        }
        #expect(fixture.delivery.loadCount == deliveryLoads)

        fixture.clock.advance(seconds: 86_400)
        fixture.delivery.failNextRemove(with: .removeFailed)
        #expect(
            try await fixture.relaunchedCoordinator().recoverAcceptedHistory()
                == .pendingLocalRecovery
        )
        #expect(fixture.delivery.currentRecord != nil)
    }

    @Test func rebuiltAcceptanceAfterProcessLossCannotResurrectAbsentRow()
        async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(.baseline)
        let originalCoordinator = fixture.coordinator()
        let original = try await coordinatorPreparation(
            using: originalCoordinator
        )
        fixture.accepted.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await originalCoordinator.accept(original).resolution
                == .pendingLocalRecovery
        )
        let rowCreates = fixture.accepted.createCount
        let rowReplaces = fixture.accepted.replaceCount

        let relaunched = fixture.relaunchedCoordinator()
        let rebuilt = try await rebuiltPreparation(
            using: relaunched,
            matching: original
        )
        let result = try await relaunched.accept(rebuilt)

        #expect(result.resolution == .pendingLocalRecovery)
        #expect(fixture.accepted.createCount == rowCreates)
        #expect(fixture.accepted.replaceCount == rowReplaces)
        #expect(fixture.accepted.currentEnvelope == nil)
        #expect(fixture.delivery.currentRecord?.historyWrite?.state == .pending)
        #expect(
            try await relaunched.accept(rebuilt).resolution
                == .pendingLocalRecovery
        )
        #expect(fixture.accepted.createCount == rowCreates)
        #expect(fixture.accepted.replaceCount == rowReplaces)
    }

    @Test func acceptanceProvenanceSurvivesVisibleAndInvisibleUncertainty()
        async throws {
        for visible in [false, true] {
            let fresh = CoordinatorFixture()
            fresh.policy.install(.baseline)
            let freshCoordinator = fresh.coordinator()
            let freshPreparation = try await coordinatorPreparation(
                using: freshCoordinator
            )
            fresh.delivery.failNextCreate(
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )
            await #expect(
                throws: IOSAcceptedOutputDeliveryError.commitUncertain
            ) {
                _ = try await freshCoordinator.accept(freshPreparation)
            }
            #expect(
                try await freshCoordinator.accept(freshPreparation).resolution
                    == .committed
            )
            #expect(fresh.accepted.currentEnvelope?.entries.count == 1)

            let preexisting = CoordinatorFixture()
            preexisting.policy.install(.baseline)
            let originalCoordinator = preexisting.coordinator()
            let original = try await coordinatorPreparation(
                using: originalCoordinator
            )
            preexisting.accepted.failNextCreate(
                with: .commitUncertain,
                commitBeforeThrowing: false
            )
            #expect(
                try await originalCoordinator.accept(original).resolution
                    == .pendingLocalRecovery
            )
            let relaunched = preexisting.relaunchedCoordinator()
            let rebuilt = try await rebuiltPreparation(
                using: relaunched,
                matching: original
            )
            preexisting.delivery.failReplace(
                onCall: preexisting.delivery.replaceCount + 1,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )
            await #expect(
                throws: IOSAcceptedOutputDeliveryError.commitUncertain
            ) {
                _ = try await relaunched.accept(rebuilt)
            }
            let rowCreates = preexisting.accepted.createCount
            #expect(
                try await relaunched.accept(rebuilt).resolution
                    == .pendingLocalRecovery
            )
            #expect(preexisting.accepted.createCount == rowCreates)
            #expect(preexisting.accepted.currentEnvelope == nil)
        }
    }

    @Test func retainedUncertaintyReconcilesBeforeExpiryOrRollbackBranch()
        async throws {
        for visible in [false, true] {
            let row = CoordinatorFixture()
            row.policy.install(.baseline)
            let rowCoordinator = row.coordinator()
            let rowPreparation = try await coordinatorPreparation(
                using: rowCoordinator
            )
            row.accepted.failNextCreate(
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )
            #expect(
                try await rowCoordinator.accept(rowPreparation).resolution
                    == .pendingLocalRecovery
            )
            row.clock.advance(seconds: 86_400)
            #expect(try await rowCoordinator.recoverAcceptedHistory() == nil)
            #expect(row.delivery.currentRecord == nil)
            #expect(row.delivery.removeCount == 1)
            #expect(row.accepted.currentEnvelope?.entries.count == (visible ? 1 : nil))

            let marker = CoordinatorFixture()
            marker.policy.install(.baseline)
            let markerCoordinator = marker.coordinator()
            let markerPreparation = try await coordinatorPreparation(
                using: markerCoordinator
            )
            marker.delivery.failReplace(
                onCall: marker.delivery.replaceCount + 2,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )
            #expect(
                try await markerCoordinator.accept(markerPreparation).resolution
                    == .pendingLocalRecovery
            )
            marker.clock.advance(seconds: 86_400)
            let markerRecovery = try await markerCoordinator
                .recoverAcceptedHistory()
            #expect(markerRecovery == (visible ? .committed : nil))
            #expect(
                marker.delivery.currentRecord?.historyWrite?.state
                    == (visible ? .committed : nil)
            )

            let rollback = CoordinatorFixture()
            rollback.policy.install(.baseline)
            let rollbackCoordinator = rollback.coordinator()
            let rollbackPreparation = try await coordinatorPreparation(
                using: rollbackCoordinator
            )
            rollback.delivery.failReplace(
                onCall: rollback.delivery.replaceCount + 2,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )
            #expect(
                try await rollbackCoordinator.accept(rollbackPreparation)
                    .resolution == .pendingLocalRecovery
            )
            rollback.clock.rollBack(seconds: 1)
            let rollbackRecovery = try await rollbackCoordinator
                .recoverAcceptedHistory()
            #expect(
                rollbackRecovery
                    == (visible ? .committed : .pendingLocalRecovery)
            )
            #expect(rollback.delivery.removeCount == 0)
        }
    }

    @Test func relaunchThatExpiresDuringConfirmationAbandonsInSameCall()
        async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(.baseline)
        let original = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: original)
        fixture.accepted.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await original.accept(preparation).resolution
                == .pendingLocalRecovery
        )

        fixture.clock.advanceOnRead(3, seconds: 86_400)
        let resolution = try await fixture.relaunchedCoordinator()
            .recoverAcceptedHistory()

        #expect(resolution == nil)
        #expect(fixture.delivery.currentRecord == nil)
        #expect(fixture.delivery.removeCount == 1)
    }

    @Test func retainedAbandonmentReloadsANewerDeliveryBeforeReturning()
        async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)
        fixture.accepted.failNextCreate(
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await coordinator.accept(preparation).resolution
                == .pendingLocalRecovery
        )
        fixture.clock.advance(seconds: 86_400)
        #expect(
            try await coordinator.accept(preparation).resolution
                == .pendingLocalRecovery
        )
        #expect(fixture.delivery.currentRecord == nil)

        let newer = try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: UUID(),
            transcriptID: UUID(),
            rawAcceptedText: "newer",
            outputIntent: .standard,
            automaticInsertionPreferenceEnabled: true,
            keepLatestResult: true,
            historyWrite: nil
        )
        _ = try await fixture.deliveryStore.accept(newer)

        #expect(
            try await coordinator.recoverAcceptedHistory() == .notRequested
        )
        #expect(fixture.delivery.currentRecord?.deliveryID == newer.deliveryID)
    }

    @Test func relaunchTerminalMatrixAlwaysUsesGenericIdenticalRewrite()
        async throws {
        let noMarker = CoordinatorFixture()
        noMarker.policy.install(.baseline)
        let raw = try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: UUID(),
            transcriptID: UUID(),
            rawAcceptedText: "no marker",
            outputIntent: .standard,
            automaticInsertionPreferenceEnabled: true,
            keepLatestResult: true,
            historyWrite: nil
        )
        _ = try await noMarker.deliveryStore.accept(raw)
        let noMarkerReplaces = noMarker.delivery.replaceCount
        #expect(
            try await noMarker.relaunchedCoordinator()
                .recoverAcceptedHistory() == .notRequested
        )
        #expect(noMarker.delivery.replaceCount == noMarkerReplaces + 1)

        let committed = CoordinatorFixture()
        committed.policy.install(.baseline)
        let committedCoordinator = committed.coordinator()
        let committedPreparation = try await coordinatorPreparation(
            using: committedCoordinator
        )
        #expect(
            try await committedCoordinator.accept(committedPreparation)
                .resolution == .committed
        )
        let committedReplaces = committed.delivery.replaceCount
        #expect(
            try await committed.relaunchedCoordinator()
                .recoverAcceptedHistory() == .committed
        )
        #expect(committed.delivery.replaceCount == committedReplaces + 1)

        let cancelled = CoordinatorFixture()
        cancelled.policy.install(.baseline)
        let cancelledCoordinator = cancelled.coordinator()
        let cancelledPreparation = try await coordinatorPreparation(
            using: cancelledCoordinator
        )
        cancelled.policy.raceNextReplace(
            with: try IOSHistoryPolicyState(
                revision: 2,
                historyEnabled: false,
                policyGeneration: 2
            )
        )
        #expect(
            try await cancelledCoordinator.accept(cancelledPreparation)
                .resolution == .cancelled
        )
        let cancelledReplaces = cancelled.delivery.replaceCount
        #expect(
            try await cancelled.relaunchedCoordinator()
                .recoverAcceptedHistory() == .cancelled
        )
        #expect(cancelled.delivery.replaceCount == cancelledReplaces + 1)
    }

    @Test func repeatedGenericConfirmationUncertaintyStaysPendingThenRecovers()
        async throws {
        for visible in [false, true] {
            let fixture = CoordinatorFixture()
            fixture.policy.install(.baseline)
            let raw = try IOSAcceptedOutputDeliveryPreparation(
                deliveryID: UUID(),
                sessionID: UUID(),
                attemptID: UUID(),
                transcriptID: UUID(),
                rawAcceptedText: "terminal",
                outputIntent: .standard,
                automaticInsertionPreferenceEnabled: true,
                keepLatestResult: true,
                historyWrite: nil
            )
            _ = try await fixture.deliveryStore.accept(raw)
            let firstFailure = fixture.delivery.replaceCount + 1
            fixture.delivery.failReplace(
                onCall: firstFailure,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )
            fixture.delivery.failReplace(
                onCall: firstFailure + 1,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )
            let relaunched = fixture.relaunchedCoordinator()

            #expect(
                try await relaunched.recoverAcceptedHistory()
                    == .pendingLocalRecovery
            )
            #expect(
                try await relaunched.recoverAcceptedHistory()
                    == .pendingLocalRecovery
            )
            #expect(
                try await relaunched.recoverAcceptedHistory() == .notRequested
            )
            #expect(fixture.accepted.loadCount == 0)
        }
    }

    @Test func cancellationUncertaintyRetriesExactInvalidationPhase()
        async throws {
        for visible in [false, true] {
            let fixture = CoordinatorFixture()
            fixture.policy.install(.baseline)
            let coordinator = fixture.coordinator()
            let preparation = try await coordinatorPreparation(
                using: coordinator
            )
            fixture.policy.raceNextReplace(
                with: try IOSHistoryPolicyState(
                    revision: 2,
                    historyEnabled: false,
                    policyGeneration: 2
                )
            )
            fixture.delivery.failReplace(
                onCall: fixture.delivery.replaceCount + 2,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )

            #expect(
                try await coordinator.accept(preparation).resolution
                    == .pendingLocalRecovery
            )
            let policyReplaces = fixture.policy.replaceCount
            let acceptedLoads = fixture.accepted.loadCount
            #expect(
                try await fixture.coordinator().accept(preparation).resolution
                    == .cancelled
            )
            #expect(fixture.policy.replaceCount == policyReplaces)
            #expect(fixture.accepted.loadCount == acceptedLoads)
            #expect(fixture.accepted.createCount == 0)
            #expect(fixture.delivery.createCount == 1)
            #expect(fixture.delivery.replaceCount == 3)
            #expect(
                try await fixture.relaunchedCoordinator()
                    .recoverAcceptedHistory() == .cancelled
            )
            #expect(fixture.delivery.replaceCount == 4)
        }
    }

    @Test func expiryObservationSurvivesConfirmationUncertaintyAndRollback()
        async throws {
        for visible in [false, true] {
            let fixture = CoordinatorFixture()
            fixture.policy.install(.baseline)
            let coordinator = fixture.coordinator()
            let preparation = try await coordinatorPreparation(
                using: coordinator
            )
            fixture.delivery.failReplace(
                onCall: fixture.delivery.replaceCount + 2,
                with: .commitUncertain,
                commitBeforeThrowing: false
            )
            #expect(
                try await coordinator.accept(preparation).resolution
                    == .pendingLocalRecovery
            )
            fixture.clock.advance(seconds: 86_400)
            fixture.delivery.failReplace(
                onCall: fixture.delivery.replaceCount + 1,
                with: .commitUncertain,
                commitBeforeThrowing: visible
            )

            #expect(
                try await coordinator.recoverAcceptedHistory()
                    == .pendingLocalRecovery
            )
            let acceptedLoads = fixture.accepted.loadCount
            let policyReplaces = fixture.policy.replaceCount
            fixture.clock.rollBack(seconds: 86_401)

            #expect(try await coordinator.recoverAcceptedHistory() == nil)
            #expect(fixture.delivery.currentRecord == nil)
            #expect(fixture.delivery.removeCount == 1)
            #expect(fixture.accepted.loadCount == acceptedLoads)
            #expect(fixture.policy.replaceCount == policyReplaces)
        }
    }

    @Test func expiryRemovalCapabilitiesAreOpaqueAndRedacted() async throws {
        let fixture = CoordinatorFixture()
        let preparation = try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: UUID(),
            transcriptID: UUID(),
            rawAcceptedText: "EXPIRY-CAPABILITY-SECRET",
            outputIntent: .standard,
            automaticInsertionPreferenceEnabled: true,
            keepLatestResult: true,
            historyWrite: nil
        )
        let record = try await fixture.deliveryStore.accept(preparation)
        fixture.clock.advance(seconds: 86_400)
        let observedResult = try await fixture.deliveryStore
            .observeExpiredHistoryAbandonment(
                expected: IOSAcceptedOutputDeliveryExpectation(record: record)
            )
        guard case .observed(let observation) = observedResult else {
            Issue.record("Expected sealed expiry observation")
            return
        }
        let removalResult = try await fixture.deliveryStore
            .confirmExpiredHistoryAbandonment(observation: observation)
        guard case .authorized(let authorization) = removalResult else {
            Issue.record("Expected sealed expiry removal authorization")
            return
        }

        let rendered = String(describing: observedResult)
            + String(reflecting: observation)
            + String(describing: removalResult)
            + String(reflecting: authorization)
        #expect(rendered.contains("redacted"))
        #expect(!rendered.contains("EXPIRY-CAPABILITY-SECRET"))
    }

    @Test func expiryCapabilitiesCannotCrossDeliveryStoreRoots() async throws {
        let first = CoordinatorFixture()
        let second = CoordinatorFixture()
        let preparation = try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: UUID(),
            transcriptID: UUID(),
            rawAcceptedText: "CROSS-ROOT-EXPIRY-SECRET",
            outputIntent: .standard,
            automaticInsertionPreferenceEnabled: true,
            keepLatestResult: true,
            historyWrite: nil
        )
        let record = try await first.deliveryStore.accept(preparation)
        second.delivery.install(record)
        first.clock.advance(seconds: 86_400)
        second.clock.advance(seconds: 86_400)
        let observedResult = try await first.deliveryStore
            .observeExpiredHistoryAbandonment(
                expected: IOSAcceptedOutputDeliveryExpectation(record: record)
            )
        guard case .observed(let observation) = observedResult else {
            Issue.record("Expected first-store expiry observation")
            return
        }

        let secondLoadsBeforeConfirmation = second.delivery.loadCount
        await #expect(
            throws: IOSAcceptedOutputDeliveryError.compareAndSwapFailed
        ) {
            _ = try await second.deliveryStore
                .confirmExpiredHistoryAbandonment(observation: observation)
        }
        #expect(second.delivery.loadCount == secondLoadsBeforeConfirmation)
        #expect(second.delivery.currentRecord == record)

        let removalResult = try await first.deliveryStore
            .confirmExpiredHistoryAbandonment(observation: observation)
        guard case .authorized(let authorization) = removalResult else {
            Issue.record("Expected first-store removal authorization")
            return
        }
        let secondLoadsBeforeRemoval = second.delivery.loadCount
        await #expect(
            throws: IOSAcceptedOutputDeliveryError.compareAndSwapFailed
        ) {
            _ = try await second.deliveryStore
                .continueExpiredHistoryAbandonment(
                    authorization: authorization
                )
        }
        #expect(second.delivery.loadCount == secondLoadsBeforeRemoval)
        #expect(second.delivery.currentRecord == record)

        let rendered = String(reflecting: observation)
            + String(reflecting: authorization)
        #expect(rendered.contains("redacted"))
        #expect(!rendered.contains("CROSS-ROOT-EXPIRY-SECRET"))
    }

    @Test func authorizedExpiryRemovalNeverReturnsToHistoryWork()
        async throws {
        for mode in 0..<4 {
            let fixture = CoordinatorFixture()
            fixture.policy.install(.baseline)
            let coordinator = fixture.coordinator()
            let preparation = try await coordinatorPreparation(
                using: coordinator
            )
            fixture.delivery.failReplace(
                onCall: fixture.delivery.replaceCount + 2,
                with: .commitUncertain,
                commitBeforeThrowing: false
            )
            #expect(
                try await coordinator.accept(preparation).resolution
                    == .pendingLocalRecovery
            )
            fixture.clock.advance(seconds: 86_400)
            let removalError: IOSAcceptedOutputDeliveryError =
                mode == 0 ? .removeFailed : .removalCommitUncertain
            fixture.delivery.failNextRemove(
                with: removalError,
                commitBeforeThrowing: mode == 2
            )

            #expect(
                try await coordinator.recoverAcceptedHistory()
                    == .pendingLocalRecovery
            )
            let acceptedLoads = fixture.accepted.loadCount
            let policyReplaces = fixture.policy.replaceCount
            let markerState = fixture.delivery.currentRecord?.historyWrite?.state
            let replaces = fixture.delivery.replaceCount
            if mode == 3, let record = fixture.delivery.currentRecord {
                fixture.delivery.install(record)
            }
            fixture.clock.rollBack(seconds: 86_401)

            #expect(try await coordinator.recoverAcceptedHistory() == nil)
            #expect(fixture.delivery.currentRecord == nil)
            #expect(fixture.accepted.loadCount == acceptedLoads)
            #expect(fixture.policy.replaceCount == policyReplaces)
            #expect(markerState == (mode == 2 ? nil : .pending))
            #expect(
                fixture.delivery.replaceCount
                    == replaces + (mode == 3 ? 1 : 0)
            )
        }
    }

    @Test func supersededExpiryRemovalReloadsNewDeliveryWithoutErasingIt()
        async throws {
        let fixture = CoordinatorFixture()
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)
        fixture.delivery.failReplace(
            onCall: fixture.delivery.replaceCount + 2,
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await coordinator.accept(preparation).resolution
                == .pendingLocalRecovery
        )
        fixture.clock.advance(seconds: 86_400)
        fixture.delivery.failNextRemove(with: .removeFailed)
        #expect(
            try await coordinator.recoverAcceptedHistory()
                == .pendingLocalRecovery
        )

        let newer = try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: UUID(),
            transcriptID: UUID(),
            rawAcceptedText: "newer after authorized expiry",
            outputIntent: .standard,
            automaticInsertionPreferenceEnabled: true,
            keepLatestResult: true,
            historyWrite: nil
        )
        _ = try await fixture.deliveryStore.accept(newer)

        #expect(
            try await coordinator.recoverAcceptedHistory() == .notRequested
        )
        #expect(fixture.delivery.currentRecord?.deliveryID == newer.deliveryID)
        #expect(fixture.delivery.currentRecord?.acceptedText == newer.acceptedText)
    }

    @Test func cancellationBeforeAcceptanceLeaseDoesNoAdditionalWork()
        async throws {
        let probe = CoordinatorGateProbe()
        let gate = IOSPersistenceOperationGate { event in probe.record(event) }
        let fixture = CoordinatorFixture(gate: gate)
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)
        let blocker = CoordinatorBoundaryBlocker()
        fixture.policy.loadBlocker = blocker

        let active = Task { try await coordinator.accept(preparation) }
        #expect(blocker.waitUntilBlocked())
        let cancelled = Task {
            try await fixture.coordinator().accept(preparation)
        }
        #expect(probe.waitUntilEnqueued())
        cancelled.cancel()
        blocker.open()

        #expect(try await active.value.resolution == .committed)
        await #expect(
            throws: IOSAcceptedHistoryCoordinatorError.cancelledBeforeOperation
        ) {
            _ = try await cancelled.value
        }
        #expect(fixture.delivery.createCount == 1)
        #expect(fixture.accepted.createCount == 1)
    }

    @Test func bindingConflictAfterDeliveryBoundaryReturnsPendingNotThrowing()
        async throws {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "holdtype-accept-binding-\(UUID().uuidString)",
                isDirectory: true
            )
        let root = parent.appendingPathComponent("root", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: parent) }
        let context = registry.context(for: root)
        let registration = IOSAcceptedHistoryCoordinatorRepositoryRegistration(
            registry: registry,
            context: context,
            applicationSupportDirectoryURL: root
        )
        let fixture = CoordinatorFixture(
            repositoryIdentityState: context.repositoryIdentityState,
            repositoryRegistration: registration
        )
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)
        let blocker = CoordinatorBoundaryBlocker()
        fixture.policy.loadBlocker = blocker
        let acceptance = Task { try await coordinator.accept(preparation) }
        #expect(blocker.waitUntilBlocked())
        #expect(fixture.delivery.currentRecord != nil)
        try FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        blocker.open()

        let result = try await acceptance.value
        #expect(result.resolution == .pendingLocalRecovery)
        #expect(context.repositoryIdentityState.isConflicted)
        #expect(await fixture.acceptanceState.current() != nil)
    }

    @Test func supersededReloadFailureKeepsPostBoundaryBindingSemantics()
        async throws {
        let registry = IOSAcceptedHistoryCoordinatorProcessContextRegistry()
        let parent = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "holdtype-superseded-binding-\(UUID().uuidString)",
                isDirectory: true
            )
        let root = parent.appendingPathComponent("root", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: parent) }
        let context = registry.context(for: root)
        let registration = IOSAcceptedHistoryCoordinatorRepositoryRegistration(
            registry: registry,
            context: context,
            applicationSupportDirectoryURL: root
        )
        let fixture = CoordinatorFixture(
            repositoryIdentityState: context.repositoryIdentityState,
            repositoryRegistration: registration
        )
        fixture.policy.install(.baseline)
        let coordinator = fixture.coordinator()
        let preparation = try await coordinatorPreparation(using: coordinator)
        fixture.delivery.failReplace(
            onCall: fixture.delivery.replaceCount + 2,
            with: .commitUncertain,
            commitBeforeThrowing: false
        )
        #expect(
            try await coordinator.accept(preparation).resolution
                == .pendingLocalRecovery
        )
        fixture.clock.advance(seconds: 86_400)
        fixture.delivery.failNextRemove(with: .removeFailed)
        #expect(
            try await coordinator.recoverAcceptedHistory()
                == .pendingLocalRecovery
        )

        let newer = try IOSAcceptedOutputDeliveryPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: UUID(),
            transcriptID: UUID(),
            rawAcceptedText: "newer retained boundary",
            outputIntent: .standard,
            automaticInsertionPreferenceEnabled: true,
            keepLatestResult: true,
            historyWrite: nil
        )
        _ = try await fixture.deliveryStore.accept(newer)
        let reloadCall = fixture.delivery.loadCount + 2
        let blocker = CoordinatorBoundaryBlocker()
        fixture.delivery.failLoad(onCall: reloadCall, with: .readFailed)
        fixture.delivery.blockLoad(onCall: reloadCall, with: blocker)
        let recovery = Task {
            try await coordinator.recoverAcceptedHistory()
        }
        #expect(blocker.waitUntilBlocked())
        try FileManager.default.removeItem(at: root)
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: false
        )
        blocker.open()

        #expect(try await recovery.value == .pendingLocalRecovery)
        #expect(context.repositoryIdentityState.isConflicted)
        #expect(fixture.delivery.currentRecord?.deliveryID == newer.deliveryID)
    }
}

private func coordinatorPreparation(
    using coordinator: IOSAcceptedHistoryCoordinator,
    text: String = "accepted text"
) async throws -> IOSAcceptedOutputDeliveryPreparation {
    let capture = try await coordinator.capture(
        transcriptionModel: "whisper-1",
        transcriptionLanguageCode: "en",
        durationMilliseconds: 1_250
    )
    return try IOSAcceptedOutputDeliveryPreparation(
        deliveryID: UUID(),
        sessionID: UUID(),
        attemptID: UUID(),
        transcriptID: UUID(),
        rawAcceptedText: text,
        outputIntent: .standard,
        automaticInsertionPreferenceEnabled: true,
        keepLatestResult: true,
        historyCapture: capture
    )
}

private func rebuiltPreparation(
    using coordinator: IOSAcceptedHistoryCoordinator,
    matching preparation: IOSAcceptedOutputDeliveryPreparation
) async throws -> IOSAcceptedOutputDeliveryPreparation {
    let marker = preparation.historyWrite
    let capture = try await coordinator.capture(
        transcriptionModel: marker?.transcriptionModel ?? "whisper-1",
        transcriptionLanguageCode: marker?.transcriptionLanguageCode,
        durationMilliseconds: marker?.durationMilliseconds
    )
    return try IOSAcceptedOutputDeliveryPreparation(
        deliveryID: preparation.deliveryID,
        sessionID: preparation.sessionID,
        attemptID: preparation.attemptID,
        transcriptID: preparation.transcriptID,
        rawAcceptedText: preparation.acceptedText,
        outputIntent: preparation.outputIntent,
        automaticInsertionPreferenceEnabled:
            preparation.automaticInsertionPreferenceEnabled,
        keepLatestResult: preparation.keepLatestResult,
        historyCapture: capture
    )
}

private final class CoordinatorFixture: @unchecked Sendable {
    let events = CoordinatorEventRecorder()
    let policy: CoordinatorPolicyJournal
    let accepted: CoordinatorAcceptedJournal
    let outbox: CoordinatorOutboxJournal
    let delivery: CoordinatorDeliveryJournal
    let gate: IOSPersistenceOperationGate
    let recoveryState = IOSAcceptedHistoryBaselineRecoveryState()
    let acceptanceState = IOSAcceptedHistoryAcceptanceOperationState()
    let ownerIdentity = IOSAcceptedHistoryCoordinatorOwnerIdentity()
    let clock: CoordinatorClock
    let policyStore: IOSHistoryPolicyStore
    let acceptedHistoryStore: IOSAcceptedHistoryStore
    let outboxStore: IOSAcceptedHistoryOutboxStore
    let deliveryStore: IOSAcceptedOutputDeliveryStore
    let repositoryIdentityState:
        IOSAcceptedHistoryCoordinatorRepositoryIdentityState
    let repositoryRegistration:
        IOSAcceptedHistoryCoordinatorRepositoryRegistration?

    init(
        gate: IOSPersistenceOperationGate = IOSPersistenceOperationGate(),
        repositoryIdentityState:
            IOSAcceptedHistoryCoordinatorRepositoryIdentityState =
                IOSAcceptedHistoryCoordinatorRepositoryIdentityState(),
        repositoryRegistration:
            IOSAcceptedHistoryCoordinatorRepositoryRegistration? = nil
    ) {
        let clock = CoordinatorClock()
        self.gate = gate
        self.clock = clock
        self.repositoryIdentityState = repositoryIdentityState
        self.repositoryRegistration = repositoryRegistration
        policy = CoordinatorPolicyJournal(events: events)
        accepted = CoordinatorAcceptedJournal(events: events)
        outbox = CoordinatorOutboxJournal(events: events)
        delivery = CoordinatorDeliveryJournal(events: events)
        policyStore = IOSHistoryPolicyStore(
            journal: policy,
            capabilityOwnerIdentity: ownerIdentity
        )
        acceptedHistoryStore = IOSAcceptedHistoryStore(
            journal: accepted,
            now: { clock.now },
            capabilityOwnerIdentity: ownerIdentity
        )
        outboxStore = IOSAcceptedHistoryOutboxStore(
            journal: outbox,
            capabilityOwnerIdentity: ownerIdentity
        )
        deliveryStore = IOSAcceptedOutputDeliveryStore(
            journal: delivery,
            now: { clock.now },
            monotonicNowNanoseconds: { clock.uptimeNanoseconds },
            capabilityOwnerIdentity: ownerIdentity
        )
    }

    func coordinator() -> IOSAcceptedHistoryCoordinator {
        IOSAcceptedHistoryCoordinator(
            policyStore: policyStore,
            acceptedHistoryStore: acceptedHistoryStore,
            outboxStore: outboxStore,
            deliveryStore: deliveryStore,
            operationGate: gate,
            baselineRecoveryState: recoveryState,
            acceptanceState: acceptanceState,
            ownerIdentity: ownerIdentity,
            repositoryIdentityState: repositoryIdentityState,
            repositoryRegistration: repositoryRegistration
        )
    }

    func relaunchedCoordinator() -> IOSAcceptedHistoryCoordinator {
        let capabilityOwnerIdentity =
            IOSAcceptedHistoryCapabilityOwnerIdentity()
        return IOSAcceptedHistoryCoordinator(
            policyStore: IOSHistoryPolicyStore(
                journal: policy,
                capabilityOwnerIdentity: capabilityOwnerIdentity
            ),
            acceptedHistoryStore: IOSAcceptedHistoryStore(
                journal: accepted,
                now: { [clock] in clock.now },
                capabilityOwnerIdentity: capabilityOwnerIdentity
            ),
            outboxStore: IOSAcceptedHistoryOutboxStore(
                journal: outbox,
                capabilityOwnerIdentity: capabilityOwnerIdentity
            ),
            deliveryStore: IOSAcceptedOutputDeliveryStore(
                journal: delivery,
                now: { [clock] in clock.now },
                monotonicNowNanoseconds: { [clock] in
                    clock.uptimeNanoseconds
                },
                capabilityOwnerIdentity: capabilityOwnerIdentity
            ),
            operationGate: gate,
            acceptanceState: IOSAcceptedHistoryAcceptanceOperationState(),
            ownerIdentity: capabilityOwnerIdentity,
            repositoryIdentityState: repositoryIdentityState,
            repositoryRegistration: repositoryRegistration
        )
    }
}

private final class CoordinatorClock: @unchecked Sendable {
    private let lock = NSLock()
    private var storedNow = Date(timeIntervalSince1970: 1_900_000_000)
    private var storedUptimeNanoseconds: UInt64 = 1_000_000_000
    private var readCount = 0
    private var scheduledAdvances: [Int: TimeInterval] = [:]

    var now: Date {
        lock.withLock {
            readCount += 1
            if let seconds = scheduledAdvances.removeValue(forKey: readCount) {
                storedNow = storedNow.addingTimeInterval(seconds)
                storedUptimeNanoseconds += UInt64(seconds * 1_000_000_000)
            }
            return storedNow
        }
    }
    var uptimeNanoseconds: UInt64 {
        lock.withLock { storedUptimeNanoseconds }
    }

    func advance(seconds: TimeInterval) {
        lock.withLock {
            storedNow = storedNow.addingTimeInterval(seconds)
            storedUptimeNanoseconds += UInt64(seconds * 1_000_000_000)
        }
    }

    func rollBack(seconds: TimeInterval) {
        lock.withLock {
            storedNow = storedNow.addingTimeInterval(-seconds)
            storedUptimeNanoseconds += 1
        }
    }

    func advanceOnRead(
        _ additionalRead: Int,
        seconds: TimeInterval
    ) {
        lock.withLock {
            scheduledAdvances[readCount + additionalRead] = seconds
        }
    }
}

private final class CoordinatorEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [String] = []

    var events: [String] { lock.withLock { storedEvents } }

    func append(_ event: String) {
        lock.withLock { storedEvents.append(event) }
    }
}

private final class CoordinatorPolicyJournal:
    IOSHistoryPolicyJournalStoring,
    @unchecked Sendable {
    private struct Failure {
        let error: IOSHistoryPolicyError
        let commitBeforeThrowing: Bool
    }

    private let lock = NSLock()
    private let events: CoordinatorEventRecorder
    private var snapshot: IOSHistoryPolicyJournalSnapshot?
    private var nextRevisionToken: UInt64 = 1
    private var createFailure: Failure?
    private var replaceFailures: [Int: Failure] = [:]
    private var nextReplaceRaceState: IOSHistoryPolicyState?
    private var replaceRaces: [Int: IOSHistoryPolicyState] = [:]
    private var storedLoadCount = 0
    private var storedCreateCount = 0
    private var storedReplaceCount = 0
    var loadBlocker: CoordinatorBoundaryBlocker?
    var createBlocker: CoordinatorBoundaryBlocker?

    init(events: CoordinatorEventRecorder) {
        self.events = events
    }

    var currentState: IOSHistoryPolicyState? {
        lock.withLock { snapshot?.state }
    }
    var loadCount: Int { lock.withLock { storedLoadCount } }
    var createCount: Int { lock.withLock { storedCreateCount } }
    var replaceCount: Int { lock.withLock { storedReplaceCount } }

    func install(_ state: IOSHistoryPolicyState) {
        lock.withLock {
            snapshot = IOSHistoryPolicyJournalSnapshot(
                state: state,
                fileRevision: makeRevisionLocked()
            )
        }
    }

    func failNextCreate(
        with error: IOSHistoryPolicyError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            createFailure = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func raceNextReplace(with state: IOSHistoryPolicyState) {
        lock.withLock { nextReplaceRaceState = state }
    }

    func raceReplace(onCall call: Int, with state: IOSHistoryPolicyState) {
        lock.withLock { replaceRaces[call] = state }
    }

    func failReplace(
        onCall call: Int,
        with error: IOSHistoryPolicyError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            replaceFailures[call] = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func load() throws -> IOSHistoryPolicyJournalSnapshot? {
        let result = lock.withLock { () -> IOSHistoryPolicyJournalSnapshot? in
            storedLoadCount += 1
            events.append("policy.load")
            return snapshot
        }
        loadBlocker?.blockOnce()
        return result
    }

    func create(
        _ state: IOSHistoryPolicyState,
        authorization: IOSHistoryPolicyBaselineAuthorization
    ) throws -> IOSHistoryPolicyJournalSnapshot {
        _ = authorization
        let result: Result<IOSHistoryPolicyJournalSnapshot, IOSHistoryPolicyError>
        lock.lock()
        storedCreateCount += 1
        events.append("policy.create")
        if snapshot != nil {
            result = .failure(.slotOccupied)
        } else if let failure = createFailure {
            createFailure = nil
            if failure.commitBeforeThrowing {
                snapshot = makeSnapshotLocked(state)
            }
            result = .failure(failure.error)
        } else {
            let created = makeSnapshotLocked(state)
            snapshot = created
            result = .success(created)
        }
        lock.unlock()
        createBlocker?.blockOnce()
        return try result.get()
    }

    func replace(
        _ state: IOSHistoryPolicyState,
        expected: IOSHistoryPolicyJournalSnapshot
    ) throws -> IOSHistoryPolicyJournalSnapshot {
        try lock.withLock {
            storedReplaceCount += 1
            events.append("policy.replace")
            if let raceState = replaceRaces.removeValue(
                forKey: storedReplaceCount
            ) ?? nextReplaceRaceState {
                snapshot = makeSnapshotLocked(raceState)
                nextReplaceRaceState = nil
            }
            guard snapshot == expected else {
                throw IOSHistoryPolicyError.compareAndSwapFailed
            }
            let replacement = makeSnapshotLocked(state)
            if let failure = replaceFailures.removeValue(
                forKey: storedReplaceCount
            ) {
                if failure.commitBeforeThrowing {
                    snapshot = replacement
                }
                throw failure.error
            }
            snapshot = replacement
            return replacement
        }
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport { .empty }

    private func makeSnapshotLocked(
        _ state: IOSHistoryPolicyState
    ) -> IOSHistoryPolicyJournalSnapshot {
        defer { nextRevisionToken += 1 }
        return IOSHistoryPolicyJournalSnapshot(
            state: state,
            fileRevision: IOSStrictProtectedRecordFileRevision(
                testingToken: nextRevisionToken
            )
        )
    }

    private func makeRevisionLocked() -> IOSStrictProtectedRecordFileRevision {
        defer { nextRevisionToken += 1 }
        return IOSStrictProtectedRecordFileRevision(
            testingToken: nextRevisionToken
        )
    }
}

private final class CoordinatorAcceptedJournal:
    IOSAcceptedHistoryJournalStoring,
    @unchecked Sendable {
    private struct Failure {
        let error: IOSAcceptedHistoryError
        let commitBeforeThrowing: Bool
    }

    private let lock = NSLock()
    private let events: CoordinatorEventRecorder
    private var snapshot: IOSAcceptedHistoryJournalSnapshot?
    private var nextRevisionToken: UInt64 = 1
    private var loadFailure: IOSAcceptedHistoryError?
    private var storedLoadCount = 0
    private var storedCreateCount = 0
    private var storedReplaceCount = 0
    private var createFailure: Failure?
    private var replaceFailures: [Int: Failure] = [:]

    init(events: CoordinatorEventRecorder) { self.events = events }

    var loadCount: Int { lock.withLock { storedLoadCount } }
    var createCount: Int { lock.withLock { storedCreateCount } }
    var replaceCount: Int { lock.withLock { storedReplaceCount } }
    var currentEnvelope: IOSAcceptedHistoryEnvelope? {
        lock.withLock { snapshot?.envelope }
    }

    func install(_ envelope: IOSAcceptedHistoryEnvelope) {
        lock.withLock {
            snapshot = IOSAcceptedHistoryJournalSnapshot(
                envelope: envelope,
                fileRevision: revisionLocked()
            )
        }
    }

    func failNextLoad(with error: IOSAcceptedHistoryError) {
        lock.withLock { loadFailure = error }
    }

    func failNextCreate(
        with error: IOSAcceptedHistoryError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            createFailure = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func failReplace(
        onCall call: Int,
        with error: IOSAcceptedHistoryError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            replaceFailures[call] = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func load() throws -> IOSAcceptedHistoryJournalSnapshot? {
        try lock.withLock {
            storedLoadCount += 1
            events.append("accepted.load")
            if let loadFailure {
                self.loadFailure = nil
                throw loadFailure
            }
            return snapshot
        }
    }

    func create(
        _ envelope: IOSAcceptedHistoryEnvelope,
        authorization: IOSAcceptedHistoryJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryJournalSnapshot {
        _ = authorization
        return try lock.withLock {
            storedCreateCount += 1
            events.append("accepted.create")
            guard snapshot == nil else {
                throw IOSAcceptedHistoryError.slotOccupied
            }
            let created = makeSnapshotLocked(envelope)
            if let failure = createFailure {
                createFailure = nil
                if failure.commitBeforeThrowing { snapshot = created }
                throw failure.error
            }
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
            storedReplaceCount += 1
            events.append("accepted.replace")
            guard snapshot == expected else {
                throw IOSAcceptedHistoryError.compareAndSwapFailed
            }
            let replacement = makeSnapshotLocked(envelope)
            if let failure = replaceFailures.removeValue(
                forKey: storedReplaceCount
            ) {
                if failure.commitBeforeThrowing { snapshot = replacement }
                throw failure.error
            }
            snapshot = replacement
            return replacement
        }
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport { .empty }

    private func revisionLocked() -> IOSStrictProtectedRecordFileRevision {
        defer { nextRevisionToken += 1 }
        return IOSStrictProtectedRecordFileRevision(
            testingToken: nextRevisionToken
        )
    }

    private func makeSnapshotLocked(
        _ envelope: IOSAcceptedHistoryEnvelope
    ) -> IOSAcceptedHistoryJournalSnapshot {
        IOSAcceptedHistoryJournalSnapshot(
            envelope: envelope,
            fileRevision: revisionLocked()
        )
    }
}

private final class CoordinatorOutboxJournal:
    IOSAcceptedHistoryOutboxJournalStoring,
    @unchecked Sendable {
    private let lock = NSLock()
    private let events: CoordinatorEventRecorder
    private var snapshot: IOSAcceptedHistoryOutboxJournalSnapshot?
    private var nextRevisionToken: UInt64 = 1
    private var storedLoadCount = 0

    init(events: CoordinatorEventRecorder) { self.events = events }
    var loadCount: Int { lock.withLock { storedLoadCount } }

    func install(_ envelope: IOSAcceptedHistoryOutboxEnvelope) {
        lock.withLock {
            snapshot = IOSAcceptedHistoryOutboxJournalSnapshot(
                envelope: envelope,
                fileRevision: revisionLocked()
            )
        }
    }

    func load() throws -> IOSAcceptedHistoryOutboxJournalSnapshot? {
        lock.withLock {
            storedLoadCount += 1
            events.append("outbox.load")
            return snapshot
        }
    }

    func create(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope,
        authorization: IOSAcceptedHistoryOutboxJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryOutboxJournalSnapshot {
        throw IOSAcceptedHistoryOutboxError.writeFailed
    }

    func replace(
        _ envelope: IOSAcceptedHistoryOutboxEnvelope,
        expected: IOSAcceptedHistoryOutboxJournalSnapshot,
        authorization: IOSAcceptedHistoryOutboxJournalMutationAuthorization
    ) throws -> IOSAcceptedHistoryOutboxJournalSnapshot {
        throw IOSAcceptedHistoryOutboxError.writeFailed
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport { .empty }

    private func revisionLocked() -> IOSStrictProtectedRecordFileRevision {
        defer { nextRevisionToken += 1 }
        return IOSStrictProtectedRecordFileRevision(
            testingToken: nextRevisionToken
        )
    }
}

private final class CoordinatorDeliveryJournal:
    IOSAcceptedOutputDeliveryJournalStoring,
    @unchecked Sendable {
    private struct Failure {
        let error: IOSAcceptedOutputDeliveryError
        let commitBeforeThrowing: Bool
    }

    private let lock = NSLock()
    private let events: CoordinatorEventRecorder
    private var snapshot: IOSAcceptedOutputDeliveryJournalSnapshot?
    private var nextRevisionToken: UInt64 = 1
    private var storedLoadCount = 0
    private var storedCreateCount = 0
    private var storedReplaceCount = 0
    private var storedRemoveCount = 0
    private var createFailure: Failure?
    private var replaceFailures: [Int: Failure] = [:]
    private var removeFailure: Failure?
    private var loadFailures: [Int: IOSAcceptedOutputDeliveryError] = [:]
    private var loadBlockers: [Int: CoordinatorBoundaryBlocker] = [:]

    init(events: CoordinatorEventRecorder) { self.events = events }
    var loadCount: Int { lock.withLock { storedLoadCount } }
    var createCount: Int { lock.withLock { storedCreateCount } }
    var replaceCount: Int { lock.withLock { storedReplaceCount } }
    var removeCount: Int { lock.withLock { storedRemoveCount } }
    var currentRecord: IOSAcceptedOutputDeliveryRecord? {
        lock.withLock { snapshot?.record }
    }

    func install(_ record: IOSAcceptedOutputDeliveryRecord) {
        lock.withLock {
            snapshot = IOSAcceptedOutputDeliveryJournalSnapshot(
                record: record,
                fileRevision: revisionLocked()
            )
        }
    }

    func failNextCreate(
        with error: IOSAcceptedOutputDeliveryError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            createFailure = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func failLoad(
        onCall call: Int,
        with error: IOSAcceptedOutputDeliveryError
    ) {
        lock.withLock { loadFailures[call] = error }
    }

    func blockLoad(
        onCall call: Int,
        with blocker: CoordinatorBoundaryBlocker
    ) {
        lock.withLock { loadBlockers[call] = blocker }
    }

    func failReplace(
        onCall call: Int,
        with error: IOSAcceptedOutputDeliveryError,
        commitBeforeThrowing: Bool
    ) {
        lock.withLock {
            replaceFailures[call] = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func failNextRemove(
        with error: IOSAcceptedOutputDeliveryError,
        commitBeforeThrowing: Bool = false
    ) {
        lock.withLock {
            removeFailure = Failure(
                error: error,
                commitBeforeThrowing: commitBeforeThrowing
            )
        }
    }

    func load() throws -> IOSAcceptedOutputDeliveryJournalSnapshot? {
        let outcome = lock.withLock {
            storedLoadCount += 1
            events.append("delivery.load")
            let call = storedLoadCount
            let blocker = loadBlockers.removeValue(forKey: call)
            let result: Result<
                IOSAcceptedOutputDeliveryJournalSnapshot?,
                IOSAcceptedOutputDeliveryError
            > = if let failure = loadFailures.removeValue(forKey: call) {
                .failure(failure)
            } else {
                .success(snapshot)
            }
            return (result, blocker)
        }
        outcome.1?.blockOnce()
        return try outcome.0.get()
    }

    func loadOpaque() throws -> IOSAcceptedOutputDeliveryOpaqueSnapshot? { nil }

    func create(
        _ record: IOSAcceptedOutputDeliveryRecord
    ) throws -> IOSAcceptedOutputDeliveryJournalSnapshot {
        try lock.withLock {
            storedCreateCount += 1
            events.append("delivery.create")
            guard snapshot == nil else {
                throw IOSAcceptedOutputDeliveryError.slotOccupied
            }
            let created = makeSnapshotLocked(record)
            if let failure = createFailure {
                createFailure = nil
                if failure.commitBeforeThrowing { snapshot = created }
                throw failure.error
            }
            snapshot = created
            return created
        }
    }

    func replace(
        _ record: IOSAcceptedOutputDeliveryRecord,
        expected: IOSAcceptedOutputDeliveryJournalSnapshot
    ) throws -> IOSAcceptedOutputDeliveryJournalSnapshot {
        try lock.withLock {
            storedReplaceCount += 1
            events.append("delivery.replace")
            guard snapshot == expected else {
                throw IOSAcceptedOutputDeliveryError.compareAndSwapFailed
            }
            let replacement = makeSnapshotLocked(record)
            if let failure = replaceFailures.removeValue(
                forKey: storedReplaceCount
            ) {
                if failure.commitBeforeThrowing { snapshot = replacement }
                throw failure.error
            }
            snapshot = replacement
            return replacement
        }
    }

    func remove(expected: IOSAcceptedOutputDeliveryJournalSnapshot) throws {
        try lock.withLock {
            storedRemoveCount += 1
            events.append("delivery.remove")
            guard snapshot == expected else {
                throw IOSAcceptedOutputDeliveryError.compareAndSwapFailed
            }
            if let removeFailure {
                self.removeFailure = nil
                if removeFailure.commitBeforeThrowing {
                    snapshot = nil
                }
                throw removeFailure.error
            }
            snapshot = nil
        }
    }

    func removeOpaque(expected: IOSAcceptedOutputDeliveryOpaqueSnapshot) throws {
        throw IOSAcceptedOutputDeliveryError.removeFailed
    }

    func performStagingMaintenance(
        now: Date
    ) throws -> IOSStrictProtectedRecordMaintenanceReport { .empty }

    private func revisionLocked() -> IOSStrictProtectedRecordFileRevision {
        defer { nextRevisionToken += 1 }
        return IOSStrictProtectedRecordFileRevision(
            testingToken: nextRevisionToken
        )
    }

    private func makeSnapshotLocked(
        _ record: IOSAcceptedOutputDeliveryRecord
    ) -> IOSAcceptedOutputDeliveryJournalSnapshot {
        IOSAcceptedOutputDeliveryJournalSnapshot(
            record: record,
            fileRevision: revisionLocked()
        )
    }
}

private final class CoordinatorBoundaryBlocker: @unchecked Sendable {
    private let lock = NSLock()
    private let blocked = DispatchSemaphore(value: 0)
    private let releaseSignal = DispatchSemaphore(value: 0)
    private var didBlock = false

    func blockOnce() {
        let shouldBlock = lock.withLock {
            guard !didBlock else { return false }
            didBlock = true
            return true
        }
        guard shouldBlock else { return }
        blocked.signal()
        _ = releaseSignal.wait(timeout: .now() + 10)
    }

    func waitUntilBlocked() -> Bool {
        blocked.wait(timeout: .now() + 10) == .success
    }

    func open() {
        releaseSignal.signal()
    }
}

private final class CoordinatorGateProbe: @unchecked Sendable {
    private let lock = NSLock()
    private let enqueued = DispatchSemaphore(value: 0)
    private var storedGrantedCount = 0
    private var storedReleasedCount = 0

    var grantedCount: Int { lock.withLock { storedGrantedCount } }
    var releasedCount: Int { lock.withLock { storedReleasedCount } }

    func record(_ event: IOSPersistenceOperationGate.Event) {
        switch event {
        case .enqueued:
            enqueued.signal()
        case .granted:
            lock.withLock { storedGrantedCount += 1 }
        case .released:
            lock.withLock { storedReleasedCount += 1 }
        case .installing, .claiming, .cancelled:
            break
        }
    }

    func waitUntilEnqueued() -> Bool {
        enqueued.wait(timeout: .now() + 10) == .success
    }
}

private func coordinatorHistoryEntry() throws -> IOSAcceptedHistoryEntry {
    try IOSAcceptedHistoryEntry(
        deliveryID: UUID(),
        transcriptID: UUID(),
        acceptedText: "accepted",
        outputIntent: .standard,
        createdAt: coordinatorDate(),
        policyGeneration: 1,
        transcriptionModel: "model",
        transcriptionLanguageCode: nil,
        durationMilliseconds: nil,
        cachedAudioRelativeIdentifier: nil
    )
}

private func coordinatorOutboxEntry() throws -> IOSAcceptedHistoryOutboxEntry {
    try IOSAcceptedHistoryOutboxEntry(
        deliveryID: UUID(),
        transcriptID: UUID(),
        acceptedText: "accepted",
        outputIntent: .standard,
        createdAt: coordinatorDate(),
        expiresAt: coordinatorDate().addingTimeInterval(86_400),
        policyGeneration: 1,
        transcriptionModel: "model",
        transcriptionLanguageCode: nil,
        durationMilliseconds: nil
    )
}

private func coordinatorDeliveryRecord(
    historyWrite: IOSAcceptedOutputHistoryWrite?
) throws -> IOSAcceptedOutputDeliveryRecord {
    let date = coordinatorDate()
    return try IOSAcceptedOutputDeliveryRecord(
        revision: 1,
        deliveryID: UUID(),
        sessionID: UUID(),
        attemptID: UUID(),
        transcriptID: UUID(),
        acceptedText: "accepted",
        outputIntent: .standard,
        createdAt: date,
        updatedAt: date,
        expiresAt: date.addingTimeInterval(86_400),
        deliveryState: .pending,
        automaticInsertionPreferenceEnabled: true,
        keepLatestResult: true,
        publicationGeneration: 0,
        historyWrite: historyWrite
    )
}

private func coordinatorDate() -> Date {
    Date(timeIntervalSince1970: 1_800_000_000)
}

private struct CoordinatorFileIdentity: Equatable {
    let device: dev_t
    let inode: ino_t
}

private func coordinatorFileIdentity(_ url: URL) -> CoordinatorFileIdentity? {
    var status = stat()
    let didRead = url.withUnsafeFileSystemRepresentation { path in
        guard let path else { return false }
        return Darwin.lstat(path, &status) == 0
    }
    guard didRead else { return nil }
    return CoordinatorFileIdentity(
        device: status.st_dev,
        inode: status.st_ino
    )
}
