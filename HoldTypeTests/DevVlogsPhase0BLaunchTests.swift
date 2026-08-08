#if DEBUG
import AppKit
import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPhase0BLaunchTests {
    @Test func gateDefaultsOffAndMalformedEnabledRunStillIsolates() {
        #expect(!DevVlogsPhase0BConfiguration.shouldIsolate(environment: [:]))
        #expect(DevVlogsPhase0BConfiguration.resolve(environment: [:]) == nil)

        let malformed = [DevVlogsPhase0BConfiguration.enabledEnvironmentKey: "1"]
        #expect(DevVlogsPhase0BConfiguration.shouldIsolate(environment: malformed))
        #expect(DevVlogsPhase0BConfiguration.resolve(environment: malformed) == nil)
    }

    @Test func configurationRequiresSanitizationAndTemporaryRunRoot() throws {
        let temporaryRoot = URL(fileURLWithPath: "/tmp/phase0b-tests", isDirectory: true)
        var environment = makeEnvironment(runRoot: "/tmp/phase0b-tests/run")
        #expect(
            DevVlogsPhase0BConfiguration.resolve(
                environment: environment,
                temporaryRoot: temporaryRoot
            ) != nil
        )

        environment[KeychainInteractionPolicy.automationEnvironmentKey] = "true"
        #expect(
            DevVlogsPhase0BConfiguration.resolve(
                environment: environment,
                temporaryRoot: temporaryRoot
            ) == nil
        )

        environment = makeEnvironment(runRoot: "/Users/example/archive")
        #expect(
            DevVlogsPhase0BConfiguration.resolve(
                environment: environment,
                temporaryRoot: temporaryRoot
            ) == nil
        )
    }

    @Test func successfulFakeRunUsesOneAudioOwnerAndFinalizesExactlyOnce() async throws {
        let fixture = makeFixture()
        let outcome = await fixture.harness.run()

        guard case .ready = outcome else {
            Issue.record("Expected fake media to become ready")
            return
        }
        #expect(fixture.audio.startCount == 1)
        #expect(fixture.audio.stopCount == 1)
        #expect(fixture.audio.cancelCount == 0)
        #expect(fixture.audio.preparedURL == fixture.paths.audioURL)
        #expect(fixture.camera.startCount == 1)
        #expect(fixture.camera.stopCount == 1)
        #expect(fixture.finalizer.callCount == 1)
        #expect(fixture.probe.callCount == 1)
        #expect(fixture.events.events.map(\.result) == [.started, .ready])

        #expect(await fixture.harness.run() == .failed(.alreadyRun))
        #expect(fixture.finalizer.callCount == 1)
    }

    @Test func cameraFailureCancelsOnlyRunOwnedAudioAndSkipsMux() async {
        let fixture = makeFixture(cameraFailure: .preferredDeviceBusy)
        #expect(
            await fixture.harness.run() == .failed(.cameraStart(.cameraSelectionBusy))
        )
        #expect(fixture.audio.startCount == 1)
        #expect(fixture.audio.stopCount == 0)
        #expect(fixture.audio.cancelCount == 1)
        #expect(fixture.camera.cleanupCount == 1)
        #expect(fixture.finalizer.callCount == 0)
        #expect(fixture.probe.callCount == 0)
        #expect(fixture.events.events.count == 2)
        #expect(fixture.events.events.last?.action == "attempt_terminal")
        #expect(fixture.events.events.last?.category == .cameraSelectionBusy)
    }

    @Test func steadyCameraFailuresReachOneTypedTerminalAndCleanup() async {
        let expected: [(DevVlogsPhase0BCameraCaptureError, DevVlogsPhase0BFailureCategory)] = [
            (.disconnectedDuringCapture, .cameraInterruptionDisconnected),
            (.runtimeFailure, .cameraSessionRuntimeFailure),
        ]

        for (failure, category) in expected {
            let fixture = makeFixture(stopFailure: failure)
            let outcome = await fixture.harness.run()

            #expect(outcome == .failed(.cameraStart(category)))
            #expect(DevVlogsPhase0BOperatorSummary.line(for: outcome).contains(category.rawValue))
            #expect(fixture.camera.stopCount == 1)
            #expect(fixture.camera.cleanupCount == 1)
            #expect(fixture.audio.stopCount == 1)
            #expect(fixture.audio.cancelCount == 1)
            #expect(fixture.finalizer.callCount == 0)
            #expect(fixture.events.events.filter { $0.action == "attempt_terminal" }.count == 1)
            #expect(fixture.events.events.last?.category == category)
            #expect(fixture.events.events.last?.category != .captureStop)
        }
    }

    @Test func cameraStartFailureUsesNaturalExitWithoutSelfCleanup() async {
        let fixture = makeFixture(cameraFailure: .permissionDenied)
        let outcome = await fixture.harness.run()
        let coordinator = DevVlogsPhase0BTerminationCoordinator(timeout: .seconds(35))
        var normalExitRequests = 0
        var externalCancelCount = 0
        var externalCleanupCount = 0

        #expect(outcome == .failed(.cameraStart(.cameraPermissionDenied)))
        #expect(
            DevVlogsPhase0BOperatorSummary.line(for: outcome) ==
                "dev_vlogs_phase_0b result=failed category=camera_permission_denied"
        )
        if coordinator.harnessDidComplete() { normalExitRequests += 1 }
        let reply = coordinator.begin(
            cancelActive: { externalCancelCount += 1 },
            cleanup: { externalCleanupCount += 1 },
            completion: { _ in Issue.record("Natural completion must not reply asynchronously") }
        )

        #expect(reply == .terminateNow)
        #expect(normalExitRequests == 1)
        #expect(externalCancelCount == 0)
        #expect(externalCleanupCount == 0)
        #expect(fixture.audio.cancelCount == 1)
        #expect(fixture.camera.cleanupCount == 1)
        #expect(fixture.events.events.filter { $0.action == "attempt_terminal" }.count == 1)
        #expect(fixture.events.events.last?.category == .cameraPermissionDenied)
        #expect(!coordinator.harnessDidComplete())
    }

    @Test func naturalCompletionClearsTaskBeforeRequestingTermination() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BLaunch.swift"
            ),
            encoding: .utf8
        )
        let completionStart = try #require(source.range(of: "private func completeHarness"))
        let completionTail = source[completionStart.lowerBound...]
        let completionEnd = try #require(completionTail.range(of: "func applicationShouldTerminate"))
        let completion = completionTail[..<completionEnd.lowerBound]
        let clear = try #require(completion.range(of: "harnessTask = nil"))
        let transition = try #require(completion.range(of: "terminationCoordinator.harnessDidComplete()"))
        let terminate = try #require(completion.range(of: "NSApplication.shared.terminate(nil)"))

        #expect(clear.lowerBound < transition.lowerBound)
        #expect(transition.lowerBound < terminate.lowerBound)
        #expect(!completion.contains("harnessTask.value"))
    }

    @Test func applicationRouterConstructsOnlyTheSelectedComposition() {
        var normalStarts = 0
        var harnessStarts = 0

        DevVlogsPhase0BLaunch.startApplication(
            environment: [:],
            startNormalApplication: { normalStarts += 1 },
            startHarnessApplication: { harnessStarts += 1 }
        )
        #expect(normalStarts == 1)
        #expect(harnessStarts == 0)

        DevVlogsPhase0BLaunch.startApplication(
            environment: [DevVlogsPhase0BConfiguration.enabledEnvironmentKey: "1"],
            startNormalApplication: { normalStarts += 1 },
            startHarnessApplication: { harnessStarts += 1 }
        )
        #expect(normalStarts == 1)
        #expect(harnessStarts == 1)
    }

    @Test func harnessCompositionContainsNoProductScenesAndNormalCompositionRemainsIntact() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("HoldType/HoldTypeApp.swift"),
            encoding: .utf8
        )
        let harnessMarker = "private struct DevVlogsPhase0BHarnessApplication: App"
        let harnessStart = try #require(source.range(of: harnessMarker))
        let harnessTail = source[harnessStart.lowerBound...]
        let harnessEnd = try #require(harnessTail.range(of: "#endif"))
        let harnessComposition = harnessTail[..<harnessEnd.lowerBound]

        #expect(harnessComposition.contains("MenuBarExtra"))
        #expect(!harnessComposition.contains("SettingsScene"))
        #expect(!harnessComposition.contains("FixesEditorScene"))
        #expect(!harnessComposition.contains("TranscriptHistoryScene"))
        #expect(!harnessComposition.contains("TranscriptionFailurePromptScene"))
        #expect(source[..<harnessStart.lowerBound].contains("SettingsScene()"))
        #expect(source[..<harnessStart.lowerBound].contains("FixesEditorScene()"))
        #expect(source[..<harnessStart.lowerBound].contains("TranscriptHistoryScene()"))
        #expect(source[..<harnessStart.lowerBound].contains("TranscriptionFailurePromptScene()"))
    }

    @Test func terminationReturnsLaterUntilCleanupCompletes() async {
        let coordinator = DevVlogsPhase0BTerminationCoordinator(timeout: .seconds(1))
        var reply = NSApplication.TerminateReply.terminateNow
        var cancelCount = 0
        var cleanupCount = 0

        let outcome = await withCheckedContinuation { continuation in
            reply = coordinator.begin(
                cancelActive: { cancelCount += 1 },
                cleanup: { cleanupCount += 1 },
                completion: { continuation.resume(returning: $0) }
            )
        }

        #expect(reply == .terminateLater)
        #expect(outcome == .cleanupCompleted)
        #expect(cancelCount == 1)
        #expect(cleanupCount == 1)
        #expect(coordinator.outcome == .cleanupCompleted)
        #expect(coordinator.state == .terminal)
        #expect(!coordinator.harnessDidComplete())
    }

    @Test func terminationTimeoutIsBoundedAndLateCleanupIsHarmless() async {
        let coordinator = DevVlogsPhase0BTerminationCoordinator(
            timeout: .seconds(1),
            sleep: { _ in }
        )
        var cleanupContinuation: CheckedContinuation<Void, Never>?
        var completionCount = 0
        var cancelCount = 0
        var reply = NSApplication.TerminateReply.terminateNow

        let outcome = await withCheckedContinuation { continuation in
            reply = coordinator.begin(
                cancelActive: { cancelCount += 1 },
                cleanup: {
                    await withCheckedContinuation { cleanupContinuation = $0 }
                },
                completion: {
                    completionCount += 1
                    continuation.resume(returning: $0)
                }
            )
        }

        #expect(reply == .terminateLater)
        #expect(outcome == .cleanupTimedOut)
        #expect(completionCount == 1)
        #expect(cancelCount == 1)
        #expect(cleanupContinuation != nil)
        cleanupContinuation?.resume()
        await Task.yield()
        #expect(completionCount == 1)
        #expect(coordinator.outcome == .cleanupTimedOut)
        #expect(!coordinator.harnessDidComplete())
        #expect(
            coordinator.begin(
                cancelActive: { cancelCount += 1 },
                cleanup: {},
                completion: { _ in completionCount += 1 }
            ) == .terminateNow
        )
        #expect(cancelCount == 1)
        #expect(completionCount == 1)
    }

    @Test func scriptUsesPlannedBoundAndExactRunOwnedSupervisorCleanup() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("script/dev_vlogs_phase_0b_spike.sh"),
            encoding: .utf8
        )

        #expect(source.contains("hardware_timeout_seconds=$(( capture_duration + 300 ))"))
        #expect(!source.contains("capture_duration + 360"))
        #expect(source.contains("capture_supervisor_pid=$!"))
        #expect(source.contains("terminate_capture_supervisor"))
        #expect(source.contains("kill -TERM \"$child_pid\""))
        #expect(source.contains("kill -KILL \"$child_pid\""))
        #expect(!source.contains("killall"))
    }

    private func makeEnvironment(runRoot: String) -> [String: String] {
        [
            DevVlogsPhase0BConfiguration.enabledEnvironmentKey: "1",
            DevVlogsPhase0BConfiguration.runRootEnvironmentKey: runRoot,
            DevVlogsPhase0BConfiguration.cameraUniqueIDEnvironmentKey: "sensitive-device-id",
            DevVlogsPhase0BConfiguration.durationEnvironmentKey: "10",
            DevVlogsPhase0BConfiguration.caseIDEnvironmentKey: "fake-success",
            KeychainInteractionPolicy.automationEnvironmentKey: "1",
            KeychainInteractionPolicy.authenticationUIEnvironmentKey:
                KeychainInteractionPolicy.skipAuthenticationUIValue,
        ]
    }

    private func makeFixture(
        cameraFailure: DevVlogsPhase0BCameraCaptureError? = nil,
        stopFailure: DevVlogsPhase0BCameraCaptureError? = nil
    ) -> HarnessFixture {
        let root = URL(fileURLWithPath: "/tmp/phase0b-tests", isDirectory: true)
        let configuration = DevVlogsPhase0BConfiguration(
            runRoot: root,
            cameraUniqueID: "sensitive-device-id",
            duration: 10,
            caseID: "fake-success"
        )
        let paths = DevVlogsPhase0BRunPaths(
            runID: "run-1",
            runDirectory: root,
            mediaDirectory: root,
            eventLogURL: root.appendingPathComponent("events.jsonl"),
            audioURL: root.appendingPathComponent("audio.m4a"),
            videoURL: root.appendingPathComponent("video.mov"),
            finalURL: root.appendingPathComponent("final.mp4")
        )
        let audio = Phase0BAudioRecorder()
        let camera = Phase0BCamera(failure: cameraFailure, stopFailure: stopFailure, videoURL: paths.videoURL)
        let finalizer = Phase0BFinalizer()
        let probe = Phase0BProbe()
        let events = Phase0BEvents()
        let harness = DevVlogsPhase0BHarness(
            configuration: configuration,
            paths: paths,
            audioRecorder: audio,
            cameraCapture: camera,
            finalizer: finalizer,
            probe: probe,
            eventLog: DevVlogsPhase0BInMemoryEventLog { events.events.append($0) },
            monotonicClock: { 12 },
            sleep: { _ in }
        )
        return HarnessFixture(
            harness: harness,
            paths: paths,
            audio: audio,
            camera: camera,
            finalizer: finalizer,
            probe: probe,
            events: events
        )
    }
}

