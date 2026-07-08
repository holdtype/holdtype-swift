//
//  SettingsTechnicalTextInputTests.swift
//  HoldTypeTests
//
//  Created by Codex on 7/6/26.
//

import AppKit
import Testing
@testable import HoldType

struct SettingsTechnicalTextInputTests {

    @MainActor
    @Test func textFieldFormattingForcesLeadingLeftToRightEditing() {
        let textField = NSTextField()
        textField.alignment = .right
        textField.baseWritingDirection = .rightToLeft
        textField.cell?.alignment = .right
        textField.cell?.baseWritingDirection = .rightToLeft
        textField.isEditable = false

        SettingsTechnicalTextFieldFormatting.apply(to: textField, isEnabled: true)

        #expect(textField.alignment == .left)
        #expect(textField.baseWritingDirection == .leftToRight)
        #expect(textField.cell?.alignment == .left)
        #expect(textField.cell?.baseWritingDirection == .leftToRight)
        #expect(textField.isEditable)
        #expect(textField.isSelectable)
    }

    @MainActor
    @Test func disabledTextFieldFormattingKeepsSelectableButNotEditable() {
        let textField = NSTextField()

        SettingsTechnicalTextFieldFormatting.apply(to: textField, isEnabled: false)

        #expect(textField.alignment == .left)
        #expect(textField.baseWritingDirection == .leftToRight)
        #expect(textField.isEditable == false)
        #expect(textField.isSelectable)
    }

    @MainActor
    @Test func textAreaFormattingForcesLeadingLeftToRightEditing() throws {
        let textView = NSTextView()
        textView.alignment = .center
        textView.baseWritingDirection = .rightToLeft
        textView.isEditable = false

        SettingsTechnicalTextFormatting.apply(to: textView, isEnabled: true)

        #expect(textView.alignment == .left)
        #expect(textView.baseWritingDirection == .leftToRight)
        #expect(textView.isEditable)
        #expect(textView.textContainer?.lineFragmentPadding == 0)
        #expect(textView.textContainerInset == NSSize(width: 8, height: 6))

        let paragraphStyle = try #require(
            textView.typingAttributes[.paragraphStyle] as? NSParagraphStyle
        )
        #expect(paragraphStyle.alignment == .left)
        #expect(paragraphStyle.baseWritingDirection == .leftToRight)
    }

    @MainActor
    @Test func disabledTextAreaFormattingKeepsSelectableButNotEditable() {
        let textView = NSTextView()

        SettingsTechnicalTextFormatting.apply(to: textView, isEnabled: false)

        #expect(textView.alignment == .left)
        #expect(textView.baseWritingDirection == .leftToRight)
        #expect(textView.isEditable == false)
        #expect(textView.isSelectable)
    }
}
