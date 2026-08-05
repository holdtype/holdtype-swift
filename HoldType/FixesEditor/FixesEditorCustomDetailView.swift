import HoldTypeDomain
import SwiftUI

struct FixesEditorCustomDetailView: View {
    @ObservedObject var model: FixesEditorModel
    @FocusState.Binding var focusedField: FixesEditorView.FocusedField?

    var body: some View {
        Form {
            identitySection
            promptSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var identitySection: some View {
        Section("Fix") {
            TextField(
                "Title",
                text: Binding(
                    get: { model.selectedDraft?.title ?? "" },
                    set: model.setSelectedTitle
                )
            )
            .focused($focusedField, equals: .title)
            .disabled(model.activity.isBusy)
            .accessibilityHint(
                "Up to \(TextFixAction.maximumTitleCharacterCount) characters"
            )

            if let message = model.selectedDraftValidation?.titleMessage {
                validationMessage(message)
            }

            FixesEditorIconPicker(
                selection: Binding(
                    get: { model.selectedDraft?.icon ?? .custom },
                    set: model.setSelectedIcon
                ),
                isEnabled: !model.activity.isBusy
            )

            Toggle(
                "Enabled",
                isOn: Binding(
                    get: { model.selectedDraft?.isEnabled ?? false },
                    set: model.setSelectedEnabled
                )
            )
            .disabled(model.activity.isBusy)
            .help("Disabled Fixes stay in the editor but are hidden from action pickers.")
        }
    }

    private var promptSection: some View {
        Section("Prompt") {
            TextEditor(
                text: Binding(
                    get: { model.selectedDraft?.prompt ?? "" },
                    set: model.setSelectedPrompt
                )
            )
            .font(.body)
            .scrollContentBackground(.hidden)
            .padding(6)
            .frame(minHeight: 230)
            .background(.quaternary.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(.separator.opacity(0.7), lineWidth: 1)
            }
            .disabled(model.activity.isBusy)
            .accessibilityLabel("Prompt")

            HStack(alignment: .firstTextBaseline) {
                if let message = model.selectedDraftValidation?.promptMessage {
                    validationMessage(message)
                }

                Spacer()

                Text(promptByteCount)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private var promptByteCount: String {
        let count = model.selectedDraft?.prompt.utf8.count ?? 0
        return "\(count) / \(TextFixAction.maximumPromptUTF8ByteCount) bytes"
    }

    private func validationMessage(_ message: String) -> some View {
        Label(message, systemImage: "exclamationmark.circle.fill")
            .font(.caption)
            .foregroundStyle(.red)
            .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview("Custom Fix") {
    FixesEditorCustomDetailPreview(
        model: makeFixesEditorPreviewModel(
            selectedActionID: TextFixCatalog.defaults.customActions[0].id
        )
    )
}

#Preview("New Fix Validation") {
    FixesEditorCustomDetailPreview(
        model: makeFixesEditorPreviewModel(addsNewFix: true)
    )
}

private struct FixesEditorCustomDetailPreview: View {
    @FocusState private var focusedField: FixesEditorView.FocusedField?
    let model: FixesEditorModel

    var body: some View {
        NavigationStack {
            FixesEditorCustomDetailView(model: model, focusedField: $focusedField)
        }
        .frame(width: 620, height: 620)
    }
}
