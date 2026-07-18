import Foundation

public struct OpenAICredential: Equatable, Sendable {
    public enum ValidationError: Error, Equatable, Sendable {
        case missingAPIKey
    }

    public let apiKey: String

    public init(apiKey: String) throws {
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw ValidationError.missingAPIKey
        }

        self.apiKey = normalizedAPIKey
    }
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

public protocol OpenAICredentialResolving {
    func resolveOpenAICredential() throws -> OpenAICredential
}
