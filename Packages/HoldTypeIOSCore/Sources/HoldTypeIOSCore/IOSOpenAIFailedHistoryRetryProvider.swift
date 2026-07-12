import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) import HoldTypePersistence

struct IOSOpenAIFailedHistoryRetryProviderBuilder:
    IOSFailedHistoryRetryProviderBuilding {
    typealias Transcribe = @Sendable (
        AudioTranscriptionRequest,
        OpenAICredential
    ) async throws -> String
    typealias Correct = @Sendable (
        AcceptedTranscript,
        TextCorrectionConfiguration,
        OpenAICredential
    ) async throws -> String
    typealias Translate = @Sendable (
        TextTranslationRequest,
        OpenAICredential
    ) async throws -> String

    private let materializer: IOSFailedHistoryRetryAudioMaterializer
    private let transcribe: Transcribe
    private let correct: Correct
    private let translate: Translate

    init() {
        let transcriptionService = OpenAITranscriptionService()
        let correctionService = OpenAITextCorrectionService()
        let translationService = OpenAITextTranslationService()
        self.init(
            materializer: IOSFailedHistoryRetryAudioMaterializer(),
            transcribe: { request, credential in
                try await transcriptionService.transcribe(
                    request,
                    credential: credential
                )
            },
            correct: { transcript, configuration, credential in
                try await correctionService.correct(
                    transcript,
                    configuration: configuration,
                    credential: credential
                )
            },
            translate: { request, credential in
                try await translationService.translate(
                    request,
                    credential: credential
                )
            }
        )
    }

    init(
        materializer: IOSFailedHistoryRetryAudioMaterializer,
        transcribe: @escaping Transcribe,
        correct: @escaping Correct,
        translate: @escaping Translate
    ) {
        self.materializer = materializer
        self.transcribe = transcribe
        self.correct = correct
        self.translate = translate
    }

    func makeFailedHistoryRetryProvider(
        credential: IOSResolvedOpenAICredential
    ) async -> any IOSFailedHistoryRetryProviderExecuting {
        IOSOpenAIFailedHistoryRetryProvider(
            credential: credential.credential,
            materializer: materializer,
            transcribe: transcribe,
            correct: correct,
            translate: translate
        )
    }
}

