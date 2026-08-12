import Foundation

/// Provider-reported usage for one successful Responses API text request.
public struct OpenAITextResponseUsage: Equatable, Sendable {
    public let model: String
    public let inputTokens: Int
    public let cachedInputTokens: Int
    public let outputTokens: Int
    public let reasoningTokens: Int

    public init(
        model: String,
        inputTokens: Int,
        cachedInputTokens: Int,
        outputTokens: Int,
        reasoningTokens: Int
    ) throws {
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedModel.isEmpty,
              inputTokens >= 0,
              cachedInputTokens >= 0,
              cachedInputTokens <= inputTokens,
              outputTokens >= 0,
              reasoningTokens >= 0,
              reasoningTokens <= outputTokens else {
            throw ValidationError.invalidUsage
        }

        self.model = normalizedModel
        self.inputTokens = inputTokens
        self.cachedInputTokens = cachedInputTokens
        self.outputTokens = outputTokens
        self.reasoningTokens = reasoningTokens
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case invalidUsage
    }
}

/// A successful provider response either supplies valid usage or explicitly
/// tells the local estimate owner that the response cannot be measured.
public enum OpenAITextUsageObservation: Equatable, Sendable {
    case measured(OpenAITextResponseUsage)
    case unavailable
}

public typealias OpenAITextUsageReporter = @Sendable (OpenAITextUsageObservation) async -> Void

struct OpenAITextResponseUsageWire: Decodable {
    let inputTokens: Int
    let inputTokensDetails: InputDetails?
    let outputTokens: Int
    let outputTokensDetails: OutputDetails?

    struct InputDetails: Decodable {
        let cachedTokens: Int?

        enum CodingKeys: String, CodingKey {
            case cachedTokens = "cached_tokens"
        }
    }

    struct OutputDetails: Decodable {
        let reasoningTokens: Int?

        enum CodingKeys: String, CodingKey {
            case reasoningTokens = "reasoning_tokens"
        }
    }

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case inputTokensDetails = "input_tokens_details"
        case outputTokens = "output_tokens"
        case outputTokensDetails = "output_tokens_details"
    }

    func runtimeUsage(responseModel: String?, requestedModel: String) throws -> OpenAITextResponseUsage {
        try OpenAITextResponseUsage(
            model: responseModel ?? requestedModel,
            inputTokens: inputTokens,
            cachedInputTokens: inputTokensDetails?.cachedTokens ?? 0,
            outputTokens: outputTokens,
            reasoningTokens: outputTokensDetails?.reasoningTokens ?? 0
        )
    }
}

func reportTextUsage(
    responseModel: String?,
    requestedModel: String,
    usage: OpenAITextResponseUsageWire?,
    reporter: OpenAITextUsageReporter
) async {
    guard let usage,
          let runtimeUsage = try? usage.runtimeUsage(
              responseModel: responseModel,
              requestedModel: requestedModel
          ) else {
        await reporter(.unavailable)
        return
    }

    await reporter(.measured(runtimeUsage))
}
