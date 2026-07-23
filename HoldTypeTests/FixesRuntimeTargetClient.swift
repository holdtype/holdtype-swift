import Foundation
@testable import HoldType

@MainActor
final class FixesRuntimeTargetClient: FocusedTextTargetClient {
    private var focusedState: FocusedTextElementState?
    private var knownStates: [FocusedTextElementToken: FocusedTextElementState]
    private(set) var focusedElementCallCount = 0

    var state: FocusedTextElementState? {
        get {
            focusedState
        }
        set {
            focusedState = newValue
            if let newValue {
                knownStates[newValue.token] = newValue
            }
        }
    }

    init(state: FocusedTextElementState) {
        focusedState = state
        knownStates = [state.token: state]
    }

    func focusedElement() -> FocusedTextElementState? {
        focusedElementCallCount += 1
        return focusedState
    }

    func currentState(
        for token: FocusedTextElementToken
    ) -> FocusedTextElementState? {
        knownStates[token]
    }

    func focus(_ token: FocusedTextElementToken) -> Bool {
        guard let state = knownStates[token] else {
            return false
        }
        focusedState = state
        return true
    }

    func setSelectedRange(
        _ range: NSRange,
        for token: FocusedTextElementToken
    ) -> Bool {
        knownStates[token]?.selectedRange == range
    }

    func isFocused(_ token: FocusedTextElementToken) -> Bool {
        focusedState?.token == token
    }

    func replaceText(_ text: String) {
        guard let focusedState else {
            return
        }
        state = FocusedTextElementState(
            token: focusedState.token,
            processIdentifier: focusedState.processIdentifier,
            text: text,
            selectedRange: focusedState.selectedRange,
            anchorRect: focusedState.anchorRect,
            isSecure: focusedState.isSecure
        )
    }

    func focusHoldTypeElement() {
        state = FocusedTextElementState(
            token: FocusedTextElementToken(),
            processIdentifier: 999,
            text: "HoldType editor",
            selectedRange: NSRange(location: 0, length: 0),
            anchorRect: nil,
            isSecure: false
        )
    }

    func focusSecureExternalElement() {
        state = FocusedTextElementState(
            token: FocusedTextElementToken(),
            processIdentifier: 202,
            text: "secret",
            selectedRange: NSRange(location: 0, length: 0),
            anchorRect: nil,
            isSecure: true
        )
    }
}