@MainActor private final class Phase0BAudioRecorder: AudioRecorderService {
    var currentStatus = AudioRecorderStatus.idle
    var lastFinalizationReachedMaximumDuration = false
    let acceptsPreparedRecordingFileURL = true
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0
    private(set) var preparedURL: URL?

    func startRecording(maximumDuration: TimeInterval) async throws {}
    func startRecording(maximumDuration: TimeInterval, outputFileURL: URL?) async throws {
        startCount += 1
        preparedURL = outputFileURL
        currentStatus = .recording
    }
    func stopRecording() async throws -> AudioRecordingArtifact {
        stopCount += 1
        let artifact = AudioRecordingArtifact(fileURL: preparedURL!, duration: 10, byteCount: 1_024)
        currentStatus = .finished(artifact: artifact)
        return artifact
    }
    func cancelRecording() {
        cancelCount += 1
        currentStatus = .cancelled
    }
    func setAutomaticStopHandler(_ handler: AudioRecorderAutomaticStopHandler?) {}
}

@MainActor private final class Phase0BCamera: DevVlogsPhase0BCameraCapturing {
    let failure: DevVlogsPhase0BCameraCaptureError?
    let stopFailure: DevVlogsPhase0BCameraCaptureError?
    let videoURL: URL
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cleanupCount = 0

