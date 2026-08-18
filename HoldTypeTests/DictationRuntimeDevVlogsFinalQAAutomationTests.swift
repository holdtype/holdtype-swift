import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct DictationRuntimeDevVlogsFinalQAAutomationTests {
    @Test func exactDoubleOptInIsRequired() {
        let enabled = [
            "HOLDTYPE_AUTOMATION": "1",
            DevVlogsFinalQAAutomation.optInEnvironmentKey:
                DevVlogsFinalQAAutomation.optInEnvironmentValue,
        ]

        #expect(DevVlogsFinalQAAutomation.isEnabled(environment: enabled))
        #expect(!DevVlogsFinalQAAutomation.isEnabled(environment: [:]))
        #expect(
            !DevVlogsFinalQAAutomation.isEnabled(
                environment: [
                    DevVlogsFinalQAAutomation.optInEnvironmentKey:
                        DevVlogsFinalQAAutomation.optInEnvironmentValue,
                ]
            )
        )
        #expect(
            !DevVlogsFinalQAAutomation.isEnabled(
                environment: [
                    "HOLDTYPE_AUTOMATION": "1",
                    DevVlogsFinalQAAutomation.optInEnvironmentKey: "1",
                ]
            )
        )
    }

    @Test func ordinaryCompositionReturnsNoAutomationOwners() {
        #expect(
            DevVlogsFinalQAAutomation.makeControllerIfEnabled(
                environment: ["HOLDTYPE_AUTOMATION": "1"]
            ) == nil
        )
        #expect(
            DevVlogsFinalQAAutomation.makeRecordingSetupPreflightIfEnabled(
                environment: [
                    DevVlogsFinalQAAutomation.optInEnvironmentKey:
                        DevVlogsFinalQAAutomation.optInEnvironmentValue,
                ]
            ) == nil
        )
    }

    @Test func windowRequestUsesTheSameExactGate() {
        var actions: [String] = []
        let ordinaryRequested = DevVlogsFinalQAAutomation.requestWindowIfEnabled(
            environment: ["HOLDTYPE_AUTOMATION": "1"],
            activateApplication: { actions.append("activate") },
            openWindow: { actions.append("open") }
        )
        #expect(!ordinaryRequested)
        #expect(actions.isEmpty)

        let finalQARequested = DevVlogsFinalQAAutomation.requestWindowIfEnabled(
            environment: [
                "HOLDTYPE_AUTOMATION": "1",
                DevVlogsFinalQAAutomation.optInEnvironmentKey:
                    DevVlogsFinalQAAutomation.optInEnvironmentValue,
            ],
            activateApplication: { actions.append("activate") },
            openWindow: { actions.append("open") }
        )
        #expect(finalQARequested)
        #expect(actions == ["activate", "open"])
    }

    @Test func deterministicOwnersNeverNeedKeychainOrNetwork() async throws {
        let credential = try DevVlogsFinalQACredentialResolver().resolveOpenAICredential()
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        try Data([0]).write(to: audioURL)
        defer { try? FileManager.default.removeItem(at: audioURL) }

        let transcriptionRequest = try AppSettings.defaults.audioTranscriptionRequest(
            audioFileURL: audioURL,
            context: nil
        )
        let transcript = try await DevVlogsFinalQATranscriptionService().transcribe(
            transcriptionRequest,
            credential: credential
        )
        let acceptedTranscript = try AcceptedTranscript(rawText: transcript)
        let correctionRequest = TextCorrectionRequest(
            acceptedTranscript: acceptedTranscript,
            correctionConfiguration: TextCorrectionConfiguration(isEnabled: true),
            postProcessingConfiguration: TranscriptPostProcessingConfiguration()
        )
        let corrected = try await DevVlogsFinalQATextCorrectionService().correct(
            correctionRequest,
            credential: credential
        )
        let output = try await DevVlogsFinalQATranscriptOutput().deliver(
            OutputDeliveryRequest(
                acceptedTranscript: acceptedTranscript,
                preferences: OutputDeliveryPreferences(
                    automaticInsertionPreferenceEnabled: true,
                    keepLatestResult: true
                )
            )
        )

        #expect(transcript == "Dev Vlogs final QA marker")
        #expect(corrected == transcript)
        #expect(output == .skipped(reason: .outputDisabled))
    }
}
