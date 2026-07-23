import CoreGraphics
import Foundation
import Testing
@testable import HoldType

@MainActor
struct FocusedTextTargetServiceTests {
    @Test func capturesExactUnicodeSelection() throws {
        let token = FocusedTextElementToken()
        let client = FakeFocusedTextTargetClient(
            state: state(
                token: token,
                text: "Hi 👋 world",
                selectedRange: NSRange(location: 3, length: 2)
            )
        )

        let snapshot = try makeService(client: client).capture()

        #expect(snapshot.token == token)
        #expect(snapshot.sourceKind == .selection)
        #expect(snapshot.sourceText == "👋")
        #expect(snapshot.replacementRange == NSRange(location: 3, length: 2))
        #expect(snapshot.capturedSelectedRange == NSRange(location: 3, length: 2))
        #expect(snapshot.anchorRect == CGRect(x: 10, y: 20, width: 30, height: 40))
        #expect(!String(describing: snapshot).contains("👋"))
        #expect(!String(reflecting: snapshot).contains("👋"))
    }

    @Test func emptySelectionCapturesCompleteField() throws {
        let client = FakeFocusedTextTargetClient(
            state: state(
                text: "Complete field",
                selectedRange: NSRange(location: 4, length: 0)
            )
        )

        let snapshot = try makeService(client: client).capture()

        #expect(snapshot.sourceKind == .completeField)
        #expect(snapshot.sourceText == "Complete field")
        #expect(
            snapshot.replacementRange
                == NSRange(location: 0, length: ("Complete field" as NSString).length)
        )
        #expect(snapshot.capturedSelectedRange == NSRange(location: 4, length: 0))
    }

    @Test func missingSelectionAttributeCapturesCompleteField() throws {
        let client = FakeFocusedTextTargetClient(
            state: state(text: "Complete", selectedRange: nil)
        )

        let snapshot = try makeService(client: client).capture()

        #expect(snapshot.sourceKind == .completeField)
        #expect(snapshot.sourceText == "Complete")
        #expect(snapshot.capturedSelectedRange == nil)
    }

    @Test func captureFailsClosedForPermissionAndUnsupportedTargets() {
        let client = FakeFocusedTextTargetClient(state: state(text: "Text"))
        #expect(throws: FocusedTextTargetError.accessibilityNotTrusted) {
            try makeService(client: client, isTrusted: false).capture()
        }

        client.state = nil
        #expect(throws: FocusedTextTargetError.unavailable) {
            try makeService(client: client).capture()
        }

        client.state = state(text: "Text", processIdentifier: 99)
        #expect(throws: FocusedTextTargetError.holdTypeOwnsFocus) {
            try makeService(
                client: client,
                holdTypeProcessIdentifier: 99
            ).capture()
        }

        client.state = state(text: "", isSecure: true)
        #expect(throws: FocusedTextTargetError.secureField) {
            try makeService(client: client).capture()
        }
    }

    @Test func captureRejectsInvalidBlankAndOversizedSources() {
        let client = FakeFocusedTextTargetClient(
            state: state(
                text: "short",
                selectedRange: NSRange(location: 5, length: 1)
            )
        )
        #expect(throws: FocusedTextTargetError.invalidRange) {
            try makeService(client: client).capture()
        }

        client.state = state(text: " \n\t")
        #expect(throws: FocusedTextTargetError.blankSource) {
            try makeService(client: client).capture()
        }

        client.state = state(
            text: String(
                repeating: "a",
                count: FocusedTextTargetService.maximumSourceByteCount + 1
            )
        )
        #expect(throws: FocusedTextTargetError.sourceTooLarge) {
            try makeService(client: client).capture()
        }
    }

    @Test func validationRejectsChangedTextRangeSelectionAndProcess() throws {
        let token = FocusedTextElementToken()
        let client = FakeFocusedTextTargetClient(
            state: state(
                token: token,
                text: "Hello world",
                selectedRange: NSRange(location: 6, length: 5)
            )
        )
        let service = makeService(client: client)
        let snapshot = try service.capture()

        try service.validate(snapshot)

        client.state = state(
            token: token,
            text: "Hello Swift",
            selectedRange: NSRange(location: 6, length: 5)
        )
        #expect(throws: FocusedTextTargetError.stale) {
            try service.validate(snapshot)
        }

        client.state = state(
            token: token,
            text: "Hello world",
            selectedRange: NSRange(location: 0, length: 5)
        )
        #expect(throws: FocusedTextTargetError.stale) {
            try service.validate(snapshot)
        }

        client.state = state(
            token: token,
            text: "Hello world",
            selectedRange: NSRange(location: 6, length: 5),
            processIdentifier: 202
        )
        #expect(throws: FocusedTextTargetError.stale) {
            try service.validate(snapshot)
        }
    }

    @Test func focusRestorationSelectsCapturedReplacementRange() throws {
        let token = FocusedTextElementToken()
        let client = FakeFocusedTextTargetClient(
            state: state(
                token: token,
                text: "Hello world",
                selectedRange: NSRange(location: 6, length: 5)
            )
        )
        let service = makeService(client: client)
        let snapshot = try service.capture()

        try service.restoreFocusAndReplacementRange(for: snapshot)

        #expect(client.focusedTokens == [token])
        #expect(
            client.selectedRanges
                == [NSRange(location: 6, length: 5)]
        )
        try service.validateFocusedReplacementRange(snapshot)
    }

    @Test func focusRestorationFailsWithoutMutatingRange() throws {
        let client = FakeFocusedTextTargetClient(state: state(text: "Hello"))
        client.shouldFocus = false
        let service = makeService(client: client)
        let snapshot = try service.capture()

        #expect(throws: FocusedTextTargetError.focusRestorationFailed) {
            try service.restoreFocusAndReplacementRange(for: snapshot)
        }
        #expect(client.selectedRanges.isEmpty)
    }

    private func makeService(
        client: FakeFocusedTextTargetClient,
        isTrusted: Bool = true,
        holdTypeProcessIdentifier: pid_t = 999
    ) -> FocusedTextTargetService {
        FocusedTextTargetService(
            accessibilityPermissionService: AccessibilityPermissionService(
                client: FakeFocusedTextPermissionClient(isTrusted: isTrusted)
            ),
            client: client,
            holdTypeProcessIdentifier: holdTypeProcessIdentifier
        )
    }

    private func state(
        token: FocusedTextElementToken = FocusedTextElementToken(),
        text: String,
        selectedRange: NSRange? = nil,
        processIdentifier: pid_t = 101,
        isSecure: Bool = false
    ) -> FocusedTextElementState {
        FocusedTextElementState(
            token: token,
            processIdentifier: processIdentifier,
            text: text,
            selectedRange: selectedRange,
            anchorRect: CGRect(x: 10, y: 20, width: 30, height: 40),
            isSecure: isSecure
        )
    }
}

