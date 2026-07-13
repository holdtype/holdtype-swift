import Foundation

nonisolated enum IOSVoiceSceneActivity: Equatable, Sendable {
    case active
    case inactive
    case background
}

nonisolated struct IOSVoiceSceneIdentity: Hashable, Sendable {
    fileprivate let registryIdentity: ObjectIdentifier
    fileprivate let value: UInt64
}

extension IOSVoiceSceneIdentity:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    var description: String { "IOSVoiceSceneIdentity" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["identity": "opaque"])
    }
}

nonisolated struct IOSVoiceSceneStartLease: Hashable, Sendable {
    fileprivate let registryIdentity: ObjectIdentifier
    fileprivate let sceneValue: UInt64
    fileprivate let generation: UInt64
    fileprivate let registry: IOSVoiceSceneRegistry

    static func == (
        lhs: IOSVoiceSceneStartLease,
        rhs: IOSVoiceSceneStartLease
    ) -> Bool {
        lhs.registryIdentity == rhs.registryIdentity
            && lhs.sceneValue == rhs.sceneValue
            && lhs.generation == rhs.generation
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(registryIdentity)
        hasher.combine(sceneValue)
        hasher.combine(generation)
    }

    /// Retires this exact capability. Accepted Start work owns this call;
    /// callers never need access to the registry's private identity fields.
    @MainActor
    @discardableResult
    func finish() -> Bool {
        registry.finishStartLease(self)
    }
}

/// Opaque, short-lived proof that the invoking scene owns the exact current
/// Start prompt. The registry revalidates it at every decision; retaining a
/// capability cannot transfer ownership to a later attempt.
nonisolated struct IOSVoiceScenePromptDecisionCapability:
    Equatable,
    Hashable,
    Sendable {
    fileprivate let registryIdentity: ObjectIdentifier
    fileprivate let sceneValue: UInt64
    fileprivate let generation: UInt64
}

extension IOSVoiceScenePromptDecisionCapability:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    var description: String { "IOSVoiceScenePromptDecisionCapability" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["capability": "opaque"])
    }
}

extension IOSVoiceSceneStartLease:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    var description: String { "IOSVoiceSceneStartLease" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["lease": "opaque"])
    }
}

nonisolated enum IOSVoiceSceneRegistrationMutation: Equatable, Sendable {
    case accepted
    case unchanged
    case stale
}

nonisolated enum IOSVoiceSceneContinuationValidation: Equatable, Sendable {
    case ready
    case awaitingPermissionDecision
    case awaitingInitiatingSceneReactivation
    case stale
}

nonisolated enum IOSVoiceScenePromptPresentation: Equatable, Sendable {
    case available
    case ownedByThisScene
    case ownedByAnotherScene
    case unavailable
}

nonisolated enum IOSVoiceSceneForegroundLossDisposition: Equatable, Sendable {
    case expectedMicrophonePermissionPrompt
    case voiceWorkMustStop
}

nonisolated struct IOSVoiceSceneRegistryEvent: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case aggregateBecameActive
        case lastActiveSceneLost(IOSVoiceSceneForegroundLossDisposition)
        case initiatingSceneBecameUnavailable
        case initiatingSceneReactivatedAfterPermission
    }

    let kind: Kind

    fileprivate let registryIdentity: ObjectIdentifier
    fileprivate let foregroundRevision: UInt64
    fileprivate let promptRevision: UInt64
}

extension IOSVoiceSceneRegistryEvent:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    var description: String { "IOSVoiceSceneRegistryEvent" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["event": "content-free"])
    }
}

nonisolated struct IOSVoiceSceneRegistrySnapshot: Equatable, Sendable {
    let registeredSceneCount: Int
    let foregroundActiveSceneCount: Int
    let isForegroundActive: Bool
    let revision: UInt64
}

/// Thread-safe exact-once storage for a MainActor observer-removal action.
/// Explicit cancellation runs synchronously on MainActor. If the subscription's
/// last reference is released on another executor, token deinitialization uses
/// a supported asynchronous hop without assuming executor identity.
private nonisolated final class IOSVoiceSceneMainActorCancellationToken:
    @unchecked Sendable {
    typealias Action = @MainActor @Sendable () -> Bool

    private let lock = NSLock()
    private var action: Action?

    init(_ action: @escaping Action) {
        self.action = action
    }

    @MainActor
    func cancel() -> Bool {
        take()?() ?? false
    }

    private func take() -> Action? {
        lock.lock()
        defer { lock.unlock() }
        let pendingAction = action
        action = nil
        return pendingAction
    }

    deinit {
        guard let action = take() else { return }
        Task { @MainActor in
            _ = action()
        }
    }
}

