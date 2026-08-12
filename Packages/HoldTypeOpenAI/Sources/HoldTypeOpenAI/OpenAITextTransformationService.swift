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
    static let defaultContainerEndpointURL = URL(string: "https://api.openai.com/v1/containers")!
    static let defaultRequestTimeout: TimeInterval = 20
    static let defaultMaxOutputTokens = 4096
    static let maximumOutputUTF8ByteCount = 64 * 1024

    private let endpointURL: URL
    private let containerEndpointURL: URL
    private let urlLoader: any URLLoading
    private let timeoutSleeper: any TranscriptionTimeoutSleeping
    private let requestTimeout: TimeInterval
    private let maxOutputTokens: Int
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let requestTaskCoordinator: OpenAIRequestTaskCoordinator
    private let writingSkillContainerCache: OpenAIWritingSkillContainerCache
    private let writingSkillArchive: @Sendable () throws -> Data
    private let usageReporter: OpenAITextUsageReporter

    public init(
        usageReporter: @escaping OpenAITextUsageReporter = { _ in }
    ) {
        self.init(
            endpointURL: Self.defaultEndpointURL,
            containerEndpointURL: Self.defaultContainerEndpointURL,
            urlLoader: URLSession.shared,
            timeoutSleeper: TaskTranscriptionTimeoutSleeper(),
            requestTimeout: Self.defaultRequestTimeout,
            maxOutputTokens: Self.defaultMaxOutputTokens,
            encoder: JSONEncoder(),
            decoder: JSONDecoder(),
            requestTaskCoordinator: OpenAIRequestTaskCoordinator(),
            writingSkillContainerCache: OpenAIWritingSkillContainerCache(),
            writingSkillArchive: BundledWritingSkillArchive.load,
            usageReporter: usageReporter
        )
    }

    init(
        endpointURL: URL,
        containerEndpointURL: URL = Self.defaultContainerEndpointURL,
        urlLoader: any URLLoading = URLSession.shared,
        timeoutSleeper: any TranscriptionTimeoutSleeping = TaskTranscriptionTimeoutSleeper(),
        requestTimeout: TimeInterval = Self.defaultRequestTimeout,
        maxOutputTokens: Int = Self.defaultMaxOutputTokens,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        requestTaskCoordinator: OpenAIRequestTaskCoordinator = OpenAIRequestTaskCoordinator(),
        writingSkillContainerCache: OpenAIWritingSkillContainerCache =
            OpenAIWritingSkillContainerCache(),
        writingSkillArchive: @escaping @Sendable () throws -> Data =
            BundledWritingSkillArchive.load,
        usageReporter: @escaping OpenAITextUsageReporter = { _ in }
    ) {
        self.endpointURL = endpointURL
        self.containerEndpointURL = containerEndpointURL
        self.urlLoader = urlLoader
        self.timeoutSleeper = timeoutSleeper
        self.requestTimeout = requestTimeout > 0 ? requestTimeout : Self.defaultRequestTimeout
        self.maxOutputTokens = max(1, maxOutputTokens)
        self.encoder = encoder
        self.decoder = decoder
        self.requestTaskCoordinator = requestTaskCoordinator
        self.writingSkillContainerCache = writingSkillContainerCache
        self.writingSkillArchive = writingSkillArchive
        self.usageReporter = usageReporter
    }

    public func transform(
        _ request: TextTransformationRequest,
        credential: OpenAICredential
    ) async throws -> String {
        let effectiveTimeout = request.requestTimeoutSeconds ?? requestTimeout
        let response: OpenAITextTransformationResponse
        if request.usesBuiltInWritingSkill {
            let containerID = try await resolveWritingSkillContainer(
                credential: credential
            )
            do {
                response = try await performTransformation(
                    request,
                    credential: credential,
                    containerID: containerID,
                    timeout: effectiveTimeout
                )
            } catch OpenAITextTransformationServiceError.writingSkillContainerExpired {
                await writingSkillContainerCache.invalidate(containerID: containerID)
                let replacementContainerID = try await resolveWritingSkillContainer(
                    credential: credential
                )
                response = try await performTransformation(
                    request,
                    credential: credential,
                    containerID: replacementContainerID,
                    timeout: effectiveTimeout
                )
            }
        } else {
            response = try await performTransformation(
                request,
                credential: credential,
                containerID: nil,
                timeout: effectiveTimeout
            )
        }
        await reportTextUsage(
            responseModel: response.model,
            requestedModel: request.model,
            usage: response.usage,
            reporter: usageReporter
        )
        return try parseOutput(from: response)
    }

    public func cancelActiveTransformation() {
        requestTaskCoordinator.cancelActiveRequest()
    }

    private func makeAuthorizedRequest(
        transformationRequest: TextTransformationRequest,
        credential: OpenAICredential,
        containerID: String?
    ) throws -> URLRequest {
        do {
            let usesWritingSkill = containerID != nil
            let inputText = usesWritingSkill
                ? "Use the de-ai-writing skill for this transformation. "
                    + "Preserve the source language, genre, audience, formatting, meaning, "
                    + "and factual claims unless the Fix instruction explicitly changes them. "
                    + "Return only the transformed text."
                : transformationRequest.sourceText
            let inputContent = usesWritingSkill
                ? [
                    OpenAITextTransformationInputContent(type: "input_text", text: inputText),
                    OpenAITextTransformationInputContent(
                        type: "input_text",
                        text: transformationRequest.sourceText
                    ),
                ]
                : [
                    OpenAITextTransformationInputContent(
                        type: "input_text",
                        text: transformationRequest.sourceText
                    ),
                ]
            let tools = containerID.map { containerID in
                [
                    OpenAITextTransformationTool(
                        type: "shell",
                        environment: OpenAITextTransformationToolEnvironment(
                            type: "container_reference",
                            containerID: containerID
                        )
                    ),
                ]
            }
            let payload = OpenAITextTransformationRequestPayload(
                model: transformationRequest.model,
                instructions: transformationRequest.prompt,
                input: [
                    OpenAITextTransformationInputMessage(
                        role: "user",
                        content: inputContent
                    ),
                ],
                reasoning: OpenAITextTransformationReasoning(
                    effort: transformationRequest.reasoningEffort.rawValue
                ),
                text: OpenAITextTransformationTextConfig(
                    format: OpenAITextTransformationTextFormat(type: "text"),
                    verbosity: "low"
                ),
                tools: tools,
                toolChoice: usesWritingSkill ? "required" : "none",
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

    private func performTransformation(
        _ transformationRequest: TextTransformationRequest,
        credential: OpenAICredential,
        containerID: String?,
        timeout: TimeInterval
    ) async throws -> OpenAITextTransformationResponse {
        var urlRequest = try makeAuthorizedRequest(
            transformationRequest: transformationRequest,
            credential: credential,
            containerID: containerID
        )
        urlRequest.timeoutInterval = timeout
        let (data, httpResponse) = try await loadWithTimeout(
            urlRequest,
            timeout: timeout
        )
        if containerID != nil,
           (httpResponse as? HTTPURLResponse)?.statusCode == 404 {
            throw OpenAITextTransformationServiceError.writingSkillContainerExpired
        }
        try validateHTTPResponse(httpResponse)
        return try decodeResponse(from: data)
    }

    private func resolveWritingSkillContainer(
        credential: OpenAICredential
    ) async throws -> String {
        if let cached = await writingSkillContainerCache.containerID() {
            return cached
        }

        let archive = try writingSkillArchive()
        let payload = OpenAIWritingSkillContainerRequestPayload(
            name: "holdtype-writing-skill",
            skills: [
                OpenAIInlineWritingSkill(
                    type: "inline",
                    name: "de-ai-writing",
                    description: "Rewrite prose so it sounds less AI-written while preserving facts.",
                    source: OpenAIInlineWritingSkillSource(
                        type: "base64",
                        mediaType: "application/zip",
                        data: archive.base64EncodedString()
                    )
                ),
            ]
        )
        var request = URLRequest(url: containerEndpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = Self.defaultRequestTimeout
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(credential.apiKey)", forHTTPHeaderField: "Authorization")
        do {
            request.httpBody = try encoder.encode(payload)
        } catch {
            throw OpenAITextTransformationServiceError.invalidRequest
        }

        let (data, response) = try await loadWithTimeout(
            request,
            timeout: Self.defaultRequestTimeout
        )
        try validateHTTPResponse(response)
        let container: OpenAIWritingSkillContainerResponse
        do {
            container = try decoder.decode(OpenAIWritingSkillContainerResponse.self, from: data)
        } catch {
            throw OpenAITextTransformationServiceError.writingSkillUnavailable
        }
        guard !container.id.isEmpty else {
            throw OpenAITextTransformationServiceError.writingSkillUnavailable
        }
        await writingSkillContainerCache.store(containerID: container.id)
        return container.id
    }

    private func loadWithTimeout(
        _ request: URLRequest,
        timeout: TimeInterval
    ) async throws -> (Data, URLResponse) {
        do {
            return try await requestTaskCoordinator.perform {
                try await urlLoader.loadData(for: request)
            } deadline: {
                try await timeoutSleeper.sleep(seconds: timeout)
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

    private func decodeResponse(from data: Data) throws -> OpenAITextTransformationResponse {
        do {
            return try decoder.decode(OpenAITextTransformationResponse.self, from: data)
        } catch {
            throw OpenAITextTransformationServiceError.invalidResponse
        }
    }

    private func parseOutput(from response: OpenAITextTransformationResponse) throws -> String {
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
    case writingSkillUnavailable
    case writingSkillContainerExpired
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
        case .writingSkillUnavailable, .writingSkillContainerExpired:
            return "HoldType’s built-in writing skill is unavailable. Try again."
        case .emptyOutput:
            return "The Fix returned no usable text."
        case .outputTooLarge:
            return "The Fix result is too large."
        }
    }
}
