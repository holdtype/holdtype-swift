import HoldTypeDomain
@_spi(HoldTypeIOSCore) import HoldTypeIOSCore
import HoldTypePersistence

struct IOSVoiceTextFixPresentation: Equatable, Sendable {
    let title: String
    let systemImage: String
    let accessibilityIdentifier: String
    let processingStatus: IOSVoiceStatusPresentation

    static func resolve(
        _ action: TextFixAction
    ) -> IOSVoiceTextFixPresentation {
        let systemImage = systemImage(for: action.icon)
        return IOSVoiceTextFixPresentation(
            title: action.title,
            systemImage: systemImage,
            accessibilityIdentifier: "ios.voice.fixes.action.\(action.id)",
            processingStatus: IOSVoiceStatusPresentation(
                title: processingTitle(for: action.kind),
                detail: "Applying \(action.title) to the reserved Draft text.",
                systemImage: systemImage,
                tone: .active,
                showsProgress: true,
                setupDestination: nil
            )
        )
    }

    static func systemImage(for icon: TextFixIcon) -> String {
        switch icon {
        case .translate:
            "character.bubble"
        case .fix:
            "wand.and.stars"
        case .improveWriting:
            "wand.and.sparkles"
        case .makeShorter:
            "text.alignleft"
        case .summarize:
            "bolt"
        case .bulletPoints:
            "list.bullet"
        case .casual:
            "face.smiling"
        case .markdown:
            "chevron.left.forwardslash.chevron.right"
        case .formal:
            "briefcase"
        case .expand:
            "arrow.left.and.right.text.vertical"
        case .rewrite:
            "arrow.triangle.2.circlepath"
        case .custom:
            "text.badge.plus"
        }
    }

    private static func processingTitle(
        for kind: TextFixActionKind
    ) -> String {
        switch kind {
        case .translate:
            "Translating…"
        case .fix:
            "Fixing…"
        case .customPrompt:
            "Applying Fix…"
        }
    }
}

struct IOSVoiceDraftClearPresentation: Equatable, Sendable {
    let isVisible: Bool
    let isEnabled: Bool

    static func resolve(
        visibleText: String,
        voicePhase: VoiceWorkPhase,
        draftIsBusy: Bool
    ) -> IOSVoiceDraftClearPresentation {
        let isVisible = !visibleText.isEmpty
        let voiceAllowsMutation = switch voicePhase {
        case .inactive, .ready:
            true
        case .arming, .listening, .finalizing, .processing:
            false
        }
        return IOSVoiceDraftClearPresentation(
            isVisible: isVisible,
            isEnabled: isVisible
                && voiceAllowsMutation
                && !draftIsBusy
        )
    }
}

struct IOSVoiceDraftPendingResultPresentation: Equatable, Sendable {
    let title: String
    let detail: String
    let systemImage: String
    let hidesConfirmedText: Bool

    var accessibilityAnnouncement: String {
        "\(title) \(detail)"
    }

    static func resolve(
        _ presentation: IOSForegroundVoicePresentation
    ) -> IOSVoiceDraftPendingResultPresentation? {
        guard let insertionMode = presentation.activeDraftInsertionMode else {
            return nil
        }
        switch presentation.phase {
        case .arming, .listening, .finalizing, .processing:
            break
        case .inactive, .ready:
            return nil
        }

        let voiceStatus = IOSVoiceHomePresentation.resolve(presentation)
        let detail = switch (insertionMode, presentation.phase) {
        case (.replace, .arming), (.replace, .listening):
            "New text will appear here when you finish."
        case (.replace, .finalizing), (.replace, .processing):
            "Your result will appear here."
        case (.append, .arming), (.append, .listening):
            "New text will be added below when you finish."
        case (.append, .finalizing), (.append, .processing):
            "Your result will be added below."
        case (_, .inactive), (_, .ready):
            preconditionFailure("Inactive Voice cannot await a Draft result.")
        }
        return IOSVoiceDraftPendingResultPresentation(
            title: voiceStatus.title,
            detail: detail,
            systemImage: voiceStatus.systemImage,
            hidesConfirmedText: insertionMode == .replace
        )
    }
}

enum IOSVoiceDraftAccessibilityFeedback {
    static let copyAnnouncement = "Current Draft copied"
    static let clearAnnouncement = "Draft cleared. Undo is available."
}
