import Foundation
import HoldTypeDomain

struct FixesPaletteActionPresentation: Equatable, Identifiable {
    static let voicePromptIdentifier = "builtin.voice-prompt"
    static let voicePrompt = FixesPaletteActionPresentation(
        id: voicePromptIdentifier,
        title: "Voice Prompt…",
        systemImageName: "mic"
    )

    let id: String
    let title: String
    let systemImageName: String

    init(
        action: TextFixAction,
        translationTargetLanguageCode: String? = nil
    ) {
        id = action.id
        if action.id == TextFixAction.translateIdentifier,
           let translationTargetLanguageCode {
            title = "Translate to \(translationTargetLanguageCode.uppercased())"
        } else {
            title = action.title
        }
        systemImageName = action.icon.fixesPaletteSystemImageName
    }

    private init(id: String, title: String, systemImageName: String) {
        self.id = id
        self.title = title
        self.systemImageName = systemImageName
    }
}

enum FixesPaletteStatus: Equatable {
    case ready
    case processing(actionID: String)
    case preparingVoicePrompt
    case recordingVoicePrompt
    case transcribingVoicePrompt
    case applyingVoicePrompt
    case unavailable(message: String)
    case failure(message: String, allowsRetry: Bool)
    case staleTarget(message: String)

    var allowsActionActivation: Bool {
        switch self {
        case .ready:
            return true
        case .failure(_, let allowsRetry):
            return allowsRetry
        case .processing,
             .preparingVoicePrompt,
             .recordingVoicePrompt,
             .transcribingVoicePrompt,
             .applyingVoicePrompt,
             .unavailable,
             .staleTarget:
            return false
        }
    }

    var isVoicePromptActive: Bool {
        switch self {
        case .preparingVoicePrompt,
             .recordingVoicePrompt,
             .transcribingVoicePrompt,
             .applyingVoicePrompt:
            return true
        case .ready, .processing, .unavailable, .failure, .staleTarget:
            return false
        }
    }
}

struct FixesPaletteStatusPresentation: Equatable {
    enum Tone: Equatable {
        case neutral
        case warning
        case error
    }

    let title: String
    let message: String?
    let systemImageName: String?
    let tone: Tone
    let showsProgress: Bool
}

extension FixesPaletteStatus {
    func presentation(actionTitle: String?) -> FixesPaletteStatusPresentation? {
        switch self {
        case .ready:
            return nil
        case .processing:
            return FixesPaletteStatusPresentation(
                title: actionTitle.map { "Applying \($0)…" } ?? "Applying Fix…",
                message: nil,
                systemImageName: nil,
                tone: .neutral,
                showsProgress: true
            )
        case .preparingVoicePrompt:
            return FixesPaletteStatusPresentation(
                title: "Preparing Voice Prompt…",
                message: nil,
                systemImageName: nil,
                tone: .neutral,
                showsProgress: true
            )
        case .recordingVoicePrompt:
            return FixesPaletteStatusPresentation(
                title: "Listening…",
                message: "Speak your instruction, then press Return to stop.",
                systemImageName: "mic.fill",
                tone: .neutral,
                showsProgress: false
            )
        case .transcribingVoicePrompt:
            return FixesPaletteStatusPresentation(
                title: "Transcribing instruction…",
                message: nil,
                systemImageName: nil,
                tone: .neutral,
                showsProgress: true
            )
        case .applyingVoicePrompt:
            return FixesPaletteStatusPresentation(
                title: "Applying instruction…",
                message: nil,
                systemImageName: nil,
                tone: .neutral,
                showsProgress: true
            )
        case .unavailable(let message):
            return FixesPaletteStatusPresentation(
                title: "Fixes Unavailable",
                message: message,
                systemImageName: "exclamationmark.circle",
                tone: .warning,
                showsProgress: false
            )
        case .failure(let message, _):
            return FixesPaletteStatusPresentation(
                title: "Fix Failed",
                message: message,
                systemImageName: "exclamationmark.triangle",
                tone: .error,
                showsProgress: false
            )
        case .staleTarget(let message):
            return FixesPaletteStatusPresentation(
                title: "Text Changed",
                message: message,
                systemImageName: "arrow.triangle.2.circlepath",
                tone: .warning,
                showsProgress: false
            )
        }
    }
}

extension TextFixIcon {
    var fixesPaletteSystemImageName: String {
        switch self {
        case .translate:
            return "character.bubble"
        case .fix:
            return "checkmark.seal"
        case .improveWriting:
            return "wand.and.stars"
        case .makeShorter:
            return "text.alignleft"
        case .summarize:
            return "doc.text"
        case .bulletPoints:
            return "list.bullet"
        case .casual:
            return "face.smiling"
        case .markdown:
            return "chevron.left.forwardslash.chevron.right"
        case .formal:
            return "briefcase"
        case .expand:
            return "arrow.up.left.and.arrow.down.right"
        case .rewrite:
            return "arrow.triangle.2.circlepath"
        case .custom:
            return "sparkles"
        }
    }
}
