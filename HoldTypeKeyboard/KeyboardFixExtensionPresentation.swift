import Foundation

struct KeyboardFixExtensionTarget: Equatable, Sendable {
    let documentIdentifier: String
    let selectedText: String

    var fingerprint: String {
        KeyboardFixSourceFingerprint.make(for: selectedText)
    }

    func matches(_ identity: KeyboardFixRequestIdentity) -> Bool {
        identity.sourceKind == .selection
            && identity.documentIdentifier == documentIdentifier
            && KeyboardFixSourceFingerprint.matches(
                identity.sourceFingerprint,
                sourceText: selectedText
            )
    }
}

enum KeyboardFixExtensionStatus: Equatable, Sendable {
    case ready
    case unavailable(message: String)
    case processing(actionIdentifier: String)
    case cancelling(actionIdentifier: String)
    case failure(message: String)
    case applied(message: String)

    var message: String? {
        switch self {
        case .ready:
            nil
        case .unavailable(let message),
             .failure(let message),
             .applied(let message):
            message
        case .processing:
            "Applying Fix…"
        case .cancelling:
            "Cancelling Fix…"
        }
    }

    var allowsActionActivation: Bool {
        switch self {
        case .ready, .failure, .applied:
            true
        case .unavailable, .processing, .cancelling:
            false
        }
    }
}

struct KeyboardFixExtensionPresentation: Equatable, Sendable {
    let actions: [KeyboardFixMetadataAction]
    let status: KeyboardFixExtensionStatus

    static let unavailable = KeyboardFixExtensionPresentation(
        actions: [],
        status: .unavailable(
            message: "Open HoldType to make Fixes available."
        )
    )

    var enabledActions: [KeyboardFixMetadataAction] {
        actions.filter(\.isEnabled)
    }

    func isActionEnabled(_ identifier: String) -> Bool {
        status.allowsActionActivation
            && actions.contains {
                $0.identifier == identifier && $0.isEnabled
            }
    }
}

extension KeyboardFixFailureCode {
    var keyboardMessage: String {
        switch self {
        case .actionUnavailable:
            "This Fix is no longer available."
        case .consentRequired:
            "Review OpenAI processing consent in HoldType."
        case .credentialUnavailable:
            "Add your OpenAI key in HoldType."
        case .translationUnavailable:
            "Choose a translation language in HoldType."
        case .providerFailed:
            "The Fix could not be completed."
        case .timedOut:
            "The Fix timed out. Try again."
        case .cancelled:
            "The Fix was cancelled."
        case .invalidOutput:
            "The Fix returned an invalid result."
        case .requestInvalid:
            "The selected text changed. Select it again."
        case .sourceTooLarge:
            "This selection is too large for one Fix."
        case .persistenceFailed:
            "HoldType could not exchange this Fix."
        }
    }
}

extension KeyboardFixIconToken {
    var systemImageName: String {
        switch self {
        case .translate:
            "character.bubble"
        case .fix:
            "text.badge.checkmark"
        case .improveWriting:
            "wand.and.stars"
        case .makeShorter:
            "text.line.last.and.arrowtriangle.forward"
        case .summarize:
            "text.alignleft"
        case .bulletPoints:
            "list.bullet"
        case .casual:
            "bubble.left.and.bubble.right"
        case .markdown:
            "chevron.left.forwardslash.chevron.right"
        case .formal:
            "briefcase"
        case .expand:
            "arrow.up.left.and.arrow.down.right"
        case .rewrite:
            "arrow.triangle.2.circlepath"
        case .custom:
            "sparkles"
        }
    }
}
