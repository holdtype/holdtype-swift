#if DEBUG
import AVFoundation
import Foundation

enum DevVlogsPhase0BCameraAuthorizationStatus: Equatable {
    case notDetermined, authorized, denied, restricted, unknown
}

enum DevVlogsPhase0BCameraAuthorizationOutcome: Equatable {
    case granted, alreadyAuthorized, denied, restricted, timedOut, cancelled, unknown

    var category: DevVlogsPhase0BFailureCategory {
        switch self {
        case .granted: .cameraAuthorizationGranted
        case .alreadyAuthorized: .cameraAuthorizationAlreadyAuthorized
        case .denied: .cameraAuthorizationDenied
        case .restricted: .cameraAuthorizationRestricted
        case .timedOut: .cameraAuthorizationTimedOut
        case .cancelled: .cameraAuthorizationCancelled
        case .unknown: .cameraAuthorizationUnknown
        }
    }

    var eventResult: DevVlogsPhase0BResult {
        switch self {
        case .granted, .alreadyAuthorized: .ready
        case .timedOut: .timedOut
        case .cancelled: .cancelled
        case .denied, .restricted, .unknown: .failed
        }
    }
}

protocol DevVlogsPhase0BCameraAuthorizationAccessing: Sendable {
    func authorizationStatus() -> DevVlogsPhase0BCameraAuthorizationStatus
    func requestAccess(completion: @escaping @Sendable (Bool) -> Void)
}

struct DevVlogsPhase0BAppleCameraAuthorizationAccess: DevVlogsPhase0BCameraAuthorizationAccessing {
    func authorizationStatus() -> DevVlogsPhase0BCameraAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined: .notDetermined
        case .authorized: .authorized
        case .denied: .denied
        case .restricted: .restricted
        @unknown default: .unknown
        }
    }

    func requestAccess(completion: @escaping @Sendable (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video, completionHandler: completion)
    }
}

final class DevVlogsPhase0BCameraAuthorizationRequest: @unchecked Sendable {
    typealias Sleep = @Sendable (Duration) async throws -> Void
    static let operationalTimeout = Duration.seconds(120)

    private let access: any DevVlogsPhase0BCameraAuthorizationAccessing
    private let timeout: Duration
    private let sleep: Sleep

    init(
        access: any DevVlogsPhase0BCameraAuthorizationAccessing,
        timeout: Duration = operationalTimeout,
        sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
    ) {
        self.access = access
        self.timeout = timeout
        self.sleep = sleep
    }

    func run() async -> DevVlogsPhase0BCameraAuthorizationOutcome {
        switch access.authorizationStatus() {
        case .authorized: return .alreadyAuthorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .unknown: return .unknown
        case .notDetermined: break
        }
        guard !Task.isCancelled else { return .cancelled }

        let gate = DevVlogsPhase0BAuthorizationContinuationGate()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard gate.install(continuation) else { return }
                let timeoutTask = Task { [sleep, timeout] in
                    do {
                        try await sleep(timeout)
                    } catch {
                        return
                    }
                    gate.finish(.timedOut)
                }
                gate.installTimeoutTask(timeoutTask)
                access.requestAccess { [access] granted in
                    gate.finish(Self.callbackOutcome(granted: granted, status: access.authorizationStatus()))
                }
            }
        } onCancel: {
            gate.finish(.cancelled)
        }
    }

    private static func callbackOutcome(
        granted: Bool,
        status: DevVlogsPhase0BCameraAuthorizationStatus
    ) -> DevVlogsPhase0BCameraAuthorizationOutcome {
        guard !granted else { return .granted }
        return status == .restricted ? .restricted : .denied
    }
}

nonisolated private final class DevVlogsPhase0BAuthorizationContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<DevVlogsPhase0BCameraAuthorizationOutcome, Never>?
    private var pendingOutcome: DevVlogsPhase0BCameraAuthorizationOutcome?
    private var timeoutTask: Task<Void, Never>?

    func install(
        _ continuation: CheckedContinuation<DevVlogsPhase0BCameraAuthorizationOutcome, Never>
    ) -> Bool {
        lock.lock()
        if let pendingOutcome {
            lock.unlock()
            continuation.resume(returning: pendingOutcome)
            return false
        }
        self.continuation = continuation
        lock.unlock()
        return true
    }

    func installTimeoutTask(_ task: Task<Void, Never>) {
        lock.lock()
        if case nil = pendingOutcome {
            timeoutTask = task
            lock.unlock()
        } else {
            lock.unlock()
            task.cancel()
        }
    }

    func finish(_ outcome: DevVlogsPhase0BCameraAuthorizationOutcome) {
        lock.lock()
        guard case nil = pendingOutcome else {
            lock.unlock()
            return
        }
        pendingOutcome = outcome
        let continuation = continuation
        self.continuation = nil
        let timeoutTask = timeoutTask
        self.timeoutTask = nil
        lock.unlock()
        timeoutTask?.cancel()
        continuation?.resume(returning: outcome)
    }
}

