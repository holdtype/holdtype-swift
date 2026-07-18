//
//  OpenAITranscriptionService.swift
//  HoldType
//
//  Created by Codex on 6/21/26.
//

import Foundation
import HoldTypeDomain

public protocol OpenAITranscriptionServing {
    func transcribe(
        _ request: AudioTranscriptionRequest,
        credential: OpenAICredential
    ) async throws -> String
    func cancelActiveTranscription()
}

public extension OpenAITranscriptionServing {
    func cancelActiveTranscription() {}
}

protocol URLLoading: Sendable {
    func loadData(for request: URLRequest) async throws -> (Data, URLResponse)
}

protocol TranscriptionTimeoutSleeping: Sendable {
    func sleep(seconds: TimeInterval) async throws
}

public struct OpenAITranscriptionService:
    OpenAITranscriptionServing,
    Sendable {
    static let defaultRequestTimeout: TimeInterval = 60

    private let requestBuilder: OpenAITranscriptionRequestBuilder
    private let urlUploader: any URLFileUploading
    private let timeoutSleeper: any TranscriptionTimeoutSleeping
    private let requestTimeout: TimeInterval
    private let decoder: JSONDecoder
    private let requestTaskCoordinator: OpenAIRequestTaskCoordinator

    public init() {
        self.init(
            requestBuilder: OpenAITranscriptionRequestBuilder(),
            urlUploader: OpenAIFileUploadTransport(),
            timeoutSleeper: TaskTranscriptionTimeoutSleeper(),
            requestTimeout: Self.defaultRequestTimeout,
            decoder: JSONDecoder(),
            requestTaskCoordinator: OpenAIRequestTaskCoordinator()
        )
    }

    init(
        requestBuilder: OpenAITranscriptionRequestBuilder,
        urlUploader: any URLFileUploading = OpenAIFileUploadTransport(),
        timeoutSleeper: any TranscriptionTimeoutSleeping = TaskTranscriptionTimeoutSleeper(),
        requestTimeout: TimeInterval = Self.defaultRequestTimeout,
        decoder: JSONDecoder = JSONDecoder(),
        requestTaskCoordinator: OpenAIRequestTaskCoordinator = OpenAIRequestTaskCoordinator()
    ) {
        self.requestBuilder = requestBuilder
        self.urlUploader = urlUploader
        self.timeoutSleeper = timeoutSleeper
        self.requestTimeout = requestTimeout > 0 ? requestTimeout : Self.defaultRequestTimeout
        self.decoder = decoder
        self.requestTaskCoordinator = requestTaskCoordinator
    }

    public func transcribe(
        _ request: AudioTranscriptionRequest,
        credential: OpenAICredential
    ) async throws -> String {
        let cleanupRegistration = requestBuilder.makeCleanupRegistration()
        defer { cleanupRegistration.requestCleanup() }

        let (data, response) = try await loadWithTimeout(
            request,
            cleanupRegistration: cleanupRegistration,
            credential: credential
        )
        try validateHTTPResponse(response)
        return try parseTranscript(from: data, promptComposition: request.promptComposition)
    }

    public func transcribe(
        _ request: OpenAIReaderTranscriptionRequest,
        credential: OpenAICredential
    ) async throws -> String {
        let cleanupRegistration = requestBuilder.makeCleanupRegistration()
        defer {
            request.invalidateReader()
            cleanupRegistration.requestCleanup()
        }

        let (data, response) = try await loadWithTimeout(
            request,
            cleanupRegistration: cleanupRegistration,
            credential: credential
        )
        try validateHTTPResponse(response)
        return try parseTranscript(from: data, promptComposition: request.promptComposition)
    }

    public func cancelActiveTranscription() {
        requestTaskCoordinator.cancelActiveRequest()
    }

    private func loadWithTimeout(
        _ transcriptionRequest: AudioTranscriptionRequest,
        cleanupRegistration: OpenAITranscriptionMultipartCleanupRegistration,
        credential: OpenAICredential
    ) async throws -> (Data, URLResponse) {
        do {
            return try await requestTaskCoordinator.perform {
                let preparation = try await requestBuilder.makePreparation(
                    transcriptionRequest,
                    cleanupRegistration: cleanupRegistration
                )
                defer { cleanupRegistration.requestCleanup() }
                let preparedUpload = try await preparation.prepareRequest()
                var request = preparedUpload.request
                request.timeoutInterval = requestTimeout
                request.setValue(
                    "Bearer \(credential.apiKey)",
                    forHTTPHeaderField: "Authorization"
                )
                try Task.checkCancellation()
                return try await urlUploader.uploadData(
                    for: request,
                    body: preparedUpload.body
                )
            } deadline: {
                try await timeoutSleeper.sleep(seconds: requestTimeout)
                throw OpenAITranscriptionServiceError.timedOut
            }
        } catch let error as OpenAITranscriptionServiceError {
            throw error
        } catch let error as OpenAITranscriptionRequestBuilderError {
            throw Self.mapRequestBuilderError(error)
        } catch let error as OpenAIFileUploadTransportError {
            throw Self.mapUploadTransportError(error)
        } catch let error as URLError {
            throw Self.mapURLError(error)
        } catch is CancellationError {
            throw OpenAITranscriptionServiceError.cancelled
        } catch {
            throw OpenAITranscriptionServiceError.networkFailure
        }
    }

    private func loadWithTimeout(
        _ transcriptionRequest: OpenAIReaderTranscriptionRequest,
        cleanupRegistration: OpenAITranscriptionMultipartCleanupRegistration,
        credential: OpenAICredential
    ) async throws -> (Data, URLResponse) {
        do {
            return try await requestTaskCoordinator.perform {
                let preparation = try await requestBuilder.makePreparation(
                    transcriptionRequest,
                    cleanupRegistration: cleanupRegistration
                )
                defer { cleanupRegistration.requestCleanup() }
                let preparedUpload = try await preparation.prepareRequest()
                var request = preparedUpload.request
                request.timeoutInterval = requestTimeout
                request.setValue(
                    "Bearer \(credential.apiKey)",
                    forHTTPHeaderField: "Authorization"
                )
                try Task.checkCancellation()
                return try await urlUploader.uploadData(
                    for: request,
                    body: preparedUpload.body
                )
            } deadline: {
                try await timeoutSleeper.sleep(seconds: requestTimeout)
                throw OpenAITranscriptionServiceError.timedOut
            }
        } catch let error as OpenAITranscriptionServiceError {
            throw error
        } catch let error as OpenAITranscriptionRequestBuilderError {
            throw Self.mapRequestBuilderError(error)
        } catch let error as OpenAIFileUploadTransportError {
            throw Self.mapUploadTransportError(error)
        } catch let error as URLError {
            throw Self.mapURLError(error)
        } catch is CancellationError {
            throw OpenAITranscriptionServiceError.cancelled
        } catch {
            throw OpenAITranscriptionServiceError.networkFailure
        }
    }

    private static func mapRequestBuilderError(
        _ error: OpenAITranscriptionRequestBuilderError
    ) -> OpenAITranscriptionServiceError {
        switch error {
        case .multipartMetadataTooLarge:
            return .multipartMetadataTooLarge
        case .multipartBodyTooLarge, .multipartBodyUnavailable, .invalidMultipartBoundary:
            return .invalidRequest
        case .missingAudioFile,
             .emptyAudioFile,
             .unsupportedAudioFileType,
             .unreadableAudioFile,
             .audioFileChanged,
             .audioFileTooLarge,
             .invalidCustomLanguageCode,
             .audioReaderAlreadyConsumed,
             .audioReaderChanged,
             .audioReaderUnreadable:
            return .invalidRecording(error)
        }
    }

    private static func mapUploadTransportError(
        _ error: OpenAIFileUploadTransportError
    ) -> OpenAITranscriptionServiceError {
        switch error {
        case .invalidRequest:
            return .invalidRequest
        case .invalidResponse, .responseTooLarge, .redirectRejected:
            return .invalidResponse
        case .cancelled:
            return .cancelled
        case .transportFailure:
            return .networkFailure
        }
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITranscriptionServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw OpenAITranscriptionServiceError.invalidAPIKey
        case 408:
            throw OpenAITranscriptionServiceError.timedOut
        case 429:
            throw OpenAITranscriptionServiceError.rateLimited
        case 400, 404, 413, 415, 422:
            throw OpenAITranscriptionServiceError.badRequest
        case 500..<600:
            throw OpenAITranscriptionServiceError.providerUnavailable
        default:
            throw OpenAITranscriptionServiceError.providerRejected(statusCode: httpResponse.statusCode)
        }
    }

    private func parseTranscript(
        from data: Data,
        promptComposition: TranscriptionPromptComposition
    ) throws -> String {
        do {
            let response = try decoder.decode(OpenAITranscriptionResponse.self, from: data)
            let transcript = try AcceptedTranscript(rawText: response.text).text
            guard !DictionaryEchoFilter.matches(
                transcript: transcript,
                dictionaryPrompt: promptComposition.dictionaryEchoGuardText
            ) else {
                throw OpenAITranscriptionServiceError.dictionaryEcho
            }

            guard !ActiveTextContextEchoFilter.matches(
                transcript: transcript,
                contextText: promptComposition.contextEchoGuardText
            ) else {
                throw OpenAITranscriptionServiceError.contextEcho
            }

            return transcript
        } catch AcceptedTranscript.ValidationError.emptyText {
            throw OpenAITranscriptionServiceError.emptyTranscript
        } catch let error as OpenAITranscriptionServiceError {
            throw error
        } catch {
            throw OpenAITranscriptionServiceError.invalidResponse
        }
    }

    private static func mapURLError(_ error: URLError) -> OpenAITranscriptionServiceError {
        switch error.code {
        case .timedOut:
            return .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return .networkUnavailable
        case .cancelled:
            return .cancelled
        default:
            return .networkFailure
        }
    }
}

