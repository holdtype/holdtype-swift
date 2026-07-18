import Foundation

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
        cancellation: @escaping @MainActor @Sendable () -> Bool
    ) {
        cancellationToken = IOSVoiceSceneMainActorCancellationToken(
            cancellation
        )
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
final class IOSVoiceSceneEventObservationOwner {
    typealias EventSink = @MainActor @Sendable (
        IOSVoiceSceneRegistryEvent
    ) -> Void

    private var observers: [UInt64: EventSink] = [:]
    private var nextObserverValue: UInt64 = 1

    var activeSubscriptionCount: Int {
        observers.count
    }

    func observe(
        _ observer: @escaping EventSink
    ) -> IOSVoiceSceneEventSubscription {
        let observerValue = nextObserverValue
        nextObserverValue &+= 1
        observers[observerValue] = observer
        return IOSVoiceSceneEventSubscription { [weak self] in
            self?.remove(observerValue) ?? false
        }
    }

    func emit(_ events: [IOSVoiceSceneRegistryEvent]) {
        for event in events {
            let observerValues = observers.keys.sorted()
            for observerValue in observerValues {
                // A prior callback may cancel itself or another observer.
                // Added observers begin with the next event, not midway
                // through the event currently being delivered.
                guard let observer = observers[observerValue] else {
                    continue
                }
                observer(event)
            }
        }
    }

    private func remove(_ observerValue: UInt64) -> Bool {
        observers.removeValue(forKey: observerValue) != nil
    }
}
