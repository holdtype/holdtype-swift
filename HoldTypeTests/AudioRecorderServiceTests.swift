//
//  AudioRecorderServiceTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/20/26.
//

import AVFoundation
import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct AudioRecorderServiceTests {

    @Test func defaultMaximumDurationUsesThePortableUtteranceContract() {
        #expect(
            AVFoundationAudioRecorderService.defaultMaximumRecordingDuration ==
                VoiceSessionPreferences.maximumUtteranceDuration
        )
        #expect(AVFoundationAudioRecorderService.defaultMaximumRecordingDuration == 300)
    }

    @Test func statusExposesRecordingState() {
        let artifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/holdtype-test.m4a"),
            duration: 1.2,
            byteCount: 512
        )

        #expect(AudioRecorderStatus.idle.isRecording == false)
        #expect(AudioRecorderStatus.recording.isRecording)
        #expect(AudioRecorderStatus.finished(artifact: artifact).isRecording == false)
        #expect(AudioRecorderStatus.cancelled.isRecording == false)
    }

    @Test func fakeRecorderTracksSuccessfulLifecycle() async throws {
        let artifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/holdtype-success.m4a"),
            duration: 1.4,
            byteCount: 2048
        )
        let recorder = FakeAudioRecorderService(stopResult: .success(artifact))

        #expect(recorder.currentStatus == .idle)

        try await recorder.startRecording()
        #expect(recorder.currentStatus == .recording)

        let stoppedArtifact = try await recorder.stopRecording()

        #expect(stoppedArtifact == artifact)
        #expect(recorder.currentStatus == .finished(artifact: artifact))
        #expect(recorder.startCount == 1)
        #expect(recorder.stopCount == 1)
        #expect(recorder.cancelCount == 0)
    }

    @Test func fakeRecorderCanSimulateStartFailure() async {
        let recorder = FakeAudioRecorderService(
            startResult: .failure(.recordingUnavailable)
        )

        do {
            try await recorder.startRecording()
            Issue.record("Expected startRecording to throw")
        } catch let error as AudioRecorderServiceError {
            #expect(error == .recordingUnavailable)
        } catch {
            Issue.record("Expected AudioRecorderServiceError, got \(error)")
        }

        #expect(
            recorder.currentStatus == .failed(
                message: AudioRecorderServiceError.recordingUnavailable.errorDescription ?? ""
            )
        )
        #expect(recorder.startCount == 1)
        #expect(recorder.stopCount == 0)
    }

    @Test func fakeRecorderCanSimulateStopFailure() async throws {
        let recorder = FakeAudioRecorderService(stopResult: .failure(.stopFailed))

        try await recorder.startRecording()

        do {
            _ = try await recorder.stopRecording()
            Issue.record("Expected stopRecording to throw")
        } catch let error as AudioRecorderServiceError {
            #expect(error == .stopFailed)
        } catch {
            Issue.record("Expected AudioRecorderServiceError, got \(error)")
        }

        #expect(
            recorder.currentStatus == .failed(
                message: AudioRecorderServiceError.stopFailed.errorDescription ?? ""
            )
        )
        #expect(recorder.startCount == 1)
        #expect(recorder.stopCount == 1)
    }

    @Test func fakeRecorderCanCancelCurrentRecording() async throws {
        let recorder = FakeAudioRecorderService()

        try await recorder.startRecording()
        recorder.cancelRecording()

        #expect(recorder.currentStatus == .cancelled)
        #expect(recorder.cancelCount == 1)
    }

    @Test func appCodeCanDependOnRecorderProtocol() async throws {
        let artifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/tmp/holdtype-protocol.m4a"),
            duration: 0.8,
            byteCount: 300
        )
        let recorder = FakeAudioRecorderService(stopResult: .success(artifact))
        let consumer = RecorderConsumer(recorder: recorder)

        let result = try await consumer.recordOnce()

        #expect(result == artifact)
        #expect(recorder.currentStatus == .finished(artifact: artifact))
    }

    @Test func avFoundationRecorderRejectsStartWhenMicrophoneIsNotAllowed() async {
        let factory = CapturingAudioRecorderEngineFactory()
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .denied },
            recorderFactory: factory,
            makeRecordingFileURL: { URL(fileURLWithPath: "/tmp/holdtype-denied.m4a") }
        )

        do {
            try await recorder.startRecording()
            Issue.record("Expected startRecording to throw")
        } catch let error as AudioRecorderServiceError {
            #expect(error == .microphonePermissionDenied)
        } catch {
            Issue.record("Expected AudioRecorderServiceError, got \(error)")
        }

        #expect(factory.makeRecorderCallCount == 0)
        #expect(
            recorder.currentStatus == .failed(
                message: AudioRecorderServiceError.microphonePermissionDenied.errorDescription ?? ""
            )
        )
    }

    @Test func avFoundationRecorderReturnsCompletedArtifactMetadata() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let fileContents = Data([0x01, 0x02, 0x03, 0x04])
        let engine = FakeAudioRecorderEngine(currentTime: 1.7)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            maximumRecordingDuration: 2.5,
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()

        #expect(recorder.currentStatus == .recording)
        #expect(factory.makeRecorderCallCount == 1)
        #expect(factory.outputFileURL == outputFileURL)
        #expect(factory.settings?[AVFormatIDKey] as? Int == Int(kAudioFormatMPEG4AAC))
        #expect(factory.settings?[AVNumberOfChannelsKey] as? Int == 1)
        #expect(engine.recordCallCount == 1)
        #expect(engine.requestedRecordDuration == 2.5)
        #expect(engine.isRecording)

        try fileContents.write(to: outputFileURL)

        let artifact = try await recorder.stopRecording()

        #expect(artifact.fileURL == outputFileURL)
        #expect(artifact.duration == 1.7)
        #expect(artifact.byteCount == Int64(fileContents.count))
        #expect(recorder.currentStatus == .finished(artifact: artifact))
        #expect(engine.stopCallCount == 1)
    }

    @Test func avFoundationRecorderRejectsParallelStartWithoutLosingRecordingState() async throws {
        let outputFileURL = URL(fileURLWithPath: "/tmp/holdtype-parallel.m4a")
        let factory = CapturingAudioRecorderEngineFactory()
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            makeRecordingFileURL: { outputFileURL }
        )

        try await recorder.startRecording()

        do {
            try await recorder.startRecording()
            Issue.record("Expected second startRecording to throw")
        } catch let error as AudioRecorderServiceError {
            #expect(error == .alreadyRecording)
        } catch {
            Issue.record("Expected AudioRecorderServiceError, got \(error)")
        }

        #expect(factory.makeRecorderCallCount == 1)
        #expect(recorder.currentStatus == .recording)
    }

    @Test func avFoundationRecorderDeletesPreparedFileWhenEngineCannotStart() async {
        let engine = FakeAudioRecorderEngine(recordResult: false)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            makeRecordingFileURL: { URL(fileURLWithPath: "/tmp/holdtype-start-failure.m4a") }
        )

        do {
            try await recorder.startRecording()
            Issue.record("Expected startRecording to throw")
        } catch let error as AudioRecorderServiceError {
            #expect(error == .startFailed)
        } catch {
            Issue.record("Expected AudioRecorderServiceError, got \(error)")
        }

        #expect(factory.makeRecorderCallCount == 1)
        #expect(engine.recordCallCount == 1)
        #expect(engine.deleteCallCount == 1)
        #expect(
            recorder.currentStatus == .failed(
                message: AudioRecorderServiceError.startFailed.errorDescription ?? ""
            )
        )
    }

    @Test func avFoundationRecorderCancelStopsAndDeletesOnlyActiveFile() async throws {
        let activeFileURL = makeTemporaryRecordingFileURL()
        let unrelatedFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine()
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            makeRecordingFileURL: { activeFileURL }
        )
        defer { try? FileManager.default.removeItem(at: activeFileURL) }
        defer { try? FileManager.default.removeItem(at: unrelatedFileURL) }

        try await recorder.startRecording()
        try Data([0x01]).write(to: activeFileURL)
        try Data([0x02]).write(to: unrelatedFileURL)

        recorder.cancelRecording()

        #expect(recorder.currentStatus == .cancelled)
        #expect(engine.stopCallCount == 1)
        #expect(engine.deleteCallCount == 1)
        #expect(FileManager.default.fileExists(atPath: activeFileURL.path) == false)
        #expect(FileManager.default.fileExists(atPath: unrelatedFileURL.path))
    }

    @Test func avFoundationRecorderCancelWithoutActiveFileDoesNotDeleteUnrelatedFiles() async throws {
        let unrelatedFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine()
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            makeRecordingFileURL: { makeTemporaryRecordingFileURL() }
        )
        defer { try? FileManager.default.removeItem(at: unrelatedFileURL) }

        try Data([0x01]).write(to: unrelatedFileURL)

        recorder.cancelRecording()

        #expect(recorder.currentStatus == .cancelled)
        #expect(engine.stopCallCount == 0)
        #expect(engine.deleteCallCount == 0)
        #expect(FileManager.default.fileExists(atPath: unrelatedFileURL.path))
    }

    @Test func avFoundationRecorderRejectsMissingCompletedFile() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 1.0)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            makeRecordingFileURL: { outputFileURL }
        )

        try await recorder.startRecording()

        do {
            _ = try await recorder.stopRecording()
            Issue.record("Expected stopRecording to throw")
        } catch let error as AudioRecorderServiceError {
            #expect(error == .missingRecordingFile)
        } catch {
            Issue.record("Expected AudioRecorderServiceError, got \(error)")
        }

        #expect(engine.stopCallCount == 1)
        #expect(engine.deleteCallCount == 1)
        #expect(
            recorder.currentStatus == .failed(
                message: AudioRecorderServiceError.missingRecordingFile.errorDescription ?? ""
            )
        )
    }

    @Test func avFoundationRecorderRejectsEmptyCompletedFile() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 1.0)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data().write(to: outputFileURL)

        do {
            _ = try await recorder.stopRecording()
            Issue.record("Expected stopRecording to throw")
        } catch let error as AudioRecorderServiceError {
            #expect(error == .emptyRecording)
        } catch {
            Issue.record("Expected AudioRecorderServiceError, got \(error)")
        }

        #expect(engine.stopCallCount == 1)
        #expect(engine.deleteCallCount == 1)
        #expect(
            recorder.currentStatus == .failed(
                message: AudioRecorderServiceError.emptyRecording.errorDescription ?? ""
            )
        )
    }

    @Test func avFoundationRecorderPreservesPositiveFileWhenDurationLooksTooShort() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0.1)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            minimumRecordingDuration: 0.5,
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01]).write(to: outputFileURL)

        let artifact = try await recorder.stopRecording()

        #expect(engine.stopCallCount == 1)
        #expect(engine.deleteCallCount == 0)
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path))
        #expect(artifact.fileURL == outputFileURL)
        #expect(artifact.duration == 0.1)
        #expect(artifact.byteCount == 1)
        #expect(recorder.currentStatus == .finished(artifact: artifact))
    }

    @Test func avFoundationRecorderAcceptsCompletedFileAtHardCaptureLimit() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 2.0)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            maximumRecordingDuration: 2.0,
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01]).write(to: outputFileURL)

        let artifact = try await recorder.stopRecording()

        #expect(artifact.duration == 2.0)
        #expect(engine.stopCallCount == 1)
        #expect(engine.deleteCallCount == 0)
        #expect(recorder.currentStatus == .finished(artifact: artifact))
    }

    @Test func avFoundationRecorderUsesFinalizedMediaDurationAfterEngineAutoStops() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let fileContents = Data([0x01, 0x02, 0x03])
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            maximumRecordingDuration: 300,
            finalizedMediaDurationProvider: { _ in 300.416 },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try fileContents.write(to: outputFileURL)
        engine.simulateAutomaticFinish(successfully: true)

        let result = await withCheckedContinuation { continuation in
            recorder.setAutomaticStopHandler { result in
                continuation.resume(returning: result)
            }
            engine.replayLastAutomaticFinish()
        }
        let completion = try result.get()
        let artifact = completion.artifact

        #expect(artifact.fileURL == outputFileURL)
        #expect(artifact.duration == 300.416)
        #expect(artifact.byteCount == Int64(fileContents.count))
        #expect(completion.reason == .maximumDuration)
        #expect(engine.stopCallCount == 0)
        #expect(engine.deleteCallCount == 0)
        #expect(recorder.currentStatus == .finished(artifact: artifact))
    }

    @Test func manualStopAfterEngineAutoStopsUsesFinalizedMediaDuration() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            maximumRecordingDuration: 300,
            finalizedMediaDurationProvider: { _ in 300.25 },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01]).write(to: outputFileURL)
        engine.simulateAutomaticFinish(successfully: true)

        let artifact = try await recorder.stopRecording()

        #expect(artifact.duration == 300.25)
        #expect(engine.stopCallCount == 1)
        #expect(engine.deleteCallCount == 0)
        #expect(recorder.currentStatus == .finished(artifact: artifact))
    }

    @Test func manualStopPublishesMaximumIdentityBeforeAnyDelegateHandler() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        var monotonicTime: TimeInterval = 100
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: CapturingAudioRecorderEngineFactory(engine: engine),
            maximumRecordingDuration: 300,
            finalizedMediaDurationProvider: { _ in 0 },
            monotonicClock: { monotonicTime },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01, 0x02]).write(to: outputFileURL)
        monotonicTime = 399.6

        let artifact = try await recorder.stopRecording()

        #expect(artifact.duration == 0)
        #expect(recorder.lastFinalizationReachedMaximumDuration)
        #expect(engine.stopCallCount == 1)
    }

    @Test func manualStopJoinsArtifactAfterAutomaticCallbackAlreadyCompleted() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: CapturingAudioRecorderEngineFactory(engine: engine),
            maximumRecordingDuration: 300,
            finalizedMediaDurationProvider: { _ in 300.4 },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01, 0x02]).write(to: outputFileURL)

        let automaticCompletion: AudioRecorderAutomaticCompletion = try await withCheckedThrowingContinuation {
            continuation in
            recorder.setAutomaticStopHandler { result in
                continuation.resume(with: result)
            }
            engine.simulateAutomaticFinish(successfully: true)
            engine.replayLastAutomaticFinish()
        }
        let manualArtifact = try await recorder.stopRecording()

        #expect(manualArtifact == automaticCompletion.artifact)
        #expect(engine.stopCallCount == 0)
        #expect(engine.deleteCallCount == 0)
    }

    @Test func unsuccessfulAutomaticFinishAtLimitStillUsesMaximumDurationAuthority() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        var monotonicTime: TimeInterval = 10
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: CapturingAudioRecorderEngineFactory(engine: engine),
            maximumRecordingDuration: 300,
            finalizedMediaDurationProvider: { _ in 300.2 },
            monotonicClock: { monotonicTime },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01, 0x02]).write(to: outputFileURL)
        monotonicTime = 310

        let completion = try await automaticCompletion(
            from: recorder,
            engine: engine,
            successfully: false
        )

        #expect(completion.reason == .maximumDuration)
        #expect(completion.recorderReportedSuccess == false)
        #expect(recorder.lastFinalizationReachedMaximumDuration)
        #expect(completion.artifact.fileURL == outputFileURL)
        #expect(completion.artifact.byteCount == 2)
        #expect(engine.deleteCallCount == 0)
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path))
    }

    @Test func unsuccessfulEarlyAutomaticFinishRemainsUnexpected() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        var monotonicTime: TimeInterval = 100
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: CapturingAudioRecorderEngineFactory(engine: engine),
            maximumRecordingDuration: 300,
            finalizedMediaDurationProvider: { _ in 20 },
            monotonicClock: { monotonicTime },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01]).write(to: outputFileURL)
        monotonicTime = 120

        let completion = try await automaticCompletion(
            from: recorder,
            engine: engine,
            successfully: false
        )

        #expect(
            completion.reason == .unexpected(recorderReportedSuccess: false)
        )
        #expect(completion.recorderReportedSuccess == false)
        #expect(recorder.lastFinalizationReachedMaximumDuration == false)
        #expect(engine.deleteCallCount == 0)
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path))
    }

    @Test func successfulEarlyAutomaticFinishIsUnexpected() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        var monotonicTime: TimeInterval = 100
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: CapturingAudioRecorderEngineFactory(engine: engine),
            maximumRecordingDuration: 300,
            finalizedMediaDurationProvider: { _ in 20 },
            monotonicClock: { monotonicTime },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01]).write(to: outputFileURL)
        monotonicTime = 120

        let completion = try await automaticCompletion(
            from: recorder,
            engine: engine,
            successfully: true
        )

        #expect(
            completion.reason == .unexpected(recorderReportedSuccess: true)
        )
        #expect(engine.deleteCallCount == 0)
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path))
    }

    @Test func successfulAutomaticFinishAtMonotonicDeadlineIsMaximumDuration() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        var monotonicTime: TimeInterval = 50
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: CapturingAudioRecorderEngineFactory(engine: engine),
            maximumRecordingDuration: 300,
            finalizedMediaDurationProvider: { _ in 20 },
            monotonicClock: { monotonicTime },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01]).write(to: outputFileURL)
        monotonicTime = 350

        let completion = try await automaticCompletion(
            from: recorder,
            engine: engine,
            successfully: true
        )

        #expect(completion.reason == .maximumDuration)
        #expect(engine.deleteCallCount == 0)
    }

    @Test func finalizedMediaDurationTimeoutFallsBackWithoutWaitingForProviderCancellation() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 12.5)
        let durationProvider = ControlledFinalizedMediaDurationProvider()
        let timeoutProbe = FinalizedMediaDurationTimeoutProbe()
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: CapturingAudioRecorderEngineFactory(engine: engine),
            finalizedMediaDurationProvider: { _ in
                await durationProvider.loadIgnoringCancellation()
            },
            finalizedMediaDurationTimeout: 2,
            finalizedMediaDurationTimeoutSleeper: { seconds in
                await durationProvider.waitUntilLoadStarted()
                timeoutProbe.record(seconds)
            },
            makeRecordingFileURL: { outputFileURL }
        )
        defer {
            durationProvider.resolve(with: 99)
            try? FileManager.default.removeItem(at: outputFileURL)
        }

        try await recorder.startRecording()
        try Data([0x01, 0x02, 0x03]).write(to: outputFileURL)

        let artifact = try await recorder.stopRecording()

        #expect(timeoutProbe.recordedDurations == [2])
        #expect(artifact.duration == 12.5)
        #expect(artifact.byteCount == 3)
        #expect(engine.deleteCallCount == 0)
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path))
    }

    @Test func staleAutomaticFinishCannotFinalizeANewerAttempt() async throws {
        let firstFileURL = makeTemporaryRecordingFileURL()
        let secondFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 1)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        var nextFileURL = firstFileURL
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            finalizedMediaDurationProvider: { _ in 1 },
            makeRecordingFileURL: {
                defer { nextFileURL = secondFileURL }
                return nextFileURL
            }
        )
        defer { try? FileManager.default.removeItem(at: firstFileURL) }
        defer { try? FileManager.default.removeItem(at: secondFileURL) }

        try await recorder.startRecording()
        let staleFinishHandler = try #require(engine.recordingFinishedHandlers.first)
        recorder.cancelRecording()

        try await recorder.startRecording()
        try Data([0x01]).write(to: secondFileURL)
        staleFinishHandler(true)
        await Task.yield()

        #expect(recorder.currentStatus == .recording)
        #expect(engine.deleteCallCount == 1)

        recorder.cancelRecording()
    }

    @Test func avFoundationRecorderReturnsPositiveFileDespiteDurationOverrun() async throws {
        let outputFileURL = makeTemporaryRecordingFileURL()
        let engine = FakeAudioRecorderEngine(currentTime: 0)
        let factory = CapturingAudioRecorderEngineFactory(engine: engine)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            recorderFactory: factory,
            maximumRecordingDuration: 2,
            finalizedMediaDurationProvider: { _ in 4.001 },
            makeRecordingFileURL: { outputFileURL }
        )
        defer { try? FileManager.default.removeItem(at: outputFileURL) }

        try await recorder.startRecording()
        try Data([0x01]).write(to: outputFileURL)

        let artifact = try await recorder.stopRecording()

        #expect(engine.stopCallCount == 1)
        #expect(engine.deleteCallCount == 0)
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path))
        #expect(artifact.fileURL == outputFileURL)
        #expect(artifact.duration == 4.001)
        #expect(artifact.byteCount == 1)
        #expect(recorder.currentStatus == .finished(artifact: artifact))
    }
}

