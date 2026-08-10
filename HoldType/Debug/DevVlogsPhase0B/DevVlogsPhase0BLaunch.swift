#if DEBUG
import AppKit
import Foundation
import HoldTypeDomain
struct DevVlogsPhase0BConfiguration: Equatable {
    static let enabledEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B",
               runRootEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_RUN_ROOT",
               cameraUniqueIDEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_CAMERA_ID",
               durationEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_DURATION",
               caseIDEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_CASE_ID",
               eventLogEnvironmentKey = "HOLDTYPE_DEV_VLOGS_PHASE_0B_EVENT_LOG"
    static let defaultDuration: TimeInterval = 10, maximumDuration: TimeInterval = 900
    let runRoot: URL; let cameraUniqueID: String
    let duration: TimeInterval; let caseID: String
    static func shouldIsolate(environment: [String: String]) -> Bool {
        environment[enabledEnvironmentKey] == "1"
    }
    static func resolve(
        environment: [String: String],
        temporaryRoot: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    ) -> DevVlogsPhase0BConfiguration? {
        try? resolveDiagnostically(environment: environment, temporaryRoot: temporaryRoot).get()
    }
    static func resolveDiagnostically(
        environment: [String: String],
        temporaryRoot: URL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
    ) -> Result<DevVlogsPhase0BConfiguration, DevVlogsPhase0BConfigurationFailureStage> {
        guard shouldIsolate(environment: environment) else { return .failure(.isolationNotEnabled) }
        guard environment[KeychainInteractionPolicy.automationEnvironmentKey] == "1" else {
            return .failure(.automationNotEnabled)
        }
        guard environment[KeychainInteractionPolicy.authenticationUIEnvironmentKey] ==
                KeychainInteractionPolicy.skipAuthenticationUIValue else {
            return .failure(.keychainUINotSuppressed)
        }
        guard let rawRoot = environment[runRootEnvironmentKey]
        else { return .failure(.runRootMissing) }
        guard let rawEventLog = environment[eventLogEnvironmentKey] else {
            return .failure(.eventLogMissing)
        }
        guard let rawCameraID = environment[cameraUniqueIDEnvironmentKey]?.trimmingCharacters(
            in: .whitespacesAndNewlines
        ), !rawCameraID.isEmpty else { return .failure(.cameraIDMissing) }
        let runRoot = URL(fileURLWithPath: rawRoot, isDirectory: true).standardizedFileURL
        let safeRoot = temporaryRoot.standardizedFileURL.resolvingSymlinksInPath()
        let resolvedRunRoot = runRoot.resolvingSymlinksInPath()
        guard resolvedRunRoot.path.hasPrefix(safeRoot.path + "/") else {
            return .failure(.runRootOutsideTemporaryRoot)
        }
        let expectedEventLog = resolvedRunRoot.appendingPathComponent(
            "hardware-raw/evidence/events.jsonl"
        ).standardizedFileURL
        guard URL(fileURLWithPath: rawEventLog).standardizedFileURL == expectedEventLog else {
            return .failure(.eventLogPathMismatch)
        }
        let duration = environment[durationEnvironmentKey].flatMap(TimeInterval.init) ?? defaultDuration
        guard duration.isFinite, (1 ... maximumDuration).contains(duration) else {
            return .failure(.durationInvalid)
        }
        let caseID = environment[caseIDEnvironmentKey] ?? "capture"
        guard isSafeIdentifier(caseID) else { return .failure(.caseIDInvalid) }
        return .success(.init(runRoot: resolvedRunRoot, cameraUniqueID: rawCameraID,
                              duration: duration, caseID: caseID))
    }
    private static func isSafeIdentifier(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 64 && value.allSatisfy {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }
    }
}
struct DevVlogsPhase0BRunPaths: Equatable {
    let runID: String
    let runDirectory, mediaDirectory, eventLogURL, audioURL, videoURL, finalURL: URL
    static func prepare(
        configuration: DevVlogsPhase0BConfiguration,
        eventLogURL: URL? = nil,
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
            eventLogURL: eventLogURL ?? evidenceDirectory.appendingPathComponent("events.jsonl"),
            audioURL: mediaDirectory.appendingPathComponent("audio.m4a"),
            videoURL: mediaDirectory.appendingPathComponent("video.mov"),
            finalURL: mediaDirectory.appendingPathComponent("candidate.mov")
        )
    }
}
enum DevVlogsPhase0BHarnessOutcome: Equatable {
    case ready(DevVlogsPhase0BMediaProbeResult), failed(DevVlogsPhase0BHarnessFailure) }
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
            let dimension = DevVlogsPhase0BVideoPreservationFailureDimension(error: error)
            let result: DevVlogsPhase0BResult = switch dimension {
            case .cancelled: .cancelled
            case .timedOut: .timedOut
            default: .failed
            }
            return fail(
                .videoPreservationFailed(dimension),
                attemptID: attemptID,
                result: result,
                cameraProbe: cameraProbe,
                finalProbe: finalProbe
            )
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
        result: DevVlogsPhase0BResult = .failed,
        cameraProbe: DevVlogsPhase0BMediaProbeResult? = nil,
        finalProbe: DevVlogsPhase0BMediaProbeResult? = nil
    ) -> DevVlogsPhase0BHarnessOutcome {
        let dimension: DevVlogsPhase0BVideoPreservationFailureDimension?
        if case .videoPreservationFailed(let value) = failure { dimension = value } else {
            dimension = nil
        }
        let stageEvidence = cameraProbe.flatMap { camera in finalProbe.map { final in
            DevVlogsPhase0BFailureStageEvidence(
                cameraProbePassed: true, passthroughCompleted: true, finalProbePassed: true,
                cameraMediaSubtype: camera.video.codec,
                finalizedMediaSubtype: final.video.codec,
                finalizedAudioMediaSubtype: final.audio?.codec,
                cameraFormat: camera.video.formatDescription,
                finalizedFormat: final.video.formatDescription
            )
        } }
        let metrics = cameraProbe.flatMap { camera in finalProbe.map {
            DevVlogsPhase0BMetric.realizedMediaEvidence(cameraProbe: camera, finalProbe: $0)
        } } ?? []
        guard record(
            action: "attempt_terminal",
            result: result,
            attemptID: attemptID,
            category: failure.category,
            metrics: metrics,
            preservationFailureDimension: dimension,
            failureStageEvidence: stageEvidence
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
        videoEvidence: DevVlogsPhase0BVideoEvidence? = nil,
        preservationFailureDimension: DevVlogsPhase0BVideoPreservationFailureDimension? = nil,
        failureStageEvidence: DevVlogsPhase0BFailureStageEvidence? = nil
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
            videoEvidence: videoEvidence,
            preservationFailureDimension: preservationFailureDimension,
            failureStageEvidence: failureStageEvidence
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
        policyReady: Bool,
        activeConfirmation: DevVlogsPhase0BActiveStateConfirmation,
        routeStarted: () -> Void,
        makeHarness: () throws -> DevVlogsPhase0BCameraAuthorizationHarness,
        makeHandshake: (DevVlogsPhase0BCameraAuthorizationConfiguration) throws
            -> any DevVlogsPhase0BCameraAuthorizationAcknowledging
    ) async -> DevVlogsPhase0BCameraAuthorizationTerminal? {
        guard DevVlogsPhase0BCameraAuthorizationConfiguration.shouldRequest(environment: environment)
        else { return nil }
        routeStarted()
        guard policyReady else {
            return .init(outcome: .activationPolicyFailed, furthestStage: .routeStarted)
        }
        guard let configuration = DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(
            environment: environment
        ) else {
            return .init(outcome: .harnessUnavailable, furthestStage: .regularPolicySet)
        }
        guard let harness = try? makeHarness() else {
            return .init(outcome: .harnessUnavailable, furthestStage: .regularPolicySet)
        }
        guard let handshake = try? makeHandshake(configuration) else {
            return .init(outcome: .harnessUnavailable, furthestStage: .regularPolicySet)
        }
        return await harness.run(handshake: handshake, activeConfirmation: activeConfirmation)
    }
    static func makeHarness(environment: [String: String]) throws -> DevVlogsPhase0BHarness {
        let configuration = try DevVlogsPhase0BConfiguration.resolveDiagnostically(
            environment: environment
        ).get()
        let eventLogURL = configuration.runRoot
            .appendingPathComponent("hardware-raw/evidence/events.jsonl")
        let paths: DevVlogsPhase0BRunPaths
        do { paths = try DevVlogsPhase0BRunPaths.prepare(
            configuration: configuration, eventLogURL: eventLogURL
        ) } catch { throw DevVlogsPhase0BConfigurationFailureStage.runPathsUnavailable }
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
@MainActor
final class DevVlogsPhase0BLaunchDelegate: NSObject, NSApplicationDelegate {
    private let environment: [String: String]
    private let naturalTerminationScheduler: DevVlogsPhase0BNaturalTerminationScheduler
    private let terminationCoordinator = DevVlogsPhase0BTerminationCoordinator(timeout: .seconds(35))
    private var harnessTask: Task<Void, Never>?
    private var authorizationPolicyReady = false
    override convenience init() {
        self.init(environment: ProcessInfo.processInfo.environment, naturalTerminationScheduler: .init())
    }
    init(
        environment: [String: String],
        naturalTerminationScheduler: DevVlogsPhase0BNaturalTerminationScheduler
    ) {
        self.environment = environment
        self.naturalTerminationScheduler = naturalTerminationScheduler
        super.init()
    }
    func applicationWillFinishLaunching(_ notification: Notification) {
        if DevVlogsPhase0BCameraAuthorizationConfiguration.resolve(environment: environment) != nil {
            authorizationPolicyReady = NSApplication.shared.setActivationPolicy(.regular)
        } else {
            NSApplication.shared.setActivationPolicy(.prohibited)
        }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let launchEnvironment = environment
        harnessTask = Task { @MainActor [weak self] in
            if let terminal = await DevVlogsPhase0BLaunch.cameraAuthorizationTerminal(
                environment: launchEnvironment,
                policyReady: self?.authorizationPolicyReady == true,
                activeConfirmation: .live,
                routeStarted: { print(DevVlogsPhase0BCameraAuthorizationOperatorSummary.routeStartedLine) },
                makeHarness: {
                    try DevVlogsPhase0BCameraAuthorizationHarness.make(environment: launchEnvironment)
                },
                makeHandshake: { configuration in
                    DevVlogsPhase0BCameraAuthorizationHandshake(configuration: configuration)
                }
            ) {
                self?.completeAuthorization(terminal)
                return
            }
            let outcome: DevVlogsPhase0BHarnessOutcome
            do {
                outcome = await try DevVlogsPhase0BLaunch.makeHarness(environment: launchEnvironment).run()
            } catch {
                _ = DevVlogsPhase0BConfigurationDiagnostic.record(
                    stage: .init(error: error), environment: launchEnvironment
                )
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
        guard terminationCoordinator.harnessDidComplete() else { return }
        naturalTerminationScheduler.schedule { [weak self] in
            guard let self, self.terminationCoordinator.permitsNaturalTermination else { return }
            NSApplication.shared.terminate(nil)
        }
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
