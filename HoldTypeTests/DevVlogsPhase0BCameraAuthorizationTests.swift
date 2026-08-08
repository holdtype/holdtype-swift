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
            (.unknown, .unknown),
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
            (.unknown, .cameraAuthorizationUnknown),
        ]
        for (outcome, category) in categories {
            #expect(outcome.category == category)
            #expect(DevVlogsPhase0BCameraAuthorizationOperatorSummary.line(for: outcome).contains(category.rawValue))
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
            let task = Task { await DevVlogsPhase0BCameraAuthorizationRequest(access: access).run() }
            await access.awaitRequest()
            access.complete(granted: granted, status: callbackStatus)
            access.complete(granted: !granted, status: .unknown)
            #expect(await task.value == expected)
            #expect(access.requestCount == 1)
        }
    }

    @Test func missingCallbackTimesOutAndLateCallbackIsIgnored() async {
        let access = CameraAuthorizationAccess(status: .notDetermined)
        let request = DevVlogsPhase0BCameraAuthorizationRequest(
            access: access,
            timeout: .milliseconds(1),
            sleep: { _ in }
        )
        #expect(await request.run() == .timedOut)
        #expect(access.requestCount == 1)
        access.complete(granted: true, status: .authorized)
        await Task.yield()
        #expect(access.requestCount == 1)
    }

    @Test func cancellationReturnsAndLateCallbackIsIgnored() async {
        let access = CameraAuthorizationAccess(status: .notDetermined)
        let task = Task {
            await DevVlogsPhase0BCameraAuthorizationRequest(
                access: access,
                timeout: .seconds(120)
            ).run()
        }
        await access.awaitRequest()
        task.cancel()
        #expect(await task.value == .cancelled)
        access.complete(granted: true, status: .authorized)
        await Task.yield()
        #expect(access.requestCount == 1)
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
        #expect(await harness.run() == .alreadyAuthorized)
        #expect(await harness.run() == .unknown)
        #expect(events.values.map(\.result) == [.started, .ready])
        let terminal = events.values.filter { $0.action == "camera_authorization_terminal" }
        #expect(terminal.count == 1)
        #expect(terminal.first?.category == .cameraAuthorizationAlreadyAuthorized)
        let encoded = try? JSONEncoder().encode(terminal.first)
        let text = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        #expect(!text.contains("/tmp/fake"))
        #expect(!text.contains("NSError"))
        #expect(!text.contains("userInfo"))
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

    @Test func launchRoutePrecedesCaptureConstructionAndAuthorizationOwnerIsNarrow() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let launch = try String(
            contentsOf: root.appendingPathComponent(
                "HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BLaunch.swift"
            ),
            encoding: .utf8
        )
        let branch = try #require(launch.range(of: "if DevVlogsPhase0BCameraAuthorizationConfiguration"))
        let capture = try #require(launch.range(of: "let outcome: DevVlogsPhase0BHarnessOutcome"))
        #expect(branch.lowerBound < capture.lowerBound)
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BCameraAuthorization.swift"
            ),
            encoding: .utf8
        )
        #expect(source.contains("AVCaptureDevice.requestAccess(for: .video"))
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
        #expect(source.contains("permission_timeout_seconds=$(( 120 + 300 ))"))
        #expect(source.contains("HOLDTYPE_DEV_VLOGS_PHASE_0B_REQUEST_CAMERA_PERMISSION=1"))
        #expect(source.contains("-u OPENAI_API_KEY"))
        #expect(source.contains("HOME=\"$sanitized_home\""))
        #expect(source.contains("capture_supervisor_pid=$!"))
        for forbidden in ["tccutil", "open x-apple.systempreferences", "osascript", "killall"] {
            #expect(!source.contains(forbidden))
        }
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

private final class CameraAuthorizationAccess: DevVlogsPhase0BCameraAuthorizationAccessing,
    @unchecked Sendable {
    private let lock = NSLock()
    private var status: DevVlogsPhase0BCameraAuthorizationStatus
    private var completion: (@Sendable (Bool) -> Void)?
    private(set) var requestCount = 0

    init(status: DevVlogsPhase0BCameraAuthorizationStatus) { self.status = status }

    func authorizationStatus() -> DevVlogsPhase0BCameraAuthorizationStatus {
        lock.withLock { status }
    }

    func requestAccess(completion: @escaping @Sendable (Bool) -> Void) {
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
#endif
