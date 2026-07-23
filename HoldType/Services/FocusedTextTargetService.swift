import ApplicationServices
import CoreGraphics
import Foundation

enum FocusedTextSourceKind: Equatable {
    case selection
    case completeField
}

final class FocusedTextElementToken: @unchecked Sendable, Hashable {
    let rawElement: AXUIElement?

    init() {
        rawElement = nil
    }

    init(rawElement: AXUIElement) {
        self.rawElement = rawElement
    }

    static func == (
        lhs: FocusedTextElementToken,
        rhs: FocusedTextElementToken
    ) -> Bool {
        lhs === rhs
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}

struct FocusedTextElementState:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    let token: FocusedTextElementToken
    let processIdentifier: pid_t
    let text: String
    let selectedRange: NSRange?
    let anchorRect: CGRect?
    let isSecure: Bool

    var description: String {
        "FocusedTextElementState(text: <redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "processIdentifier": processIdentifier,
                "selectedRange": selectedRange as Any,
                "isSecure": isSecure,
                "text": "<redacted>",
            ]
        )
    }
}

struct FocusedTextTargetSnapshot:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    let id: UUID
    let token: FocusedTextElementToken
    let processIdentifier: pid_t
    let sourceKind: FocusedTextSourceKind
    let sourceText: String
    let replacementRange: NSRange
    let capturedSelectedRange: NSRange?
    let anchorRect: CGRect?

    var description: String {
        "FocusedTextTargetSnapshot(id: \(id), source: <redacted>)"
    }

    var debugDescription: String {
        description
    }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [
                "id": id,
                "processIdentifier": processIdentifier,
                "sourceKind": String(describing: sourceKind),
                "replacementRange": replacementRange,
                "sourceText": "<redacted>",
            ]
        )
    }
}

enum FocusedTextTargetError: Error, Equatable, LocalizedError {
    case accessibilityNotTrusted
    case unavailable
    case holdTypeOwnsFocus
    case secureField
    case invalidRange
    case blankSource
    case sourceTooLarge
    case stale
    case focusRestorationFailed
    case cancelled
    case replacementTimedOut
    case replacementFailed

    var errorDescription: String? {
        switch self {
        case .accessibilityNotTrusted:
            return "Accessibility permission is needed to use Fixes."
        case .unavailable:
            return "Fixes is not available for this text field."
        case .holdTypeOwnsFocus:
            return "Choose text in another app before opening Fixes."
        case .secureField:
            return "Fixes is not available in secure text fields."
        case .invalidRange:
            return "The current text selection is not available."
        case .blankSource:
            return "Select or enter some text before using Fixes."
        case .sourceTooLarge:
            return "This text is too large for one Fix."
        case .stale:
            return "The text changed before the Fix could be applied."
        case .focusRestorationFailed:
            return "HoldType could not return to the original text field."
        case .cancelled:
            return "The Fix request was cancelled."
        case .replacementTimedOut:
            return "Applying the Fix timed out."
        case .replacementFailed:
            return "HoldType could not replace the original text."
        }
    }
}

@MainActor
protocol FocusedTextTargetClient: AnyObject {
    func focusedElement() -> FocusedTextElementState?
    func currentState(for token: FocusedTextElementToken) -> FocusedTextElementState?
    func focus(_ token: FocusedTextElementToken) -> Bool
    func setSelectedRange(
        _ range: NSRange,
        for token: FocusedTextElementToken
    ) -> Bool
    func isFocused(_ token: FocusedTextElementToken) -> Bool
}

@MainActor
struct FocusedTextTargetService {
    static let maximumSourceByteCount = 32 * 1_024

    private let accessibilityPermissionService: AccessibilityPermissionService
    private let client: any FocusedTextTargetClient
    private let holdTypeProcessIdentifier: pid_t

