//
//  SettingsTextInputStyle.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

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

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
    }
}

struct SettingsTechnicalSecureFieldInput: View {
    @Binding var text: String

    var body: some View {
        SecureField("", text: $text)
            .textFieldStyle(.roundedBorder)
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
    }
}

struct SettingsTechnicalTextAreaInput: View {
    let placeholder: String
    @Binding var text: String
    var minLines: Int = 2
    var maxLines: Int = 4

    var body: some View {
        TextEditor(text: $text)
            .font(.body)
            .multilineTextAlignment(.leading)
            .autocorrectionDisabled()
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(height: Self.height(forLineCount: max(minLines, maxLines)))
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .stroke(.separator, lineWidth: 1)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .environment(\.layoutDirection, .leftToRight)
    }

    static func height(forLineCount lineCount: Int) -> CGFloat {
        CGFloat(max(1, lineCount) * 20 + 14)
    }
}
