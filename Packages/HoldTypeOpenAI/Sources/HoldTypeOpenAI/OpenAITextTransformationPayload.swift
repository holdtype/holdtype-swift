//
//  OpenAITextTransformationPayload.swift
//  HoldType
//
//  Created by Codex on 7/23/26.
//

struct OpenAITextTransformationRequestPayload: Encodable {
    let model: String
    let instructions: String
    let input: [OpenAITextTransformationInputMessage]
    let reasoning: OpenAITextTransformationReasoning
    let text: OpenAITextTransformationTextConfig
    let toolChoice: String
    let maxOutputTokens: Int
    let store: Bool

    enum CodingKeys: String, CodingKey {
        case model
        case instructions
        case input
        case reasoning
        case text
        case toolChoice = "tool_choice"
        case maxOutputTokens = "max_output_tokens"
        case store
    }
}

struct OpenAITextTransformationInputMessage: Encodable {
    let role: String
    let content: [OpenAITextTransformationInputContent]
}

struct OpenAITextTransformationInputContent: Encodable {
    let type: String
    let text: String
}

struct OpenAITextTransformationReasoning: Encodable {
    let effort: String
}

struct OpenAITextTransformationTextConfig: Encodable {
    let format: OpenAITextTransformationTextFormat
    let verbosity: String
}

struct OpenAITextTransformationTextFormat: Encodable {
    let type: String
}

struct OpenAITextTransformationResponse: Decodable {
    let outputText: String?
    let output: [OpenAITextTransformationOutputItem]?

    var firstOutputText: String? {
        output?
            .compactMap { item in
                item.content?.first { $0.type == "output_text" }?.text
            }
            .first
    }

    enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }
}

struct OpenAITextTransformationOutputItem: Decodable {
    let content: [OpenAITextTransformationOutputContent]?
}

struct OpenAITextTransformationOutputContent: Decodable {
    let type: String
    let text: String?
}
