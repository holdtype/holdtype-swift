import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
import Testing
@testable import HoldType

@MainActor
struct TextFixExecutionServiceTests {
    @Test func translateUsesSavedTypedRouteEvenWhenShortcutIsOff() async throws {
        let translation = FakeFixTranslationService(output: "  Bonjour  ")
        let service = makeService(translation: translation)
        var settings = AppSettings.defaults
        settings.translationShortcutEnabled = false
        settings.translationTargetLanguage = .french
        settings.translationModel = "translation-model"
        settings.translationPrompt = "Translation instructions"

        let output = try await service.execute(
            action: TextFixCatalog.defaults.actions[0],
            sourceText: "  Hello  ",
            settings: settings,
            credential: credential
        )

        #expect(output == "Bonjour")
        #expect(translation.requests.count == 1)
        let request = try #require(translation.requests.first)
        #expect(request.acceptedTranscript.text == "Hello")
        #expect(request.translationConfiguration.resolvedModel == "translation-model")
        #expect(
            request.translationConfiguration.resolvedPrompt
                == "Translation instructions"
        )
    }

    @Test func translateRejectsAnUnresolvedRouteBeforeProviderWork() async {
        let translation = FakeFixTranslationService(output: "ignored")
        let service = makeService(translation: translation)

        await #expect(throws: TranslationConfigurationIssue.missingTargetLanguage) {
            try await service.execute(
                action: TextFixCatalog.defaults.actions[0],
                sourceText: "Hello",
                settings: .defaults,
                credential: credential
            )
        }
        #expect(translation.requests.isEmpty)
    }

    @Test func fixForcesSavedCorrectionConfigurationWithoutChangingSettings() async throws {
        let correction = FakeFixCorrectionService(output: "  Corrected  ")
        let service = makeService(correction: correction)
        var settings = AppSettings.defaults
        settings.textCorrectionEnabled = false
        settings.textCorrectionModelPreset = .custom
        settings.customTextCorrectionModel = "correction-model"
        settings.textCorrectionPrompt = "Correction instructions"

        let output = try await service.execute(
            action: TextFixCatalog.defaults.actions[1],
            sourceText: "  Source  ",
            settings: settings,
            credential: credential
        )

        #expect(output == "Corrected")
        #expect(!settings.textCorrectionEnabled)
        let call = try #require(correction.calls.first)
        #expect(call.transcript.text == "Source")
        #expect(call.configuration.isEnabled)
        #expect(call.configuration.resolvedModel == "correction-model")
        #expect(call.configuration.resolvedPrompt == "Correction instructions")
    }

    @Test func customFixPreservesExactSourcePromptAndOutput() async throws {
        let transformation = FakeFixTransformationService(
            output: "\n- one\n- two\n"
        )
        let service = makeService(transformation: transformation)
        var settings = AppSettings.defaults
        settings.textCorrectionModelPreset = .custom
        settings.customTextCorrectionModel = "custom-model"
        let action = try #require(
            TextFixCatalog.defaults.action(id: "default.bullet-points")
        )

        let output = try await service.execute(
            action: action,
            sourceText: "  one, two  ",
            settings: settings,
            credential: credential
        )

        #expect(output == "\n- one\n- two\n")
        let request = try #require(transformation.requests.first)
        #expect(request.sourceText == "  one, two  ")
        #expect(request.prompt == action.prompt)
        #expect(request.model == "custom-model")
    }

    @Test func cancellationFansOutToEveryProvider() {
        let translation = FakeFixTranslationService(output: "translation")
        let correction = FakeFixCorrectionService(output: "correction")
        let transformation = FakeFixTransformationService(output: "transform")
        let service = makeService(
            translation: translation,
            correction: correction,
            transformation: transformation
        )

        service.cancelActiveExecution()

        #expect(translation.cancelCount == 1)
        #expect(correction.cancelCount == 1)
        #expect(transformation.cancelCount == 1)
    }

    private var credential: OpenAICredential {
        get throws {
            try OpenAICredential(apiKey: "test-key")
        }
    }

    private func makeService(
        translation: FakeFixTranslationService? = nil,
        correction: FakeFixCorrectionService? = nil,
        transformation: FakeFixTransformationService? = nil
    ) -> TextFixExecutionService {
        TextFixExecutionService(
            translationService: translation
                ?? FakeFixTranslationService(output: "translation"),
            correctionService: correction
                ?? FakeFixCorrectionService(output: "correction"),
            transformationService: transformation
                ?? FakeFixTransformationService(output: "transform")
        )
    }
}

@MainActor
private final class FakeFixTranslationService: TranscriptTranslationServing {
    let output: String
    private(set) var requests: [TextTranslationRequest] = []
    private(set) var cancelCount = 0

    init(output: String) {
        self.output = output
    }

    func translate(
        _ request: TextTranslationRequest,
        credential: OpenAICredential
    ) async throws -> String {
        requests.append(request)
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cancelActiveTranslation() {
        cancelCount += 1
    }
}

@MainActor
private final class FakeFixCorrectionService: OpenAITextCorrectionServing {
    struct Call {
        let transcript: AcceptedTranscript
        let configuration: TextCorrectionConfiguration
    }

    let output: String
    private(set) var calls: [Call] = []
    private(set) var cancelCount = 0

    init(output: String) {
        self.output = output
    }

    func correct(
        _ transcript: AcceptedTranscript,
        configuration: TextCorrectionConfiguration,
        credential: OpenAICredential
    ) async throws -> String {
        calls.append(
            Call(
                transcript: transcript,
                configuration: configuration
            )
        )
        return output
    }

    func cancelActiveCorrection() {
        cancelCount += 1
    }
}

@MainActor
private final class FakeFixTransformationService:
    OpenAITextTransformationServing {
    let output: String
    private(set) var requests: [TextTransformationRequest] = []
    private(set) var cancelCount = 0

    init(output: String) {
        self.output = output
    }

    func transform(
        _ request: TextTransformationRequest,
        credential: OpenAICredential
    ) async throws -> String {
        requests.append(request)
        return output
    }

    func cancelActiveTransformation() {
        cancelCount += 1
    }
}
