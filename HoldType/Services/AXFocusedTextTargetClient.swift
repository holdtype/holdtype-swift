import ApplicationServices
import CoreGraphics
import Foundation

@MainActor
final class AXFocusedTextTargetClient: FocusedTextTargetClient {
    func focusedElement() -> FocusedTextElementState? {
        guard let element = copyFocusedElement() else {
            return nil
        }

        return makeState(
            from: element,
            token: FocusedTextElementToken(rawElement: element)
        )
    }

    func currentState(
        for token: FocusedTextElementToken
    ) -> FocusedTextElementState? {
        guard let element = token.rawElement else {
            return nil
        }

        return makeState(from: element, token: token)
    }

    func focus(_ token: FocusedTextElementToken) -> Bool {
        guard let element = token.rawElement else {
            return false
        }
        return AXUIElementSetAttributeValue(
            element,
            kAXFocusedAttribute as CFString,
            kCFBooleanTrue
        ) == .success
    }

    func setSelectedRange(
        _ range: NSRange,
        for token: FocusedTextElementToken
    ) -> Bool {
        guard let element = token.rawElement else {
            return false
        }

        var cfRange = CFRange(
            location: range.location,
            length: range.length
        )
        guard let value = AXValueCreate(.cfRange, &cfRange) else {
            return false
        }
        return AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            value
        ) == .success
    }

    func isFocused(_ token: FocusedTextElementToken) -> Bool {
        guard let tokenElement = token.rawElement,
              let focusedElement = copyFocusedElement()
        else {
            return false
        }
        return CFEqual(tokenElement, focusedElement)
    }

    private func makeState(
        from element: AXUIElement,
        token: FocusedTextElementToken
    ) -> FocusedTextElementState? {
        var processIdentifier = pid_t()
        guard AXUIElementGetPid(element, &processIdentifier) == .success else {
            return nil
        }

        let subrole = copyStringAttribute(
            from: element,
            attribute: kAXSubroleAttribute
        )
        if subrole == (kAXSecureTextFieldSubrole as String) {
            return FocusedTextElementState(
                token: token,
                processIdentifier: processIdentifier,
                text: "",
                selectedRange: nil,
                anchorRect: nil,
                isSecure: true
            )
        }

        guard let text = copyStringAttribute(
            from: element,
            attribute: kAXValueAttribute
        ) else {
            return nil
        }
        let selectedRange = copySelectedTextRange(from: element)
        let anchorRange = selectedRange ?? NSRange(
            location: (text as NSString).length,
            length: 0
        )

        return FocusedTextElementState(
            token: token,
            processIdentifier: processIdentifier,
            text: text,
            selectedRange: selectedRange,
            anchorRect: copyBounds(for: anchorRange, from: element),
            isSecure: false
        )
    }

    private func copyFocusedElement() -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        guard let value = copyAttribute(
            from: systemWideElement,
            attribute: kAXFocusedUIElementAttribute
        ) else {
            return nil
        }
        return (value as! AXUIElement)
    }

    private func copyStringAttribute(
        from element: AXUIElement,
        attribute: String
    ) -> String? {
        copyAttribute(from: element, attribute: attribute) as? String
    }

    private func copySelectedTextRange(
        from element: AXUIElement
    ) -> NSRange? {
        guard let value = copyAttribute(
            from: element,
            attribute: kAXSelectedTextRangeAttribute
        ),
        CFGetTypeID(value) == AXValueGetTypeID()
        else {
            return nil
        }

        let axValue = value as! AXValue
        guard AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }
        return NSRange(location: range.location, length: range.length)
    }

    private func copyBounds(
        for range: NSRange,
        from element: AXUIElement
    ) -> CGRect? {
        var cfRange = CFRange(
            location: range.location,
            length: range.length
        )
        guard let rangeValue = AXValueCreate(.cfRange, &cfRange) else {
            return nil
        }

        var rawBounds: CFTypeRef?
        let error = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &rawBounds
        )
        guard error == .success,
              let rawBounds,
              CFGetTypeID(rawBounds) == AXValueGetTypeID()
        else {
            return nil
        }

        let boundsValue = rawBounds as! AXValue
        guard AXValueGetType(boundsValue) == .cgRect else {
            return nil
        }

        var bounds = CGRect.zero
        guard AXValueGetValue(boundsValue, .cgRect, &bounds) else {
            return nil
        }
        return bounds
    }

    private func copyAttribute(
        from element: AXUIElement,
        attribute: String
    ) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )
        guard error == .success else {
            return nil
        }
        return value
    }
}