@MainActor
private final class FakeFocusedTextTargetClient: FocusedTextTargetClient {
    var state: FocusedTextElementState?
    var shouldFocus = true
    var shouldSetSelectedRange = true
    private(set) var focusedTokens: [FocusedTextElementToken] = []
    private(set) var selectedRanges: [NSRange] = []

    init(state: FocusedTextElementState?) {
        self.state = state
    }

    func focusedElement() -> FocusedTextElementState? {
        state
    }

    func currentState(
        for token: FocusedTextElementToken
    ) -> FocusedTextElementState? {
        guard state?.token == token else {
            return nil
        }
        return state
    }

    func focus(_ token: FocusedTextElementToken) -> Bool {
        guard shouldFocus else {
            return false
        }
        focusedTokens.append(token)
        return true
    }

    func setSelectedRange(
        _ range: NSRange,
        for token: FocusedTextElementToken
    ) -> Bool {
        guard shouldSetSelectedRange, state?.token == token else {
            return false
        }
        selectedRanges.append(range)
        if let current = state {
            state = FocusedTextElementState(
                token: current.token,
                processIdentifier: current.processIdentifier,
                text: current.text,
                selectedRange: range,
                anchorRect: current.anchorRect,
                isSecure: current.isSecure
            )
        }
        return true
    }

    func isFocused(_ token: FocusedTextElementToken) -> Bool {
        focusedTokens.last == token
    }
}

private final class FakeFocusedTextPermissionClient:
    AccessibilityPermissionClient {
    private let isTrusted: Bool

    init(isTrusted: Bool) {
        self.isTrusted = isTrusted
    }

    func isProcessTrusted(promptIfNeeded: Bool) -> Bool {
        isTrusted
    }

    func openAccessibilitySettings() -> Bool {
        false
    }
}
