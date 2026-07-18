//
//  OpenAITranscriptionServiceError.swift
//  HoldType
//
//  Created by Codex on 7/18/26.
//

import Foundation

public nonisolated enum OpenAITranscriptionServiceError: Error, Equatable, LocalizedError, Sendable {
    case missingAPIKey
    case apiKeyUnavailable
    case invalidRecording(OpenAITranscriptionRequestBuilderError)
    case invalidRequest
    case multipartMetadataTooLarge
    case timedOut
    case networkUnavailable
    case networkFailure
    case cancelled
    case invalidAPIKey
    case rateLimited
    case providerUnavailable
    case badRequest
    case providerRejected(statusCode: Int)
    case invalidResponse
    case emptyTranscript
    case dictionaryEcho
    case contextEcho

    public var errorDescription: String? {
        userFacingMessage
    }

    public var userFacingMessage: String {
        switch self {
        case .missingAPIKey:
            return "Enter an OpenAI API key before transcribing."
        case .apiKeyUnavailable:
            return "The OpenAI API key could not be read."
        case .invalidRecording(let error):
            return error.userFacingMessage
        case .invalidRequest:
            return "The transcription request could not be prepared."
        case .multipartMetadataTooLarge:
            return "The transcription request settings are too large."
        case .timedOut:
            return "Transcription timed out."
        case .networkUnavailable:
            return "The network is unavailable. Try again when you are connected."
        case .networkFailure:
            return "The transcription request failed. Try again."
        case .cancelled:
            return "Transcription was cancelled."
        case .invalidAPIKey:
            return "OpenAI rejected the saved API key."
        case .rateLimited:
            return "OpenAI rate limits were reached. Try again later."
        case .providerUnavailable:
            return "OpenAI is unavailable. Try again later."
        case .badRequest:
            return "Transcription settings or recording format need attention."
        case .providerRejected:
            return "OpenAI rejected the transcription request."
        case .invalidResponse:
            return "OpenAI returned an unreadable transcription response."
        case .emptyTranscript:
            return "No speech text was detected."
        case .dictionaryEcho:
            return "Only dictionary hints were detected."
        case .contextEcho:
            return "Only nearby context was detected."
        }
    }

    public var operatorLogCategory: String {
        switch self {
        case .missingAPIKey:
            return "missing_api_key"
        case .apiKeyUnavailable:
            return "api_key_unavailable"
        case .invalidRecording(let error):
            return error.operatorLogCategory
        case .invalidRequest:
            return "invalid_request"
        case .multipartMetadataTooLarge:
            return "multipart_metadata_too_large"
        case .timedOut:
            return "timeout"
        case .networkUnavailable:
            return "network_unavailable"
        case .networkFailure:
            return "network_failure"
        case .cancelled:
            return "cancelled"
        case .invalidAPIKey:
            return "invalid_api_key"
        case .rateLimited:
            return "rate_limited"
        case .providerUnavailable:
            return "provider_unavailable"
        case .badRequest:
            return "bad_request"
        case .providerRejected(let statusCode):
            return "provider_rejected_\(statusCode)"
        case .invalidResponse:
            return "invalid_response"
        case .emptyTranscript:
            return "empty_transcript"
        case .dictionaryEcho:
            return "dictionary_echo"
        case .contextEcho:
            return "context_echo"
        }
    }
}

nonisolated extension OpenAITranscriptionServiceError:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String {
        "OpenAITranscriptionServiceError(<redacted>)"
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [(label: String?, value: Any)](),
            displayStyle: .enum
        )
    }
}

private extension OpenAITranscriptionRequestBuilderError {
    var userFacingMessage: String {
        switch self {
        case .missingAudioFile:
            return "The recording file is missing."
        case .emptyAudioFile:
            return "No audio was captured. Try recording again."
        case .unsupportedAudioFileType:
            return "The recording format is not supported."
        case .unreadableAudioFile:
            return "The recording file could not be read."
        case .audioFileChanged:
            return "The recording changed while the request was being prepared."
        case .audioFileTooLarge:
            return "The recording is too large to send."
        case .multipartMetadataTooLarge:
            return "The transcription request settings are too large."
        case .multipartBodyTooLarge, .multipartBodyUnavailable:
            return "The transcription request could not be prepared."
        case .invalidMultipartBoundary:
            return "The transcription request could not be prepared."
        case .invalidCustomLanguageCode:
            return "Use a two- or three-letter custom language code."
        case .audioReaderAlreadyConsumed:
            return "The recording is no longer available for this request."
        case .audioReaderChanged:
            return "The recording changed while the request was being prepared."
        case .audioReaderUnreadable:
            return "The recording could not be read."
        }
    }

    var operatorLogCategory: String {
        switch self {
        case .missingAudioFile:
            return "missing_audio_file"
        case .emptyAudioFile:
            return "empty_audio"
        case .unsupportedAudioFileType:
            return "unsupported_audio"
        case .unreadableAudioFile:
            return "unreadable_audio"
        case .audioFileChanged:
            return "changed_audio"
        case .audioFileTooLarge:
            return "audio_too_large"
        case .multipartMetadataTooLarge:
            return "multipart_metadata_too_large"
        case .multipartBodyTooLarge:
            return "multipart_body_too_large"
        case .multipartBodyUnavailable:
            return "multipart_body_unavailable"
        case .invalidMultipartBoundary:
            return "invalid_multipart_boundary"
        case .invalidCustomLanguageCode:
            return "invalid_language_code"
        case .audioReaderAlreadyConsumed:
            return "audio_reader_consumed"
        case .audioReaderChanged:
            return "changed_audio"
        case .audioReaderUnreadable:
            return "unreadable_audio"
        }
    }
}
