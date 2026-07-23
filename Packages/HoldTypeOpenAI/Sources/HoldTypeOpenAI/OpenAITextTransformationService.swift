//
//  OpenAITextTransformationService.swift
//  HoldType
//
//  Created by Codex on 7/23/26.
//

import Foundation
import HoldTypeDomain

public protocol OpenAITextTransformationServing {
    func transform(
        _ request: TextTransformationRequest,
        credential: OpenAICredential
    ) async throws -> String
    func cancelActiveTransformation()
}

public struct OpenAITextTransformationService: OpenAITextTransformationServing, Sendable {
    static let defaultEndpointURL = URL(string: "https://api.openai.com/v1/responses")!
    static let defaultRequestTimeout: TimeInterval = 20
    static let defaultMaxOutputTokens = 4096
    static let maximumOutputUTF8ByteCount = 64 * 1024

    private let endpointURL: URL
    private let urlLoader: any URLLoading
    private let timeoutSleeper: any TranscriptionTimeoutSleeping
    private let requestTimeout: TimeInterval
    private let maxOutputTokens: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let requestTaskCoordinator: OpenAIRequestTaskCoordinator

    public init() {
        self.init(
            endpointURL: Self.defaultEndpointURL,
            urlLoader: URLSession.shared,
            timeoutSleeper: TaskTranscriptionTimeoutSleeper(),
            requestTimeout: Self.defaultRequestTimeout,
            maxOutputTokens: Self.defaultMaxOutputTokens,
            encoder: JSONEncoder(),
            decoder: JSONDecoder(),
            requestTaskCoordinator: OpenAIRequestTaskCoordinator()
        )
    }

    init(
        endpointURL: URL,
        urlLoader: any URLLoading = URLSession.shared,
        timeoutSleeper: any TranscriptionTimeoutSleeping = TaskTranscriptionTimeoutSleeper(),
        requestTimeout: TimeInterval = Self.defaultRequestTimeout,
        maxOutputTokens: Int = Self.defaultMaxOutputTokens,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        requestTaskCoordinator: OpenAIRequestTaskCoordinator = OpenAIRequestTaskCoordinator()
    ) {
        self.endpointURL = endpointURL
        self.urlLoader = urlLoader
        self.timeoutSleeper = timeoutSleeper
        self.requestTimeout = requestTimeout > 0 ? requestTimeout : Self.defaultRequestTimeout
        self.maxOutputTokens = max(1, maxOutputTokens)
        self.encoder = encoder
        self.decoder = decoder
        self.requestTaskCoordinator = requestTaskCoordinator
    }

    public func transform(
        _ request: TextTransformationRequest,
        credential: OpenAICredential
    ) async throws -> String {
        var urlRequest = try makeAuthorizedRequest(
            transformationRequest: request,
            credential: credential
        )
        urlRequest.timeoutInterval = requestTimeout

        let (data, response) = try await loadWithTimeout(urlRequest)
        try validateHTTPResponse(response)
        return try parseOutput(from: data)
    }

    public func cancelActiveTransformation() {
        requestTaskCoordinator.cancelActiveRequest()
    }

    private func makeAuthorizedRequest(
        transformationRequest: TextTransformationRequest,
        credential: OpenAICredential
    ) throws -> URLRequest {
        do {
            let payload = OpenAITextTransformationRequestPayload(
                model: transformationRequest.model,
                instructions: transformationRequest.prompt,
                input: [
                    OpenAITextTransformationInputMessage(
                        role: "user",
                        content: [
                            OpenAITextTransformationInputContent(
                                type: "input_text",
                                text: transformationRequest.sourceText
                            ),
                        ]
                    ),
                ],
                reasoning: OpenAITextTransformationReasoning(effort: "low"),
                text: OpenAITextTransformationTextConfig(
                    format: OpenAITextTransformationTextFormat(type: "text"),
                    verbosity: "low"
                ),
                toolChoice: "none",
                maxOutputTokens: maxOutputTokens,
                store: false
            )

            var request = URLRequest(url: endpointURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
            request.httpBody = try encoder.encode(payload)
            return request
        } catch {
            throw OpenAITextTransformationServiceError.invalidRequest
        }
    }

    private func loadWithTimeout(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await requestTaskCoordinator.perform {
                try await urlLoader.loadData(for: request)
            } deadline: {
                try await timeoutSleeper.sleep(seconds: requestTimeout)
                throw OpenAITextTransformationServiceError.timedOut
            }
        } catch let error as OpenAITextTransformationServiceError {
            throw error
        } catch let error as URLError {
            throw Self.mapURLError(error)
        } catch is CancellationError {
            throw OpenAITextTransformationServiceError.cancelled
        } catch {
            throw OpenAITextTransformationServiceError.networkFailure
        }
    }

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAITextTransformationServiceError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200..<300:
            return
        case 401, 403:
            throw OpenAITextTransformationServiceError.invalidAPIKey
        case 408:
            throw OpenAITextTransformationServiceError.timedOut
        case 429:
            throw OpenAITextTransformationServiceError.rateLimited
        case 400, 404, 413, 415, 422:
            throw OpenAITextTransformationServiceError.badRequest
        case 500..<600:
            throw OpenAITextTransformationServiceError.providerUnavailable
        default:
            throw OpenAITextTransformationServiceError.providerRejected(
                statusCode: httpResponse.statusCode
            )
        }
    }

    private func parseOutput(from data: Data) throws -> String {
        let response: OpenAITextTransformationResponse
        do {
            response = try decoder.decode(OpenAITextTransformationResponse.self, from: data)
        } catch {
            throw OpenAITextTransformationServiceError.invalidResponse
        }

        let output = response.outputText ?? response.firstOutputText ?? ""
        guard !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw OpenAITextTransformationServiceError.emptyOutput
        }
        guard output.utf8.count <= Self.maximumOutputUTF8ByteCount else {
            throw OpenAITextTransformationServiceError.outputTooLarge(
                maximumUTF8ByteCount: Self.maximumOutputUTF8ByteCount
            )
        }
        return output
    }

    private static func mapURLError(
        _ error: URLError
    ) -> OpenAITextTransformationServiceError {
        switch error.code {
        case .timedOut:
            return .timedOut
        case .notConnectedToInternet,
             .networkConnectionLost,
             .cannotFindHost,
             .cannotConnectToHost:
            return .networkUnavailable
        case .cancelled:
            return .cancelled
        default:
            return .networkFailure
        }
    }
}

public enum OpenAITextTransformationServiceError:
    Error,
    Equatable,
    LocalizedError,
    Sendable {
    case invalidRequest
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
    case emptyOutput
    case outputTooLarge(maximumUTF8ByteCount: Int)

    public var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The Fix request could not be prepared."
        case .timedOut:
            return "The Fix request timed out."
        case .networkUnavailable:
            return "The network is unavailable. The Fix was not completed."
        case .networkFailure:
            return "The Fix request failed."
        case .cancelled:
            return "The Fix request was cancelled."
        case .invalidAPIKey:
            return "OpenAI rejected the saved API key. Check Settings."
        case .rateLimited:
            return "OpenAI rate limits were reached. The Fix was not completed."
        case .providerUnavailable:
            return "OpenAI is unavailable. The Fix was not completed."
        case .badRequest:
            return "The Fix settings need attention."
        case .providerRejected:
            return "OpenAI rejected the Fix request."
        case .invalidResponse:
            return "OpenAI returned an unreadable Fix response."
        case .emptyOutput:
            return "The Fix returned no usable text."
        case .outputTooLarge:
            return "The Fix result is too large."
        }
    }
}
