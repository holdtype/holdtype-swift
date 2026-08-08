#if DEBUG
import AppKit
import AVFoundation
import Foundation

enum DevVlogsPhase0BCameraAuthorizationStatus: Equatable {
    case notDetermined, authorized, denied, restricted, unknown
}

enum DevVlogsPhase0BCameraAuthorizationOutcome: Equatable {
    case granted, alreadyAuthorized, denied, restricted, timedOut, cancelled, statusUnknown
    case activationPolicyFailed, activationRejected, activationTimedOut, activationCancelled
    case harnessUnavailable, alreadyCompleted

    var category: DevVlogsPhase0BFailureCategory {
        switch self {
        case .granted: .cameraAuthorizationGranted
        case .alreadyAuthorized: .cameraAuthorizationAlreadyAuthorized
        case .denied: .cameraAuthorizationDenied
        case .restricted: .cameraAuthorizationRestricted
        case .timedOut: .cameraAuthorizationTimedOut
        case .cancelled: .cameraAuthorizationCancelled
        case .statusUnknown: .cameraAuthorizationStatusUnknown
        case .activationPolicyFailed: .cameraAuthorizationActivationPolicyFailed
        case .activationRejected: .cameraAuthorizationActivationRejected
        case .activationTimedOut: .cameraAuthorizationActivationTimedOut
        case .activationCancelled: .cameraAuthorizationActivationCancelled
        case .harnessUnavailable: .cameraAuthorizationHarnessUnavailable
        case .alreadyCompleted: .alreadyRun
        }
    }

    var eventResult: DevVlogsPhase0BResult {
        switch self {
        case .granted, .alreadyAuthorized: .ready
        case .timedOut, .activationTimedOut: .timedOut
        case .cancelled, .activationCancelled: .cancelled
        case .denied, .restricted, .statusUnknown, .activationPolicyFailed,
             .activationRejected, .harnessUnavailable, .alreadyCompleted: .failed
        }
    }
}

struct DevVlogsPhase0BCameraAuthorizationTerminal: Equatable {
    let outcome: DevVlogsPhase0BCameraAuthorizationOutcome
    let furthestStage: DevVlogsPhase0BCameraAuthorizationStage
}

private enum DevVlogsPhase0BApplicationActivationOutcome {
    case active, policyFailed, requestRejected, confirmationTimedOut, cancelled
}

@MainActor
struct DevVlogsPhase0BApplicationActivation {
    typealias Sleep = @MainActor @Sendable (Duration) async throws -> Void
    let setRegularPolicy: () -> Bool
    let requestActivation: () -> Bool
    let isActive: () -> Bool
    let sleep: Sleep
    let confirmationAttempts: Int

    static let live = Self(
        setRegularPolicy: { NSApplication.shared.setActivationPolicy(.regular) },
        requestActivation: {
            let application = NSApplication.shared
            let accepted = NSRunningApplication.current.activate(options: [])
            application.activate()
            return accepted
        },
        isActive: { NSApplication.shared.isActive },
        sleep: { try await Task.sleep(for: $0) },
        confirmationAttempts: 100
    )

