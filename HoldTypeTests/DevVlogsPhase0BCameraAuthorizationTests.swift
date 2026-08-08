#if DEBUG
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BCameraAuthorizationTests {
    @Test func settledStatusesNeverRequestAccess() async {
        let cases: [(DevVlogsPhase0BCameraAuthorizationStatus, DevVlogsPhase0BCameraAuthorizationOutcome)] = [
            (.authorized, .alreadyAuthorized), (.denied, .denied),
            (.restricted, .restricted), (.unknown, .statusUnknown),
        ]
        for (status, expected) in cases {
            let access = AuthorizationAccess(status: status)
            #expect(await DevVlogsPhase0BCameraAuthorizationRequest(access: access).run() == expected)
            #expect(access.requestCount == 0)
        }
    }

    @Test func requestAccessIsExactOnceAcrossCallbackTimeoutAndCancellation() async {
        let granted = AuthorizationAccess(status: .notDetermined)
        let grantedTask = Task { await DevVlogsPhase0BCameraAuthorizationRequest(access: granted).run() }
        await granted.awaitRequest()
        granted.complete(granted: true, status: .authorized)
        granted.complete(granted: false, status: .denied)
        #expect(await grantedTask.value == .granted)
        #expect(granted.requestCount == 1)

        let timedOut = AuthorizationAccess(status: .notDetermined)
        let timeoutRequest = DevVlogsPhase0BCameraAuthorizationRequest(
            access: timedOut, timeout: .milliseconds(1), sleep: { _ in }
        )
        #expect(await timeoutRequest.run() == .timedOut)
        timedOut.complete(granted: true, status: .authorized)
        #expect(timedOut.requestCount == 1)

        let cancelled = AuthorizationAccess(status: .notDetermined)
        let cancelledTask = Task {
            await DevVlogsPhase0BCameraAuthorizationRequest(access: cancelled).run()
        }
        await cancelled.awaitRequest()
        cancelledTask.cancel()
        #expect(await cancelledTask.value == .cancelled)
        cancelled.complete(granted: true, status: .authorized)
        #expect(cancelled.requestCount == 1)
    }

    @Test func configurationRequiresTokenSanitizationAndTemporaryRoot() {
        let temporaryRoot = URL(fileURLWithPath: "/tmp/phase0b-auth", isDirectory: true)
        let valid = authorizationEnvironment(runRoot: "/tmp/phase0b-auth/run")
        let configuration = DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(
            environment: valid, temporaryRoot: temporaryRoot
        )
        #expect(configuration?.launchToken == String(repeating: "a", count: 64))
        var missingToken = valid
        missingToken.removeValue(forKey:
            DevVlogsPhase0BCameraAuthorizationConfiguration.launchTokenEnvironmentKey)
        #expect(DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(
            environment: missingToken, temporaryRoot: temporaryRoot
        ) == nil)
        var unsafe = valid
        unsafe[DevVlogsPhase0BConfiguration.runRootEnvironmentKey] = "/Users/example/archive"
        #expect(DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(
            environment: unsafe, temporaryRoot: temporaryRoot
        ) == nil)
    }

    @Test func acknowledgedActiveRouteEntersStatusThenRequest() async {
        let trace = Trace()
        let access = AuthorizationAccess(
            status: .notDetermined,
            onStatus: { trace.append("status") },
            onRequest: { trace.append("request") }
        )
        var active = [false, true]
        let task = Task { @MainActor in
            await makeHarness(access: access).run(
                handshake: FakeHandshake { trace.append("ack"); return .acknowledged },
                activeConfirmation: .init(
                    isActive: { trace.append("active"); return active.removeFirst() },
                    sleep: { _ in trace.append("sleep") },
                    confirmationAttempts: 1
                )
            )
        }
        await access.awaitRequest()
        #expect(trace.values == ["ack", "active", "sleep", "active", "status", "request"])
        access.complete(granted: true, status: .authorized)
        #expect(await task.value == .init(outcome: .granted, furthestStage: .requestAccessStarted))
    }

    @Test func acknowledgmentFailuresNeverInspectStatusOrRequest() async {
        let cases: [(DevVlogsPhase0BCameraAuthorizationAcknowledgmentOutcome,
                     DevVlogsPhase0BCameraAuthorizationOutcome,
                     DevVlogsPhase0BFailureCategory)] = [
            (.invalid, .acknowledgmentInvalid, .cameraAuthorizationAcknowledgmentInvalid),
            (.timedOut, .acknowledgmentTimedOut, .cameraAuthorizationAcknowledgmentTimedOut),
            (.cancelled, .acknowledgmentCancelled, .cameraAuthorizationAcknowledgmentCancelled),
        ]
        for (acknowledgment, expected, category) in cases {
            let access = AuthorizationAccess(status: .notDetermined)
            let events = Events()
            let terminal = await makeHarness(access: access, events: events).run(
                handshake: FakeHandshake { acknowledgment },
                activeConfirmation: activeConfirmation(true)
            )
            #expect(terminal == .init(outcome: expected, furthestStage: .regularPolicySet))
            #expect(access.statusCount == 0)
            #expect(access.requestCount == 0)
            #expect(events.values.last?.category == category)
            #expect(events.values.filter { $0.action == "camera_authorization_terminal" }.count == 1)
        }
    }

    @Test func inactiveTimeoutAfterAcknowledgmentPreservesStage() async {
        let access = AuthorizationAccess(status: .notDetermined)
        let terminal = await makeHarness(access: access).run(
            handshake: FakeHandshake { .acknowledged },
            activeConfirmation: .init(isActive: { false }, sleep: { _ in }, confirmationAttempts: 1)
        )
        #expect(terminal == .init(
            outcome: .activationTimedOut, furthestStage: .launchIdentityAcknowledged
        ))
        #expect(access.statusCount == 0)
        #expect(access.requestCount == 0)
    }

    @Test func exactOneTerminalAndLateCallbackCannotAdvanceStage() async {
        let access = AuthorizationAccess(status: .notDetermined)
        let events = Events()
        let harness = makeHarness(access: access, events: events)
        let task = Task {
            await harness.run(
                handshake: FakeHandshake { .acknowledged },
                activeConfirmation: activeConfirmation(true)
            )
        }
        await access.awaitRequest()
        task.cancel()
        #expect(await task.value.outcome == .cancelled)
        access.complete(granted: true, status: .authorized)
        #expect(await harness.run(
            handshake: FakeHandshake { .acknowledged },
            activeConfirmation: activeConfirmation(true)
        ).outcome == .alreadyCompleted)
        #expect(events.values.filter { $0.action == "camera_authorization_terminal" }.count == 1)
    }

    @Test func launchRouteRejectsInvalidPolicyBeforeHarness() async {
        var made = false
        let terminal = await DevVlogsPhase0BLaunch.cameraAuthorizationTerminal(
            environment: authorizationEnvironment(runRoot: "/tmp/phase0b-auth/run"),
            policyReady: false,
            activeConfirmation: activeConfirmation(true),
            routeStarted: {},
            makeHarness: { made = true; return makeHarness(access: .init(status: .authorized)) },
            makeHandshake: { _ in FakeHandshake { .acknowledged } }
        )
        #expect(terminal == .init(outcome: .activationPolicyFailed, furthestStage: .routeStarted))
        #expect(!made)
    }

    private func makeHarness(
        access: AuthorizationAccess,
        events: Events? = nil
    ) -> DevVlogsPhase0BCameraAuthorizationHarness {
        let events = events ?? Events()
        return DevVlogsPhase0BCameraAuthorizationHarness(
            configuration: .init(
                runRoot: URL(fileURLWithPath: "/tmp/fake", isDirectory: true),
                caseID: "camera-authorization",
                launchToken: String(repeating: "a", count: 64)
            ),
            runID: "run-1",
            request: .init(access: access),
            eventLog: DevVlogsPhase0BInMemoryEventLog { events.values.append($0) },
            monotonicClock: { 12 }
        )
    }

    private func activeConfirmation(_ active: Bool) -> DevVlogsPhase0BActiveStateConfirmation {
        .init(isActive: { active }, sleep: { _ in }, confirmationAttempts: 1)
    }
}

