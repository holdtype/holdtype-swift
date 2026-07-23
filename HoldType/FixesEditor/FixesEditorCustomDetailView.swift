import HoldTypeDomain
import SwiftUI

struct FixesEditorCustomDetailView: View {
    @ObservedObject var model: FixesEditorModel

    @State private var showsDeleteConfirmation = false

    var body: some View {
        Form {
            identitySection
            promptSection
            orderSection
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(navigationTitle)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
        .alert("Delete this Fix?", isPresented: $showsDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await model.deleteSelection()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the Fix from the macOS catalog.")
        }
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

    private var orderSection: some View {
        Section("Order") {
            HStack {
                Button {
                    Task {
                        await model.moveSelectionUp()
                    }
                } label: {
                    Label("Move Up", systemImage: "arrow.up")
                }
                .disabled(!model.canMoveSelectionUp)

                Button {
                    Task {
                        await model.moveSelectionDown()
                    }
                } label: {
                    Label("Move Down", systemImage: "arrow.down")
                }
                .disabled(!model.canMoveSelectionDown)

                Spacer()

                Text("Translate and Fix stay pinned first.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button("Delete", role: .destructive) {
                showsDeleteConfirmation = true
            }
            .disabled(!model.canDeleteSelection)

            if model.selectedDraft?.isNew == true {
                Text("Not saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if model.selectedDraftHasChanges {
                Text("Unsaved changes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if model.activity.isBusy {
                ProgressView()
                    .controlSize(.small)
            }

            Button("Save") {
                Task {
                    await model.saveSelectedDraft()
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(!model.canSaveSelectedDraft)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var navigationTitle: String {
        let title = model.selectedDraft?.title ?? ""
        return title.isEmpty ? "New Fix" : title
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
    let model = makeFixesEditorPreviewModel(
        selectedActionID: TextFixCatalog.defaults.customActions[0].id
    )
    NavigationStack {
        FixesEditorCustomDetailView(model: model)
    }
    .frame(width: 620, height: 620)
}

#Preview("New Fix Validation") {
    let model = makeFixesEditorPreviewModel(addsNewFix: true)
    NavigationStack {
        FixesEditorCustomDetailView(model: model)
    }
    .frame(width: 620, height: 620)
}