    init(
        failure: DevVlogsPhase0BCameraCaptureError?,
        stopFailure: DevVlogsPhase0BCameraCaptureError?,
        videoURL: URL
    ) {
        self.failure = failure
        self.stopFailure = stopFailure
        self.videoURL = videoURL
    }
    func startCapture(_ request: DevVlogsPhase0BCameraCaptureRequest) async throws
        -> DevVlogsPhase0BCameraCaptureStart {
        startCount += 1
        if let failure {
            cleanupCount += 1
            throw failure
        }
        return .init(
            requestMonotonicTime: 12,
            recordingStartMonotonicTime: 12.1,
            deviceClass: .builtIn,
            redactedDeviceLabel: "built_in_camera"
        )
    }
    func stopCapture() async throws -> DevVlogsPhase0BCameraCaptureArtifact {
        stopCount += 1
        if let stopFailure { throw stopFailure }
        return .init(
            fileURL: videoURL,
            requestMonotonicTime: 12,
            recordingStartMonotonicTime: 12.1,
            firstFrameMonotonicTime: 12.2,
            firstFramePresentationTime: 0,
            recordingStopMonotonicTime: 22
        )
    }
    func cancelCapture() async { cleanupCount += 1 }
}

@MainActor private final class Phase0BFinalizer: DevVlogsPhase0BMediaFinalizing {
    private(set) var callCount = 0
    func finalize(_ request: DevVlogsPhase0BMediaFinalizationRequest) async throws
        -> DevVlogsPhase0BMediaFinalization {
        callCount += 1
        return .init(outputFileURL: request.outputFileURL, audioInsertionOffset: 0, videoInsertionOffset: 0.1)
    }
}

