import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) import HoldTypePersistence

enum IOSForegroundVoiceProviderFailure: Equatable, Sendable {
    case credentialMissing
    case credentialUnavailable
    case credentialRejected
    case networkUnavailable
    case networkFailure
    case timedOut
    case rateLimited
    case providerUnavailable
    case badRequest
    case providerRejected
    case invalidResponse
    case emptyResult
    case dictionaryEcho
    case contextEcho
    case invalidRecording
    case invalidRequest
    case multipartMetadataTooLarge
    case invalidTranslationRoute
    case cancelled
    case unknown

    var publicFailure: IOSForegroundVoiceProcessingFailure {
        switch self {
        case .credentialMissing, .credentialUnavailable,
             .credentialRejected:
            .credentialRejected
        case .networkUnavailable:
            .networkUnavailable
        case .networkFailure:
            .networkFailure
        case .timedOut:
            .timedOut
        case .rateLimited, .providerUnavailable, .badRequest,
             .providerRejected:
            .providerUnavailable
        case .invalidResponse, .emptyResult, .dictionaryEcho,
             .contextEcho:
            .invalidResponse
        case .invalidRecording, .multipartMetadataTooLarge:
            .invalidRecording
        case .invalidRequest, .invalidTranslationRoute:
            .invalidConfiguration
        case .cancelled:
            .cancelled
        case .unknown:
            .providerUnavailable
        }
    }
}

struct IOSForegroundVoiceOpenAIProviderOperations: Sendable {
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

    let transcribe: Transcribe
    let correct: Correct
    let translate: Translate

    init() {
        let transcriptionService = OpenAITranscriptionService()
        let correctionService = OpenAITextCorrectionService()
        let translationService = OpenAITextTranslationService()
        transcribe = { request, credential in
            try await transcriptionService.transcribe(
                request,
                credential: credential
            )
        }
        correct = { transcript, configuration, credential in
            try await correctionService.correct(
                transcript,
                configuration: configuration,
                credential: credential
            )
        }
        translate = { request, credential in
            try await translationService.translate(
                request,
                credential: credential
            )
        }
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
}

enum IOSForegroundVoiceProviderFailureMapper {
    static func transcription(
        _ error: any Error
    ) -> IOSForegroundVoiceProviderFailure {
        if error is CancellationError { return .cancelled }
        if error is AcceptedTranscript.ValidationError {
            return .emptyResult
        }
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

    static func correction(
        _ error: any Error
    ) -> IOSForegroundVoiceProviderFailure {
        if error is CancellationError { return .cancelled }
        if error is AcceptedTranscript.ValidationError {
            return .emptyResult
        }
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

    static func translation(
        _ error: any Error
    ) -> IOSForegroundVoiceProviderFailure {
        if error is CancellationError { return .cancelled }
        if error is AcceptedTranscript.ValidationError {
            return .emptyResult
        }
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

enum IOSForegroundVoiceTranscriptionStageError: Error, Sendable {
    case failure(IOSForegroundVoiceProviderFailure)
    case cancelled
    case authorizationUnavailable
}

struct IOSForegroundVoiceTranscriptionExecutor:
    IOSPendingTranscriptionExecutor,
    Sendable {
    let authorization: IOSV1ProviderConsentAuthorization
    let stageExecutor: IOSProviderConsentStageExecutor
    let provider: IOSForegroundVoiceOpenAIProviderOperations
    let credential: OpenAICredential
    let promptComposition: TranscriptionPromptComposition

    func transcribe(
        recording: IOSPendingRecording,
        audio: IOSPendingTranscriptionAudio
    ) async throws -> String {
        guard recording.durationMilliseconds == audio.durationMilliseconds,
              recording.byteCount == audio.byteCount else {
            throw IOSForegroundVoiceTranscriptionStageError
                .failure(.invalidRecording)
        }
        let format: OpenAIReaderTranscriptionRequest.AudioFormat =
            switch audio.format {
            case .m4a: .m4a
            case .wav: .wav
            }
        let provider = provider
        let credential = credential
        let request: OpenAIReaderTranscriptionRequest
        do {
            request = try OpenAIReaderTranscriptionRequest(
                format: format,
                durationMilliseconds: audio.durationMilliseconds,
                byteCount: audio.byteCount,
                model: recording.transcriptionModel,
                languageCode: recording.transcriptionLanguageCode,
                promptComposition: promptComposition,
                reader: OpenAITranscriptionAudioReader { offset, count in
                    try await audio.read(
                        atOffset: offset,
                        maximumByteCount: count
                    )
                }
            )
        } catch {
            throw IOSForegroundVoiceTranscriptionStageError.failure(
                IOSForegroundVoiceProviderFailureMapper.transcription(error)
            )
        }
        let outcome = await stageExecutor.execute(
            authorization,
            for: .transcription,
            operation: {
                let text = try await provider.transcribe(request, credential)
                return try AcceptedTranscript(rawText: text)
            },
            normalizeFailure: {
                IOSForegroundVoiceProviderFailureMapper.transcription($0)
            }
        )
        switch outcome {
        case .success(let transcript):
            return transcript.text
        case .failure(let failure):
            throw IOSForegroundVoiceTranscriptionStageError.failure(failure)
        case .cancelled:
            throw IOSForegroundVoiceTranscriptionStageError.cancelled
        case .authorizationUnavailable:
            throw IOSForegroundVoiceTranscriptionStageError
                .authorizationUnavailable
        }
    }
}

extension IOSForegroundVoiceTranscriptionExecutor:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoiceTranscriptionExecutor(redacted)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceProviderFailure:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoiceProviderFailure(redacted)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSForegroundVoiceTranscriptionStageError:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    var description: String {
        "IOSForegroundVoiceTranscriptionStageError(redacted)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
