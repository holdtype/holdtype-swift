import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSVoiceSceneRegistryTests {
    @Test func constructionIsPassiveAndOpaqueValuesAreRedacted() throws {
        let events = VoiceSceneEventRecorder()
        let registry = IOSVoiceSceneRegistry()
        let subscription = registry.observeEvents { event in
            events.record(event)
        }
        defer { subscription.cancel() }

        #expect(
            registry.snapshot == IOSVoiceSceneRegistrySnapshot(
                registeredSceneCount: 0,
                foregroundActiveSceneCount: 0,
                isForegroundActive: false,
                revision: 0
            )
        )
        #expect(events.values.isEmpty)
        #expect(
            String(reflecting: subscription)
                == "IOSVoiceSceneEventSubscription"
        )

        let scene = registry.registerScene(initialActivity: .background)
        #expect(events.values.isEmpty)
        #expect(scene.promptPresentation == .unavailable)
        #expect(scene.acquireStartLease() == nil)
        #expect(String(describing: scene) == "IOSVoiceSceneFacade")
        #expect(
            String(reflecting: scene.identity)
                == "IOSVoiceSceneIdentity"
        )

        #expect(scene.updateActivity(.active) == .accepted)
        let lease = try #require(scene.acquireStartLease())
        #expect(
            String(reflecting: lease) == "IOSVoiceSceneStartLease"
        )
        let event = try #require(events.values.last)
        #expect(
            String(reflecting: event) == "IOSVoiceSceneRegistryEvent"
        )

        var identityDump = ""
        dump(scene.identity, to: &identityDump)
        #expect(!identityDump.contains("registryIdentity"))
        #expect(!identityDump.contains("generation"))
        #expect(!identityDump.contains("value:"))
    }

    @Test func oneOfTwoActiveScenesMayResignWithoutStoppingVoice() throws {
        let events = VoiceSceneEventRecorder()
        let registry = IOSVoiceSceneRegistry()
        let subscription = registry.observeEvents { events.record($0) }
        defer { subscription.cancel() }
        let first = registry.registerScene(initialActivity: .active)
        let second = registry.registerScene(initialActivity: .active)
        events.removeAll()

        #expect(first.updateActivity(.inactive) == .accepted)
        #expect(registry.snapshot.foregroundActiveSceneCount == 1)
        #expect(registry.snapshot.isForegroundActive)
        #expect(events.values.isEmpty)

        #expect(second.updateActivity(.inactive) == .accepted)
        #expect(registry.snapshot.foregroundActiveSceneCount == 0)
        let loss = try #require(events.values.last)
        #expect(
            loss.kind
                == .lastActiveSceneLost(.voiceWorkMustStop)
        )
        #expect(registry.validate(loss))

        #expect(first.updateActivity(.active) == .accepted)
        #expect(!registry.validate(loss))
        #expect(events.values.last?.kind == .aggregateBecameActive)
    }

    @Test func initiatingSceneDisappearanceRetiresItsExactLease() throws {
        let events = VoiceSceneEventRecorder()
        let registry = IOSVoiceSceneRegistry()
        let subscription = registry.observeEvents { events.record($0) }
        defer { subscription.cancel() }
        let scene = registry.registerScene(initialActivity: .active)
        let lease = try #require(scene.acquireStartLease())
        events.removeAll()

        #expect(scene.unregister() == .accepted)
        #expect(scene.unregister() == .stale)
        #expect(scene.updateActivity(.active) == .stale)
        #expect(scene.promptPresentation == .unavailable)
        #expect(registry.validateContinuation(lease) == .stale)
        #expect(!registry.beginExpectedMicrophonePermissionPrompt(lease))
        #expect(registry.microphonePermissionPromptDidReturn(lease) == .stale)
        #expect(!registry.finishStartLease(lease))
        #expect(
            events.values.map(\.kind) == [
                .initiatingSceneBecameUnavailable,
                .lastActiveSceneLost(.voiceWorkMustStop),
            ]
        )
    }

    @Test func expectedPermissionSheetIsTheOnlyInactiveException()
        async throws {
        let events = VoiceSceneEventRecorder()
        let registry = IOSVoiceSceneRegistry()
        let subscription = registry.observeEvents { events.record($0) }
        defer { subscription.cancel() }
        let scene = registry.registerScene(initialActivity: .active)
        let lease = try #require(scene.acquireStartLease())
        #expect(registry.beginExpectedMicrophonePermissionPrompt(lease))
        events.removeAll()

        #expect(scene.updateActivity(.inactive) == .accepted)
        let loss = try #require(events.values.last)
        #expect(
            loss.kind == .lastActiveSceneLost(
                .expectedMicrophonePermissionPrompt
            )
        )
        #expect(registry.validate(loss))
        #expect(
            registry.validateContinuation(lease)
                == .awaitingPermissionDecision
        )

        #expect(
            registry.microphonePermissionPromptDidReturn(lease)
                == .awaitingInitiatingSceneReactivation
        )
        #expect(!registry.validate(loss))
        #expect(
            registry.validateContinuation(lease)
                == .awaitingInitiatingSceneReactivation
        )

        let waiter = Task { @MainActor in
            await registry.waitUntilInitiatingSceneActive(lease)
        }
        await Task.yield()
        #expect(scene.updateActivity(.active) == .accepted)
        #expect(await waiter.value == .ready)
        #expect(registry.validateContinuation(lease) == .ready)
        #expect(
            events.values.map(\.kind).suffix(2) == [
                .initiatingSceneReactivatedAfterPermission,
                .aggregateBecameActive,
            ]
        )
        #expect(registry.finishStartLease(lease))
        #expect(registry.validateContinuation(lease) == .stale)
    }

    @Test func ordinaryInactiveInitiatingSceneCannotContinueConsent()
        throws {
        let events = VoiceSceneEventRecorder()
        let registry = IOSVoiceSceneRegistry()
        let subscription = registry.observeEvents { events.record($0) }
        defer { subscription.cancel() }
        let scene = registry.registerScene(initialActivity: .active)
        let lease = try #require(scene.acquireStartLease())
        events.removeAll()

        #expect(scene.updateActivity(.inactive) == .accepted)
        #expect(registry.validateContinuation(lease) == .stale)
        #expect(
            events.values.map(\.kind) == [
                .initiatingSceneBecameUnavailable,
                .lastActiveSceneLost(.voiceWorkMustStop),
            ]
        )
    }

    @Test func promptOwnershipCannotTransferBetweenScenes() throws {
        let registry = IOSVoiceSceneRegistry()
        let initiating = registry.registerScene(initialActivity: .active)
        let other = registry.registerScene(initialActivity: .active)
        let firstLease = try #require(initiating.acquireStartLease())

        #expect(initiating.promptPresentation == .ownedByThisScene)
        #expect(other.promptPresentation == .ownedByAnotherScene)
        #expect(other.acquireStartLease() == nil)

        #expect(initiating.updateActivity(.inactive) == .accepted)
        #expect(registry.validateContinuation(firstLease) == .stale)
        let secondLease = try #require(other.acquireStartLease())
        #expect(secondLease != firstLease)
        #expect(
            registry.microphonePermissionPromptDidReturn(firstLease)
                == .stale
        )
        #expect(registry.validateContinuation(secondLease) == .ready)
    }

    @Test func backgroundInvalidatesPermissionExceptionEvenWithOtherScene()
        throws {
        let events = VoiceSceneEventRecorder()
        let registry = IOSVoiceSceneRegistry()
        let subscription = registry.observeEvents { events.record($0) }
        defer { subscription.cancel() }
        let initiating = registry.registerScene(initialActivity: .active)
        _ = registry.registerScene(initialActivity: .active)
        let lease = try #require(initiating.acquireStartLease())
        #expect(registry.beginExpectedMicrophonePermissionPrompt(lease))
        events.removeAll()

        #expect(initiating.updateActivity(.background) == .accepted)
        #expect(registry.snapshot.isForegroundActive)
        #expect(registry.validateContinuation(lease) == .stale)
        #expect(
            events.values.map(\.kind)
                == [.initiatingSceneBecameUnavailable]
        )
    }

    @Test func permissionCompletionWhileActiveStillRequiresFreshLeaseProof()
        throws {
        let registry = IOSVoiceSceneRegistry()
        let scene = registry.registerScene(initialActivity: .active)
        let lease = try #require(scene.acquireStartLease())
        #expect(registry.beginExpectedMicrophonePermissionPrompt(lease))

        #expect(registry.microphonePermissionPromptDidReturn(lease) == .ready)
        #expect(registry.validateContinuation(lease) == .ready)
        #expect(scene.updateActivity(.inactive) == .accepted)
        #expect(registry.validateContinuation(lease) == .stale)
    }

    @Test func staleSceneAndEventCapabilitiesFailAcrossRegistries() throws {
        let firstEvents = VoiceSceneEventRecorder()
        let firstRegistry = IOSVoiceSceneRegistry()
        let subscription = firstRegistry.observeEvents {
            firstEvents.record($0)
        }
        defer { subscription.cancel() }
        let firstScene = firstRegistry.registerScene(initialActivity: .active)
        let firstEvent = try #require(firstEvents.values.last)
        let firstLease = try #require(firstScene.acquireStartLease())

        let secondRegistry = IOSVoiceSceneRegistry()
        let secondScene = secondRegistry.registerScene(initialActivity: .active)

        #expect(
            secondRegistry.updateActivity(
                .inactive,
                for: firstScene.identity
            ) == .stale
        )
        #expect(!secondRegistry.validate(firstEvent))
        #expect(secondRegistry.validateContinuation(firstLease) == .stale)
        #expect(secondScene.promptPresentation == .available)
    }

    @Test func cancelledReactivationWaitDoesNotLeaveAContinuation()
        async throws {
        let registry = IOSVoiceSceneRegistry()
        let scene = registry.registerScene(initialActivity: .active)
        let lease = try #require(scene.acquireStartLease())
        #expect(registry.beginExpectedMicrophonePermissionPrompt(lease))
        #expect(scene.updateActivity(.inactive) == .accepted)
        #expect(
            registry.microphonePermissionPromptDidReturn(lease)
                == .awaitingInitiatingSceneReactivation
        )

        let waiter = Task { @MainActor in
            await registry.waitUntilInitiatingSceneActive(lease)
        }
        await Task.yield()
        waiter.cancel()
        #expect(await waiter.value == .stale)

        #expect(scene.updateActivity(.active) == .accepted)
        #expect(registry.validateContinuation(lease) == .ready)
    }

    @Test func eventSubscriptionsCancelIdempotentlyAndAreReentrantSafe() {
        let registry = IOSVoiceSceneRegistry()
        let scene = registry.registerScene(initialActivity: .background)
        let harness = VoiceSceneSubscriptionHarness()

        harness.first = registry.observeEvents { event in
            harness.calls.append(
                VoiceSceneObserverCall(observer: "first", kind: event.kind)
            )
            if event.kind == .aggregateBecameActive {
                _ = harness.second?.cancel()
                if harness.third == nil {
                    harness.third = registry.observeEvents { nestedEvent in
                        harness.calls.append(
                            VoiceSceneObserverCall(
                                observer: "third",
                                kind: nestedEvent.kind
                            )
                        )
                    }
                }
                if !harness.performedReentrantMutation {
                    harness.performedReentrantMutation = true
                    _ = scene.updateActivity(.inactive)
                }
            }
        }
        harness.second = registry.observeEvents { event in
            harness.calls.append(
                VoiceSceneObserverCall(observer: "second", kind: event.kind)
            )
        }

        #expect(scene.updateActivity(.active) == .accepted)
        #expect(!registry.snapshot.isForegroundActive)
        #expect(
            harness.calls == [
                VoiceSceneObserverCall(
                    observer: "first",
                    kind: .aggregateBecameActive
                ),
                VoiceSceneObserverCall(
                    observer: "first",
                    kind: .lastActiveSceneLost(.voiceWorkMustStop)
                ),
                VoiceSceneObserverCall(
                    observer: "third",
                    kind: .lastActiveSceneLost(.voiceWorkMustStop)
                ),
            ]
        )
        #expect(harness.second?.cancel() == false)
        #expect(harness.first?.cancel() == true)
        #expect(harness.first?.cancel() == false)

        harness.calls.removeAll()
        #expect(scene.updateActivity(.active) == .accepted)
        #expect(
            harness.calls == [
                VoiceSceneObserverCall(
                    observer: "third",
                    kind: .aggregateBecameActive
                )
            ]
        )
    }
}

@MainActor
private final class VoiceSceneEventRecorder {
    private(set) var values: [IOSVoiceSceneRegistryEvent] = []

    func record(_ event: IOSVoiceSceneRegistryEvent) {
        values.append(event)
    }

    func removeAll() {
        values.removeAll()
    }
}

@MainActor
private final class VoiceSceneSubscriptionHarness {
    var first: IOSVoiceSceneEventSubscription?
    var second: IOSVoiceSceneEventSubscription?
    var third: IOSVoiceSceneEventSubscription?
    var performedReentrantMutation = false
    var calls: [VoiceSceneObserverCall] = []
}

private struct VoiceSceneObserverCall: Equatable {
    let observer: String
    let kind: IOSVoiceSceneRegistryEvent.Kind
}