@MainActor
final class IOSVoiceSceneEventSubscription:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    private let cancellationToken: IOSVoiceSceneMainActorCancellationToken

    fileprivate init(
        registry: IOSVoiceSceneRegistry,
        observerValue: UInt64
    ) {
        cancellationToken = IOSVoiceSceneMainActorCancellationToken {
            [weak registry] in
            registry?.removeEventObserver(observerValue) ?? false
        }
    }

    var description: String { "IOSVoiceSceneEventSubscription" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["subscription": "opaque"])
    }

    @discardableResult
    func cancel() -> Bool {
        cancellationToken.cancel()
    }
}

@MainActor
final class IOSVoiceSceneFacade:
    CustomDebugStringConvertible,
    CustomReflectable,
    CustomStringConvertible {
    private weak var registry: IOSVoiceSceneRegistry?
    let identity: IOSVoiceSceneIdentity

    fileprivate init(
        registry: IOSVoiceSceneRegistry,
        identity: IOSVoiceSceneIdentity
    ) {
        self.registry = registry
        self.identity = identity
    }

    var description: String { "IOSVoiceSceneFacade" }
    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(self, children: ["scene": "opaque"])
    }

    var promptPresentation: IOSVoiceScenePromptPresentation {
        guard let registry else { return .unavailable }
        return registry.promptPresentation(for: identity)
    }

    @discardableResult
    func updateActivity(
        _ activity: IOSVoiceSceneActivity
    ) -> IOSVoiceSceneRegistrationMutation {
        guard let registry else { return .stale }
        return registry.updateActivity(activity, for: identity)
    }

    @discardableResult
    func unregister() -> IOSVoiceSceneRegistrationMutation {
        guard let registry else { return .stale }
        return registry.unregisterScene(identity)
    }

    func acquireStartLease() -> IOSVoiceSceneStartLease? {
        registry?.acquireStartLease(initiatingScene: identity)
    }

    func promptDecisionCapability()
        -> IOSVoiceScenePromptDecisionCapability? {
        registry?.makePromptDecisionCapability(for: identity)
    }
}

@MainActor
final class IOSVoiceSceneRegistry {
    typealias EventSink = @MainActor @Sendable (
        IOSVoiceSceneRegistryEvent
    ) -> Void

    private struct SceneRecord {
        var activity: IOSVoiceSceneActivity
    }

    private enum PromptPhase {
        case preflight
        case permissionPromptExpected
        case awaitingReactivation
        case readyAfterPermission
    }

    private struct PromptOwner {
        let sceneValue: UInt64
        let generation: UInt64
        var phase: PromptPhase
    }

    private struct ActivationWaiter {
        let lease: IOSVoiceSceneStartLease
        let continuation: CheckedContinuation<
            IOSVoiceSceneContinuationValidation,
            Never
        >
    }

    private var scenes: [UInt64: SceneRecord] = [:]
    private var promptOwner: PromptOwner?
    private var activationWaiters: [UInt64: ActivationWaiter] = [:]
    private var eventObservers: [UInt64: EventSink] = [:]
    private var nextSceneValue: UInt64 = 1
    private var nextPromptGeneration: UInt64 = 1
    private var nextWaiterValue: UInt64 = 1
    private var nextObserverValue: UInt64 = 1
    private var revision: UInt64 = 0
    private var foregroundRevision: UInt64 = 0
    private var promptRevision: UInt64 = 0

    init() {}

    var snapshot: IOSVoiceSceneRegistrySnapshot {
        let activeCount = foregroundActiveSceneCount
        return IOSVoiceSceneRegistrySnapshot(
            registeredSceneCount: scenes.count,
            foregroundActiveSceneCount: activeCount,
            isForegroundActive: activeCount > 0,
            revision: revision
        )
    }

    var activeEventSubscriptionCount: Int {
        eventObservers.count
    }

    func observeEvents(
        _ observer: @escaping EventSink
    ) -> IOSVoiceSceneEventSubscription {
        let observerValue = nextObserverValue
        nextObserverValue &+= 1
        eventObservers[observerValue] = observer
        return IOSVoiceSceneEventSubscription(
            registry: self,
            observerValue: observerValue
        )
    }

