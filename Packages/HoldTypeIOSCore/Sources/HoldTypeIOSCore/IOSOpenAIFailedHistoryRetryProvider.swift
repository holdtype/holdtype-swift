import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) import HoldTypePersistence

struct IOSOpenAIFailedHistoryRetryProviderBuilder:
    IOSFailedHistoryRetryProviderBuilding {
    typealias Transcribe = @Sendable (
        OpenAIReaderTranscriptionRequest,
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

    private let transcribe: Transcribe
    private let correct: Correct
    private let translate: Translate

    init() {
        let transcriptionService = OpenAITranscriptionService()
        let correctionService = OpenAITextCorrectionService()
        let translationService = OpenAITextTranslationService()
        self.init(
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
        transcribe: @escaping Transcribe,
        correct: @escaping Correct,
        translate: @escaping Translate
    ) {
        self.transcribe = transcribe
        self.correct = correct
        self.translate = translate
    }

    func makeFailedHistoryRetryProvider(
        credential: IOSResolvedOpenAICredential
    ) async -> any IOSFailedHistoryRetryProviderExecuting {
        IOSOpenAIFailedHistoryRetryProvider(
            credential: credential.credential,
            transcribe: transcribe,
            correct: correct,
            translate: translate
        )
    }
}

struct IOSOpenAIFailedHistoryRetryProvider:
    IOSFailedHistoryRetryProviderExecuting {
    private let credential: OpenAICredential
    private let transcribeOperation:
        IOSOpenAIFailedHistoryRetryProviderBuilder.Transcribe
    private let correctOperation:
        IOSOpenAIFailedHistoryRetryProviderBuilder.Correct
    private let translateOperation:
        IOSOpenAIFailedHistoryRetryProviderBuilder.Translate

    init(
        credential: OpenAICredential,
        transcribe: @escaping IOSOpenAIFailedHistoryRetryProviderBuilder
            .Transcribe,
        correct: @escaping IOSOpenAIFailedHistoryRetryProviderBuilder.Correct,
        translate: @escaping IOSOpenAIFailedHistoryRetryProviderBuilder
            .Translate
    ) {
        self.credential = credential
        transcribeOperation = transcribe
        correctOperation = correct
        translateOperation = translate
    }

    func transcribe(
        _ request: IOSFailedHistoryRetryTranscriptionRequest
    ) async -> IOSFailedHistoryRetryProviderTextOutcome {
        do {
            let format: OpenAIReaderTranscriptionRequest.AudioFormat =
                switch request.audio.format {
                case .m4a: .m4a
                case .wav: .wav
                }
            let providerRequest = try OpenAIReaderTranscriptionRequest(
                format: format,
                durationMilliseconds: request.audio.durationMilliseconds,
                byteCount: request.audio.byteCount,
                model: request.resolvedModel,
                languageCode: request.resolvedLanguageCode,
                promptComposition: request.promptComposition,
                reader: OpenAITranscriptionAudioReader { offset, count in
                    try await request.audio.read(
                        atOffset: offset,
                        maximumByteCount: count
                    )
                }
            )
            let text = try await transcribeOperation(
                providerRequest,
                credential
            )
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
        if error is OpenAIReaderTranscriptionRequest.ValidationError {
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
