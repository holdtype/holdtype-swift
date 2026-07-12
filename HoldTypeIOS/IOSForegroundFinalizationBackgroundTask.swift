import UIKit

nonisolated struct IOSForegroundBackgroundTaskIdentifier:
    Equatable,
    Hashable,
    Sendable {
    fileprivate let rawValue: Int

    init(rawValue: Int) {
        self.rawValue = rawValue
    }
}

nonisolated struct IOSForegroundBackgroundTaskClient: Sendable {
    typealias Begin = @MainActor @Sendable (
        String,
        @escaping @MainActor @Sendable (
            IOSForegroundBackgroundTaskIdentifier
        ) -> Void
    ) -> IOSForegroundBackgroundTaskIdentifier?
    typealias End = @MainActor @Sendable (
        IOSForegroundBackgroundTaskIdentifier
    ) -> Void

    let begin: Begin
    let end: End

    init(begin: @escaping Begin, end: @escaping End) {
        self.begin = begin
        self.end = end
    }

    nonisolated static let live = IOSForegroundBackgroundTaskClient(
        begin: { name, expiration in
            let identity = IOSLiveBackgroundTaskIdentity()
            let identifier = UIApplication.shared.beginBackgroundTask(
                withName: name,
                expirationHandler: {
                    identity.requestExpiration(expiration)
                }
            )
            guard identifier != .invalid else { return nil }
            let result = IOSForegroundBackgroundTaskIdentifier(
                rawValue: identifier.rawValue
            )
            identity.assign(result, expiration: expiration)
            return result
        },
        end: { identifier in
            UIApplication.shared.endBackgroundTask(
                UIBackgroundTaskIdentifier(rawValue: identifier.rawValue)
            )
        }
    )
}

@MainActor
final class IOSLiveBackgroundTaskIdentity {
    private var identifier: IOSForegroundBackgroundTaskIdentifier?
    private var didRequestExpiration = false
    private var didDeliverExpiration = false

    func requestExpiration(
        _ expiration: @escaping @MainActor @Sendable (
            IOSForegroundBackgroundTaskIdentifier
        ) -> Void
    ) {
        didRequestExpiration = true
        deliverExpirationIfReady(expiration)
    }

    func assign(
        _ identifier: IOSForegroundBackgroundTaskIdentifier,
        expiration: @escaping @MainActor @Sendable (
            IOSForegroundBackgroundTaskIdentifier
        ) -> Void
    ) {
        self.identifier = identifier
        deliverExpirationIfReady(expiration)
    }

    private func deliverExpirationIfReady(
        _ expiration: @escaping @MainActor @Sendable (
            IOSForegroundBackgroundTaskIdentifier
        ) -> Void
    ) {
        guard didRequestExpiration,
              !didDeliverExpiration,
              let identifier else {
            return
        }
        didDeliverExpiration = true
        expiration(identifier)
    }
}

nonisolated struct IOSForegroundFinalizationBackgroundLease:
    Equatable,
    Hashable,
    Sendable {
    let token: UInt64
}

nonisolated enum IOSForegroundFinalizationExpirationReason:
    Equatable,
    Sendable {
    case systemExpiration
    case tenSecondWatchdog
    case cancelled
}

@MainActor
final class IOSForegroundFinalizationBackgroundTask {
    typealias Expiration = @MainActor @Sendable (
        IOSForegroundFinalizationExpirationReason
    ) -> Void
    typealias Sleep = @Sendable (Duration) async throws -> Void

    static let assertionName = "HoldType foreground recording finalization"
    static let maximumDuration = Duration.seconds(10)

    private let client: IOSForegroundBackgroundTaskClient
    private let sleep: Sleep
    private var nextToken: UInt64 = 0
    private var active: Active?

    init(
        client: IOSForegroundBackgroundTaskClient,
        sleep: @escaping Sleep = { duration in
            try await Task.sleep(for: duration)
        }
    ) {
        self.client = client
        self.sleep = sleep
    }

