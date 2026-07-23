import Foundation
import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypePersistence

extension IOSForegroundVoiceProcessor {
    /// Runs a provider-only action against an existing app-private Draft. This
    /// shares the Voice processor's operation gate but never creates Pending,
    /// transcription usage, Latest, or History state.
    @_spi(HoldTypeIOSCore)
    public func processDraftText(
        _ request: IOSVoiceDraftTextActionRequest
    ) async -> IOSVoiceDraftTextActionResolution {
        let action = switch request.action {
        case .translate:
            TextFixCatalog.defaults.actions[0]
        case .correct:
            TextFixCatalog.defaults.actions[1]
        }
        return await processDraftTextFix(
            IOSVoiceDraftTextFixRequest(
                action: action,
                text: request.text,
                settings: request.settings,
                credential: request.credential,
                consentObservation: request.consentObservation
            )
        )
    }

    /// Runs one typed or custom catalog Fix without touching durable Voice
    /// recovery, accepted-output, History, or Usage state.
    @_spi(HoldTypeIOSCore)
    public func processDraftTextFix(
        _ request: IOSVoiceDraftTextFixRequest
    ) async -> IOSVoiceDraftTextActionResolution {
        guard activeOperationID == nil else { return .failure(.busy) }
        guard !request.text.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return .failure(.invalidText)
        }
        guard request.text.utf8.count
                <= TextTransformationRequest.maximumSourceUTF8ByteCount else {
            return .failure(.sourceTooLarge)
        }
        guard let authorization = consentCoordinator.makeAuthorization(
            from: request.consentObservation
        ) else {
            return .failure(.consentUnavailable)
        }
        if request.action.kind == .translate,
           !request.settings.translationConfiguration.isConfigurationReady {
            return .failure(.invalidConfiguration)
        }

        let operationID = UUID()
        activeOperationID = operationID
        defer {
            if activeOperationID == operationID {
                activeOperationID = nil
            }
        }

        let outcome = await runDraftTextFix(
            request,
            authorization: authorization
        )
        guard activeOperationID == operationID, !Task.isCancelled else {
            return .failure(.cancelled)
        }
        return outcome
    }

    private func runDraftTextFix(
        _ request: IOSVoiceDraftTextFixRequest,
        authorization: IOSV1ProviderConsentAuthorization
    ) async -> IOSVoiceDraftTextActionResolution {
        let provider = provider
        let credential = request.credential.credential
        let outcome: IOSProviderConsentStageOutcome<
            String,
            IOSForegroundVoiceProviderFailure
        >

        switch request.action.kind {
        case .fix:
            guard let source = try? AcceptedTranscript(
                rawText: request.text
            ) else {
                return .failure(.invalidText)
            }
            var configuration = request.settings.textCorrectionConfiguration
            configuration.isEnabled = true
            let correctionConfiguration = configuration
            outcome = await stageExecutor.execute(
                authorization,
                for: .correction,
                operation: {
                    try AcceptedTranscript(
                        rawText: try await provider.correct(
                            source,
                            correctionConfiguration,
                            credential
                        )
                    ).text
                },
                normalizeFailure: {
                    IOSForegroundVoiceProviderFailureMapper.correction($0)
                }
            )
        case .translate:
            guard let source = try? AcceptedTranscript(
                rawText: request.text
            ) else {
                return .failure(.invalidText)
            }
            let translationRequest = TextTranslationRequest(
                acceptedTranscript: source,
                translationConfiguration:
                    request.settings.translationConfiguration,
                transcriptionConfiguration:
                    request.settings.transcriptionConfiguration
            )
            outcome = await stageExecutor.execute(
                authorization,
                for: .translation,
                operation: {
                    try AcceptedTranscript(
                        rawText: try await provider.translate(
                            translationRequest,
                            credential
                        )
                    ).text
                },
                normalizeFailure: {
                    IOSForegroundVoiceProviderFailureMapper.translation($0)
                }
            )
        case .customPrompt:
            guard let prompt = request.action.prompt else {
                return .failure(.invalidConfiguration)
            }
            let transformationRequest: TextTransformationRequest
            do {
                transformationRequest = try TextTransformationRequest(
                    sourceText: request.text,
                    prompt: prompt,
                    model: request.settings.textCorrectionConfiguration
                        .resolvedModel
                )
            } catch {
                return .failure(.invalidConfiguration)
            }
            outcome = await stageExecutor.execute(
                authorization,
                for: .correction,
                operation: {
                    try await provider.transform(
                        transformationRequest,
                        credential
                    )
                },
                normalizeFailure: {
                    IOSForegroundVoiceProviderFailureMapper
                        .transformation($0)
                }
            )
        }

        switch outcome {
        case .success(let result):
            return acceptedDraftTextFixResult(
                result,
                source: request.text,
                action: request.action,
                settings: request.settings
            )
        case .failure(let failure):
            if failure == .credentialRejected {
                await recordProviderRejection(request.credential.generation)
            }
            return .failure(Self.draftTextActionFailure(from: failure))
        case .cancelled:
            return .failure(.cancelled)
        case .authorizationUnavailable:
            return .failure(.consentUnavailable)
        }
    }

    private func acceptedDraftTextFixResult(
        _ result: String,
        source: String,
        action: TextFixAction,
        settings: IOSAppSettings
    ) -> IOSVoiceDraftTextActionResolution {
        if action.kind == .customPrompt {
            guard !result.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty else {
                return .failure(.invalidResponse)
            }
            return .success(result)
        }
        guard let acceptedResult = try? AcceptedTranscript(rawText: result),
              let acceptedSource = try? AcceptedTranscript(rawText: source)
        else {
            return .failure(.invalidResponse)
        }
        if action.kind == .fix,
           !Self.isSafeCorrection(
               original: acceptedSource.text,
               corrected: acceptedResult.text
           ) {
            return .success(acceptedSource.text)
        }
        guard action.kind == .translate,
              settings.localTextCleanupEnabled else {
            return .success(acceptedResult.text)
        }
        let normalized = TranscriptTextPostProcessor
            .normalizedInformalTypography(
                from: acceptedResult.text,
                fallback: acceptedResult.text
            )
        guard let accepted = try? AcceptedTranscript(rawText: normalized) else {
            return .failure(.invalidResponse)
        }
        return .success(accepted.text)
    }

    private static func draftTextActionFailure(
        from failure: IOSForegroundVoiceProviderFailure
    ) -> IOSVoiceDraftTextActionFailure {
        switch failure {
        case .credentialMissing, .credentialUnavailable, .credentialRejected:
            .credentialUnavailable
        case .networkUnavailable:
            .networkUnavailable
        case .timedOut:
            .timedOut
        case .invalidRequest, .invalidTranslationRoute:
            .invalidConfiguration
        case .invalidResponse, .emptyResult, .dictionaryEcho, .contextEcho:
            .invalidResponse
        case .cancelled:
            .cancelled
        case .networkFailure, .rateLimited, .providerUnavailable,
             .badRequest, .providerRejected, .unknown:
            .providerUnavailable
        case .invalidRecording, .multipartMetadataTooLarge:
            .invalidResponse
        }
    }

    static func isSafeCorrection(
        original: String,
        corrected: String
    ) -> Bool {
        guard let normalized = AcceptedTranscript.nonEmptyNormalizedText(
            from: corrected
        ) else {
            return false
        }
        guard original.count >= 20 else { return true }
        return normalized.count >= max(1, original.count / 3)
            && normalized.count <= original.count * 3
    }
}