    init() {
        self.init(
            accessibilityPermissionService: AccessibilityPermissionService(),
            client: AXFocusedTextTargetClient(),
            holdTypeProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
    }

    init(
        accessibilityPermissionService: AccessibilityPermissionService,
        client: any FocusedTextTargetClient,
        holdTypeProcessIdentifier: pid_t
    ) {
        self.accessibilityPermissionService = accessibilityPermissionService
        self.client = client
        self.holdTypeProcessIdentifier = holdTypeProcessIdentifier
    }

    func capture() throws -> FocusedTextTargetSnapshot {
        guard accessibilityPermissionService.currentStatus() == .trusted else {
            throw FocusedTextTargetError.accessibilityNotTrusted
        }
        guard let state = client.focusedElement() else {
            throw FocusedTextTargetError.unavailable
        }

        return try makeSnapshot(from: state)
    }

    func validate(_ snapshot: FocusedTextTargetSnapshot) throws {
        guard let state = client.currentState(for: snapshot.token) else {
            throw FocusedTextTargetError.stale
        }
        try validate(snapshot, against: state)
    }

    func validateFocusedReplacementRange(
        _ snapshot: FocusedTextTargetSnapshot
    ) throws {
        guard client.isFocused(snapshot.token),
              let state = client.currentState(for: snapshot.token),
              state.selectedRange == snapshot.replacementRange
        else {
            throw FocusedTextTargetError.stale
        }
        try validateSource(snapshot, in: state)
    }

    func restoreFocusAndReplacementRange(
        for snapshot: FocusedTextTargetSnapshot
    ) throws {
        guard (client.isFocused(snapshot.token) || client.focus(snapshot.token)),
              client.setSelectedRange(
                snapshot.replacementRange,
                for: snapshot.token
              )
        else {
            throw FocusedTextTargetError.focusRestorationFailed
        }
    }

    private func makeSnapshot(
        from state: FocusedTextElementState
    ) throws -> FocusedTextTargetSnapshot {
        guard state.processIdentifier != holdTypeProcessIdentifier else {
            throw FocusedTextTargetError.holdTypeOwnsFocus
        }
        guard !state.isSecure else {
            throw FocusedTextTargetError.secureField
        }

        let textLength = (state.text as NSString).length
        let selectedRange = try validatedRange(
            state.selectedRange,
            textLength: textLength
        )
        let sourceKind: FocusedTextSourceKind
        let replacementRange: NSRange

        if let selectedRange, selectedRange.length > 0 {
            sourceKind = .selection
            replacementRange = selectedRange
        } else {
            sourceKind = .completeField
            replacementRange = NSRange(location: 0, length: textLength)
        }

        let sourceText = (state.text as NSString).substring(
            with: replacementRange
        )
        guard !sourceText.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            throw FocusedTextTargetError.blankSource
        }
        guard sourceText.utf8.count <= Self.maximumSourceByteCount else {
            throw FocusedTextTargetError.sourceTooLarge
        }

        return FocusedTextTargetSnapshot(
            id: UUID(),
            token: state.token,
            processIdentifier: state.processIdentifier,
            sourceKind: sourceKind,
            sourceText: sourceText,
            replacementRange: replacementRange,
            capturedSelectedRange: state.selectedRange,
            anchorRect: state.anchorRect
        )
    }

    private func validate(
        _ snapshot: FocusedTextTargetSnapshot,
        against state: FocusedTextElementState
    ) throws {
        guard !state.isSecure,
              state.processIdentifier == snapshot.processIdentifier,
              state.selectedRange == snapshot.capturedSelectedRange
        else {
            throw FocusedTextTargetError.stale
        }
        try validateSource(snapshot, in: state)
    }

    private func validateSource(
        _ snapshot: FocusedTextTargetSnapshot,
        in state: FocusedTextElementState
    ) throws {
        let text = state.text as NSString
        guard snapshot.replacementRange.location >= 0,
              snapshot.replacementRange.length >= 0,
              NSMaxRange(snapshot.replacementRange) <= text.length,
              text.substring(with: snapshot.replacementRange)
                == snapshot.sourceText
        else {
            throw FocusedTextTargetError.stale
        }
    }

    private func validatedRange(
        _ range: NSRange?,
        textLength: Int
    ) throws -> NSRange? {
        guard let range else {
            return nil
        }
        guard range.location >= 0,
              range.length >= 0,
              NSMaxRange(range) <= textLength
        else {
            throw FocusedTextTargetError.invalidRange
        }
        return range
    }
}
