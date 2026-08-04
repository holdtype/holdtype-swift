//
//  RecordingFinalizationFailureTests.swift
//  HoldTypeTests
//

import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct RecordingFinalizationFailureTests {
    @Test func missingRecordingFileReturnsToReadyWithoutRecoveryControls() async throws {
        let recorder = FakeAudioRecorderService(
            stopResult: .failure(.missingRecordingFile)
        )
        let controller = DictationSessionController(
            recorder: recorder,
            settingsProvider: { .defaults },
            credentialResolverForUngatedActions: nil
        )
        let credential = try OpenAICredential(apiKey: "sk-finalization-failure-test")

        await controller.performRecordingAction(credential: credential)
        #expect(controller.status == .recording)

        await controller.performRecordingAction(credential: credential)

        #expect(controller.status == .idle)
        #expect(controller.outputStatusText == nil)
        #expect(controller.failurePresentation == nil)
        #expect(recorder.stopCount == 1)

        await controller.performRecordingAction(credential: credential)

        #expect(controller.status == .recording)
        #expect(recorder.startCount == 2)
    }

    @Test func subSecondRecordingReturnsToReadyWithoutRecoveryControls() async throws {
        let recorder = FakeAudioRecorderService(
            stopResult: .failure(.recordingTooShort(duration: 0.99, minimumDuration: 1))
        )
        let controller = DictationSessionController(
            recorder: recorder,
            settingsProvider: { .defaults },
            credentialResolverForUngatedActions: nil
        )
        let credential = try OpenAICredential(apiKey: "sk-short-recording-test")

        await controller.performRecordingAction(credential: credential)
        await controller.performRecordingAction(credential: credential)

        #expect(controller.status == .idle)
        #expect(controller.outputStatusText == nil)
        #expect(controller.failurePresentation == nil)
        #expect(recorder.stopCount == 1)
    }

    @Test func subSecondRecordingDeletesOnlyItsPreparedCapture() async throws {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-short-capture-\(UUID().uuidString)",
            isDirectory: true
        )
        defer { try? FileManager.default.removeItem(at: rootURL) }

        let recorder = PreparedShortRecordingRecorder()
        let recovery = FakeTranscriptionFailureRecovery()
        let controller = DictationSessionController(
            recorder: recorder,
            settingsProvider: { .defaults },
            transcriptionFailureRecovery: recovery,
            recordingCaptureJournal: RecordingCaptureJournal(
                directoryURL: rootURL.appendingPathComponent("Active", isDirectory: true),
                releasedDirectoryURL: rootURL.appendingPathComponent("Released", isDirectory: true)
            ),
            credentialResolverForUngatedActions: nil
        )
        let credential = try OpenAICredential(apiKey: "sk-short-capture-cleanup-test")

        await controller.performRecordingAction(credential: credential)
        let outputFileURL = try #require(recorder.outputFileURL)
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path))

        await controller.performRecordingAction(credential: credential)

        #expect(controller.status == .idle)
        #expect(controller.failurePresentation == nil)
        #expect(recovery.failedAttempts.isEmpty)
        #expect(FileManager.default.fileExists(atPath: outputFileURL.path) == false)
    }
}

private final class PreparedShortRecordingRecorder: AudioRecorderService {
    private(set) var currentStatus: AudioRecorderStatus = .idle
    private(set) var outputFileURL: URL?
    let acceptsPreparedRecordingFileURL = true
    let lastFinalizationReachedMaximumDuration = false

    func startRecording(maximumDuration: TimeInterval) async throws {
        throw AudioRecorderServiceError.temporaryFileUnavailable
    }

    func startRecording(
        maximumDuration: TimeInterval,
        outputFileURL: URL?
    ) async throws {
        guard let outputFileURL else {
            throw AudioRecorderServiceError.temporaryFileUnavailable
        }

        try Data("short capture".utf8).write(to: outputFileURL)
        self.outputFileURL = outputFileURL
        currentStatus = .recording
    }

    func stopRecording() async throws -> AudioRecordingArtifact {
        currentStatus = .failed(
            message: AudioRecorderServiceError.recordingTooShort(
                duration: 0.99,
                minimumDuration: 1
            ).errorDescription ?? ""
        )
        throw AudioRecorderServiceError.recordingTooShort(duration: 0.99, minimumDuration: 1)
    }

    func cancelRecording() {
        currentStatus = .cancelled
    }

    func setAutomaticStopHandler(_ handler: AudioRecorderAutomaticStopHandler?) {}
}