    func registerScene(
        initialActivity: IOSVoiceSceneActivity = .background
    ) -> IOSVoiceSceneFacade {
        let wasForegroundActive = isForegroundActive
        let identity = IOSVoiceSceneIdentity(
            registryIdentity: ObjectIdentifier(self),
            value: nextSceneValue
        )
        nextSceneValue &+= 1
        scenes[identity.value] = SceneRecord(activity: initialActivity)
        advanceRevision()

        var events: [IOSVoiceSceneRegistryEvent] = []
        appendAggregateTransitionIfNeeded(
            wasForegroundActive: wasForegroundActive,
            to: &events
        )
        emit(events)
        return IOSVoiceSceneFacade(registry: self, identity: identity)
    }

    @discardableResult
    func updateActivity(
        _ activity: IOSVoiceSceneActivity,
        for identity: IOSVoiceSceneIdentity
    ) -> IOSVoiceSceneRegistrationMutation {
        guard owns(identity),
              let current = scenes[identity.value] else {
            return .stale
        }
        guard current.activity != activity else { return .unchanged }

        let wasForegroundActive = isForegroundActive
        scenes[identity.value]?.activity = activity
        advanceRevision()

        var events: [IOSVoiceSceneRegistryEvent] = []
        reconcilePromptOwnerAfterSceneMutation(
            sceneValue: identity.value,
            activity: activity,
            events: &events
        )
        appendAggregateTransitionIfNeeded(
            wasForegroundActive: wasForegroundActive,
            to: &events
        )
        emit(events)
        return .accepted
    }

    @discardableResult
    func unregisterScene(
        _ identity: IOSVoiceSceneIdentity
    ) -> IOSVoiceSceneRegistrationMutation {
        guard owns(identity), scenes[identity.value] != nil else {
            return .stale
        }

        let wasForegroundActive = isForegroundActive
        scenes.removeValue(forKey: identity.value)
        advanceRevision()

        var events: [IOSVoiceSceneRegistryEvent] = []
        if promptOwner?.sceneValue == identity.value {
            invalidatePromptOwner(emitUnavailableEvent: true, events: &events)
        }
        appendAggregateTransitionIfNeeded(
            wasForegroundActive: wasForegroundActive,
            to: &events
        )
        emit(events)
        return .accepted
    }

    func promptPresentation(
        for identity: IOSVoiceSceneIdentity
    ) -> IOSVoiceScenePromptPresentation {
        guard owns(identity), let scene = scenes[identity.value] else {
            return .unavailable
        }
        guard let promptOwner else {
            return scene.activity == .active ? .available : .unavailable
        }
        return promptOwner.sceneValue == identity.value
            ? .ownedByThisScene
            : .ownedByAnotherScene
    }

    func acquireStartLease(
        initiatingScene identity: IOSVoiceSceneIdentity
    ) -> IOSVoiceSceneStartLease? {
        guard promptOwner == nil,
              owns(identity),
              scenes[identity.value]?.activity == .active,
              isForegroundActive else {
            return nil
        }

        let generation = nextPromptGeneration
        nextPromptGeneration &+= 1
        promptOwner = PromptOwner(
            sceneValue: identity.value,
            generation: generation,
            phase: .preflight
        )
        advanceRevision()
        advancePromptRevision()
        return IOSVoiceSceneStartLease(
            registryIdentity: ObjectIdentifier(self),
            sceneValue: identity.value,
            generation: generation,
            registry: self
        )
    }

    func validateContinuation(
        _ lease: IOSVoiceSceneStartLease
    ) -> IOSVoiceSceneContinuationValidation {
        guard let owner = exactOwner(for: lease),
              let scene = scenes[owner.sceneValue] else {
            return .stale
        }

        switch owner.phase {
        case .permissionPromptExpected:
            return .awaitingPermissionDecision
        case .awaitingReactivation:
            return .awaitingInitiatingSceneReactivation
        case .preflight, .readyAfterPermission:
            return scene.activity == .active && isForegroundActive
                ? .ready
                : .stale
        }
    }

    func validatePromptDecision(
        _ capability: IOSVoiceScenePromptDecisionCapability,
        for lease: IOSVoiceSceneStartLease
    ) -> Bool {
        guard capability.registryIdentity == ObjectIdentifier(self),
              capability.sceneValue == lease.sceneValue,
              capability.generation == lease.generation,
              let owner = exactOwner(for: lease) else {
            return false
        }
        return owner.sceneValue == capability.sceneValue
            && owner.generation == capability.generation
    }