private struct RecorderConsumer {
    let recorder: any AudioRecorderService

    func recordOnce() async throws -> AudioRecordingArtifact {
        try await recorder.startRecording()
        return try await recorder.stopRecording()
    }
}

private final class CapturingAudioRecorderEngineFactory: AudioRecorderEngineFactory {
    private let engine: FakeAudioRecorderEngine

    private(set) var makeRecorderCallCount = 0
    private(set) var outputFileURL: URL?
    private(set) var settings: [String: Any]?

    init(engine: FakeAudioRecorderEngine = FakeAudioRecorderEngine()) {
        self.engine = engine
    }

    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any]
    ) throws -> any AudioRecorderEngine {
        makeRecorderCallCount += 1
        self.outputFileURL = outputFileURL
        self.settings = settings
        return engine
    }
}

private final class FakeAudioRecorderEngine: AudioRecorderEngine {
    private let recordResult: Bool

    private(set) var isRecording = false
    let currentTime: TimeInterval
    private(set) var recordCallCount = 0
    private(set) var requestedRecordDuration: TimeInterval?
    private(set) var stopCallCount = 0
    private(set) var deleteCallCount = 0
    private var recordingFinishedHandler: ((Bool) -> Void)?
    private var lastAutomaticFinishWasSuccessful = true
    private(set) var recordingFinishedHandlers: [(Bool) -> Void] = []

