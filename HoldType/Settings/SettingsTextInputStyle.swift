//
//  SettingsTextInputStyle.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import AppKit
import SwiftUI

struct SettingsTechnicalTextArea: View {
    let title: String
    @Binding var text: String
    var minLines: Int
    var maxLines: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)

            SettingsTechnicalTextAreaInput(
                placeholder: title,
                text: $text,
                minLines: minLines,
                maxLines: maxLines
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct SettingsTechnicalPromptTextArea<Accessory: View>: View {
    let title: String
    @Binding var text: String
    var minLines: Int
    var maxLines: Int
    @ViewBuilder let accessory: () -> Accessory

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                Text(title)

                Spacer(minLength: 12)

                accessory()
            }

            SettingsTechnicalTextAreaInput(
                placeholder: title,
                text: $text,
                minLines: minLines,
                maxLines: maxLines
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct SettingsTechnicalTextField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        LabeledContent(title) {
            SettingsTechnicalTextFieldInput(
                placeholder: title,
                text: $text
            )
        }
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct SettingsTechnicalTextFieldInput: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        SettingsTechnicalTextFieldRepresentable(
            text: $text,
            placeholder: placeholder,
            isEnabled: isEnabled,
            isSecure: false
        )
        .frame(height: 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct SettingsTechnicalSecureFieldInput: View {
    @Binding var text: String

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        SettingsTechnicalTextFieldRepresentable(
            text: $text,
            placeholder: "",
            isEnabled: isEnabled,
            isSecure: true
        )
        .frame(height: 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
    }
}

struct SettingsTechnicalTextAreaInput: View {
    let placeholder: String
    @Binding var text: String
    var minLines: Int = 2
    var maxLines: Int = 4

    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        SettingsTechnicalTextAreaRepresentable(
            text: $text,
            isEnabled: isEnabled
        )
        .frame(height: Self.height(forLineCount: max(minLines, maxLines)))
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
        }
        .overlay(alignment: .topLeading) {
            if text.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 7)
                    .allowsHitTesting(false)
            }
        }
        .opacity(isEnabled ? 1 : 0.6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.layoutDirection, .leftToRight)
    }

    private static func height(forLineCount lineCount: Int) -> CGFloat {
        let font = NSFont.preferredFont(forTextStyle: .body)
        let lineHeight = font.ascender - font.descender + font.leading
        return ceil(lineHeight * CGFloat(max(1, lineCount))) + 14
    }
}

struct SettingsTechnicalTextFieldFormatting {
    static func apply(to textField: NSTextField, isEnabled: Bool) {
        textField.alignment = .left
        textField.baseWritingDirection = .leftToRight
        textField.isEnabled = isEnabled
        textField.isEditable = isEnabled
        textField.isSelectable = true
        textField.font = NSFont.preferredFont(forTextStyle: .body)
        textField.textColor = isEnabled ? .labelColor : .disabledControlTextColor
        textField.backgroundColor = .textBackgroundColor
        textField.drawsBackground = true
        textField.isBezeled = true
        textField.bezelStyle = .roundedBezel
        textField.lineBreakMode = .byClipping

        if let cell = textField.cell as? NSTextFieldCell {
            cell.alignment = .left
            cell.baseWritingDirection = .leftToRight
            cell.usesSingleLineMode = true
            cell.wraps = false
            cell.isScrollable = true
        }
    }
}

struct SettingsTechnicalTextFormatting {
    static func apply(to textView: NSTextView, isEnabled: Bool) {
        textView.alignment = .left
        textView.baseWritingDirection = .leftToRight
        textView.isEditable = isEnabled
        textView.isSelectable = true
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 6)
        textView.textContainer?.lineFragmentPadding = 0
        textView.font = NSFont.preferredFont(forTextStyle: .body)
        textView.textColor = isEnabled ? .labelColor : .disabledControlTextColor
        textView.insertionPointColor = .labelColor
        textView.typingAttributes = typingAttributes(isEnabled: isEnabled)
        textView.defaultParagraphStyle = paragraphStyle
    }

    static var paragraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .left
        style.baseWritingDirection = .leftToRight
        return style
    }

    static func typingAttributes(isEnabled: Bool) -> [NSAttributedString.Key: Any] {
        [
            .font: NSFont.preferredFont(forTextStyle: .body),
            .foregroundColor: isEnabled ? NSColor.labelColor : NSColor.disabledControlTextColor,
            .paragraphStyle: paragraphStyle
        ]
    }
}

private struct SettingsTechnicalTextFieldRepresentable: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool
    let isSecure: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField: NSTextField = isSecure ? NSSecureTextField() : NSTextField()
        textField.delegate = context.coordinator
        textField.placeholderString = placeholder
        textField.stringValue = text
        SettingsTechnicalTextFieldFormatting.apply(to: textField, isEnabled: isEnabled)
        return textField
    }

    func updateNSView(_ textField: NSTextField, context: Context) {
        context.coordinator.text = $text
        textField.placeholderString = placeholder
        SettingsTechnicalTextFieldFormatting.apply(to: textField, isEnabled: isEnabled)

        if textField.stringValue != text {
            textField.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }

            text.wrappedValue = textField.stringValue
            SettingsTechnicalTextFieldFormatting.apply(
                to: textField,
                isEnabled: textField.isEditable
            )
        }
    }
}

private struct SettingsTechnicalTextAreaRepresentable: NSViewRepresentable {
    @Binding var text: String
    let isEnabled: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.autoresizingMask = [.width]
        SettingsTechnicalTextFormatting.apply(to: textView, isEnabled: isEnabled)

        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else {
            return
        }

        context.coordinator.text = $text
        SettingsTechnicalTextFormatting.apply(to: textView, isEnabled: isEnabled)

        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text
            textView.setSelectedRanges(
                selectedRanges,
                affinity: .downstream,
                stillSelecting: false
            )
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var text: Binding<String>

        init(text: Binding<String>) {
            self.text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else {
                return
            }

            text.wrappedValue = textView.string
            SettingsTechnicalTextFormatting.apply(to: textView, isEnabled: textView.isEditable)
        }
    }
}