    fileprivate func run(
        stage: (DevVlogsPhase0BCameraAuthorizationStage) -> Void
    ) async -> DevVlogsPhase0BApplicationActivationOutcome {
        guard !Task.isCancelled else { return .cancelled }
        guard setRegularPolicy() else { return .policyFailed }
        stage(.regularPolicySet)
        guard !Task.isCancelled else { return .cancelled }
        stage(.activationRequested)
        guard requestActivation() else { return .requestRejected }
        for _ in 0 ..< confirmationAttempts {
            guard !Task.isCancelled else { return .cancelled }
            if isActive() {
                stage(.activeStateConfirmed)
                return .active
            }
            do {
                try await sleep(.milliseconds(50))
            } catch is CancellationError {
                return .cancelled
            } catch {
                return .confirmationTimedOut
            }
        }
        return .confirmationTimedOut
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

    func run(
        stage: @escaping @Sendable (DevVlogsPhase0BCameraAuthorizationStage) -> Void = { _ in }
    ) async -> DevVlogsPhase0BCameraAuthorizationOutcome {
        let status = access.authorizationStatus()
        stage(.authorizationStatusInspected)
        switch status {
        case .authorized: return .alreadyAuthorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .unknown: return .statusUnknown
        case .notDetermined: break
        }
        guard !Task.isCancelled else { return .cancelled }

        let gate = DevVlogsPhase0BAuthorizationContinuationGate()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                guard gate.install(continuation) else { return }
                guard !Task.isCancelled else {
                    gate.finish(.cancelled)
                    return
                }
                let timeoutTask = Task { [sleep, timeout] in
                    do {
                        try await sleep(timeout)
                    } catch {
                        return
                    }
                    gate.finish(.timedOut)
                }
                gate.installTimeoutTask(timeoutTask)
                stage(.requestAccessStarted)
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

    func run(
        activation: DevVlogsPhase0BApplicationActivation
    ) async -> DevVlogsPhase0BCameraAuthorizationTerminal {
        guard !hasRun else {
            return .init(outcome: .alreadyCompleted, furthestStage: .routeStarted)
        }
        hasRun = true
        let attemptID = UUID().uuidString.lowercased()
        let stages = DevVlogsPhase0BCameraAuthorizationStageTracker()
        record(
            action: "camera_authorization",
            result: .started,
            attemptID: attemptID,
            category: nil,
            furthestStage: .routeStarted
        )
        let activationOutcome = await activation.run { stages.advance(to: $0) }
        switch activationOutcome {
        case .policyFailed: return finish(.activationPolicyFailed, stages, attemptID)
        case .requestRejected: return finish(.activationRejected, stages, attemptID)
        case .confirmationTimedOut: return finish(.activationTimedOut, stages, attemptID)
        case .cancelled: return finish(.activationCancelled, stages, attemptID)
        case .active: break
        }
        stages.advance(to: .authorizationHarnessEntered)
        let outcome = await request.run { stages.advance(to: $0) }
        return finish(outcome, stages, attemptID)
    }

    private func finish(
        _ outcome: DevVlogsPhase0BCameraAuthorizationOutcome,
        _ stages: DevVlogsPhase0BCameraAuthorizationStageTracker,
        _ attemptID: String
    ) -> DevVlogsPhase0BCameraAuthorizationTerminal {
        let furthestStage = stages.finish()
        record(
            action: "camera_authorization_terminal",
            result: outcome.eventResult,
            attemptID: attemptID,
            category: outcome.category,
            furthestStage: furthestStage
        )
        return .init(outcome: outcome, furthestStage: furthestStage)
    }

    private func record(
        action: String,
        result: DevVlogsPhase0BResult,
        attemptID: String,
        category: DevVlogsPhase0BFailureCategory?,
        furthestStage: DevVlogsPhase0BCameraAuthorizationStage
    ) {
        try? eventLog.record(
            DevVlogsPhase0BEvent(
                runID: runID,
                caseID: configuration.caseID,
                attemptID: attemptID,
                monotonicMilliseconds: Int64(monotonicClock() * 1_000),
                action: action,
                result: result,
                category: category,
                furthestStage: furthestStage
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
    static let routeStartedLine =
        "dev_vlogs_phase_0b result=started furthest_stage=route_started"

    static func line(for terminal: DevVlogsPhase0BCameraAuthorizationTerminal) -> String {
        "dev_vlogs_phase_0b result=\(terminal.outcome.eventResult.rawValue) "
            + "category=\(terminal.outcome.category.rawValue) "
            + "furthest_stage=\(terminal.furthestStage.rawValue)"
    }
}

private final class DevVlogsPhase0BCameraAuthorizationStageTracker: @unchecked Sendable {
    private let lock = NSLock()
    private var stage = DevVlogsPhase0BCameraAuthorizationStage.routeStarted
    private var isTerminal = false

    func advance(to next: DevVlogsPhase0BCameraAuthorizationStage) {
        lock.withLock {
            guard !isTerminal, next.rank > stage.rank else { return }
            stage = next
        }
    }

    func finish() -> DevVlogsPhase0BCameraAuthorizationStage {
        lock.withLock {
            isTerminal = true
            return stage
        }
    }
}
#endif
