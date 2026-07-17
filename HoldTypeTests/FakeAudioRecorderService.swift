//
//  FakeAudioRecorderService.swift
//  HoldTypeTests
//
//  Created by Codex on 6/20/26.
//

import Foundation
import HoldTypeDomain
@testable import HoldType

final class FakeAudioRecorderService: AudioRecorderService {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private(set) var cancelCount = 0
    private(set) var requestedMaximumDurations: [TimeInterval] = []
    private(set) var currentStatus: AudioRecorderStatus
    private(set) var lastFinalizationReachedMaximumDuration = false
    private var automaticStopHandler: AudioRecorderAutomaticStopHandler?

    var startResult: Result<Void, AudioRecorderServiceError>
    var stopResult: Result<AudioRecordingArtifact, AudioRecorderServiceError>
    var cancelStatus: AudioRecorderStatus
    private let beforeStop: (() async -> Void)?
    private let stopFinalizationReachedMaximumDuration: Bool

    init(
        currentStatus: AudioRecorderStatus = .idle,
        startResult: Result<Void, AudioRecorderServiceError> = .success(()),
        stopResult: Result<AudioRecordingArtifact, AudioRecorderServiceError> = .success(
            AudioRecordingArtifact(
                fileURL: URL(fileURLWithPath: "/tmp/holdtype-fake-recording.m4a"),
                duration: 1.2,
                byteCount: 1024
            )
        ),
        cancelStatus: AudioRecorderStatus = .cancelled,
        beforeStop: (() async -> Void)? = nil,
        stopFinalizationReachedMaximumDuration: Bool = false
    ) {
        self.currentStatus = currentStatus
        self.startResult = startResult
        self.stopResult = stopResult
        self.cancelStatus = cancelStatus
        self.beforeStop = beforeStop
        self.stopFinalizationReachedMaximumDuration =
            stopFinalizationReachedMaximumDuration
    }

    func startRecording(maximumDuration: TimeInterval) async throws {
        startCount += 1
        requestedMaximumDurations.append(maximumDuration)
        lastFinalizationReachedMaximumDuration = false

        do {
            try startResult.get()
            currentStatus = .recording
        } catch let error as AudioRecorderServiceError {
            currentStatus = .failed(message: error.errorDescription ?? error.localizedDescription)
            throw error
        }
    }

    func stopRecording() async throws -> AudioRecordingArtifact {
        stopCount += 1
        await beforeStop?()
        lastFinalizationReachedMaximumDuration =
            stopFinalizationReachedMaximumDuration

        do {
            let artifact = try stopResult.get()
            currentStatus = .finished(artifact: artifact)
            return artifact
        } catch let error as AudioRecorderServiceError {
            currentStatus = .failed(message: error.errorDescription ?? error.localizedDescription)
            throw error
        }
    }

    func cancelRecording() {
        cancelCount += 1
        lastFinalizationReachedMaximumDuration = false
        currentStatus = cancelStatus
    }

    func setAutomaticStopHandler(_ handler: AudioRecorderAutomaticStopHandler?) {
        automaticStopHandler = handler
    }

    @MainActor
    func simulateAutomaticStop(
        _ result: Result<AudioRecorderAutomaticCompletion, AudioRecorderServiceError>
    ) {
        switch result {
        case .success(let completion):
            currentStatus = .finished(artifact: completion.artifact)
            lastFinalizationReachedMaximumDuration =
                completion.reason == .maximumDuration
        case .failure(let error):
            currentStatus = .failed(message: error.errorDescription ?? error.localizedDescription)
            lastFinalizationReachedMaximumDuration = false
        }

        automaticStopHandler?(result)
    }
}
