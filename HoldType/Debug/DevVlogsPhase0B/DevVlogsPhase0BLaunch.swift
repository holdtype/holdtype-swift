#if DEBUG
import AppKit
import Foundation
import HoldTypeDomain
struct DevVlogsPhase0BConfiguration: Equatable {
    static let enabledEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B"
    static let runRootEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT"
    static let cameraUniqueIDEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_CAMERA_ID"
    static let durationEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_DURATION"
    static let caseIDEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_CASE_ID"
    static let defaultDuration: TimeInterval = 10
    static let maximumDuration: TimeInterval = 900
    let runRoot: URL
    let cameraUniqueID: String
    let duration: TimeInterval
    let caseID: String
    static func shouldIsolate(environment: [String: String]) -> Bool {
        environment[enabledEnvironmentKey] == "1"
    }
    static func resolve(
        environment: [String: String],
        temporaryRoot: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    ) -> DevVlogsPhase0BConfiguration? {
        guard shouldIsolate(environment: environment),
              environment[KeychainInteractionPolicy.automationEnvironmentKey] == "1",
              environment[KeychainInteractionPolicy.authenticationUIEnvironmentKey] ==
                KeychainInteractionPolicy.skipAuthenticationUIValue,
              let rawRoot = environment[runRootEnvironmentKey],
              let rawCameraID = environment[cameraUniqueIDEnvironmentKey]?.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ),
              !rawCameraID.isEmpty else {
            return nil
        }
        let runRoot = URL(fileURLWithPath: rawRoot, isDirectory: true).standardizedFileURL
        let safeRoot = temporaryRoot.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedRunRoot = runRoot.resolvingSymlinksInPath()
        guard resolvedRunRoot.path.hasPrefix(safeRoot.path + "/") else {
            return nil
        }
        let duration = environment[durationEnvironmentKey]
            .flatMap(TimeInterval.init) ?? defaultDuration
        guard duration.isFinite, (1 ... maximumDuration).contains(duration) else {
            return nil
        }
        let caseID = environment[caseIDEnvironmentKey] ?? "capture"
        guard isSafeIdentifier(caseID) else {
            return nil
        }
        return DevVlogsPhase0BConfiguration(
            runRoot: resolvedRunRoot,
            cameraUniqueID: rawCameraID,
            duration: duration,
            caseID: caseID
        )
    }
    private static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64 && value.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_")
        }
    }
}
struct DevVlogsPhase0BRunPaths: Equatable {
    let runID: String
    let runDirectory, mediaDirectory, eventLogURL, audioURL, videoURL, finalURL: URL
    static func prepare(
        configuration: DevVlogsPhase0BConfiguration,
        fileManager: FileManager = .default,
        makeID: () -> UUID = UUID.init
    ) throws -> DevVlogsPhase0BRunPaths {
        let runID = makeID().uuidString.lowercased()
        let runDirectory = configuration.runRoot.appendingPathComponent(
            "dv-p0b-\(runID)",
            isDirectory: true
        )
        let mediaDirectory = runDirectory.appendingPathComponent("media", isDirectory: true)
        let evidenceDirectory = runDirectory.appendingPathComponent("evidence", isDirectory: true)
        try fileManager.createDirectory(at: mediaDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
        return DevVlogsPhase0BRunPaths(
            runID: runID,
            runDirectory: runDirectory,
            mediaDirectory: mediaDirectory,
            eventLogURL: evidenceDirectory.appendingPathComponent("events.jsonl"),
            audioURL: mediaDirectory.appendingPathComponent("audio.m4a"),
            videoURL: mediaDirectory.appendingPathComponent("video.mov"),
            finalURL: mediaDirectory.appendingPathComponent("candidate.mov")
        )
    }
}
enum DevVlogsPhase0BHarnessOutcome: Equatable {
    case ready(DevVlogsPhase0BMediaProbeResult), failed(DevVlogsPhase0BHarnessFailure)
}
@MainActor
final class DevVlogsPhase0BHarness {
    private let configuration: DevVlogsPhase0BConfiguration
    private let paths: DevVlogsPhase0BRunPaths
    private let audioRecorder: any AudioRecorderService
    private let cameraCapture: any DevVlogsPhase0BCameraCapturing
    private let finalizer: any DevVlogsPhase0BMediaFinalizing
    private let probe: any DevVlogsPhase0BMediaProbing
    private let preservation: any DevVlogsPhase0BVideoPreserving
    private let eventLog: any DevVlogsPhase0BEventLogging
    private let monotonicClock: () -> TimeInterval
    private let sleep: (Duration) async throws -> Void
    private var hasRun = false
    init(
        configuration: DevVlogsPhase0BConfiguration,
        paths: DevVlogsPhase0BRunPaths,
        audioRecorder: any AudioRecorderService,
        cameraCapture: any DevVlogsPhase0BCameraCapturing,
        finalizer: any DevVlogsPhase0BMediaFinalizing,
        probe: any DevVlogsPhase0BMediaProbing,
        preservation: any DevVlogsPhase0BVideoPreserving,
        eventLog: any DevVlogsPhase0BEventLogging,
        monotonicClock: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.configuration = configuration
        self.paths = paths
        self.audioRecorder = audioRecorder
        self.cameraCapture = cameraCapture
        self.finalizer = finalizer
        self.probe = probe
        self.preservation = preservation
        self.eventLog = eventLog
        self.monotonicClock = monotonicClock
        self.sleep = sleep
    }
    func run() async -> DevVlogsPhase0BHarnessOutcome {
        guard !hasRun else { return .failed(.alreadyRun) }
        hasRun = true
        let attemptID = UUID().uuidString.lowercased()
        guard record(action: "attempt", result: .started, attemptID: attemptID) else {
            return .failed(.eventLog)
        }
        let audioStartTime = monotonicClock()
        do {
            try await audioRecorder.startRecording(
                maximumDuration: configuration.duration,
                outputFileURL: paths.audioURL
            )
        } catch {
            return fail(.audioStart, attemptID: attemptID)
        }
        let cameraStart: DevVlogsPhase0BCameraCaptureStart
        do {
            cameraStart = try await cameraCapture.startCapture(
                DevVlogsPhase0BCameraCaptureRequest(
                    deviceUniqueID: configuration.cameraUniqueID,
                    outputFileURL: paths.videoURL,
                    setupTimeout: .seconds(30)
                )
            )
        } catch {
            audioRecorder.cancelRecording()
            return fail(
                .cameraStart(DevVlogsPhase0BCameraCaptureError.redactedCategory(for: error)),
                attemptID: attemptID
            )
        }
        do {
            try await sleep(.seconds(configuration.duration))
        } catch {
            await cameraCapture.cancelCapture()
            audioRecorder.cancelRecording()
            return fail(.captureStop, attemptID: attemptID, result: .cancelled)
        }
        let cameraArtifact: DevVlogsPhase0BCameraCaptureArtifact
        let audioArtifact: AudioRecordingArtifact
        do {
            async let stoppedCamera = cameraCapture.stopCapture()
            async let stoppedAudio = audioRecorder.stopRecording()
            (cameraArtifact, audioArtifact) = try await (stoppedCamera, stoppedAudio)
        } catch {
            await cameraCapture.cancelCapture()
            audioRecorder.cancelRecording()
            let failure = (error as? DevVlogsPhase0BCameraCaptureError)
                .map { DevVlogsPhase0BHarnessFailure.cameraStart($0.redactedCategory) } ?? .captureStop
            return fail(failure, attemptID: attemptID)
        }
        let cameraProbe: DevVlogsPhase0BMediaProbeResult
        do {
            cameraProbe = try await probe.probe(
                fileURL: cameraArtifact.fileURL,
                expectation: .cameraOnly
            )
        } catch {
            return fail(.cameraProbe, attemptID: attemptID)
        }
        let finalization: DevVlogsPhase0BMediaFinalization
        do {
            finalization = try await finalizer.finalize(
                DevVlogsPhase0BMediaFinalizationRequest(
                    videoFileURL: cameraArtifact.fileURL,
                    audioFileURL: audioArtifact.fileURL,
                    outputFileURL: paths.finalURL,
                    alignment: DevVlogsPhase0BMediaAlignment(
                        audioCaptureStartMonotonicTime: audioStartTime,
                        videoCaptureStartMonotonicTime: cameraStart.recordingStartMonotonicTime
                    ),
                    timeout: .seconds(300)
                )
            )
        } catch let error as DevVlogsPhase0BMediaFinalizerError {
            switch error {
            case .passthroughIncompatible:
                return fail(.passthroughIncompatible, attemptID: attemptID)
            case .passthroughExportFailed:
                return fail(.passthroughExportFailed, attemptID: attemptID)
            default:
                return fail(.finalization, attemptID: attemptID)
            }
        } catch {
            return fail(.finalization, attemptID: attemptID)
        }
        let finalProbe: DevVlogsPhase0BMediaProbeResult
        do {
            finalProbe = try await probe.probe(fileURL: paths.finalURL, expectation: .finalized)
        } catch {
            return fail(.finalProbe, attemptID: attemptID)
        }
        let preservationResult: DevVlogsPhase0BVideoPreservationResult
        do {
            preservationResult = try await preservation.compare(
                DevVlogsPhase0BVideoPreservationRequest(
                    cameraFileURL: cameraArtifact.fileURL,
                    finalizedFileURL: finalization.outputFileURL,
                    expectedInsertionOffset: finalization.videoSampleTimestampOffset,
                    timeout: .seconds(300)
                )
            )
        } catch {
            return fail(.videoPreservationFailed, attemptID: attemptID)
        }
        do {
            guard record(
                action: "attempt_terminal",
                result: .ready,
                attemptID: attemptID,
                deviceClass: cameraStart.deviceClass,
                redactedDeviceLabel: cameraStart.redactedDeviceLabel,
                metrics: DevVlogsPhase0BMetric.captureEvidence(
                    camera: cameraArtifact,
                    cameraProbe: cameraProbe,
                    finalProbe: finalProbe,
                    preservation: preservationResult
                ),
                videoEvidence: DevVlogsPhase0BVideoEvidence(
                    cameraMediaSubtype: cameraProbe.video.codec,
                    finalizedMediaSubtype: finalProbe.video.codec,
                    finalizedAudioMediaSubtype: finalProbe.audio?.codec,
                    cameraFormat: cameraProbe.video.formatDescription,
                    finalizedFormat: finalProbe.video.formatDescription,
                    preservationMethod: DevVlogsPhase0BVideoPreservationResult.method,
                    preservedSampleCount: preservationResult.sampleCount,
                    preservedEncodedByteCount: preservationResult.encodedByteCount,
                    matched: true
                )
            ) else {
                return .failed(.eventLog)
            }
            return .ready(finalProbe)
        }
    }
    private func fail(
        _ failure: DevVlogsPhase0BHarnessFailure,
        attemptID: String,
        result: DevVlogsPhase0BResult = .failed
    ) -> DevVlogsPhase0BHarnessOutcome {
        guard record(
            action: "attempt_terminal",
            result: result,
            attemptID: attemptID,
            category: failure.category
        ) else {
            return .failed(.eventLog)
        }
        return .failed(failure)
    }
    private func record(
        action: String,
        result: DevVlogsPhase0BResult,
        attemptID: String,
        category: DevVlogsPhase0BFailureCategory? = nil,
        deviceClass: DevVlogsPhase0BDeviceClass? = nil,
        redactedDeviceLabel: String? = nil,
        metrics: [DevVlogsPhase0BMetric] = [],
        videoEvidence: DevVlogsPhase0BVideoEvidence? = nil
    ) -> Bool {
        let event = DevVlogsPhase0BEvent(
            runID: paths.runID,
            caseID: configuration.caseID,
            attemptID: attemptID,
            monotonicMilliseconds: Int64(monotonicClock() * 1_000),
            action: action,
            result: result,
            category: category,
            deviceClass: deviceClass,
            redactedDeviceLabel: redactedDeviceLabel,
            metrics: metrics,
            videoEvidence: videoEvidence
        )
        do { try eventLog.record(event); return true } catch { return false }
    }
}
@MainActor
enum DevVlogsPhase0BLaunch {
    static func shouldIsolate(environment: [String: String] = ProcessInfo.processInfo.environment) -> Bool {
        DevVlogsPhase0BConfiguration.shouldIsolate(environment: environment)
            || DevVlogsPhase0BCameraAuthorizationConfiguration.shouldRequest(environment: environment)
    }
    static func startApplication(
        environment: [String: String],
        startNormalApplication: () -> Void,
        startHarnessApplication: () -> Void
    ) {
        shouldIsolate(environment: environment) ? startHarnessApplication() : startNormalApplication()
    }
    static func cameraAuthorizationTerminal(
        environment: [String: String],
        activation: DevVlogsPhase0BApplicationActivation,
        routeStarted: () -> Void,
        makeHarness: () throws -> DevVlogsPhase0BCameraAuthorizationHarness
    ) async -> DevVlogsPhase0BCameraAuthorizationTerminal? {
        guard DevVlogsPhase0BCameraAuthorizationConfiguration.shouldRequest(environment: environment)
        else { return nil }
        routeStarted()
        guard let harness = try? makeHarness() else {
            return .init(outcome: .harnessUnavailable, furthestStage: .routeStarted)
        }
        return await harness.run(activation: activation)
    }
    static func makeHarness(environment: [String: String]) throws -> DevVlogsPhase0BHarness {
        guard let configuration = DevVlogsPhase0BConfiguration.resolve(environment: environment) else {
            throw DevVlogsPhase0BHarnessFailure.invalidConfiguration
        }
        let paths = try DevVlogsPhase0BRunPaths.prepare(configuration: configuration)
        return DevVlogsPhase0BHarness(
            configuration: configuration,
            paths: paths,
            audioRecorder: AVFoundationAudioRecorderService(),
            cameraCapture: DevVlogsPhase0BCameraCapture(),
            finalizer: DevVlogsPhase0BMediaFinalizer(),
            probe: DevVlogsPhase0BMediaProbe(),
            preservation: DevVlogsPhase0BVideoPreservation(),
            eventLog: DevVlogsPhase0BJSONLEventLog(fileURL: paths.eventLogURL)
        )
    }
}
enum DevVlogsPhase0BTerminationOutcome: Equatable { case cleanupCompleted, cleanupTimedOut }
enum DevVlogsPhase0BTerminationState: Equatable { case active, harnessCompleted, cleanupPending, terminal }
@MainActor
final class DevVlogsPhase0BTerminationCoordinator {
    typealias Sleep = @MainActor (Duration) async throws -> Void
    private let timeout: Duration
    private let sleep: Sleep
    private var raceContinuation: CheckedContinuation<DevVlogsPhase0BTerminationOutcome, Never>?
    private var cleanupWorker: Task<Void, Never>?
    private var timeoutTask: Task<Void, Never>?
    private var completionTask: Task<Void, Never>?
    private(set) var state = DevVlogsPhase0BTerminationState.active
    private(set) var outcome: DevVlogsPhase0BTerminationOutcome?
    init(timeout: Duration, sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
        self.timeout = timeout
        self.sleep = sleep
    }
    func harnessDidComplete() -> Bool {
        guard state == .active else { return false }
        state = .harnessCompleted; return true
    }
    func begin(
        cancelActive: () -> Void,
        cleanup: @escaping @MainActor () async -> Void,
        completion: @escaping @MainActor (DevVlogsPhase0BTerminationOutcome) -> Void
    ) -> NSApplication.TerminateReply {
        switch state {
        case .harnessCompleted:
            state = .terminal
            return .terminateNow
        case .cleanupPending:
            return .terminateLater
        case .terminal:
            return .terminateNow
        case .active:
            state = .cleanupPending
        }
        cancelActive()
        completionTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let outcome = await self.raceCleanup(cleanup)
            completion(outcome)
        }
        return .terminateLater
    }
    private func raceCleanup(
        _ cleanup: @escaping @MainActor () async -> Void
    ) async -> DevVlogsPhase0BTerminationOutcome {
        await withCheckedContinuation { continuation in
            raceContinuation = continuation
            cleanupWorker = Task { @MainActor [weak self] in
                await cleanup()
                self?.finish(.cleanupCompleted)
            }
            timeoutTask = Task { @MainActor [weak self, timeout, sleep] in
                do {
                    try await sleep(timeout)
                } catch {
                    return
                }
                self?.finish(.cleanupTimedOut)
            }
        }
    }
    private func finish(_ outcome: DevVlogsPhase0BTerminationOutcome) {
        guard state == .cleanupPending, let continuation = raceContinuation else { return }
        raceContinuation = nil
        state = .terminal
        self.outcome = outcome
        cleanupWorker?.cancel()
        timeoutTask?.cancel()
        cleanupWorker = nil
        timeoutTask = nil
        continuation.resume(returning: outcome)
    }
}
@MainActor
final class DevVlogsPhase0BLaunchDelegate: NSObject, NSApplicationDelegate {
    private let environment: [String: String]
    private let terminationCoordinator = DevVlogsPhase0BTerminationCoordinator(
        timeout: .seconds(35)
    )
    private var harnessTask: Task<Void, Never>?
    override init() { environment = ProcessInfo.processInfo.environment; super.init() }
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let launchEnvironment = environment
        harnessTask = Task { @MainActor [weak self] in
            if let terminal = await DevVlogsPhase0BLaunch.cameraAuthorizationTerminal(
                environment: launchEnvironment,
                activation: .live,
                routeStarted: {
                    print(DevVlogsPhase0BCameraAuthorizationOperatorSummary.routeStartedLine)
                },
                makeHarness: {
                    try DevVlogsPhase0BCameraAuthorizationHarness.make(
                        environment: launchEnvironment
                    )
                }
            ) {
                self?.completeAuthorization(terminal)
                return
            }
            let outcome: DevVlogsPhase0BHarnessOutcome
            if let harness = try? DevVlogsPhase0BLaunch.makeHarness(environment: launchEnvironment) {
                outcome = await harness.run()
            } else {
                outcome = .failed(.invalidConfiguration)
            }
            self?.completeHarness(outcome)
        }
    }
    private func completeAuthorization(_ terminal: DevVlogsPhase0BCameraAuthorizationTerminal) {
        complete(line: DevVlogsPhase0BCameraAuthorizationOperatorSummary.line(for: terminal)) }
    private func completeHarness(_ outcome: DevVlogsPhase0BHarnessOutcome) {
        complete(line: DevVlogsPhase0BOperatorSummary.line(for: outcome)) }
    private func complete(line: String) {
        print(line)
        harnessTask = nil
        if terminationCoordinator.harnessDidComplete() { NSApplication.shared.terminate(nil) }
    }
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let activeTask = harnessTask
        return terminationCoordinator.begin(
            cancelActive: { activeTask?.cancel() },
            cleanup: {
                await activeTask?.value
            },
            completion: { outcome in
                if outcome == .cleanupTimedOut {
                    print("dev_vlogs_phase_0b result=failed category=termination_timeout")
                }
                NSApplication.shared.reply(toApplicationShouldTerminate: true)
            }
        )
    }
}
#endif
