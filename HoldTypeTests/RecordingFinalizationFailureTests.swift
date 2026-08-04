//
//  RecordingFinalizationFailureTests.swift
//  HoldTypeTests
//

import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct RecordingFinalizationFailureTests {
    @Test func missingRecordingFileReturnsToReadyWithOneSimpleMessage() async throws {
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
        #expect(controller.outputStatusText == "Couldn't transcribe the recording.")
        #expect(controller.failurePresentation == nil)
        #expect(recorder.stopCount == 1)

        await controller.performRecordingAction(credential: credential)

        #expect(controller.status == .recording)
        #expect(recorder.startCount == 2)
    }
}
