import Foundation

/// Exact source, prompt, and model values for one user-invoked custom Fix.
public struct TextTransformationRequest:
    Equatable,
    Sendable,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    public enum ValidationError: Error, Equatable, Sendable {
        case emptySource
        case sourceTooLarge(maximumUTF8ByteCount: Int)
        case emptyPrompt
        case promptTooLarge(maximumUTF8ByteCount: Int)
        case emptyModel
    }

    public static let maximumSourceUTF8ByteCount = 32 * 1024
    public static let maximumPromptUTF8ByteCount = 8 * 1024

    public let sourceText: String
    public let prompt: String
    public let model: String

    public init(sourceText: String, prompt: String, model: String) throws {
        guard !sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptySource
        }
        guard sourceText.utf8.count <= Self.maximumSourceUTF8ByteCount else {
            throw ValidationError.sourceTooLarge(
                maximumUTF8ByteCount: Self.maximumSourceUTF8ByteCount
            )
        }
        guard !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyPrompt
        }
        guard prompt.utf8.count <= Self.maximumPromptUTF8ByteCount else {
            throw ValidationError.promptTooLarge(
                maximumUTF8ByteCount: Self.maximumPromptUTF8ByteCount
            )
        }
        guard !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ValidationError.emptyModel
        }

        self.sourceText = sourceText
        self.prompt = prompt
        self.model = model
    }

    public var description: String {
        """
        TextTransformationRequest(sourceText: <redacted>, prompt: <redacted>, \
        modelCharacterCount: \(model.count))
        """
    }

    public var debugDescription: String {
        description
    }

    public var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "sourceText": "<redacted>",
                "prompt": "<redacted>",
                "modelCharacterCount": model.count,
            ]
        )
    }
}
