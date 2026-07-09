import Foundation

public struct OpenAICredential: Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case missingAPIKey
    }

    public let apiKey: String
    public let source: OpenAICredentialSource

    public init(
        apiKey: String,
        source: OpenAICredentialSource = .runtimeStorage
    ) throws {
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw ValidationError.missingAPIKey
        }

        self.apiKey = normalizedAPIKey
        self.source = source
    }
}

public enum OpenAICredentialSource: Equatable, Sendable {
    case runtimeStorage
}

extension OpenAICredential: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "OpenAICredential(<redacted>)"
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [(label: String?, value: Any)](),
            displayStyle: .struct
        )
    }
}

extension OpenAICredentialSource: CustomStringConvertible, CustomDebugStringConvertible, CustomReflectable {
    public var description: String {
        "OpenAICredentialSource(<redacted>)"
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

public protocol OpenAICredentialResolving {
    func resolveOpenAICredential() throws -> OpenAICredential
}