struct IOSOpenAIFailedHistoryRetryProvider:
    IOSFailedHistoryRetryProviderExecuting {
    private let credential: OpenAICredential
    private let materializer: IOSFailedHistoryRetryAudioMaterializer
    private let transcribeOperation:
        IOSOpenAIFailedHistoryRetryProviderBuilder.Transcribe
    private let correctOperation:
        IOSOpenAIFailedHistoryRetryProviderBuilder.Correct
    private let translateOperation:
        IOSOpenAIFailedHistoryRetryProviderBuilder.Translate

    init(
        credential: OpenAICredential,
        materializer: IOSFailedHistoryRetryAudioMaterializer,
        transcribe: @escaping IOSOpenAIFailedHistoryRetryProviderBuilder
            .Transcribe,
        correct: @escaping IOSOpenAIFailedHistoryRetryProviderBuilder.Correct,
        translate: @escaping IOSOpenAIFailedHistoryRetryProviderBuilder
            .Translate
    ) {
        self.credential = credential
        self.materializer = materializer
        transcribeOperation = transcribe
        correctOperation = correct
        translateOperation = translate
    }

    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        do {
            let configuration = TranscriptionConfiguration(
                model: request.resolvedModel,
                language: request.resolvedLanguageCode == nil
                    ? .automatic
                    : .custom,
                customLanguageCode: request.resolvedLanguageCode ?? ""
            )
            let text = try await materializer.withMaterializedAudio(
                request.audio
            ) { fileURL in
                let providerRequest = try AudioTranscriptionRequest(
                    audioFileURL: fileURL,
                    transcriptionConfiguration: configuration,
                    promptComposition: request.promptComposition
                )
                return try await transcribeOperation(
                    providerRequest,
                    credential
                )
            }
            return .success(text)
        } catch {
            return .failure(Self.transcriptionFailure(for: error))
        }
    }

    func correct(
        _ request: IOSFailedHistoryRetryCorrectionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        do {
            return .success(
                try await correctOperation(
                    request.transcript,
                    request.configuration,
                    credential
                )
            )
        } catch {
            return .failure(Self.correctionFailure(for: error))
        }
    }

    func translate(
        _ request: IOSFailedHistoryRetryTranslationRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        do {
            return .success(
                try await translateOperation(
                    request.translationRequest,
                    credential
                )
            )
        } catch {
            return .failure(Self.translationFailure(for: error))
        }
    }

    static func transcriptionFailure(
        for error: any Error
    ) -> IOSFailedHistoryRetryRuntimeFailure {
        if error is CancellationError { return .cancelled }
        if error is IOSFailedHistoryRetryAudioMaterializationError {
            return .invalidRecording
        }
        guard let error = error as? OpenAITranscriptionServiceError else {
            return .unknown
        }
        return switch error {
        case .missingAPIKey: .credentialMissing
        case .apiKeyUnavailable: .credentialUnavailable
        case .invalidAPIKey: .credentialRejected
        case .networkUnavailable: .networkUnavailable
        case .networkFailure: .networkFailure
        case .timedOut: .timedOut
        case .rateLimited: .rateLimited
        case .providerUnavailable: .providerUnavailable
        case .badRequest: .badRequest
        case .providerRejected: .providerRejected
        case .invalidResponse: .invalidResponse
        case .emptyTranscript: .emptyResult
        case .dictionaryEcho: .dictionaryEcho
        case .contextEcho: .contextEcho
        case .invalidRecording: .invalidRecording
        case .invalidRequest: .invalidRequest
        case .multipartMetadataTooLarge: .multipartMetadataTooLarge
        case .cancelled: .cancelled
        }
    }

    static func correctionFailure(
        for error: any Error
    ) -> IOSFailedHistoryRetryRuntimeFailure {
        if error is CancellationError { return .cancelled }
        guard let error = error as? OpenAITextCorrectionServiceError else {
            return .unknown
        }
        return switch error {
        case .missingAPIKey: .credentialMissing
        case .apiKeyUnavailable: .credentialUnavailable
        case .invalidAPIKey: .credentialRejected
        case .networkUnavailable: .networkUnavailable
        case .networkFailure: .networkFailure
        case .timedOut: .timedOut
        case .rateLimited: .rateLimited
        case .providerUnavailable: .providerUnavailable
        case .badRequest: .badRequest
        case .providerRejected: .providerRejected
        case .invalidResponse: .invalidResponse
        case .emptyCorrection: .emptyResult
        case .invalidRequest: .invalidRequest
        case .cancelled: .cancelled
        }
    }

    static func translationFailure(
        for error: any Error
    ) -> IOSFailedHistoryRetryRuntimeFailure {
        if error is CancellationError { return .cancelled }
        guard let error = error as? OpenAITextTranslationServiceError else {
            return .unknown
        }
        return switch error {
        case .missingAPIKey: .credentialMissing
        case .apiKeyUnavailable: .credentialUnavailable
        case .invalidAPIKey: .credentialRejected
        case .networkUnavailable: .networkUnavailable
        case .networkFailure: .networkFailure
        case .timedOut: .timedOut
        case .rateLimited: .rateLimited
        case .providerUnavailable: .providerUnavailable
        case .badRequest: .badRequest
        case .providerRejected: .providerRejected
        case .invalidResponse: .invalidResponse
        case .emptyTranslation: .emptyResult
        case .invalidLanguageConfiguration: .invalidTranslationRoute
        case .invalidRequest: .invalidRequest
        case .cancelled: .cancelled
        }
    }
}

extension IOSFailedHistoryRetryAudioMaterializationError:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSFailedHistoryRetryAudioMaterializationError(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSOpenAIFailedHistoryRetryProvider:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSOpenAIFailedHistoryRetryProvider(redacted)"
    }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
