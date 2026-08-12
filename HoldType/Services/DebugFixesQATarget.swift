#if DEBUG
import CoreGraphics
import Foundation

@MainActor
enum DebugFixesQATargetFixture {
    static func makeTargetService() -> FocusedTextTargetService {
        let client = DebugFixesQATargetClient()
        return FocusedTextTargetService(
            accessibilityPermissionService: AccessibilityPermissionService(
                client: DebugFixesQATrustedPermissionClient()
            ),
            client: client,
            holdTypeProcessIdentifier: ProcessInfo.processInfo.processIdentifier
        )
    }
}

private struct DebugFixesQATrustedPermissionClient:
    AccessibilityPermissionClient {
    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        true
    }

    func openAccessibilitySettings() -> Bool {
        false
    }
}

@MainActor
private final class DebugFixesQATargetClient: FocusedTextTargetClient {
    private let token = FocusedTextElementToken()
    private let sourceText = "Controlled Fixes QA source."

    func focusedElement() -> FocusedTextElementState? {
        state()
    }

    func currentState(
        for token: FocusedTextElementToken
    ) -> FocusedTextElementState? {
        guard token == self.token else {
            return nil
        }
        return state()
    }

    func focus(_ token: FocusedTextElementToken) -> Bool {
        token == self.token
    }

    func setSelectedRange(
        _ range: NSRange,
        for token: FocusedTextElementToken
    ) -> Bool {
        token == self.token
            && range == NSRange(location: 0, length: (sourceText as NSString).length)
    }

    func isFocused(_ token: FocusedTextElementToken) -> Bool {
        token == self.token
    }

    private func state() -> FocusedTextElementState {
        FocusedTextElementState(
            token: token,
            processIdentifier: ProcessInfo.processInfo.processIdentifier + 1,
            text: sourceText,
            selectedRange: nil,
            anchorRect: CGRect(x: 480, y: 360, width: 1, height: 1),
            isSecure: false
        )
    }
}

@MainActor
struct DebugFixesQASyntheticReplacementService:
    FocusedTextReplacing {
    func replace(
        snapshot: FocusedTextTargetSnapshot,
        with output: String
    ) async throws {
        guard !output.isEmpty else {
            throw FocusedTextTargetError.replacementFailed
        }
    }
}
#endif
