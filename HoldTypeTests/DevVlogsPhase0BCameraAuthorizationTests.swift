#if DEBUG
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BCameraAuthorizationTests {
    @Test func settledStatusesNeverRequestAccess() async {
        let cases: [(DevVlogsPhase0BCameraAuthorizationStatus, DevVlogsPhase0BCameraAuthorizationOutcome)] = [
            (.authorized, .alreadyAuthorized),
            (.denied, .denied),
            (.restricted, .restricted),
            (.unknown, .statusUnknown),
        ]
        for (status, expected) in cases {
            let access = CameraAuthorizationAccess(status: status)
            let outcome = await DevVlogsPhase0BCameraAuthorizationRequest(access: access).run()
            #expect(outcome == expected)
            #expect(access.requestCount == 0)
        }
        let categories: [(DevVlogsPhase0BCameraAuthorizationOutcome, DevVlogsPhase0BFailureCategory)] = [
            (.granted, .cameraAuthorizationGranted),
            (.alreadyAuthorized, .cameraAuthorizationAlreadyAuthorized),
            (.denied, .cameraAuthorizationDenied),
            (.restricted, .cameraAuthorizationRestricted),
            (.timedOut, .cameraAuthorizationTimedOut),
            (.cancelled, .cameraAuthorizationCancelled),
            (.statusUnknown, .cameraAuthorizationStatusUnknown),
            (.activationPolicyFailed, .cameraAuthorizationActivationPolicyFailed),
            (.activationRejected, .cameraAuthorizationActivationRejected),
            (.activationTimedOut, .cameraAuthorizationActivationTimedOut),
            (.activationCancelled, .cameraAuthorizationActivationCancelled),
            (.harnessUnavailable, .cameraAuthorizationHarnessUnavailable),
            (.alreadyCompleted, .alreadyRun),
        ]
        for (outcome, category) in categories {
            #expect(outcome.category == category)
            let terminal = DevVlogsPhase0BCameraAuthorizationTerminal(
                outcome: outcome,
                furthestStage: .routeStarted
            )
            #expect(DevVlogsPhase0BCameraAuthorizationOperatorSummary.line(for: terminal)
                .contains(category.rawValue))
        }
    }

    @Test func undeterminedStatusRequestsExactlyOnceAndMapsCallback() async {
        for (granted, callbackStatus, expected) in [
            (true, DevVlogsPhase0BCameraAuthorizationStatus.authorized, .granted),
            (false, .denied, .denied),
            (false, .restricted, .restricted),
            (false, .unknown, .denied),
        ] as [(Bool, DevVlogsPhase0BCameraAuthorizationStatus, DevVlogsPhase0BCameraAuthorizationOutcome)] {
            let access = CameraAuthorizationAccess(status: .notDetermined)
            let trace = CameraAuthorizationRouteTrace()
            let task = Task {
                await DevVlogsPhase0BCameraAuthorizationRequest(access: access).run {
                    trace.append($0.rawValue)
                }
            }
            await access.awaitRequest()
            #expect(trace.snapshot == ["authorization_status_inspected", "request_access_started"])
            access.complete(granted: granted, status: callbackStatus)
            access.complete(granted: !granted, status: .unknown)
            #expect(await task.value == expected)
            #expect(access.requestCount == 1)
            #expect(trace.snapshot == ["authorization_status_inspected", "request_access_started"])
        }
    }

    @Test func missingCallbackTimesOutAndLateCallbackIsIgnored() async {
        let access = CameraAuthorizationAccess(status: .notDetermined)
        let request = DevVlogsPhase0BCameraAuthorizationRequest(
            access: access,
            timeout: .milliseconds(1),
            sleep: { _ in }
        )
        let trace = CameraAuthorizationRouteTrace()
        #expect(await request.run { trace.append($0.rawValue) } == .timedOut)
        #expect(access.requestCount == 1)
        access.complete(granted: true, status: .authorized)
        await Task.yield()
        #expect(access.requestCount == 1)
        #expect(trace.snapshot == ["authorization_status_inspected", "request_access_started"])
    }

    @Test func cancellationReturnsAndLateCallbackIsIgnored() async {
        let access = CameraAuthorizationAccess(status: .notDetermined)
        let trace = CameraAuthorizationRouteTrace()
        let task = Task {
            await DevVlogsPhase0BCameraAuthorizationRequest(
                access: access,
                timeout: .seconds(120)
            ).run { trace.append($0.rawValue) }
        }
        await access.awaitRequest()
        task.cancel()
        #expect(await task.value == .cancelled)
        access.complete(granted: true, status: .authorized)
        await Task.yield()
        #expect(access.requestCount == 1)
        #expect(trace.snapshot == ["authorization_status_inspected", "request_access_started"])
    }

    @Test func harnessEmitsOneRedactedTerminalAndCannotRunTwice() async {
        let access = CameraAuthorizationAccess(status: .authorized)
        let events = CameraAuthorizationEvents()
        let configuration = DevVlogsPhase0BCameraAuthorizationConfiguration(
            runRoot: URL(fileURLWithPath: "/tmp/fake", isDirectory: true),
            caseID: "camera-authorization"
        )
        let harness = DevVlogsPhase0BCameraAuthorizationHarness(
            configuration: configuration,
            runID: "run-1",
            request: DevVlogsPhase0BCameraAuthorizationRequest(access: access),
            eventLog: DevVlogsPhase0BInMemoryEventLog { events.values.append($0) },
            monotonicClock: { 12 }
        )
        let terminalResult = await harness.run(activation: successfulActivation())
        #expect(terminalResult == .init(
            outcome: .alreadyAuthorized,
            furthestStage: .authorizationStatusInspected
        ))
        #expect(await harness.run(activation: successfulActivation()).outcome == .alreadyCompleted)
        #expect(events.values.map(\.result) == [.started, .ready])
        let terminal = events.values.filter { $0.action == "camera_authorization_terminal" }
        #expect(terminal.count == 1)
        #expect(terminal.first?.category == .cameraAuthorizationAlreadyAuthorized)
        #expect(terminal.first?.furthestStage == .authorizationStatusInspected)
        let encoded = try? JSONEncoder().encode(terminal.first)
        let text = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(text.contains("furthest_stage"))
        #expect(text.contains("authorization_status_inspected"))
        #expect(!text.contains("/tmp/fake"))
        #expect(!text.contains("NSError"))
        #expect(!text.contains("userInfo"))
    }

    @Test func unknownStatusIsPostActivationAndNeverRequestsAccess() async {
        let access = CameraAuthorizationAccess(status: .unknown)
        let events = CameraAuthorizationEvents()
        let terminal = await makeHarness(access: access, events: events).run(
            activation: successfulActivation()
        )
        #expect(terminal == .init(
            outcome: .statusUnknown,
            furthestStage: .authorizationStatusInspected
        ))
        #expect(access.requestCount == 0)
        #expect(events.values.map(\.furthestStage) == [.routeStarted, .authorizationStatusInspected])
        #expect(events.values.last?.category == .cameraAuthorizationStatusUnknown)
    }

    @Test func cancelledHarnessTerminalKeepsRequestStageAndIgnoresLateCallback() async {
        let access = CameraAuthorizationAccess(status: .notDetermined)
        let events = CameraAuthorizationEvents()
        let harness = makeHarness(access: access, events: events)
        let task = Task { await harness.run(activation: successfulActivation()) }
        await access.awaitRequest()
        task.cancel()
        #expect(await task.value == .init(
            outcome: .cancelled,
            furthestStage: .requestAccessStarted
        ))
        access.complete(granted: true, status: .authorized)
        await Task.yield()
        #expect(events.values.filter { $0.action == "camera_authorization_terminal" }.count == 1)
        #expect(events.values.last?.furthestStage == .requestAccessStarted)
        #expect(events.values.last?.category == .cameraAuthorizationCancelled)
    }

    @Test func configurationRequiresExplicitSanitizedTemporaryMode() {
        let temporaryRoot = URL(fileURLWithPath: "/tmp/phase0b-auth", isDirectory: true)
        let valid = authorizationEnvironment(runRoot: "/tmp/phase0b-auth/run")
        #expect(!DevVlogsPhase0BCameraAuthorizationConfiguration.shouldRequest(environment: [:]))
        #expect(DevVlogsPhase0BLaunch.shouldIsolate(environment: valid))
        #expect(
            DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(
                environment: valid,
                temporaryRoot: temporaryRoot
            ) != nil
        )
        var missingAutomation = valid
        missingAutomation.removeValue(forKey: KeychainInteractionPolicy.automationEnvironmentKey)
        #expect(
            DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(
                environment: missingAutomation,
                temporaryRoot: temporaryRoot
            ) == nil
        )
        var outsideTemporary = valid
        outsideTemporary[DevVlogsPhase0BConfiguration.runRootEnvironmentKey] = "/Users/example/archive"
        #expect(
            DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(
                environment: outsideTemporary,
                temporaryRoot: temporaryRoot
            ) == nil
        )
    }

    @Test func explicitRouteActivatesBeforeAuthorizationStatusAndRequest() async {
        let trace = CameraAuthorizationRouteTrace()
        var activeObservations = [false, false, true]
        let access = CameraAuthorizationAccess(
            status: .notDetermined,
            onStatus: { trace.append("status") },
            onRequest: { trace.append("request") }
        )
        let task = Task { @MainActor in
            await DevVlogsPhase0BLaunch.cameraAuthorizationTerminal(
                environment: authorizationEnvironment(runRoot: "/tmp/phase0b-auth/run"),
                activation: DevVlogsPhase0BApplicationActivation(
                    setRegularPolicy: { trace.append("policy"); return true },
                    activateApplication: { trace.append("activate") },
                    isActive: { trace.append("active"); return activeObservations.removeFirst() },
                    sleep: { _ in trace.append("sleep") },
                    confirmationAttempts: 2
                ),
                routeStarted: { trace.append("route") },
                makeHarness: {
                    trace.append("make")
                    return makeHarness(access: access)
                }
            )
        }
        await access.awaitRequest()
        #expect(trace.snapshot == [
            "route", "make", "policy", "activate", "active", "sleep", "active", "sleep", "active",
            "status", "request",
        ])
        access.complete(granted: true, status: .authorized)
        #expect(await task.value == .init(outcome: .granted, furthestStage: .requestAccessStarted))
        #expect(access.requestCount == 1)
    }

    @Test func activationFailuresHaveClosedCategoriesAndExactStages() async {
        let cases: [(DevVlogsPhase0BApplicationActivation, DevVlogsPhase0BCameraAuthorizationOutcome,
                     DevVlogsPhase0BCameraAuthorizationStage)] = [
            (activation(policy: false), .activationPolicyFailed, .routeStarted),
            (activation(active: false), .activationTimedOut, .activationRequested),
            (activation(active: false, cancellation: true), .activationCancelled, .activationRequested),
        ]
        for (activation, expectedOutcome, expectedStage) in cases {
            let access = CameraAuthorizationAccess(status: .notDetermined)
            let events = CameraAuthorizationEvents()
            let terminal = await makeHarness(access: access, events: events).run(activation: activation)
            #expect(terminal == .init(outcome: expectedOutcome, furthestStage: expectedStage))
            #expect(access.requestCount == 0)
            #expect(events.values.map(\.action) == ["camera_authorization", "camera_authorization_terminal"])
            #expect(events.values.last?.category == expectedOutcome.category)
            #expect(events.values.last?.furthestStage == expectedStage)
        }
    }

    @Test func harnessUnavailableFailsBeforeActivationOrAuthorization() async {
        let trace = CameraAuthorizationRouteTrace()
        let terminal = await DevVlogsPhase0BLaunch.cameraAuthorizationTerminal(
            environment: authorizationEnvironment(runRoot: "/tmp/phase0b-auth/run"),
            activation: tracedActivation(trace),
            routeStarted: { trace.append("route") },
            makeHarness: { trace.append("make"); throw CameraAuthorizationHarnessError.unavailable }
        )
        #expect(terminal == .init(outcome: .harnessUnavailable, furthestStage: .routeStarted))
        #expect(trace.snapshot == ["route", "make"])
    }

    @Test func normalAndHardwareRoutesNeverStartAuthorization() async {
        for environment in [[:], [DevVlogsPhase0BConfiguration.enabledEnvironmentKey: "1"]] {
            let trace = CameraAuthorizationRouteTrace()
            let terminal = await DevVlogsPhase0BLaunch.cameraAuthorizationTerminal(
                environment: environment,
                activation: tracedActivation(trace),
                routeStarted: { trace.append("route") },
                makeHarness: { trace.append("make"); throw CameraAuthorizationHarnessError.unavailable }
            )
            #expect(terminal == nil)
            #expect(trace.snapshot.isEmpty)
        }
    }

    @Test func launchRoutePrecedesCaptureConstructionAndAuthorizationOwnerIsNarrow() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let launch = try String(
            contentsOf: root.appendingPathComponent(
                "HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BLaunch.swift"
            ),
            encoding: .utf8
        )
        let branch = try #require(launch.range(
            of: "if let terminal = await DevVlogsPhase0BLaunch.cameraAuthorizationTerminal"
        ))
        let capture = try #require(launch.range(of: "let outcome: DevVlogsPhase0BHarnessOutcome"))
        #expect(branch.lowerBound < capture.lowerBound)
        for forbidden in ["NSWindow(", "SettingsScene(", "FixesEditorScene(", "TranscriptHistoryScene("] {
            #expect(!launch.contains(forbidden))
        }
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BCameraAuthorization.swift"
            ),
            encoding: .utf8
        )
        #expect(source.contains("AVCaptureDevice.requestAccess(for: .video"))
        #expect(source.contains("setActivationPolicy(.regular)"))
        #expect(!source.contains("NSRunningApplication.current.activate"))
        #expect(source.contains("NSApplication.shared.activate()"))
        #expect(source.contains("NSApplication.shared.isActive"))
        #expect(!source.contains("camera_authorization_unknown"))
        for forbidden in ["AVCaptureSession", "AVCaptureDeviceInput", "startCapture(",
                          "AudioRecorder", "MediaFinalizer", "MediaProbe", "VideoPreservation",
                          "DictationRuntime", "KeychainService", "SettingsScene"] {
            #expect(!source.contains(forbidden))
        }
    }

    @Test func scriptModeIsExplicitBoundedSanitizedAndMutuallyExclusive() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent("script/dev_vlogs_phase_0b_spike.sh"),
            encoding: .utf8
        )
        #expect(source.contains("--request-camera-permission"))
        #expect(source.contains("permission_timeout_seconds=420"))
        #expect(source.contains("permission_deadline=$(( SECONDS + permission_timeout_seconds ))"))
        #expect(source.contains("capture_permission_baseline"))
        #expect(source.contains("discover_permission_candidate_pids"))
        #expect(source.contains("lsof -t -- \"$app_binary\""))
        #expect(source.contains("permission_marker_matches"))
        #expect(source.contains("ps -E -ww"))
        #expect(source.contains("HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT=$resolved_run_root"))
        #expect(source.contains("permission_registry_pids"))
        #expect(source.contains("permission_quiet_rescan"))
        #expect(source.contains("permission_identity_matches_index"))
        #expect(source.contains("signal_permission_processes TERM"))
        for topology in ["descendant", "script-sibling", "external-parent", "reparented-unknown"] {
            #expect(source.contains(topology))
        }
        #expect(source.contains("HOLDTYPE_DEV_VLOGS_PHASE_0B_REQUEST_CAMERA_PERMISSION=1"))
        #expect(source.contains("-u OPENAI_API_KEY"))
        #expect(source.contains("HOME=\"$sanitized_home\""))
        #expect(source.contains("permission_app_pid=$!"))
        #expect(source.contains("permission_terminal_observed"))
        for forbidden in ["permission_cleanup_reserve_seconds", "permission_terminal_deadline", "tccutil",
                          "open x-apple.systempreferences", "osascript", "killall", "pkill", "pgrep"] {
            #expect(!source.contains(forbidden))
        }
    }

    private func successfulActivation() -> DevVlogsPhase0BApplicationActivation {
        activation()
    }

    private func activation(
        policy: Bool = true,
        active: Bool = true,
        cancellation: Bool = false
    ) -> DevVlogsPhase0BApplicationActivation {
        DevVlogsPhase0BApplicationActivation(
            setRegularPolicy: { policy },
            activateApplication: {},
            isActive: { active },
            sleep: { _ in if cancellation { throw CancellationError() } },
            confirmationAttempts: 1
        )
    }

    private func tracedActivation(
        _ trace: CameraAuthorizationRouteTrace
    ) -> DevVlogsPhase0BApplicationActivation {
        DevVlogsPhase0BApplicationActivation(
            setRegularPolicy: { trace.append("policy"); return true },
            activateApplication: { trace.append("activate") },
            isActive: { trace.append("active"); return true },
            sleep: { _ in },
            confirmationAttempts: 1
        )
    }

    private func makeHarness(
        access: CameraAuthorizationAccess,
        events: CameraAuthorizationEvents? = nil
    ) -> DevVlogsPhase0BCameraAuthorizationHarness {
        let events = events ?? CameraAuthorizationEvents()
        return DevVlogsPhase0BCameraAuthorizationHarness(
            configuration: .init(
                runRoot: URL(fileURLWithPath: "/tmp/fake", isDirectory: true),
                caseID: "camera-authorization"
            ),
            runID: "run-1",
            request: DevVlogsPhase0BCameraAuthorizationRequest(access: access),
            eventLog: DevVlogsPhase0BInMemoryEventLog { events.values.append($0) },
            monotonicClock: { 12 }
        )
    }

    private func authorizationEnvironment(runRoot: String) -> [String: String] {
        [
            DevVlogsPhase0BCameraAuthorizationConfiguration.enabledEnvironmentKey: "1",
            DevVlogsPhase0BConfiguration.runRootEnvironmentKey: runRoot,
            DevVlogsPhase0BConfiguration.caseIDEnvironmentKey: "camera-authorization",
            KeychainInteractionPolicy.automationEnvironmentKey: "1",
            KeychainInteractionPolicy.authenticationUIEnvironmentKey:
                KeychainInteractionPolicy.skipAuthenticationUIValue,
        ]
    }
}