    init(recordResult: Bool = true, currentTime: TimeInterval = 1.0) {
        self.recordResult = recordResult
        self.currentTime = currentTime
    }

    func record() -> Bool {
        record(forDuration: .infinity)
    }

    func record(forDuration duration: TimeInterval) -> Bool {
        recordCallCount += 1
        requestedRecordDuration = duration
        isRecording = recordResult
        return recordResult
    }

    func stop() {
        stopCallCount += 1
        isRecording = false
    }

    func deleteRecording() -> Bool {
        deleteCallCount += 1
        return true
    }

    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) {
        recordingFinishedHandler = handler
        if let handler {
            recordingFinishedHandlers.append(handler)
        }
    }

    func simulateAutomaticFinish(successfully: Bool) {
        isRecording = false
        lastAutomaticFinishWasSuccessful = successfully
    }

    func replayLastAutomaticFinish() {
        recordingFinishedHandler?(lastAutomaticFinishWasSuccessful)
    }
}

private func makeTemporaryRecordingFileURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("holdtype-test-recording-\(UUID().uuidString)")
        .appendingPathExtension("m4a")
}

@MainActor
private func automaticCompletion(
    from recorder: AVFoundationAudioRecorderService,
    engine: FakeAudioRecorderEngine,
    successfully: Bool
) async throws -> AudioRecorderAutomaticCompletion {
    try await withCheckedThrowingContinuation { continuation in
        recorder.setAutomaticStopHandler { result in
            continuation.resume(with: result)
        }
        engine.simulateAutomaticFinish(successfully: successfully)
        engine.replayLastAutomaticFinish()
    }
}

