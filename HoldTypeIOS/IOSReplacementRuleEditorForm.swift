import Foundation
import HoldTypeDomain
import SwiftUI

struct IOSReplacementRuleEditorForm: View {
    let isNew: Bool
    let session: IOSReplacementRuleEditorSession
    @Binding var search: String
    @Binding var replacement: String
    let canDelete: Bool
    let isDisabled: Bool
    let reloadLatest: () -> Void
    let requestReplaceLatest: () -> Void
    let requestDelete: () -> Void

    var body: some View {
        Form {
            IOSReplacementRuleEditorStatusSection(
                phase: session.phase,
                canReloadLatest: session.canReloadLatest,
                canReplaceLatest: session.canReplaceLatest
                    && session.validation == .valid,
                reloadLatest: reloadLatest,
                requestReplaceLatest: requestReplaceLatest
            )

            Section("Search") {
                exactInput(
                    text: $search,
                    placeholder: "Text to find",
                    accessibilityLabel: "Search text",
                    identifier: "ios.library.replacement-rule.search"
                )

                Text(
                    "Matched literally and case-insensitively. Spaces and "
                        + "line breaks are part of the match."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Replacement") {
                exactInput(
                    text: $replacement,
                    placeholder: "Replacement text",
                    accessibilityLabel: "Replacement text",
                    identifier: "ios.library.replacement-rule.replacement"
                )

                Text("Leave empty to remove matching text.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            validationSection

            if !isNew {
                Section {
                    Button(
                        "Delete Replacement Rule",
                        role: .destructive,
                        action: requestDelete
                    )
                    .disabled(!canDelete)
                }
            }

            Section {
                Text(
                    "This rule runs locally, in the saved order, after emoji "
                        + "commands. It is not copied into the keyboard."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .disabled(isDisabled)
    }

    private func exactInput(
        text: Binding<String>,
        placeholder: String,
        accessibilityLabel: String,
        identifier: String
    ) -> some View {
        ZStack(alignment: .topLeading) {
            IOSExactMultilineTextInput(
                text: text,
                accessibilityLabel: accessibilityLabel
            )
            .accessibilityIdentifier(identifier)

            if text.wrappedValue.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 6)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    @ViewBuilder
    private var validationSection: some View {
        if isNew,
           session.draft.hasAnyInput,
           session.validation == .missingSearch {
            Section {
                IOSSettingsWarningLabel(
                    "Enter non-whitespace Search text.",
                    color: .red
                )
            }
        } else if !isNew,
                  !session.draft.candidate(isEnabled: true).hasSearchText {
            Section {
                IOSSettingsWarningLabel(
                    "Inactive — add non-whitespace Search text to activate this rule.",
                    color: .orange
                )
            }
        }
    }
}

extension IOSReplacementRuleEditorForm: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

#Preview("Replacement rule editor form") {
    let rule = TextReplacementRule(
        id: UUID(
            uuid: (0x10, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)
        ),
        search: "colour\nmode",
        replacement: "color\nmode"
    )

    NavigationStack {
        IOSReplacementRuleEditorForm(
            isNew: false,
            session: IOSReplacementRuleEditorSession(rule: rule),
            search: .constant(rule.search),
            replacement: .constant(rule.replacement),
            canDelete: true,
            isDisabled: false,
            reloadLatest: {},
            requestReplaceLatest: {},
            requestDelete: {}
        )
        .navigationTitle("Replacement Rule")
    }
}