    convenience init() {
        self.init(client: .live)
    }

    var hasActiveFinalization: Bool { active != nil }

    func begin(
        onExpiration: @escaping Expiration
    ) -> IOSForegroundFinalizationBackgroundLease? {
        guard active == nil else { return nil }

        nextToken &+= 1
        let lease = IOSForegroundFinalizationBackgroundLease(
            token: nextToken
        )
        active = Active(lease: lease, onExpiration: onExpiration)

        let identifier = client.begin(Self.assertionName) {
            [weak self] identifier in
            self?.expire(
                lease,
                reason: .systemExpiration,
                eventIdentifier: identifier
            )
        }
        guard var current = active, current.lease == lease else {
            if let identifier {
                client.end(identifier)
            }
            return lease
        }
        if current.identifier == nil {
            current.identifier = identifier
        } else if let identifier,
                  current.identifier != identifier,
                  !current.didEndAssertion {
            client.end(identifier)
        }

        if current.expirationReason == nil {
            let sleep = sleep
            current.watchdog = Task { @MainActor [weak self] in
                do {
                    try await sleep(Self.maximumDuration)
                } catch {
                    return
                }
                self?.expire(
                    lease,
                    reason: .tenSecondWatchdog,
                    eventIdentifier: nil
                )
            }
        }
        active = current
        return lease
    }

    func cancel(_ lease: IOSForegroundFinalizationBackgroundLease) {
        expire(lease, reason: .cancelled, eventIdentifier: nil)
    }

    func finish(_ lease: IOSForegroundFinalizationBackgroundLease) {
        guard var current = active, current.lease == lease else { return }
        current.watchdog?.cancel()
        current.watchdog = nil
        endAssertionIfNeeded(&current)
        active = nil
    }

    private func expire(
        _ lease: IOSForegroundFinalizationBackgroundLease,
        reason: IOSForegroundFinalizationExpirationReason,
        eventIdentifier: IOSForegroundBackgroundTaskIdentifier?
    ) {
        guard var current = active,
              current.lease == lease,
              current.expirationReason == nil else {
            return
        }
        if let eventIdentifier {
            guard current.identifier == nil
                    || current.identifier == eventIdentifier else {
                return
            }
            current.identifier = eventIdentifier
        }

        current.expirationReason = reason
        current.watchdog?.cancel()
        current.watchdog = nil
        active = current
        current.onExpiration(reason)
        guard var latest = active, latest.lease == lease else { return }
        endAssertionIfNeeded(&latest)
    }

    private func endAssertionIfNeeded(_ current: inout Active) {
        guard !current.didEndAssertion,
              let identifier = current.identifier else {
            return
        }
        current.didEndAssertion = true
        if active?.lease == current.lease {
            active = current
        }
        client.end(identifier)
    }

    private struct Active {
        let lease: IOSForegroundFinalizationBackgroundLease
        let onExpiration: Expiration
        var identifier: IOSForegroundBackgroundTaskIdentifier?
        var expirationReason:
            IOSForegroundFinalizationExpirationReason?
        var didEndAssertion = false
        var watchdog: Task<Void, Never>?

        init(
            lease: IOSForegroundFinalizationBackgroundLease,
            onExpiration: @escaping Expiration
        ) {
            self.lease = lease
            self.onExpiration = onExpiration
        }
    }
}

extension IOSForegroundBackgroundTaskIdentifier:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundBackgroundTaskIdentifier(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundBackgroundTaskClient:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundBackgroundTaskClient(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundFinalizationBackgroundLease:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundFinalizationBackgroundLease(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundFinalizationExpirationReason:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundFinalizationExpirationReason(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundFinalizationBackgroundTask:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    nonisolated var description: String {
        "IOSForegroundFinalizationBackgroundTask(<redacted>)"
    }

    nonisolated var debugDescription: String { description }
    nonisolated var customMirror: Mirror { Mirror(self, children: [:]) }
}