private enum CameraAuthorizationHarnessError: Error { case unavailable }

private final class CameraAuthorizationAccess: DevVlogsPhase0BCameraAuthorizationAccessing,
    @unchecked Sendable {
    private let lock = NSLock()
    private var status: DevVlogsPhase0BCameraAuthorizationStatus
    private var completion: (@Sendable (Bool) -> Void)?
    private let onStatus: @Sendable () -> Void
    private let onRequest: @Sendable () -> Void
    private(set) var requestCount = 0

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
        return lock.withLock { status }
    }

    func requestAccess(completion: @escaping @Sendable (Bool) -> Void) {
        onRequest()
        lock.withLock {
            requestCount += 1
            self.completion = completion
        }
    }

    func complete(granted: Bool, status: DevVlogsPhase0BCameraAuthorizationStatus) {
        let callback = lock.withLock { () -> (@Sendable (Bool) -> Void)? in
            self.status = status
            let callback = completion
            completion = nil
            return callback
        }
        callback?(granted)
    }

    func awaitRequest() async {
        for _ in 0 ..< 100 where lock.withLock({ requestCount == 0 }) {
            await Task.yield()
        }
        #expect(lock.withLock { requestCount == 1 })
    }
}

@MainActor private final class CameraAuthorizationEvents {
    var values: [DevVlogsPhase0BEvent] = []
}

private final class CameraAuthorizationRouteTrace: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String] = []

    var snapshot: [String] { lock.withLock { values } }
    func append(_ value: String) { lock.withLock { values.append(value) } }
}
#endif