nonisolated private final class ControlledFinalizedMediaDurationProvider: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<TimeInterval, Never>?
    private var loadStartedContinuations: [CheckedContinuation<Void, Never>] = []
    private var didStartLoading = false
    private var resolvedDuration: TimeInterval?

    func loadIgnoringCancellation() async -> TimeInterval {
        signalLoadStarted()
        return await withCheckedContinuation { continuation in
            let immediateDuration = lock.withLock { () -> TimeInterval? in
                if let resolvedDuration {
                    return resolvedDuration
                }

                precondition(self.continuation == nil)
                self.continuation = continuation
                return nil
            }
            if let immediateDuration {
                continuation.resume(returning: immediateDuration)
            }
        }
    }

    func waitUntilLoadStarted() async {
        await withCheckedContinuation { continuation in
            let didStartLoading = lock.withLock { () -> Bool in
                if self.didStartLoading {
                    return true
                }

                loadStartedContinuations.append(continuation)
                return false
            }
            if didStartLoading {
                continuation.resume()
            }
        }
    }

    func resolve(with duration: TimeInterval) {
        let continuation = lock.withLock { () -> CheckedContinuation<TimeInterval, Never>? in
            guard resolvedDuration == nil else {
                return nil
            }

            resolvedDuration = duration
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(returning: duration)
    }

    private func signalLoadStarted() {
        let continuations = lock.withLock {
            didStartLoading = true
            defer { loadStartedContinuations.removeAll() }
            return loadStartedContinuations
        }
        continuations.forEach { $0.resume() }
    }
}

nonisolated private final class FinalizedMediaDurationTimeoutProbe: @unchecked Sendable {
    private let lock = NSLock()
    private var durations: [TimeInterval] = []

    var recordedDurations: [TimeInterval] {
        lock.withLock { durations }
    }

    func record(_ duration: TimeInterval) {
        lock.withLock {
            durations.append(duration)
        }
    }
}
