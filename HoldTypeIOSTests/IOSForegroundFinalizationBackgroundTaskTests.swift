import Testing
@testable import HoldTypeIOS

@MainActor
struct IOSForegroundFinalizationBackgroundTaskTests {
    @Test func finishEndsOneNamedAssertionExactlyOnce() async throws {
        let system = BackgroundTaskFake()
        let timeout = FinalizationWatchdogLatch()
        let adapter = makeAdapter(system: system, timeout: timeout)
        let expirations = FinalizationExpirationRecorder()

        let lease = try #require(adapter.begin {
            expirations.append($0)
        })
        try await finalizationEventually {
            await timeout.requestedDurations() == [.seconds(10)]
        }
        #expect(adapter.hasActiveFinalization)
        #expect(system.beginNames == [
            IOSForegroundFinalizationBackgroundTask.assertionName
        ])

        adapter.finish(lease)
        adapter.finish(lease)
        #expect(!adapter.hasActiveFinalization)
        #expect(system.ended == [.init(rawValue: 1)])
        #expect(expirations.values.isEmpty)
        await timeout.open()
    }

    @Test func unavailableAssertionStillOwnsTheTenSecondWatchdog()
        async throws {
        let system = BackgroundTaskFake(grantsAssertion: false)
        let timeout = FinalizationWatchdogLatch()
        let adapter = makeAdapter(system: system, timeout: timeout)
        let expirations = FinalizationExpirationRecorder()

        let lease = try #require(adapter.begin {
            expirations.append($0)
        })
        try await finalizationEventually {
            await timeout.requestedDurations() == [.seconds(10)]
        }
        await timeout.open()
        try await finalizationEventually {
            expirations.values == [.tenSecondWatchdog]
        }
        #expect(system.ended.isEmpty)
        #expect(adapter.hasActiveFinalization)

        adapter.finish(lease)
        #expect(!adapter.hasActiveFinalization)
    }

    @Test func systemExpirationCleansUpSynchronouslyAndStaysBusy()
        throws {
        let system = BackgroundTaskFake()
        let timeout = FinalizationWatchdogLatch()
        let adapter = makeAdapter(system: system, timeout: timeout)
        let expirations = FinalizationExpirationRecorder()
        let lease = try #require(adapter.begin {
            expirations.append($0)
        })

        system.expire()
        #expect(expirations.values == [.systemExpiration])
        #expect(system.ended == [.init(rawValue: 1)])
        #expect(adapter.hasActiveFinalization)
        #expect(adapter.begin(onExpiration: { _ in }) == nil)

        adapter.finish(lease)
        #expect(system.ended == [.init(rawValue: 1)])
        #expect(!adapter.hasActiveFinalization)
    }

    @Test func synchronousBeginExpirationStartsNoWatchdogAndEndsOnce()
        throws {
        let system = BackgroundTaskFake(expiresSynchronously: true)
        let timeout = FinalizationWatchdogLatch()
        let adapter = makeAdapter(system: system, timeout: timeout)
        let expirations = FinalizationExpirationRecorder()

        let lease = try #require(adapter.begin {
            expirations.append($0)
        })
        #expect(expirations.values == [.systemExpiration])
        #expect(system.ended == [.init(rawValue: 1)])
        #expect(adapter.hasActiveFinalization)

        adapter.finish(lease)
        #expect(system.ended == [.init(rawValue: 1)])
    }

    @Test func liveIdentityDeliversAnExpirationRequestedBeforeAssignment() {
        let identity = IOSLiveBackgroundTaskIdentity()
        let identifiers = FinalizationIdentifierRecorder()

        identity.requestExpiration { identifiers.append($0) }
        #expect(identifiers.values.isEmpty)
        identity.assign(.init(rawValue: 9)) { identifiers.append($0) }
        identity.requestExpiration { identifiers.append($0) }

        #expect(identifiers.values == [.init(rawValue: 9)])
    }

    @Test func expirationCallbackCanReenterWithoutDoubleEndOrResurrection()
        throws {
        let system = BackgroundTaskFake()
        let timeout = FinalizationWatchdogLatch()
        let adapter = makeAdapter(system: system, timeout: timeout)
        let reentrant = FinalizationReentrantFinisher(adapter: adapter)
        let lease = try #require(adapter.begin {
            reentrant.handle($0)
        })
        reentrant.lease = lease

        system.expire()

        #expect(reentrant.reasons == [.systemExpiration])
        #expect(reentrant.competingLease == nil)
        #expect(system.beginNames.count == 1)
        #expect(system.ended == [.init(rawValue: 1)])
        #expect(!adapter.hasActiveFinalization)
    }

    @Test func watchdogCancelsOnceAndWaitsForWorkflowQuiescence()
        async throws {
        let system = BackgroundTaskFake()
        let timeout = FinalizationWatchdogLatch()
        let adapter = makeAdapter(system: system, timeout: timeout)
        let expirations = FinalizationExpirationRecorder()
        let lease = try #require(adapter.begin {
            expirations.append($0)
        })

        try await finalizationEventually {
            await timeout.requestedDurations() == [.seconds(10)]
        }
        await timeout.open()
        try await finalizationEventually {
            expirations.values == [.tenSecondWatchdog]
        }
        #expect(system.ended == [.init(rawValue: 1)])
        #expect(adapter.begin(onExpiration: { _ in }) == nil)

        adapter.finish(lease)
        let nextLease = adapter.begin(onExpiration: { _ in })
        let next = try #require(nextLease)
        #expect(system.beginNames.count == 2)
        adapter.finish(next)
    }

    @Test func callerCancellationIsSynchronousAndLeaseBound() throws {
        let system = BackgroundTaskFake()
        let timeout = FinalizationWatchdogLatch()
        let adapter = makeAdapter(system: system, timeout: timeout)
        let firstExpirations = FinalizationExpirationRecorder()
        let lease = try #require(adapter.begin {
            firstExpirations.append($0)
        })

        adapter.cancel(lease)
        adapter.cancel(lease)
        #expect(firstExpirations.values == [.cancelled])
        #expect(system.ended == [.init(rawValue: 1)])
        #expect(adapter.hasActiveFinalization)

        adapter.finish(.init(token: lease.token &+ 1))
        #expect(adapter.hasActiveFinalization)
        adapter.finish(lease)
        #expect(!adapter.hasActiveFinalization)
    }

    @Test func diagnosticsAndReflectionAreRedacted() {
        let system = BackgroundTaskFake()
        let timeout = FinalizationWatchdogLatch()
        let adapter = makeAdapter(system: system, timeout: timeout)
        let identifier = IOSForegroundBackgroundTaskIdentifier(rawValue: 42)
        let lease = IOSForegroundFinalizationBackgroundLease(token: 43)

        for value in [
            String(describing: identifier),
            String(reflecting: identifier),
            String(describing: system.client),
            String(reflecting: system.client),
            String(describing: lease),
            String(reflecting: lease),
            String(describing:
                IOSForegroundFinalizationExpirationReason.systemExpiration),
            String(reflecting:
                IOSForegroundFinalizationExpirationReason.systemExpiration),
            String(describing: adapter),
            String(reflecting: adapter),
        ] {
            #expect(value.contains("<redacted>"))
            #expect(!value.contains("42"))
            #expect(!value.contains("43"))
        }
        #expect(Mirror(reflecting: identifier).children.isEmpty)
        #expect(Mirror(reflecting: lease).children.isEmpty)
        #expect(Mirror(reflecting: system.client).children.isEmpty)
        #expect(Mirror(reflecting: adapter).children.isEmpty)
    }

    private func makeAdapter(
        system: BackgroundTaskFake,
        timeout: FinalizationWatchdogLatch
    ) -> IOSForegroundFinalizationBackgroundTask {
        IOSForegroundFinalizationBackgroundTask(
            client: system.client,
            sleep: { duration in
                try await timeout.sleep(for: duration)
            }
        )
    }
}

