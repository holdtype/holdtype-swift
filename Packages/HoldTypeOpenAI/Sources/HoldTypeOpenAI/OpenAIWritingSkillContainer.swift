import Foundation

struct OpenAIWritingSkillContainerRequestPayload: Encodable {
    let name: String
    let skills: [OpenAIInlineWritingSkill]
}

struct OpenAIInlineWritingSkill: Encodable {
    let type: String
    let name: String
    let description: String
    let source: OpenAIInlineWritingSkillSource
}

struct OpenAIInlineWritingSkillSource: Encodable {
    let type: String
    let mediaType: String
    let data: String

    enum CodingKeys: String, CodingKey {
        case type
        case mediaType = "media_type"
        case data
    }
}

struct OpenAIWritingSkillContainerResponse: Decodable {
    let id: String
}

actor OpenAIWritingSkillContainerCache {
    private var cachedContainerID: String?

    func containerID() -> String? {
        cachedContainerID
    }

    func store(containerID: String) {
        cachedContainerID = containerID
    }

    func invalidate(containerID: String) {
        guard cachedContainerID == containerID else {
            return
        }
        cachedContainerID = nil
    }
}

enum BundledWritingSkillArchive {
    static let load: @Sendable () throws -> Data = {
        guard let url = Bundle.module.url(
            forResource: "de-ai-writing",
            withExtension: "zip"
        ) else {
            throw OpenAITextTransformationServiceError.writingSkillUnavailable
        }

        do {
            return try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw OpenAITextTransformationServiceError.writingSkillUnavailable
        }
    }
}
