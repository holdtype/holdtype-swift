#if DEBUG
import AppKit
import CoreMedia
import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType
@MainActor
struct DevVlogsPhase0BLaunchTests {
    @Test func gateDefaultsOffAndEveryHardwareIntentStillIsolates() {
        #expect(!DevVlogsPhase0BConfiguration.shouldIsolate(environment: [:])); #expect(DevVlogsPhase0BConfiguration.resolve(environment: [:]) == nil)
        for key in DevVlogsPhase0BConfiguration.hardwareIntentEnvironmentKeys {
            let partial = [key: key == DevVlogsPhase0BConfiguration.enabledEnvironmentKey ? "wrong" : "value"]
            #expect(DevVlogsPhase0BConfiguration.shouldIsolate(environment: partial))
            #expect(DevVlogsPhase0BConfiguration.resolveDiagnostically(environment: partial) == .failure(.isolationNotEnabled))
        }
    }
    @Test func everyPreAttemptGuardHasOneClosedDiagnosticAndNoOperatorSemanticChange() throws {
        let fileManager = FileManager.default; let temporaryRoot = fileManager.temporaryDirectory
        let runRoot = temporaryRoot.appendingPathComponent("dv-p0b-paths-\(UUID().uuidString)")
        let evidence = runRoot.appendingPathComponent("hardware-raw/evidence", isDirectory: true)
        try fileManager.createDirectory(at: evidence, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: runRoot) }
        let valid = makeEnvironment(runRoot: runRoot.path), eventLog = evidence.appendingPathComponent("events.jsonl")
        try Data().write(to: eventLog, options: .withoutOverwriting); #expect(DevVlogsPhase0BConfiguration.resolve(environment: valid) != nil)
        _ = try DevVlogsPhase0BLaunch.makeHarness(environment: valid)
        var resolvedAlias = valid; resolvedAlias[DevVlogsPhase0BConfiguration.eventLogEnvironmentKey] =
            evidence.resolvingSymlinksInPath().appendingPathComponent("events.jsonl").path
        #expect(DevVlogsPhase0BConfiguration.resolve(environment: resolvedAlias) != nil)
        let parentAlias = runRoot.appendingPathComponent("event-parent-alias"); try fileManager.createSymbolicLink(at: parentAlias, withDestinationURL: evidence)
        var symlinkAlias = valid; symlinkAlias[DevVlogsPhase0BConfiguration.eventLogEnvironmentKey] =
            parentAlias.appendingPathComponent("events.jsonl").path
        #expect(DevVlogsPhase0BConfiguration.resolve(environment: symlinkAlias) != nil)
        func expectRejectedLeaf() {
            #expect(DevVlogsPhase0BConfiguration.resolveDiagnostically(environment: valid) == .failure(.eventLogPathMismatch))
            #expect(throws: DevVlogsPhase0BConfigurationFailureStage.self) { _ = try DevVlogsPhase0BLaunch.makeHarness(environment: valid) }
        }
        let foreignSentinel = runRoot.appendingPathComponent("foreign-sentinel"), sentinelBytes = Data("sentinel".utf8)
        try sentinelBytes.write(to: foreignSentinel, options: .withoutOverwriting); try fileManager.removeItem(at: eventLog)
        try fileManager.createSymbolicLink(at: eventLog, withDestinationURL: foreignSentinel)
        let foreignLink = try fileManager.destinationOfSymbolicLink(atPath: eventLog.path); expectRejectedLeaf(); #expect(try Data(contentsOf: foreignSentinel) == sentinelBytes); #expect(try fileManager.destinationOfSymbolicLink(atPath: eventLog.path) == foreignLink)
        try fileManager.removeItem(at: eventLog); let sameParentTarget = evidence.appendingPathComponent("same-parent-target")
        try sentinelBytes.write(to: sameParentTarget, options: .withoutOverwriting)
        try fileManager.createSymbolicLink(at: eventLog, withDestinationURL: sameParentTarget)
        let sameParentLink = try fileManager.destinationOfSymbolicLink(atPath: eventLog.path); expectRejectedLeaf(); #expect(try Data(contentsOf: sameParentTarget) == sentinelBytes); #expect(try fileManager.destinationOfSymbolicLink(atPath: eventLog.path) == sameParentLink)
        try fileManager.removeItem(at: eventLog); try fileManager.createDirectory(at: eventLog, withIntermediateDirectories: false)
        expectRejectedLeaf(); #expect(try eventLog.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true)
        try fileManager.removeItem(at: eventLog); #expect(DevVlogsPhase0BConfiguration.resolve(environment: valid) != nil)
        let foreign = runRoot.appendingPathComponent("foreign", isDirectory: true)
        try fileManager.createDirectory(at: foreign, withIntermediateDirectories: true)
        let escape = runRoot.appendingPathComponent("escape"); try fileManager.createSymbolicLink(
            at: escape, withDestinationURL: foreign)
        let rejectedEventPaths = [foreign.appendingPathComponent("events.jsonl").path,
            escape.appendingPathComponent("events.jsonl").path,
            evidence.appendingPathComponent("wrong.jsonl").path,
            evidence.appendingPathComponent("events.jsonl").path + "/", ""]
        for eventPath in rejectedEventPaths {
            var rejected = valid; rejected[DevVlogsPhase0BConfiguration.eventLogEnvironmentKey] = eventPath
            #expect(DevVlogsPhase0BConfiguration.resolveDiagnostically(environment: rejected) ==
                    .failure(.eventLogPathMismatch))
            #expect(throws: DevVlogsPhase0BConfigurationFailureStage.self) { _ = try
                DevVlogsPhase0BLaunch.makeHarness(environment: rejected) }
            #expect(!fileManager.fileExists(atPath: eventPath))
        }
        let cases: [(DevVlogsPhase0BConfigurationFailureStage, ([String: String]) -> [String: String])] = [
            (.isolationNotEnabled, { var value = $0; value.removeValue(forKey: DevVlogsPhase0BConfiguration.enabledEnvironmentKey); return value }),
            (.automationNotEnabled, { var value = $0; value[KeychainInteractionPolicy.automationEnvironmentKey] = "true"; return value }),
            (.keychainUINotSuppressed, { var value = $0; value[KeychainInteractionPolicy.authenticationUIEnvironmentKey] = "allow"; return value }),
            (.runRootMissing, { var value = $0; value.removeValue(forKey: DevVlogsPhase0BConfiguration.runRootEnvironmentKey); return value }),
            (.eventLogMissing, { var value = $0; value.removeValue(forKey: DevVlogsPhase0BConfiguration.eventLogEnvironmentKey); return value }),
            (.cameraIDMissing, { var value = $0; value[DevVlogsPhase0BConfiguration.cameraUniqueIDEnvironmentKey] = "  "; return value }),
            (.runRootOutsideTemporaryRoot, { _ in self.makeEnvironment(runRoot: "/not-temporary/archive") }),
            (.durationInvalid, { var value = $0; value[DevVlogsPhase0BConfiguration.durationEnvironmentKey] = "inf"; return value }),
            (.caseIDInvalid, { var value = $0; value[DevVlogsPhase0BConfiguration.caseIDEnvironmentKey] = "private/path"; return value }),
        ]
        for (stage, mutate) in cases {
            #expect(DevVlogsPhase0BConfiguration.resolveDiagnostically(
                environment: mutate(valid), temporaryRoot: temporaryRoot) == .failure(stage))
        }
        #expect(Set(cases.map(\.0)).union([.eventLogPathMismatch, .runPathsUnavailable, .unknown]) ==
                Set(DevVlogsPhase0BConfigurationFailureStage.allCases))
        #expect(DevVlogsPhase0BConfigurationFailureStage(error: NSError(domain: "private", code: 7)) == .unknown)
        #expect(DevVlogsPhase0BOperatorSummary.line(for: .failed(.invalidConfiguration)) ==
                "dev_vlogs_phase_0b result=failed category=invalid_configuration")
        var transportEnvironment = valid; transportEnvironment[DevVlogsPhase0BConfigurationDiagnostic.descriptorEnvironmentKey] = "3"
        var written = Data()
        #expect(DevVlogsPhase0BConfigurationDiagnostic.record(stage: .eventLogPathMismatch,
            environment: transportEnvironment, write: { written.append($0) }))
        #expect(String(decoding: written, as: UTF8.self) == DevVlogsPhase0BConfigurationDiagnostic.line(stage: .eventLogPathMismatch) + "\n")
        #expect(!String(decoding: written, as: UTF8.self).contains(runRoot.path))
        #expect(!DevVlogsPhase0BConfigurationDiagnostic.record(
            stage: .unknown, environment: valid, write: { _ in Issue.record("unexpected write") }
        ))
        let blockedRoot = FileManager.default.temporaryDirectory.appendingPathComponent("dv-p0b-configuration-\(UUID().uuidString)")
        try fileManager.createDirectory(at: blockedRoot.appendingPathComponent("hardware-raw/evidence"), withIntermediateDirectories: true); try fileManager.setAttributes([.posixPermissions: 0o500], ofItemAtPath: blockedRoot.path)
        defer { try? fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: blockedRoot.path); try? fileManager.removeItem(at: blockedRoot) }
        do { _ = try DevVlogsPhase0BLaunch.makeHarness(environment: makeEnvironment(runRoot: blockedRoot.path)); Issue.record("Expected run path preparation to fail") }
        catch { #expect(DevVlogsPhase0BConfigurationFailureStage(error: error) == .runPathsUnavailable) }
    }
    @Test func successfulFakeRunUsesOneAudioOwnerAndFinalizesExactlyOnce() async throws {
        let fixture = makeFixture()
        let outcome = await fixture.harness.run()
        guard case .ready = outcome else { Issue.record("Expected fake media to become ready"); return }
        #expect(fixture.audio.startCount == 1); #expect(fixture.audio.stopCount == 1)
        #expect(fixture.audio.cancelCount == 0); #expect(fixture.audio.preparedURL == fixture.paths.audioURL)
        #expect(fixture.camera.startCount == 1); #expect(fixture.camera.stopCount == 1)
        #expect(fixture.finalizer.callCount == 1); #expect(fixture.probe.expectations == [.cameraOnly, .finalized])
        #expect(fixture.preservation.callCount == 1)
        #expect(fixture.events.events.map(\.result) == [.started, .ready])
        #expect(await fixture.harness.run() == .failed(.alreadyRun))
        #expect(fixture.finalizer.callCount == 1)
        #expect(fixture.preservation.callCount == 1)
    }
    @Test func cameraFailureCancelsOnlyRunOwnedAudioAndSkipsMux() async {
        let fixture = makeFixture(cameraFailure: .preferredDeviceBusy)
        #expect(await fixture.harness.run() == .failed(.cameraStart(.cameraSelectionBusy)))
        #expect(fixture.audio.startCount == 1)
        #expect(fixture.audio.stopCount == 0)
        #expect(fixture.audio.cancelCount == 1)
        #expect(fixture.camera.cleanupCount == 1)
        #expect(fixture.finalizer.callCount == 0)
        #expect(fixture.probe.callCount == 0)
        #expect(fixture.preservation.callCount == 0)
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
            #expect(fixture.preservation.callCount == 0)
            #expect(fixture.events.events.filter { $0.action == "attempt_terminal" }.count == 1)
            #expect(fixture.events.events.last?.category == category)
            #expect(fixture.events.events.last?.category != .captureStop)
        }
    }
    @Test func passthroughAndPreservationFailuresNeverBecomeReady() async {
        let cases: [(HarnessFixture, DevVlogsPhase0BHarnessFailure)] = [
            (makeFixture(finalizerFailure: .passthroughIncompatible), .passthroughIncompatible),
            (makeFixture(finalizerFailure: .passthroughExportFailed), .passthroughExportFailed),
            (makeFixture(preservationFailure: .encodedPayloadMismatch),
             .videoPreservationFailed(.encodedPayloadMismatch)),
        ]
        for (fixture, expected) in cases {
            let outcome = await fixture.harness.run()
            #expect(outcome == .failed(expected))
            #expect(DevVlogsPhase0BOperatorSummary.line(for: outcome).contains(expected.category.rawValue))
            #expect(fixture.events.events.filter { $0.result == .ready }.isEmpty)
            #expect(fixture.events.events.filter { $0.action == "attempt_terminal" }.count == 1)
        }
        #expect(cases[0].0.probe.expectations == [.cameraOnly])
        #expect(cases[1].0.probe.expectations == [.cameraOnly])
        #expect(cases[2].0.probe.expectations == [.cameraOnly, .finalized])
        #expect(cases[2].0.preservation.callCount == 1)
        let terminal = cases[2].0.events.events.last
        #expect(terminal?.preservationFailureDimension == .encodedPayloadMismatch)
        #expect(terminal?.failureStageEvidence?.cameraProbePassed == true)
        #expect(terminal?.failureStageEvidence?.passthroughCompleted == true)
        #expect(terminal?.failureStageEvidence?.finalProbePassed == true)
        #expect(terminal?.failureStageEvidence?.cameraMediaSubtype == "avc1")
        #expect(terminal?.failureStageEvidence?.finalizedAudioMediaSubtype == "aac ")
        #expect(terminal?.metrics.contains { $0.name == "camera_width" } == true)
        #expect(DevVlogsPhase0BOperatorSummary.line(for: .failed(
            .videoPreservationFailed(.timedOut))).contains("result=timed_out"))
        #expect(await cases[2].0.harness.run() == .failed(.alreadyRun))
        #expect(cases[2].0.events.events.filter { $0.action == "attempt_terminal" }.count == 1)
    }
    @Test func cameraStartFailureUsesNaturalExitWithoutSelfCleanup() async {
        let fixture = makeFixture(cameraFailure: .permissionDenied)
        let outcome = await fixture.harness.run()
        #expect(outcome == .failed(.cameraStart(.cameraPermissionDenied)))
        #expect(
            DevVlogsPhase0BOperatorSummary.line(for: outcome) ==
                "dev_vlogs_phase_0b result=failed category=camera_permission_denied"
        )
        #expect(fixture.audio.cancelCount == 1)
        #expect(fixture.camera.cleanupCount == 1)
        #expect(fixture.events.events.filter { $0.action == "attempt_terminal" }.count == 1)
        #expect(fixture.events.events.last?.category == .cameraPermissionDenied)
    }
    @Test func naturalTerminationIsDeferredOnceAndExternalQuitWinsTheRace() throws {
        var pending: (@MainActor () -> Void)?
        var enqueueCount = 0
        let scheduler = DevVlogsPhase0BNaturalTerminationScheduler {
            enqueueCount += 1; pending = $0
        }
        var naturalRequests = 0
        scheduler.schedule { naturalRequests += 1 }
        scheduler.schedule { naturalRequests += 100 }
        #expect(enqueueCount == 1)
        #expect(naturalRequests == 0)
        pending?()
        #expect(naturalRequests == 1)
        let coordinator = DevVlogsPhase0BTerminationCoordinator(timeout: .seconds(35))
        var racedRequest: (@MainActor () -> Void)?
        let racedScheduler = DevVlogsPhase0BNaturalTerminationScheduler { racedRequest = $0 }
        #expect(coordinator.harnessDidComplete())
        racedScheduler.schedule {
            if coordinator.permitsNaturalTermination { naturalRequests += 1 }
        }
        #expect(coordinator.begin(cancelActive: {}, cleanup: {}, completion: { _ in }) == .terminateNow)
        racedRequest?()
        #expect(naturalRequests == 1)
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent("HoldType/Debug/DevVlogsPhase0B/DevVlogsPhase0BLaunch.swift"),
            encoding: .utf8
        )
        let start = try #require(source.range(of: "private func complete(line:"))
        let tail = source[start.lowerBound...]
        let end = try #require(tail.range(of: "func applicationShouldTerminate"))
        let completion = tail[..<end.lowerBound]
        let printLine = try #require(completion.range(of: "print(line)"))
        let clear = try #require(completion.range(of: "harnessTask = nil"))
        let transition = try #require(completion.range(of: "terminationCoordinator.harnessDidComplete()"))
        let schedule = try #require(completion.range(of: "naturalTerminationScheduler.schedule"))
        #expect(printLine.lowerBound < clear.lowerBound && clear.lowerBound < transition.lowerBound)
        #expect(transition.lowerBound < schedule.lowerBound && !completion.contains("harnessTask.value"))
    }
    @Test func applicationRouterConstructsNormalOnlyWithoutHardwareIntent() {
        var normalStarts = 0
        var harnessStarts = 0
        DevVlogsPhase0BLaunch.startApplication(
            environment: [:],
            startNormalApplication: { normalStarts += 1 }, startHarnessApplication: { harnessStarts += 1 })
        #expect(normalStarts == 1)
        #expect(harnessStarts == 0)
        for key in DevVlogsPhase0BConfiguration.hardwareIntentEnvironmentKeys {
            DevVlogsPhase0BLaunch.startApplication(
                environment: [key: "wrong"],
                startNormalApplication: { normalStarts += 1 }, startHarnessApplication: { harnessStarts += 1 })
        }
        #expect(normalStarts == 1)
        #expect(harnessStarts == DevVlogsPhase0BConfiguration.hardwareIntentEnvironmentKeys.count)
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
    private func makeEnvironment(runRoot: String) -> [String: String] {
        [
            DevVlogsPhase0BConfiguration.enabledEnvironmentKey: "1",
            DevVlogsPhase0BConfiguration.runRootEnvironmentKey: runRoot,
            DevVlogsPhase0BConfiguration.cameraUniqueIDEnvironmentKey: "sensitive-device-id",
            DevVlogsPhase0BConfiguration.durationEnvironmentKey: "10",
            DevVlogsPhase0BConfiguration.caseIDEnvironmentKey: "fake-success",
            DevVlogsPhase0BConfiguration.eventLogEnvironmentKey: "\(runRoot)/hardware-raw/evidence/events.jsonl",
            KeychainInteractionPolicy.automationEnvironmentKey: "1",
            KeychainInteractionPolicy.authenticationUIEnvironmentKey: KeychainInteractionPolicy.skipAuthenticationUIValue,
        ]
    }
    private func makeFixture(
        cameraFailure: DevVlogsPhase0BCameraCaptureError? = nil,
        stopFailure: DevVlogsPhase0BCameraCaptureError? = nil,
        finalizerFailure: DevVlogsPhase0BMediaFinalizerError? = nil,
        preservationFailure: DevVlogsPhase0BVideoPreservationError? = nil
    ) -> HarnessFixture {
        let root = URL(fileURLWithPath: "/tmp/phase0b-tests", isDirectory: true)
        let configuration = DevVlogsPhase0BConfiguration(
            runRoot: root, cameraUniqueID: "sensitive-device-id", duration: 10, caseID: "fake-success"
        )
        let paths = DevVlogsPhase0BRunPaths(
            runID: "run-1",
            runDirectory: root, mediaDirectory: root, eventLogURL: root.appendingPathComponent("events.jsonl"),
            audioURL: root.appendingPathComponent("audio.m4a"),
            videoURL: root.appendingPathComponent("video.mov"),
            finalURL: root.appendingPathComponent("final.mov")
        )
        let audio = Phase0BAudioRecorder()
        let camera = Phase0BCamera(failure: cameraFailure, stopFailure: stopFailure, videoURL: paths.videoURL)
        let finalizer = Phase0BFinalizer(error: finalizerFailure)
        let probe = Phase0BProbe()
        let preservation = Phase0BPreservation(error: preservationFailure)
        let events = Phase0BEvents()
        let harness = DevVlogsPhase0BHarness(
            configuration: configuration,
            paths: paths,
            audioRecorder: audio,
            cameraCapture: camera,
            finalizer: finalizer,
            probe: probe,
            preservation: preservation,
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
            preservation: preservation,
            events: events
        )
    }
}
@MainActor private final class Phase0BAudioRecorder: AudioRecorderService {
    var currentStatus = AudioRecorderStatus.idle
    var lastFinalizationReachedMaximumDuration = false
    let acceptsPreparedRecordingFileURL = true
    private(set) var startCount = 0, stopCount = 0, cancelCount = 0
    private(set) var preparedURL: URL?
    func startRecording(maximumDuration: TimeInterval) async throws {}
    func startRecording(maximumDuration: TimeInterval, outputFileURL: URL?) async throws {
        startCount += 1; preparedURL = outputFileURL; currentStatus = .recording
    }
    func stopRecording() async throws -> AudioRecordingArtifact {
        stopCount += 1
        let artifact = AudioRecordingArtifact(fileURL: preparedURL!, duration: 10, byteCount: 1_024)
        currentStatus = .finished(artifact: artifact); return artifact
    }
    func cancelRecording() { cancelCount += 1; currentStatus = .cancelled }
    func setAutomaticStopHandler(_ handler: AudioRecorderAutomaticStopHandler?) {}
}
@MainActor private final class Phase0BCamera: DevVlogsPhase0BCameraCapturing {
    let failure, stopFailure: DevVlogsPhase0BCameraCaptureError?
    let videoURL: URL
    private(set) var startCount = 0, stopCount = 0, cleanupCount = 0
    init(
        failure: DevVlogsPhase0BCameraCaptureError?,
        stopFailure: DevVlogsPhase0BCameraCaptureError?,
        videoURL: URL
    ) {
        self.failure = failure; self.stopFailure = stopFailure; self.videoURL = videoURL
    }
    func startCapture(_ request: DevVlogsPhase0BCameraCaptureRequest) async throws
        -> DevVlogsPhase0BCameraCaptureStart {
        startCount += 1
        if let failure { cleanupCount += 1; throw failure }
        return .init(requestMonotonicTime: 12, recordingStartMonotonicTime: 12.1,
                     deviceClass: .builtIn, redactedDeviceLabel: "built_in_camera")
    }
    func stopCapture() async throws -> DevVlogsPhase0BCameraCaptureArtifact {
        stopCount += 1
        if let stopFailure { throw stopFailure }
        return .init(fileURL: videoURL, requestMonotonicTime: 12,
                     recordingStartMonotonicTime: 12.1, firstFrameMonotonicTime: 12.2,
                     firstFramePresentationTime: 0, recordingStopMonotonicTime: 22)
    }
    func cancelCapture() async { cleanupCount += 1 }
}
@MainActor private final class Phase0BFinalizer: DevVlogsPhase0BMediaFinalizing {
    let error: DevVlogsPhase0BMediaFinalizerError?
    private(set) var callCount = 0
    init(error: DevVlogsPhase0BMediaFinalizerError? = nil) { self.error = error }
    func finalize(_ request: DevVlogsPhase0BMediaFinalizationRequest) async throws
        -> DevVlogsPhase0BMediaFinalization {
        callCount += 1; if let error { throw error }
        return .init(outputFileURL: request.outputFileURL, audioInsertionOffset: 0,
                     videoInsertionOffset: 0.1,
                     videoSampleTimestampOffset: CMTime(seconds: 0.1, preferredTimescale: 60_000))
    }
}
@MainActor private final class Phase0BProbe: DevVlogsPhase0BMediaProbing {
    private(set) var expectations: [DevVlogsPhase0BMediaProbeExpectation] = []
    var callCount: Int { expectations.count }
    func probe(fileURL: URL, expectation: DevVlogsPhase0BMediaProbeExpectation) async throws
        -> DevVlogsPhase0BMediaProbeResult {
        expectations.append(expectation)
        return phase0BValidProbeResult(audio: expectation == .finalized)
    }
}
@MainActor private final class Phase0BPreservation: DevVlogsPhase0BVideoPreserving {
    let error: DevVlogsPhase0BVideoPreservationError?
    private(set) var callCount = 0
    init(error: DevVlogsPhase0BVideoPreservationError? = nil) { self.error = error }
    func compare(_ request: DevVlogsPhase0BVideoPreservationRequest) async throws
        -> DevVlogsPhase0BVideoPreservationResult {
        callCount += 1; if let error { throw error }
        return .init(sampleCount: 300, encodedByteCount: 1_000_000, mediaSubtype: "avc1")
    }
}
@MainActor private final class Phase0BEvents {
    var events: [DevVlogsPhase0BEvent] = []
}
@MainActor private struct HarnessFixture {
    let harness: DevVlogsPhase0BHarness; let paths: DevVlogsPhase0BRunPaths
    let audio: Phase0BAudioRecorder
    let camera: Phase0BCamera
    let finalizer: Phase0BFinalizer; let probe: Phase0BProbe
    let preservation: Phase0BPreservation
    let events: Phase0BEvents
}
private func phase0BValidProbeResult(audio: Bool) -> DevVlogsPhase0BMediaProbeResult {
    let video = DevVlogsPhase0BMediaTrackProbe(
        codec: "avc1", formatDescription: "avc1:1280x720:descriptions_1",
        durationSeconds: 10, startTimestampSeconds: 0, endTimestampSeconds: 10,
        naturalDimensions: CGSize(width: 1_280, height: 720),
        displayDimensions: CGSize(width: 1_280, height: 720), nominalFrameRate: 30,
        derivedFrameRate: 30, estimatedDataRate: 2_000_000,
        preferredTransform: .identity, playable: true
    )
    return DevVlogsPhase0BMediaProbeResult(
        assetPlayable: true,
        video: video,
        audio: audio ? .init(
            codec: "aac ", formatDescription: "aac:audio:descriptions_1",
            durationSeconds: 10, startTimestampSeconds: 0, endTimestampSeconds: 10,
            naturalDimensions: nil, displayDimensions: nil, nominalFrameRate: nil,
            derivedFrameRate: nil, estimatedDataRate: 128_000,
            preferredTransform: nil, playable: true
        ) : nil
    )
}
#endif
