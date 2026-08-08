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
    let runDirectory: URL
    let mediaDirectory: URL
    let eventLogURL: URL
    let audioURL: URL
    let videoURL: URL
    let finalURL: URL

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
            finalURL: mediaDirectory.appendingPathComponent("candidate.mp4")
        )
    }
}

enum DevVlogsPhase0BHarnessFailure: String, Error, Equatable {
    case invalidConfiguration = "invalid_configuration"
    case audioStart = "audio_start"
    case cameraStart = "camera_start"
    case captureStop = "capture_stop"
    case finalization = "finalization"
    case probe = "probe"
    case eventLog = "event_log"
    case alreadyRun = "already_run"
}

enum DevVlogsPhase0BHarnessOutcome: Equatable {
    case ready(DevVlogsPhase0BMediaProbeResult)
    case failed(DevVlogsPhase0BHarnessFailure)
}

@MainActor
final class DevVlogsPhase0BHarness {
    private let configuration: DevVlogsPhase0BConfiguration
    private let paths: DevVlogsPhase0BRunPaths
    private let audioRecorder: any AudioRecorderService
    private let cameraCapture: any DevVlogsPhase0BCameraCapturing
    private let finalizer: any DevVlogsPhase0BMediaFinalizing
    private let probe: any DevVlogsPhase0BMediaProbing
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
            return fail(.cameraStart, attemptID: attemptID)
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
            return fail(.captureStop, attemptID: attemptID)
        }

        do {
            _ = try await finalizer.finalize(
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
        } catch {
            return fail(.finalization, attemptID: attemptID)
        }

        do {
            let result = try await probe.probe(fileURL: paths.finalURL)
            guard record(
                action: "attempt_terminal",
                result: .ready,
                attemptID: attemptID,
                deviceClass: cameraStart.deviceClass,
                redactedDeviceLabel: cameraStart.redactedDeviceLabel,
                metrics: metrics(camera: cameraArtifact, probe: result)
            ) else {
                return .failed(.eventLog)
            }
            return .ready(result)
        } catch {
            return fail(.probe, attemptID: attemptID)
        }
    }

    private func fail(
        _ failure: DevVlogsPhase0BHarnessFailure,
        attemptID: String,
        result: DevVlogsPhase0BResult = .failed
    ) -> DevVlogsPhase0BHarnessOutcome {
        guard record(
            action: "attempt_terminal_\(failure.rawValue)",
            result: result,
            attemptID: attemptID
        ) else {
            return .failed(.eventLog)
        }
        return .failed(failure)
    }

    private func record(
        action: String,
        result: DevVlogsPhase0BResult,
        attemptID: String,
        deviceClass: DevVlogsPhase0BDeviceClass? = nil,
        redactedDeviceLabel: String? = nil,
        metrics: [DevVlogsPhase0BMetric] = []
    ) -> Bool {
        let event = DevVlogsPhase0BEvent(
            runID: paths.runID,
            caseID: configuration.caseID,
            attemptID: attemptID,
            monotonicMilliseconds: Int64(monotonicClock() * 1_000),
            action: action,
            result: result,
            deviceClass: deviceClass,
            redactedDeviceLabel: redactedDeviceLabel,
            metrics: metrics
        )
        do {
            try eventLog.record(event)
            return true
        } catch {
            return false
        }
    }

    private func metrics(
        camera: DevVlogsPhase0BCameraCaptureArtifact,
        probe: DevVlogsPhase0BMediaProbeResult
    ) -> [DevVlogsPhase0BMetric] {
        let firstFrameLatency = camera.firstFrameMonotonicTime.map {
            ($0 - camera.requestMonotonicTime) * 1_000
        }
        return [
            firstFrameLatency.map {
                DevVlogsPhase0BMetric(
                    name: "camera_request_to_first_frame",
                    value: $0,
                    unit: "ms",
                    disposition: "evidence_only"
                )
            },
            DevVlogsPhase0BMetric(
                name: "video_duration",
                value: probe.video.durationSeconds,
                unit: "s",
                disposition: "evidence_only"
            ),
            DevVlogsPhase0BMetric(
                name: "audio_duration",
                value: probe.audio.durationSeconds,
                unit: "s",
                disposition: "evidence_only"
            ),
        ].compactMap { $0 }
    }
}

@MainActor
enum DevVlogsPhase0BLaunch {
    static func shouldIsolate(
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        DevVlogsPhase0BConfiguration.shouldIsolate(environment: environment)
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
            eventLog: DevVlogsPhase0BJSONLEventLog(fileURL: paths.eventLogURL)
        )
    }
}

@MainActor
final class DevVlogsPhase0BLaunchDelegate: NSObject, NSApplicationDelegate {
    private let environment: [String: String]
    private let normalDelegate: HoldTypeAppDelegate?
    private var harnessTask: Task<Void, Never>?

    override init() {
        let environment = ProcessInfo.processInfo.environment
        self.environment = environment
        normalDelegate = DevVlogsPhase0BLaunch.shouldIsolate(environment: environment)
            ? nil
            : HoldTypeAppDelegate()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let normalDelegate {
            normalDelegate.applicationDidFinishLaunching(notification)
            return
        }

        NSApplication.shared.setActivationPolicy(.prohibited)
        harnessTask = Task { @MainActor in
            if let harness = try? DevVlogsPhase0BLaunch.makeHarness(environment: environment) {
                switch await harness.run() {
                case .ready:
                    print("dev_vlogs_phase_0b result=ready")
                case .failed(let failure):
                    print("dev_vlogs_phase_0b result=failed category=\(failure.rawValue)")
                }
            } else {
                print("dev_vlogs_phase_0b result=failed category=invalid_configuration")
            }
            NSApplication.shared.terminate(nil)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let normalDelegate else {
            harnessTask?.cancel()
            return .terminateNow
        }
        return normalDelegate.applicationShouldTerminate(sender)
    }

    func applicationWillTerminate(_ notification: Notification) {
        if let normalDelegate {
            normalDelegate.applicationWillTerminate(notification)
        } else {
            harnessTask?.cancel()
        }
    }
}
#endif
