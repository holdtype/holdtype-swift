import Foundation

public nonisolated enum OpenAITranscriptionRequestBuilderError:
    Error,
    Equatable,
    LocalizedError,
    Sendable {
    case missingAudioFile(URL)
    case emptyAudioFile(URL)
    case unsupportedAudioFileType(String)
    case unreadableAudioFile(URL)
    case audioFileChanged(URL)
    case audioFileTooLarge(byteCount: Int64, maximumExclusive: Int64)
    case multipartMetadataTooLarge(byteCount: Int64, maximum: Int64)
    case multipartBodyTooLarge
    case multipartBodyUnavailable
    case invalidMultipartBoundary
    case invalidCustomLanguageCode(String)
    case audioReaderAlreadyConsumed
    case audioReaderChanged
    case audioReaderUnreadable

    public var errorDescription: String? {
        switch self {
        case .missingAudioFile: "The recording file is missing."
        case .emptyAudioFile: "The recording file is empty."
        case .unsupportedAudioFileType: "The recording format is not supported."
        case .unreadableAudioFile: "The recording file could not be read."
        case .audioFileChanged: "The recording changed while the request was being prepared."
        case .audioFileTooLarge: "The recording is too large to send."
        case .multipartMetadataTooLarge: "The transcription request settings are too large."
        case .multipartBodyTooLarge, .multipartBodyUnavailable, .invalidMultipartBoundary:
            "The transcription request could not be prepared."
        case .invalidCustomLanguageCode: "Use a two- or three-letter custom language code."
        case .audioReaderAlreadyConsumed:
            "The recording reader is no longer available."
        case .audioReaderChanged:
            "The recording changed while the request was being prepared."
        case .audioReaderUnreadable:
            "The recording could not be read."
        }
    }
}

nonisolated extension OpenAITranscriptionRequestBuilderError:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    public var description: String { "OpenAITranscriptionRequestBuilderError(<redacted>)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror {
        Mirror(
            self,
            children: [(label: String?, value: Any)](),
            displayStyle: .enum
        )
    }
}
