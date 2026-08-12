import Foundation

public enum TextFixReasoningEffort: String, CaseIterable, Equatable, Sendable {
    case low
    case medium
    case high
    case xhigh
    case max
}

public struct TextFixProcessingProfile: Equatable, Sendable {
    public enum Preset: String, CaseIterable, Equatable, Sendable {
        case inherit
        case gpt56Terra = "gpt-5.6-terra"
        case gpt56SolMax = "gpt-5.6-sol-max"
        case custom
    }

    public enum ValidationError: Error, Equatable, Sendable {
        case emptyCustomModel
        case customModelTooLarge(maximumUTF8ByteCount: Int)
    }

    public static let maximumCustomModelUTF8ByteCount = 128
    public static let standardRequestTimeoutSeconds: TimeInterval = 20
    public static let premiumRequestTimeoutSeconds: TimeInterval = 60

    public static let inherit = TextFixProcessingProfile(
        preset: .inherit,
        customModel: nil,
        customReasoningEffort: nil
    )
    public static let gpt56Terra = TextFixProcessingProfile(
        preset: .gpt56Terra,
        customModel: nil,
        customReasoningEffort: nil
    )
    public static let gpt56SolMax = TextFixProcessingProfile(
        preset: .gpt56SolMax,
        customModel: nil,
        customReasoningEffort: nil
    )

    public let preset: Preset
    public let customModel: String?
    public let customReasoningEffort: TextFixReasoningEffort?

    public static func custom(
        model: String,
        reasoningEffort: TextFixReasoningEffort
    ) throws -> TextFixProcessingProfile {
        let normalizedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedModel.isEmpty else {
            throw ValidationError.emptyCustomModel
        }
        guard normalizedModel.utf8.count <= maximumCustomModelUTF8ByteCount else {
            throw ValidationError.customModelTooLarge(
                maximumUTF8ByteCount: maximumCustomModelUTF8ByteCount
            )
        }
        return TextFixProcessingProfile(
            preset: .custom,
            customModel: normalizedModel,
            customReasoningEffort: reasoningEffort
        )
    }

    public func resolved(inheritedModel: String) -> TextFixResolvedProcessingProfile {
        switch preset {
        case .inherit:
            return TextFixResolvedProcessingProfile(
                model: inheritedModel,
                reasoningEffort: .low,
                requestTimeoutSeconds: Self.standardRequestTimeoutSeconds
            )
        case .gpt56Terra:
            return TextFixResolvedProcessingProfile(
                model: "gpt-5.6-terra",
                reasoningEffort: .medium,
                requestTimeoutSeconds: Self.standardRequestTimeoutSeconds
            )
        case .gpt56SolMax:
            return TextFixResolvedProcessingProfile(
                model: "gpt-5.6-sol",
                reasoningEffort: .max,
                requestTimeoutSeconds: Self.premiumRequestTimeoutSeconds
            )
        case .custom:
            return TextFixResolvedProcessingProfile(
                model: customModel ?? inheritedModel,
                reasoningEffort: customReasoningEffort ?? .low,
                requestTimeoutSeconds: Self.standardRequestTimeoutSeconds
            )
        }
    }

    private init(
        preset: Preset,
        customModel: String?,
        customReasoningEffort: TextFixReasoningEffort?
    ) {
        self.preset = preset
        self.customModel = customModel
        self.customReasoningEffort = customReasoningEffort
    }
}

public struct TextFixResolvedProcessingProfile: Equatable, Sendable {
    public let model: String
    public let reasoningEffort: TextFixReasoningEffort
    public let requestTimeoutSeconds: TimeInterval

    public init(
        model: String,
        reasoningEffort: TextFixReasoningEffort,
        requestTimeoutSeconds: TimeInterval
    ) {
        self.model = model
        self.reasoningEffort = reasoningEffort
        self.requestTimeoutSeconds = requestTimeoutSeconds
    }
}
