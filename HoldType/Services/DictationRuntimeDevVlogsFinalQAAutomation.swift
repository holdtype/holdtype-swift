import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

enum DevVlogsFinalQAAutomation {
    static let optInEnvironmentKey = "HOLDTYPE_DEV_VLOGS_FINAL_QA"
    static let optInEnvironmentValue = "camera-to-publish"

    static func isEnabled(environment: [String: String]) -> Bool {
        environment["HOLDTYPE_AUTOMATION"] == "1"
            && environment[optInEnvironmentKey] == optInEnvironmentValue
    }

    @MainActor
    @discardableResult
    static func requestWindowIfEnabled(
        environment: [String: String],
        activateApplication: () -> Void,
        openWindow: () -> Void
    ) -> Bool {
        guard isEnabled(environment: environment) else {
            return false
        }

        activateApplication()
        openWindow()
        return true
    }

    @MainActor
    static func makeControllerIfEnabled(
        environment: [String: String]
    ) -> DictationSessionController? {
        guard isEnabled(environment: environment) else {
            return nil
        }

        return DictationSessionController(
            transcriptionService: DevVlogsFinalQATranscriptionService(),
            textCorrectionService: DevVlogsFinalQATextCorrectionService(),
            translationService: DevVlogsFinalQATranslationService(),
            transcriptOutput: DevVlogsFinalQATranscriptOutput(),
            credentialResolverForUngatedActions: DevVlogsFinalQACredentialResolver()
        )
    }

    static func makeRecordingSetupPreflightIfEnabled(
        environment: [String: String]
    ) -> RecordingSetupPreflight? {
        guard isEnabled(environment: environment) else {
            return nil
        }

        return RecordingSetupPreflight(
            credentialResolver: DevVlogsFinalQACredentialResolver()
        )
    }
}

struct DevVlogsFinalQACredentialResolver: OpenAICredentialResolving {
    func resolveOpenAICredential() throws -> OpenAICredential {
        try OpenAICredential(apiKey: "holdtype-final-qa-no-network")
    }
}

struct DevVlogsFinalQATranscriptionService: OpenAITranscriptionServing {
    func transcribe(
        _ request: AudioTranscriptionRequest,
        credential: OpenAICredential
    ) async throws -> String {
        "Dev Vlogs final QA marker"
    }
}

struct DevVlogsFinalQATextCorrectionService: TextCorrectionServing {
    func correct(
        _ request: TextCorrectionRequest,
        credential: OpenAICredential
    ) async throws -> String {
        request.acceptedTranscript.text
    }

    func cancelActiveCorrection() {}
}

struct DevVlogsFinalQATranslationService: TranscriptTranslationServing {
    func translate(
        _ request: TextTranslationRequest,
        credential: OpenAICredential
    ) async throws -> String {
        request.acceptedTranscript.text
    }

    func cancelActiveTranslation() {}
}

struct DevVlogsFinalQATranscriptOutput: TranscriptOutputDelivering {
    func deliver(_ request: OutputDeliveryRequest) async throws -> TextInsertionResult {
        .skipped(reason: .outputDisabled)
    }
}
