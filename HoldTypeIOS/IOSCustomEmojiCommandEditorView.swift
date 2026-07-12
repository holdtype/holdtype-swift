import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSCustomEmojiCommandEditorView: View {
    @Environment(IOSLibraryStateOwner.self) private var stateOwner
    @Environment(\.dismiss) private var dismiss

    private let mode: IOSEmojiCommandEditorMode
    @State private var session: IOSEmojiCommandEditorSession?
    @State private var initialResolutionComplete: Bool
    @State private var showsDiscardConfirmation = false
    @State private var showsReplaceConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var deleteInFlight = false
    @Binding private var hasUnsavedSceneEditor: Bool
    @Binding private var hasBlockingSceneOperation: Bool

    init(
        mode: IOSEmojiCommandEditorMode,
        hasUnsavedSceneEditor: Binding<Bool>,
        hasBlockingSceneOperation: Binding<Bool> = .constant(false)
    ) {
        self.mode = mode
        _hasUnsavedSceneEditor = hasUnsavedSceneEditor
        _hasBlockingSceneOperation = hasBlockingSceneOperation
        switch mode {
        case .add(let id):
            _session = State(
                initialValue: IOSEmojiCommandEditorSession(
                    newCommandID: id
                )
            )
            _initialResolutionComplete = State(initialValue: true)
        case .edit:
            _session = State(initialValue: nil)
            _initialResolutionComplete = State(initialValue: false)
        }
    }

    var body: some View {
        editorContent
        .navigationTitle(mode.isNew ? "New Custom Command" : "Custom Command")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(
            session?.isDirty == true || deleteInFlight
        )
        .toolbar {
            if session?.isDirty == true {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showsDiscardConfirmation = true
                    }
                    .disabled(
                        session?.isSaving == true || deleteInFlight
                    )
                }
            }

            if session != nil {
                ToolbarItem(placement: .confirmationAction) {
                    if session?.isSaving == true {
                        ProgressView()
                            .accessibilityLabel("Saving Custom Command")
                    } else {
                        Button("Save", action: beginSave)
                            .disabled(!canSave)
                    }
                }
            }
        }
        .confirmationDialog(
            "Discard Changes?",
            isPresented: $showsDiscardConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                guard var current = session else { return }
                current.discard()
                session = current
                hasUnsavedSceneEditor = false
                dismiss()
            }
            Button("Keep Editing", role: .cancel) {}
        } message: {
            Text("Your unsaved custom command edits will be lost.")
        }
        .confirmationDialog(
            "Replace Latest Command?",
            isPresented: $showsReplaceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace Latest", role: .destructive) {
                beginSave(replacingLatest: true)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "This saves the current draft over the latest saved fields. "
                    + "A newer change still wins through conflict protection."
            )
        }
        .confirmationDialog(
            "Delete Custom Command?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Command", role: .destructive) {
                beginDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the saved custom command.")
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let phase = session?.phase {
                IOSEmojiCommandEditorPersistentStatus(phase: phase)
            }
        }
        .onAppear(perform: resolveInitialSession)
        .onChange(of: durableCustomCommands, initial: true) { _, commands in
            observeDurableCommands(commands)
        }
        .onChange(of: session?.isDirty, initial: true) { _, isDirty in
            hasUnsavedSceneEditor = isDirty == true
        }
        .onChange(of: editorOperationInFlight, initial: true) { _, isBusy in
            hasBlockingSceneOperation = isBusy
        }
        .onDisappear {
            if session?.isDirty != true {
                hasUnsavedSceneEditor = false
            }
            if !editorOperationInFlight {
                hasBlockingSceneOperation = false
            }
        }
        .accessibilityIdentifier(
            mode.isNew
                ? "ios.library.emoji-commands.new.screen"
                : "ios.library.emoji-commands.edit.screen"
        )
    }

    private var editorContent: AnyView {
        if let current = session {
            return editorForm(current)
        }
        if initialResolutionComplete {
            return AnyView(IOSMissingCustomEmojiCommandView())
        }
        return AnyView(
            IOSDestinationLoadingView(title: "Loading Command")
        )
    }

    private func editorForm(
        _ current: IOSEmojiCommandEditorSession
    ) -> AnyView {
        AnyView(Form {
            IOSEmojiCommandEditorStatusSection(
                phase: current.phase,
                canReloadLatest: current.canReloadLatest,
                canReplaceLatest: current.canReplaceLatest
                    && current.validation(
                        in: durableCustomCommands
                    ) == .valid,
                reloadLatest: reloadLatest,
                requestReplaceLatest: {
                    showsReplaceConfirmation = true
                }
            )

            Section("Command") {
                TextField(
                    "Output",
                    text: draftBinding(\.output),
                    axis: .vertical
                )
                .lineLimit(1...3)
                .autocorrectionDisabled()
                .accessibilityHint(
                    "Enter the text or emoji produced by the spoken phrase."
                )

                TextField(
                    "Primary spoken phrase",
                    text: draftBinding(\.primaryPhrase),
                    axis: .vertical
                )
                .lineLimit(1...3)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            }

            Section("Aliases") {
                TextField(
                    "One optional alias per line",
                    text: draftBinding(\.aliasesText),
                    axis: .vertical
                )
                .lineLimit(3...10)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

                Text(
                    "Aliases are alternate spoken phrases for the same output."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            validationSection(current)

            if !mode.isNew {
                Section {
                    Button("Delete Custom Command", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .disabled(!canDelete)
                }
            }

            Section {
                Text(
                    "Custom commands are normalized only when you Save. "
                        + "They remain private to the containing app and are "
                        + "never copied into the keyboard extension."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .disabled(current.isSaving || deleteInFlight)
        .scrollDismissesKeyboard(.interactively))
    }

    @ViewBuilder
    private func validationSection(
        _ current: IOSEmojiCommandEditorSession
    ) -> some View {
        if current.isDirty {
            switch current.validation(in: durableCustomCommands) {
            case .valid:
                EmptyView()
            case .missingOutput:
                Section {
                    IOSSettingsWarningLabel(
                        "Enter a non-empty output.",
                        color: .red
                    )
                }
            case .missingPrimaryPhrase:
                Section {
                    IOSSettingsWarningLabel(
                        "Enter a primary spoken phrase. An alias cannot replace it.",
                        color: .red
                    )
                }
            case .customPhraseCollision:
                Section {
                    IOSSettingsWarningLabel(
                        "A primary phrase or alias already belongs to another custom command.",
                        color: .red
                    )
                }
            }
        }
    }

    private var durableCustomCommands: [CustomEmojiCommand] {
        stateOwner.state.durableValue?
            .emojiCommandsConfiguration.customCommands ?? []
    }

    private var canSave: Bool {
        guard let session else { return false }
        return session.isDirty
            && !session.isSaving
            && !deleteInFlight
            && session.phase != .changedElsewhere
            && session.phase != .deletedElsewhere
            && session.validation(in: durableCustomCommands) == .valid
    }

    private var canDelete: Bool {
        guard let session else { return false }
        return !session.isSaving
            && !deleteInFlight
            && session.phase != .changedElsewhere
            && session.phase != .deletedElsewhere
            && session.baseline != nil
    }

    private var editorOperationInFlight: Bool {
        session?.isSaving == true || deleteInFlight
    }

    private func draftBinding(
        _ keyPath: WritableKeyPath<IOSEmojiCommandEditorDraft, String>
    ) -> Binding<String> {
        Binding(
            get: { session?.draft[keyPath: keyPath] ?? "" },
            set: { value in
                guard var current = session else { return }
                current.set(value, at: keyPath)
                session = current
            }
        )
    }

    private func resolveInitialSession() {
        guard session == nil else { return }
        defer { initialResolutionComplete = true }
        guard case .edit(let id) = mode,
              let command = durableCustomCommands.first(
                where: { $0.id == id }
              ) else {
            return
        }
        session = IOSEmojiCommandEditorSession(command: command)
    }

    private func observeDurableCommands(
        _ commands: [CustomEmojiCommand]
    ) {
        if session == nil {
            resolveInitialSession()
        }
        guard var current = session else { return }
        current.observeDurableCommand(
            commands.first { $0.id == mode.id }
        )
        session = current
    }

    private func reloadLatest() {
        guard var current = session else { return }
        current.reloadLatest()
        session = current
        iosAnnounceSettingsStatus("Latest custom command loaded.")
    }

    private func beginSave() {
        beginSave(replacingLatest: false)
    }

    private func beginSave(replacingLatest: Bool) {
        guard var current = session,
              let request = current.beginSave(
                customCommands: durableCustomCommands,
                replacingLatest: replacingLatest
              ) else {
            return
        }
        session = current
        hasBlockingSceneOperation = true
        Task { await commit(request) }
    }

    private func commit(_ request: IOSEmojiCommandSaveRequest) async {
        defer { hasBlockingSceneOperation = false }
        do {
            let completion = try await stateOwner.apply(request.mutation)
            let returnedCommand = completion.state.durableValue?
                .emojiCommandsConfiguration.customCommands.first {
                    $0.id == request.commandID
                }
            let currentCommand = durableCustomCommands.first {
                $0.id == request.commandID
            }
            guard var current = session else { return }
            switch completion.receipt.disposition {
            case .committed:
                current.commitSucceeded(
                    returnedCommand: returnedCommand,
                    currentCommand: currentCommand
                )
            case .unchanged, .duplicate, .targetMissing, .conflict, .invalid:
                current.completeWithoutCommit(
                    disposition: completion.receipt.disposition,
                    returnedCommand: returnedCommand,
                    currentCommand: currentCommand
                )
            }
            session = current

            switch completion.receipt.disposition {
            case .committed, .unchanged:
                iosAnnounceSettingsStatus("Custom command saved.")
                if mode.isNew {
                    hasUnsavedSceneEditor = false
                    dismiss()
                }
            case .targetMissing:
                iosAnnounceSettingsStatus(
                    "The custom command was deleted elsewhere."
                )
            case .conflict:
                iosAnnounceSettingsStatus(
                    "Custom command changed elsewhere. Draft not saved."
                )
            case .duplicate, .invalid:
                iosAnnounceSettingsStatus("Custom command is invalid.")
            }
        } catch {
            guard var current = session else { return }
            current.commitFailed(
                currentCommand: durableCustomCommands.first {
                    $0.id == request.commandID
                }
            )
            session = current
            iosAnnounceSettingsStatus(
                "Custom command was not saved. Draft retained."
            )
        }
    }

    private func beginDelete() {
        guard var current = session,
              let expected = current.baseline,
              canDelete else {
            return
        }
        let commandID = expected.id
        current.observeDurableCommand(
            durableCustomCommands.first { $0.id == commandID }
        )
        guard current.phase != .changedElsewhere,
              current.phase != .deletedElsewhere else {
            session = current
            return
        }
        session = current
        deleteInFlight = true
        hasBlockingSceneOperation = true

        Task {
            defer {
                deleteInFlight = false
                hasBlockingSceneOperation = false
            }
            do {
                let completion = try await stateOwner.apply(
                    .emojiCommands(.remove(expected: expected))
                )
                switch completion.receipt.disposition {
                case .committed:
                    hasUnsavedSceneEditor = false
                    iosAnnounceSettingsStatus("Custom command deleted.")
                    dismiss()
                case .targetMissing, .conflict:
                    guard var latest = session else { return }
                    latest.completeWithoutCommit(
                        disposition: completion.receipt.disposition,
                        returnedCommand: completion.state.durableValue?
                            .emojiCommandsConfiguration.customCommands.first {
                                $0.id == commandID
                            },
                        currentCommand: durableCustomCommands.first {
                            $0.id == commandID
                        }
                    )
                    session = latest
                    iosAnnounceSettingsStatus(
                        "Custom command changed elsewhere."
                    )
                case .unchanged, .duplicate, .invalid:
                    break
                }
            } catch {
                guard var latest = session else { return }
                latest.commitFailed(
                    currentCommand: durableCustomCommands.first {
                        $0.id == commandID
                    },
                    forceNotSaved: true
                )
                session = latest
                iosAnnounceSettingsStatus(
                    "Custom command was not deleted."
                )
            }
        }
    }

}

private struct IOSMissingCustomEmojiCommandView: View {
    var body: some View {
        ContentUnavailableView {
            Label(
                "Command Unavailable",
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text(
                "This custom command is no longer in the saved Library."
            )
        }
    }
}

private struct IOSEmojiCommandEditorStatusSection: View {
    let phase: IOSEmojiCommandEditorPhase
    let canReloadLatest: Bool
    let canReplaceLatest: Bool
    let reloadLatest: () -> Void
    let requestReplaceLatest: () -> Void

    @ViewBuilder
    var body: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .saving:
            Section {
                ProgressView("Saving…")
            }
        case .saved:
            Section {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .saveFailed:
            Section {
                IOSSettingsWarningLabel(
                    "Not Saved. The saved command is unchanged and any draft is retained.",
                    color: .red
                )
            }
        case .changedElsewhere:
            Section("Changed Elsewhere") {
                IOSSettingsWarningLabel(
                    "The saved command changed. This draft has not been saved.",
                    color: .orange
                )
                Button("Reload Latest", action: reloadLatest)
                    .disabled(!canReloadLatest)
                Button("Replace Latest", role: .destructive) {
                    requestReplaceLatest()
                }
                .disabled(!canReplaceLatest)
            }
        case .deletedElsewhere:
            Section {
                IOSSettingsWarningLabel(
                    "This command was deleted elsewhere. Save cannot recreate it.",
                    color: .orange
                )
            }
        case .invalid:
            Section {
                IOSSettingsWarningLabel(
                    "This draft is invalid or conflicts with another custom phrase.",
                    color: .red
                )
            }
        }
    }
}

private struct IOSEmojiCommandEditorPersistentStatus: View {
    let phase: IOSEmojiCommandEditorPhase

    @ViewBuilder
    var body: some View {
        switch phase {
        case .saveFailed:
            status(
                "Not Saved — saved command unchanged",
                systemImage: "exclamationmark.triangle.fill",
                color: .red
            )
        case .changedElsewhere:
            status(
                "Changed Elsewhere — draft not saved",
                systemImage: "arrow.triangle.2.circlepath",
                color: .orange
            )
        case .deletedElsewhere:
            status(
                "Deleted Elsewhere — Save unavailable",
                systemImage: "trash",
                color: .orange
            )
        case .idle, .saving, .saved, .invalid:
            EmptyView()
        }
    }

    private func status(
        _ title: String,
        systemImage: String,
        color: Color
    ) -> some View {
        Label {
            Text(title)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(color)
        }
        .font(.footnote.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .overlay(alignment: .top) { Divider() }
        .accessibilityIdentifier(
            "ios.library.emoji-commands.editor.persistent-status"
        )
    }
}

extension IOSCustomEmojiCommandEditorView: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
