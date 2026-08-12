import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

@MainActor
protocol TextFixExecuting {
    func execute(
        action: TextFixAction,
        sourceText: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String
    func cancelActiveExecution()
}

@MainActor
struct TextFixExecutionService: TextFixExecuting {
    private let translationService: any TranscriptTranslationServing
    private let correctionService: any OpenAITextCorrectionServing
    private let transformationService: any OpenAITextTransformationServing

    init(
        translationService: (any TranscriptTranslationServing)? = nil,
        correctionService: (any OpenAITextCorrectionServing)? = nil,
        transformationService: (any OpenAITextTransformationServing)? = nil
    ) {
        self.translationService = translationService
            ?? TranscriptTranslationService(
                openAITextTranslationService: OpenAITextTranslationService(
                    usageReporter: OpenAIUsageStore.reporter(for: .translation)
                )
            )
        self.correctionService = correctionService
            ?? OpenAITextCorrectionService(
                usageReporter: OpenAIUsageStore.reporter(for: .textCorrection)
            )
        self.transformationService = transformationService
            ?? OpenAITextTransformationService(
                usageReporter: OpenAIUsageStore.reporter(for: .fixes)
            )
    }

    func execute(
        action: TextFixAction,
        sourceText: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        switch action.kind {
        case .translate:
            return try await translate(
                sourceText,
                settings: settings,
                credential: credential
            )
        case .fix:
            return try await fix(
                sourceText,
                settings: settings,
                credential: credential
            )
        case .customPrompt:
            return try await transform(
                sourceText,
                action: action,
                settings: settings,
                credential: credential
            )
        }
    }

    func cancelActiveExecution() {
        translationService.cancelActiveTranslation()
        correctionService.cancelActiveCorrection()
        transformationService.cancelActiveTransformation()
    }

    private func translate(
        _ sourceText: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        if let issue = settings.translationConfiguration.routeConfigurationIssue {
            throw issue
        }

        let request = TextTranslationRequest(
            acceptedTranscript: try AcceptedTranscript(rawText: sourceText),
            translationConfiguration: settings.translationConfiguration,
            transcriptionConfiguration: settings.transcriptionConfiguration
        )
        return try await translationService.translate(
            request,
            credential: credential
        )
    }

    private func fix(
        _ sourceText: String,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        let savedConfiguration = settings.textCorrectionConfiguration
        let forcedConfiguration = TextCorrectionConfiguration(
            isEnabled: true,
            modelPreset: savedConfiguration.modelPreset,
            customModel: savedConfiguration.customModel,
            prompt: savedConfiguration.prompt
        )
        let output = try await correctionService.correct(
            try AcceptedTranscript(rawText: sourceText),
            configuration: forcedConfiguration,
            credential: credential
        )
        guard let normalizedOutput = AcceptedTranscript.nonEmptyNormalizedText(
            from: output
        ) else {
            throw OpenAITextCorrectionServiceError.emptyCorrection
        }
        return normalizedOutput
    }

    private func transform(
        _ sourceText: String,
        action: TextFixAction,
        settings: AppSettings,
        credential: OpenAICredential
    ) async throws -> String {
        guard let prompt = action.prompt else {
            throw TextFixExecutionError.missingCustomPrompt
        }
        let processing = action.processingProfile.resolved(
            inheritedModel: settings.resolvedTextCorrectionModel
        )
        if action.usesBuiltInWritingSkill,
           !TextFixWritingSkillCompatibility.supports(model: processing.model) {
            throw TextFixExecutionError.unsupportedBuiltInWritingSkillModel
        }
        let request = try TextTransformationRequest(
            sourceText: sourceText,
            prompt: prompt,
            model: processing.model,
            reasoningEffort: processing.reasoningEffort,
            usesBuiltInWritingSkill: action.usesBuiltInWritingSkill,
            requestTimeoutSeconds: processing.requestTimeoutSeconds
        )
        return try await transformationService.transform(
            request,
            credential: credential
        )
    }
}

enum TextFixExecutionError: Error, Equatable, LocalizedError {
    case missingCustomPrompt
    case unsupportedBuiltInWritingSkillModel

    var errorDescription: String? {
        switch self {
        case .missingCustomPrompt:
            "This Fix is missing its instruction."
        case .unsupportedBuiltInWritingSkillModel:
            "The selected model does not support HoldType’s built-in writing skill."
        }
    }
}