struct DevVlogsPhase0BCameraAuthorizationConfiguration: Equatable {
    static let enabledEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_REQUEST_CAMERA_PERMISSION"
    let runRoot: URL
    let caseID: String

    static func shouldRequest(environment: [String: String]) -> Bool {
        environment[enabledEnvironmentKey] == "1"
    }

    static func resolve(
        environment: [String: String],
        temporaryRoot: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    ) -> Self? {
        guard shouldRequest(environment: environment),
              environment[KeychainInteractionPolicy.automationEnvironmentKey] == "1",
              environment[KeychainInteractionPolicy.authenticationUIEnvironmentKey] ==
                KeychainInteractionPolicy.skipAuthenticationUIValue,
              let rawRoot = environment[DevVlogsPhase0BConfiguration.runRootEnvironmentKey]
        else { return nil }
        let runRoot = URL(fileURLWithPath: rawRoot, isDirectory: true).standardizedFileURL
            .resolvingSymlinksInPath()
        let safeRoot = temporaryRoot.standardizedFileURL.resolvingSymlinksInPath()
        let caseID = environment[DevVlogsPhase0BConfiguration.caseIDEnvironmentKey] ?? "camera-authorization"
        guard runRoot.path.hasPrefix(safeRoot.path + "/"), isSafeIdentifier(caseID) else { return nil }
        return Self(runRoot: runRoot, caseID: caseID)
    }

    private static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64 && value.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
        }
    }
}

@MainActor
final class DevVlogsPhase0BCameraAuthorizationHarness {
    private let configuration: DevVlogsPhase0BCameraAuthorizationConfiguration
    private let runID: String
    private let request: DevVlogsPhase0BCameraAuthorizationRequest
    private let eventLog: any DevVlogsPhase0BEventLogging
    private let monotonicClock: () -> TimeInterval
    private var hasRun = false

    init(
        configuration: DevVlogsPhase0BCameraAuthorizationConfiguration,
        runID: String,
        request: DevVlogsPhase0BCameraAuthorizationRequest,
        eventLog: any DevVlogsPhase0BEventLogging,
        monotonicClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.configuration = configuration
        self.runID = runID
        self.request = request
        self.eventLog = eventLog
        self.monotonicClock = monotonicClock
    }

    func run() async -> DevVlogsPhase0BCameraAuthorizationOutcome {
        guard !hasRun else { return .unknown }
        hasRun = true
        let attemptID = UUID().uuidString.lowercased()
        record(action: "camera_authorization", result: .started, attemptID: attemptID, category: nil)
        let outcome = await request.run()
        record(
            action: "camera_authorization_terminal",
            result: outcome.eventResult,
            attemptID: attemptID,
            category: outcome.category
        )
        return outcome
    }

    private func record(
        action: String,
        result: DevVlogsPhase0BResult,
        attemptID: String,
        category: DevVlogsPhase0BFailureCategory?
    ) {
        try? eventLog.record(
            DevVlogsPhase0BEvent(
                runID: runID,
                caseID: configuration.caseID,
                attemptID: attemptID,
                monotonicMilliseconds: Int64(monotonicClock() * 1_000),
                action: action,
                result: result,
                category: category
            )
        )
    }

    static func make(environment: [String: String]) throws -> Self {
        guard let configuration = DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(
            environment: environment
        ) else { throw DevVlogsPhase0BHarnessFailure.invalidConfiguration }
        let runID = UUID().uuidString.lowercased()
        let evidenceDirectory = configuration.runRoot.appendingPathComponent(
            "dv-p0b-camera-authorization-\(runID)/evidence",
            isDirectory: true
        )
        try FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
        return Self(
            configuration: configuration,
            runID: runID,
            request: DevVlogsPhase0BCameraAuthorizationRequest(
                access: DevVlogsPhase0BAppleCameraAuthorizationAccess()
            ),
            eventLog: DevVlogsPhase0BJSONLEventLog(
                fileURL: evidenceDirectory.appendingPathComponent("events.jsonl")
            )
        )
    }
}

enum DevVlogsPhase0BCameraAuthorizationOperatorSummary {
    static func line(for outcome: DevVlogsPhase0BCameraAuthorizationOutcome) -> String {
        "dev_vlogs_phase_0b result=\(outcome.eventResult.rawValue) category=\(outcome.category.rawValue)"
    }
}
#endif
