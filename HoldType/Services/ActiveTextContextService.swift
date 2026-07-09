//
//  ActiveTextContextService.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import ApplicationServices
import Foundation
import HoldTypeDomain

@MainActor
protocol ActiveTextContextReading {
    func currentContext(settings: AppSettings) -> TranscriptionPromptContext?
}

struct ActiveTextContextService: ActiveTextContextReading {
    private let accessibilityPermissionService: AccessibilityPermissionService
    private let client: any ActiveTextContextClient
    private let maximumCharacterCount: Int

    init(
        accessibilityPermissionService: AccessibilityPermissionService = AccessibilityPermissionService(),
        client: any ActiveTextContextClient = AXActiveTextContextClient(),
        maximumCharacterCount: Int = TranscriptionPromptContext.defaultMaximumCharacterCount
    ) {
        self.accessibilityPermissionService = accessibilityPermissionService
        self.client = client
        self.maximumCharacterCount = max(1, maximumCharacterCount)
    }

    func currentContext(settings: AppSettings) -> TranscriptionPromptContext? {
        guard settings.useActiveTextContext else {
            return nil
        }

        guard accessibilityPermissionService.currentStatus() == .trusted else {
            return nil
        }

        guard let element = client.focusedTextElement(), !element.isSecure else {
            return nil
        }

        return element.context(maximumCharacterCount: maximumCharacterCount)
    }
}

protocol ActiveTextContextClient {
    func focusedTextElement() -> ActiveTextContextElement?
}

struct ActiveTextContextElement: Equatable {
    let text: String
    let selectedRange: NSRange?
    let isSecure: Bool

    init(text: String, selectedRange: NSRange? = nil, isSecure: Bool = false) {
        self.text = text
        self.selectedRange = selectedRange
        self.isSecure = isSecure
    }

    func context(maximumCharacterCount: Int) -> TranscriptionPromptContext? {
        guard !isSecure else {
            return nil
        }

        return TranscriptionPromptContext(
            textBeforeSelectionOrFullTextSuffix,
            maximumCharacterCount: maximumCharacterCount
        )
    }

    private var textBeforeSelectionOrFullTextSuffix: String {
        guard let selectedRange else {
            return text
        }

        let nsText = text as NSString
        let location = min(max(0, selectedRange.location), nsText.length)
        return nsText.substring(to: location)
    }
}

struct AXActiveTextContextClient: ActiveTextContextClient {
    func focusedTextElement() -> ActiveTextContextElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        guard let focusedElement = copyAXElementAttribute(
            from: systemWideElement,
            attribute: kAXFocusedUIElementAttribute
        ) else {
            return nil
        }

        let subrole = copyStringAttribute(from: focusedElement, attribute: kAXSubroleAttribute)
        guard subrole != (kAXSecureTextFieldSubrole as String) else {
            return ActiveTextContextElement(text: "", isSecure: true)
        }

        guard let text = copyStringAttribute(from: focusedElement, attribute: kAXValueAttribute) else {
            return nil
        }

        return ActiveTextContextElement(
            text: text,
            selectedRange: copySelectedTextRange(from: focusedElement),
            isSecure: false
        )
    }

    private func copyAXElementAttribute(from element: AXUIElement, attribute: String) -> AXUIElement? {
        guard let value = copyAttribute(from: element, attribute: attribute) else {
            return nil
        }

        return (value as! AXUIElement)
    }

    private func copyStringAttribute(from element: AXUIElement, attribute: String) -> String? {
        copyAttribute(from: element, attribute: attribute) as? String
    }

    private func copySelectedTextRange(from element: AXUIElement) -> NSRange? {
        guard let value = copyAttribute(from: element, attribute: kAXSelectedTextRangeAttribute),
              CFGetTypeID(value) == AXValueGetTypeID() else {
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

    private func copyAttribute(from element: AXUIElement, attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else {
            return nil
        }

        return value
    }
}