@MainActor private final class Phase0BProbe: DevVlogsPhase0BMediaProbing {
    private(set) var callCount = 0
    func probe(fileURL: URL) async throws -> DevVlogsPhase0BMediaProbeResult {
        callCount += 1
        return phase0BValidProbeResult()
    }
}

@MainActor private final class Phase0BEvents {
    var events: [DevVlogsPhase0BEvent] = []
}

@MainActor private struct HarnessFixture {
    let harness: DevVlogsPhase0BHarness
    let paths: DevVlogsPhase0BRunPaths
    let audio: Phase0BAudioRecorder
    let camera: Phase0BCamera
    let finalizer: Phase0BFinalizer
    let probe: Phase0BProbe
    let events: Phase0BEvents
}

private func phase0BValidProbeResult() -> DevVlogsPhase0BMediaProbeResult {
    DevVlogsPhase0BMediaProbeResult(
        assetPlayable: true,
        video: .init(
            codec: "avc1", durationSeconds: 10, startTimestampSeconds: 0,
            dimensions: CGSize(width: 1_280, height: 720), nominalFrameRate: 30,
            estimatedDataRate: 2_000_000, playable: true
        ),
        audio: .init(
            codec: "aac ", durationSeconds: 10, startTimestampSeconds: 0,
            dimensions: nil, nominalFrameRate: nil, estimatedDataRate: 128_000, playable: true
        )
    )
}
#endif