    @discardableResult
    func beginExpectedMicrophonePermissionPrompt(
        _ lease: IOSVoiceSceneStartLease
    ) -> Bool {
        guard let owner = exactOwner(for: lease),
              owner.phase == .preflight,
              scenes[owner.sceneValue]?.activity == .active,
              isForegroundActive else {
            return false
        }
        promptOwner?.phase = .permissionPromptExpected
        advanceRevision()
        advancePromptRevision()
        return true
    }

    func microphonePermissionPromptDidReturn(
        _ lease: IOSVoiceSceneStartLease
    ) -> IOSVoiceSceneContinuationValidation {
        guard let owner = exactOwner(for: lease),
              owner.phase == .permissionPromptExpected,
              let scene = scenes[owner.sceneValue] else {
            return .stale
        }

        advanceRevision()
        advancePromptRevision()
        if scene.activity == .active {
            promptOwner?.phase = .readyAfterPermission
            return .ready
        }

        promptOwner?.phase = .awaitingReactivation
        // The permission-sheet exception event is no longer a current stop
        // decision after the system callback returns. The same scene must
        // reactivate before the original explicit Start can continue.
        foregroundRevision &+= 1
        return .awaitingInitiatingSceneReactivation
    }

    func waitUntilInitiatingSceneActive(
        _ lease: IOSVoiceSceneStartLease
    ) async -> IOSVoiceSceneContinuationValidation {
        let current = validateContinuation(lease)
        guard current == .awaitingInitiatingSceneReactivation else {
            return current
        }

        let waiterValue = nextWaiterValue
        nextWaiterValue &+= 1
        let registry = self
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard !Task.isCancelled else {
                    continuation.resume(returning: .stale)
                    return
                }
                let revalidated = validateContinuation(lease)
                guard revalidated == .awaitingInitiatingSceneReactivation else {
                    continuation.resume(returning: revalidated)
                    return
                }
                activationWaiters[waiterValue] = ActivationWaiter(
                    lease: lease,
                    continuation: continuation
                )
            }
        } onCancel: {
            Task { @MainActor in
                registry.cancelActivationWaiter(waiterValue)
            }
        }
    }

    @discardableResult
    func finishStartLease(_ lease: IOSVoiceSceneStartLease) -> Bool {
        guard exactOwner(for: lease) != nil else { return false }
        var events: [IOSVoiceSceneRegistryEvent] = []
        invalidatePromptOwner(emitUnavailableEvent: false, events: &events)
        advanceRevision()
        return true
    }

    func validate(_ event: IOSVoiceSceneRegistryEvent) -> Bool {
        guard event.registryIdentity == ObjectIdentifier(self) else {
            return false
        }
        switch event.kind {
        case .aggregateBecameActive:
            return event.foregroundRevision == foregroundRevision
                && isForegroundActive
        case let .lastActiveSceneLost(disposition):
            return event.foregroundRevision == foregroundRevision
                && !isForegroundActive
                && foregroundLossDisposition == disposition
        case .initiatingSceneBecameUnavailable:
            return event.promptRevision == promptRevision
                && promptOwner == nil
        case .initiatingSceneReactivatedAfterPermission:
            guard event.promptRevision == promptRevision,
                  let promptOwner,
                  promptOwner.phase == .readyAfterPermission else {
                return false
            }
            return scenes[promptOwner.sceneValue]?.activity == .active
        }
    }

    private var foregroundActiveSceneCount: Int {
        scenes.values.reduce(into: 0) { count, scene in
            if scene.activity == .active {
                count += 1
            }
        }
    }

    private var isForegroundActive: Bool {
        foregroundActiveSceneCount > 0
    }

    private var foregroundLossDisposition:
        IOSVoiceSceneForegroundLossDisposition {
        guard let promptOwner,
              promptOwner.phase == .permissionPromptExpected,
              scenes[promptOwner.sceneValue]?.activity == .inactive else {
            return .voiceWorkMustStop
        }
        return .expectedMicrophonePermissionPrompt
    }

    private func owns(_ identity: IOSVoiceSceneIdentity) -> Bool {
        identity.registryIdentity == ObjectIdentifier(self)
    }

    private func exactOwner(
        for lease: IOSVoiceSceneStartLease
    ) -> PromptOwner? {
        guard lease.registryIdentity == ObjectIdentifier(self),
              let promptOwner,
              promptOwner.sceneValue == lease.sceneValue,
              promptOwner.generation == lease.generation else {
            return nil
        }
        return promptOwner
    }

    fileprivate func makePromptDecisionCapability(
        for identity: IOSVoiceSceneIdentity
    ) -> IOSVoiceScenePromptDecisionCapability? {
        guard owns(identity),
              let owner = promptOwner,
              owner.sceneValue == identity.value else {
            return nil
        }
        return IOSVoiceScenePromptDecisionCapability(
            registryIdentity: ObjectIdentifier(self),
            sceneValue: owner.sceneValue,
            generation: owner.generation
        )
    }

    private func reconcilePromptOwnerAfterSceneMutation(
        sceneValue: UInt64,
        activity: IOSVoiceSceneActivity,
        events: inout [IOSVoiceSceneRegistryEvent]
    ) {
        guard let owner = promptOwner,
              owner.sceneValue == sceneValue else {
            return
        }

        switch activity {
        case .active:
            guard owner.phase == .awaitingReactivation else { return }
            promptOwner?.phase = .readyAfterPermission
            advancePromptRevision()
            let event = makeEvent(
                .initiatingSceneReactivatedAfterPermission
            )
            events.append(event)
            resumeActivationWaiters(for: owner, returning: .ready)
        case .inactive:
            guard owner.phase != .permissionPromptExpected,
                  owner.phase != .awaitingReactivation else {
                return
            }
            invalidatePromptOwner(
                emitUnavailableEvent: true,
                events: &events
            )
        case .background:
            invalidatePromptOwner(
                emitUnavailableEvent: true,
                events: &events
            )
        }
    }

    private func invalidatePromptOwner(
        emitUnavailableEvent: Bool,
        events: inout [IOSVoiceSceneRegistryEvent]
    ) {
        guard let owner = promptOwner else { return }
        promptOwner = nil
        advancePromptRevision()
        resumeActivationWaiters(for: owner, returning: .stale)
        if emitUnavailableEvent {
            events.append(makeEvent(.initiatingSceneBecameUnavailable))
        }
    }

    private func appendAggregateTransitionIfNeeded(
        wasForegroundActive: Bool,
        to events: inout [IOSVoiceSceneRegistryEvent]
    ) {
        let foregroundActive = isForegroundActive
        guard foregroundActive != wasForegroundActive else { return }
        foregroundRevision &+= 1
        if foregroundActive {
            events.append(makeEvent(.aggregateBecameActive))
        } else {
            events.append(
                makeEvent(
                    .lastActiveSceneLost(foregroundLossDisposition)
                )
            )
        }
    }

    private func makeEvent(
        _ kind: IOSVoiceSceneRegistryEvent.Kind
    ) -> IOSVoiceSceneRegistryEvent {
        IOSVoiceSceneRegistryEvent(
            kind: kind,
            registryIdentity: ObjectIdentifier(self),
            foregroundRevision: foregroundRevision,
            promptRevision: promptRevision
        )
    }

    private func emit(_ events: [IOSVoiceSceneRegistryEvent]) {
        for event in events {
            let observerValues = eventObservers.keys.sorted()
            for observerValue in observerValues {
                // A prior callback may cancel itself or another observer.
                // Added observers begin with the next event, not midway
                // through the event currently being delivered.
                guard let observer = eventObservers[observerValue] else {
                    continue
                }
                observer(event)
            }
        }
    }

    fileprivate func removeEventObserver(_ observerValue: UInt64) -> Bool {
        eventObservers.removeValue(forKey: observerValue) != nil
    }

    private func advanceRevision() {
        revision &+= 1
    }

    private func advancePromptRevision() {
        promptRevision &+= 1
    }

    private func resumeActivationWaiters(
        for owner: PromptOwner,
        returning validation: IOSVoiceSceneContinuationValidation
    ) {
        let matching = activationWaiters.filter { _, waiter in
            waiter.lease.sceneValue == owner.sceneValue
                && waiter.lease.generation == owner.generation
        }
        for (key, waiter) in matching {
            activationWaiters.removeValue(forKey: key)
            waiter.continuation.resume(returning: validation)
        }
    }

    private func cancelActivationWaiter(_ waiterValue: UInt64) {
        guard let waiter = activationWaiters.removeValue(
            forKey: waiterValue
        ) else {
            return
        }
        waiter.continuation.resume(returning: .stale)
    }
}