struct DictionaryEchoFilter {
    static func matches(transcript: String?, dictionaryPrompt: String?) -> Bool {
        guard let transcript, let dictionaryPrompt else {
            return false
        }

        let transcriptWords = Set(normalizedWords(in: transcript))
        let dictionaryWords = Set(normalizedWords(in: dictionaryPrompt))
        guard !transcriptWords.isEmpty, !dictionaryWords.isEmpty else {
            return false
        }

        let matchingWordCount = transcriptWords.intersection(dictionaryWords).count
        let textComposition = Double(matchingWordCount) / Double(transcriptWords.count)
        let dictionaryUsage = Double(matchingWordCount) / Double(dictionaryWords.count)

        return textComposition >= 0.9 && dictionaryUsage >= 0.7
    }

    private static func normalizedWords(in text: String) -> [String] {
        var scalars = String.UnicodeScalarView()
        let space = UnicodeScalar(" ")

        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
            } else {
                scalars.append(space)
            }
        }

        return String(scalars).split(separator: " ").map(String.init)
    }
}

struct ActiveTextContextEchoFilter {
    static func matches(transcript: String?, contextText: String?) -> Bool {
        guard let transcript, let contextText else {
            return false
        }

        let transcriptWords = normalizedWords(in: transcript)
        let contextWords = normalizedWords(in: contextText)
        guard transcriptWords.count >= 4, contextWords.count >= transcriptWords.count else {
            return false
        }

        for startIndex in 0...(contextWords.count - transcriptWords.count) {
            let endIndex = startIndex + transcriptWords.count
            if Array(contextWords[startIndex..<endIndex]) == transcriptWords {
                return true
            }
        }

        return false
    }

    private static func normalizedWords(in text: String) -> [String] {
        var scalars = String.UnicodeScalarView()
        let space = UnicodeScalar(" ")

        for scalar in text.lowercased().unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                scalars.append(scalar)
            } else {
                scalars.append(space)
            }
        }

        return String(scalars).split(separator: " ").map(String.init)
    }
}

extension URLSession: URLLoading {
    func loadData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request)
    }
}

struct TaskTranscriptionTimeoutSleeper: TranscriptionTimeoutSleeping {
    func sleep(seconds: TimeInterval) async throws {
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }
}

private struct OpenAITranscriptionResponse: Decodable {
    let text: String
}