@MainActor
private final class BackgroundTaskFake {
    let grantsAssertion: Bool
    let expiresSynchronously: Bool
    private(set) var beginNames: [String] = []
    private(set) var ended: [IOSForegroundBackgroundTaskIdentifier] = []
    private(set) var expiration: (@MainActor @Sendable () -> Void)?
    private var nextRawValue = 0

    init(
        grantsAssertion: Bool = true,
        expiresSynchronously: Bool = false
    ) {
        self.grantsAssertion = grantsAssertion
        self.expiresSynchronously = expiresSynchronously
    }

    var client: IOSForegroundBackgroundTaskClient {
        IOSForegroundBackgroundTaskClient(
            begin: { [weak self] name, expiration in
                guard let self else { return nil }
                beginNames.append(name)
                guard grantsAssertion else { return nil }
                nextRawValue += 1
                let identifier = IOSForegroundBackgroundTaskIdentifier(
                    rawValue: nextRawValue
                )
                self.expiration = { expiration(identifier) }
                if expiresSynchronously {
                    expiration(identifier)
                }
                return identifier
            },
            end: { [weak self] identifier in
                self?.ended.append(identifier)
            }
        )
    }

    func expire() {
        expiration?()
    }
}

@MainActor
private final class FinalizationExpirationRecorder {
    private(set) var values: [
        IOSForegroundFinalizationExpirationReason
    ] = []

    func append(_ value: IOSForegroundFinalizationExpirationReason) {
        values.append(value)
    }
}

@MainActor
private final class FinalizationIdentifierRecorder {
    private(set) var values: [IOSForegroundBackgroundTaskIdentifier] = []

    func append(_ value: IOSForegroundBackgroundTaskIdentifier) {
        values.append(value)
    }
}

@MainActor
private final class FinalizationReentrantFinisher {
    let adapter: IOSForegroundFinalizationBackgroundTask
    var lease: IOSForegroundFinalizationBackgroundLease?
    private(set) var reasons: [
        IOSForegroundFinalizationExpirationReason
    ] = []
    private(set) var competingLease:
        IOSForegroundFinalizationBackgroundLease?

    init(adapter: IOSForegroundFinalizationBackgroundTask) {
        self.adapter = adapter
    }

    func handle(_ reason: IOSForegroundFinalizationExpirationReason) {
        reasons.append(reason)
        guard let lease else { return }
        adapter.cancel(lease)
        competingLease = adapter.begin(onExpiration: { _ in })
        adapter.finish(lease)
    }
}

private actor FinalizationWatchdogLatch {
    private var durations: [Duration] = []
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func sleep(for duration: Duration) async throws {
        durations.append(duration)
        if isOpen { return }
        try Task.checkCancellation()
        await withCheckedContinuation { continuation in
            if isOpen {
                continuation.resume()
            } else {
                waiters.append(continuation)
            }
        }
        try Task.checkCancellation()
    }

    func requestedDurations() -> [Duration] { durations }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let waiters = waiters
        self.waiters.removeAll()
        for waiter in waiters {
            waiter.resume()
        }
    }
}

@MainActor
private func finalizationEventually(
    _ predicate: @escaping @MainActor @Sendable () async -> Bool
) async throws {
    for _ in 0..<100 {
        if await predicate() { return }
        try await Task.sleep(for: .milliseconds(10))
    }
    Issue.record("Timed out waiting for finalization background state.")
}