private struct FakeHandshake: DevVlogsPhase0BCameraAuthorizationAcknowledging {
    let result: @Sendable () -> DevVlogsPhase0BCameraAuthorizationAcknowledgmentOutcome
    func waitForAcknowledgment() async -> DevVlogsPhase0BCameraAuthorizationAcknowledgmentOutcome {
        result()
    }
}

private final class AuthorizationAccess: DevVlogsPhase0BCameraAuthorizationAccessing,
    @unchecked Sendable {
    private let lock = NSLock()
    private var status: DevVlogsPhase0BCameraAuthorizationStatus
    private var completion: (@Sendable (Bool) -> Void)?
    private let onStatus: @Sendable () -> Void
    private let onRequest: @Sendable () -> Void
    private(set) var requestCount = 0
    private(set) var statusCount = 0

    init(
        status: DevVlogsPhase0BCameraAuthorizationStatus,
        onStatus: @escaping @Sendable () -> Void = {},
        onRequest: @escaping @Sendable () -> Void = {}
    ) {
        self.status = status
        self.onStatus = onStatus
        self.onRequest = onRequest
    }

    func authorizationStatus() -> DevVlogsPhase0BCameraAuthorizationStatus {
        onStatus()
        return lock.withLock { statusCount += 1; return status }
    }

    func requestAccess(completion: @escaping @Sendable (Bool) -> Void) {
        onRequest()
        lock.withLock { requestCount += 1; self.completion = completion }
    }

    func complete(granted: Bool, status: DevVlogsPhase0BCameraAuthorizationStatus) {
        let callback = lock.withLock { () -> (@Sendable (Bool) -> Void)? in
            self.status = status
            let value = completion
            completion = nil
            return value
        }
        callback?(granted)
    }

    func awaitRequest() async {
        for _ in 0 ..< 100 where lock.withLock({ requestCount == 0 }) { await Task.yield() }
        #expect(lock.withLock { requestCount == 1 })
    }
}

@MainActor private final class Events { var values: [DevVlogsPhase0BEvent] = [] }
private final class Trace: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var values: [String] { lock.withLock { storage } }
    func append(_ value: String) { lock.withLock { storage.append(value) } }
}

private func authorizationEnvironment(runRoot: String) -> [String: String] {
    [
        DevVlogsPhase0BCameraAuthorizationConfiguration.enabledEnvironmentKey: "1",
        DevVlogsPhase0BCameraAuthorizationConfiguration.launchTokenEnvironmentKey:
            String(repeating: "a", count: 64),
        DevVlogsPhase0BConfiguration.runRootEnvironmentKey: runRoot,
        DevVlogsPhase0BConfiguration.caseIDEnvironmentKey: "camera-authorization",
        KeychainInteractionPolicy.automationEnvironmentKey: "1",
        KeychainInteractionPolicy.authenticationUIEnvironmentKey:
            KeychainInteractionPolicy.skipAuthenticationUIValue,
    ]
}
#endif
