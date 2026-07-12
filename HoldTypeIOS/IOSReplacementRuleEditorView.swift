import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSReplacementRuleEditorView: View {
    @Environment(IOSLibraryStateOwner.self) private var stateOwner
    @Environment(\.dismiss) private var dismiss

    private let mode: IOSReplacementRuleEditorMode
    @State private var session: IOSReplacementRuleEditorSession?
    @State private var initialResolutionComplete: Bool
    @State private var showsDiscardConfirmation = false
    @State private var showsReplaceConfirmation = false
    @State private var showsDeleteConfirmation = false
    @State private var deleteInFlight = false
    @Binding private var hasUnsavedSceneEditor: Bool
    @Binding private var hasBlockingSceneOperation: Bool

    init(
        mode: IOSReplacementRuleEditorMode,
        hasUnsavedSceneEditor: Binding<Bool>,
        hasBlockingSceneOperation: Binding<Bool> = .constant(false)
    ) {
        self.mode = mode
        _hasUnsavedSceneEditor = hasUnsavedSceneEditor
        _hasBlockingSceneOperation = hasBlockingSceneOperation
        switch mode {
        case .add(let id):
            _session = State(
                initialValue: IOSReplacementRuleEditorSession(
                    newRuleID: id
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
        .navigationTitle(mode.isNew ? "New Replacement Rule" : "Replacement Rule")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(
            session?.isDirty == true || editorOperationInFlight
        )
        .toolbar {
            if session?.isDirty == true {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showsDiscardConfirmation = true
                    }
                    .disabled(editorOperationInFlight)
                }
            }

            if session != nil {
                ToolbarItem(placement: .confirmationAction) {
                    if session?.isSaving == true {
                        ProgressView()
                            .accessibilityLabel("Saving Replacement Rule")
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
            Text("Your unsaved replacement rule edits will be lost.")
        }
        .confirmationDialog(
            "Replace Latest Rule?",
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
            "Delete Replacement Rule?",
            isPresented: $showsDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete Rule", role: .destructive) {
                beginDelete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let phase = session?.phase {
                IOSReplacementRuleEditorPersistentStatus(phase: phase)
            }
        }
        .onAppear(perform: resolveInitialSession)
        .onChange(of: durableRules, initial: true) { _, rules in
            observeDurableRules(rules)
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
                ? "ios.library.replacement-rules.new.screen"
                : "ios.library.replacement-rules.edit.screen"
        )
    }

    private var editorContent: AnyView {
        if let current = session {
            return editorForm(current)
        }
        if initialResolutionComplete {
            return AnyView(IOSMissingReplacementRuleView())
        }
        return AnyView(
            IOSDestinationLoadingView(title: "Loading Replacement Rule")
        )
    }

    private func editorForm(
        _ current: IOSReplacementRuleEditorSession
    ) -> AnyView {
        AnyView(Form {
            IOSReplacementRuleEditorStatusSection(
                phase: current.phase,
                canReloadLatest: current.canReloadLatest,
                canReplaceLatest: current.canReplaceLatest
                    && current.validation == .valid,
                reloadLatest: reloadLatest,
                requestReplaceLatest: {
                    showsReplaceConfirmation = true
                }
            )

            Section("Search") {
                exactInput(
                    text: draftBinding(\.search),
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
                    text: draftBinding(\.replacement),
                    placeholder: "Replacement text",
                    accessibilityLabel: "Replacement text",
                    identifier: "ios.library.replacement-rule.replacement"
                )

                Text("Leave empty to remove matching text.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            validationSection(current)

            if !mode.isNew {
                Section {
                    Button("Delete Replacement Rule", role: .destructive) {
                        showsDeleteConfirmation = true
                    }
                    .disabled(!canDelete)
                }
            }

            Section {
                Text(
                    "This rule runs locally, in Library order, after voice "
                        + "emoji commands. Its content never enters the "
                        + "keyboard extension or App Group."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .disabled(editorOperationInFlight))
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
    private func validationSection(
        _ current: IOSReplacementRuleEditorSession
    ) -> some View {
        if mode.isNew,
           current.draft.hasAnyInput,
           current.validation == .missingSearch {
            Section {
                IOSSettingsWarningLabel(
                    "Enter non-whitespace Search text.",
                    color: .red
                )
            }
        } else if !mode.isNew,
                  !current.draft.candidate(isEnabled: true).hasSearchText {
            Section {
                IOSSettingsWarningLabel(
                    "Inactive — add non-whitespace Search text to activate this rule.",
                    color: .orange
                )
            }
        }
    }

    private var durableRules: [TextReplacementRule] {
        stateOwner.state.durableValue?.replacementRules ?? []
    }

    private var canSave: Bool {
        guard let session else { return false }
        return session.isDirty
            && !editorOperationInFlight
            && session.phase != .changedElsewhere
            && session.phase != .deletedElsewhere
            && session.validation == .valid
    }

    private var canDelete: Bool {
        guard let session else { return false }
        return !mode.isNew
            && !editorOperationInFlight
            && session.baseline != nil
            && session.phase != .changedElsewhere
            && session.phase != .deletedElsewhere
    }

    private var editorOperationInFlight: Bool {
        session?.isSaving == true || deleteInFlight
    }

    private var deleteConfirmationMessage: String {
        session?.isDirty == true
            ? "This removes the saved rule and discards unsaved edits."
            : "This removes the saved replacement rule."
    }

    private func draftBinding(
        _ keyPath: WritableKeyPath<IOSReplacementRuleEditorDraft, String>
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
              let rule = durableRules.first(where: { $0.id == id }) else {
            return
        }
        session = IOSReplacementRuleEditorSession(rule: rule)
    }

    private func observeDurableRules(_ rules: [TextReplacementRule]) {
        if session == nil {
            resolveInitialSession()
        }
        guard var current = session else { return }
        let previousPhase = current.phase
        current.observeDurableRule(
            rules.first { $0.id == mode.id }
        )
        session = current
        guard !editorOperationInFlight,
              current.phase != previousPhase else { return }
        switch current.phase {
        case .changedElsewhere:
            iosAnnounceSettingsStatus(
                mode.isNew
                    ? "A replacement rule identifier is already in use. Draft retained."
                    : "Replacement rule changed elsewhere. Draft retained."
            )
        case .deletedElsewhere:
            iosAnnounceSettingsStatus(
                "The replacement rule was deleted elsewhere. Draft retained."
            )
        case .idle, .saving, .saved, .saveFailed, .invalid:
            break
        }
    }

    private func reloadLatest() {
        guard var current = session else { return }
        current.reloadLatest()
        session = current
        iosAnnounceSettingsStatus("Latest replacement rule loaded.")
    }

    private func beginSave() {
        beginSave(replacingLatest: false)
    }

    private func beginSave(replacingLatest: Bool) {
        guard var current = session,
              let request = current.beginSave(
                replacingLatest: replacingLatest
              ) else {
            return
        }
        session = current
        hasBlockingSceneOperation = true
        Task { await commit(request) }
    }

    private func commit(_ request: IOSReplacementRuleSaveRequest) async {
        defer { hasBlockingSceneOperation = false }
        do {
            let completion = try await stateOwner.apply(request.mutation)
            let returnedRule = completion.state.durableValue?
                .replacementRules.first { $0.id == request.ruleID }
            let currentRule = durableRules.first {
                $0.id == request.ruleID
            }
            guard var current = session else { return }
            switch completion.receipt.disposition {
            case .committed:
                current.commitSucceeded(
                    returnedRule: returnedRule,
                    currentRule: currentRule
                )
            case .unchanged, .duplicate, .targetMissing, .conflict, .invalid:
                current.completeWithoutCommit(
                    disposition: completion.receipt.disposition,
                    returnedRule: returnedRule,
                    currentRule: currentRule
                )
            }
            session = current
            announceSaveCompletion(
                disposition: completion.receipt.disposition,
                phase: current.phase
            )
        } catch {
            guard var current = session else { return }
            current.commitFailed(
                currentRule: durableRules.first {
                    $0.id == request.ruleID
                }
            )
            session = current
            iosAnnounceSettingsStatus(
                "Replacement rule was not saved. Draft retained."
            )
        }
    }

    private func announceSaveCompletion(
        disposition: IOSLibraryMutationDisposition,
        phase: IOSReplacementRuleEditorPhase
    ) {
        switch disposition {
        case .committed, .unchanged:
            switch phase {
            case .saved, .idle:
                iosAnnounceSettingsStatus("Replacement rule saved.")
                if mode.isNew {
                    hasUnsavedSceneEditor = false
                    dismiss()
                }
            case .changedElsewhere:
                iosAnnounceSettingsStatus(
                    "Replacement rule changed elsewhere. Draft retained."
                )
            case .deletedElsewhere:
                iosAnnounceSettingsStatus(
                    "The replacement rule was deleted elsewhere."
                )
            case .saving, .saveFailed, .invalid:
                iosAnnounceSettingsStatus(
                    "Replacement rule was not saved."
                )
            }
        case .targetMissing:
            iosAnnounceSettingsStatus(
                "The replacement rule was deleted elsewhere."
            )
        case .conflict:
            iosAnnounceSettingsStatus(
                "Replacement rule changed elsewhere. Draft not saved."
            )
        case .duplicate, .invalid:
            iosAnnounceSettingsStatus("Replacement rule is invalid.")
        }
    }

    private func beginDelete() {
        guard var current = session,
              let expected = current.baseline,
              canDelete else {
            return
        }
        let ruleID = expected.id
        current.observeDurableRule(
            durableRules.first { $0.id == ruleID }
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
                    .replacementRules(.remove(expected: expected))
                )
                let returnedRule = completion.state.durableValue?
                    .replacementRules.first { $0.id == ruleID }
                let currentRule = durableRules.first { $0.id == ruleID }
                switch completion.receipt.disposition {
                case .committed where currentRule == nil:
                    hasUnsavedSceneEditor = false
                    iosAnnounceSettingsStatus("Replacement rule deleted.")
                    dismiss()
                case .committed, .targetMissing, .conflict:
                    guard var latest = session else { return }
                    latest.completeWithoutCommit(
                        disposition: .conflict,
                        returnedRule: returnedRule,
                        currentRule: currentRule
                    )
                    session = latest
                    iosAnnounceSettingsStatus(
                        "Replacement rule changed elsewhere."
                    )
                case .unchanged, .duplicate, .invalid:
                    break
                }
            } catch {
                guard var latest = session else { return }
                latest.commitFailed(
                    currentRule: durableRules.first { $0.id == ruleID },
                    forceNotSaved: true
                )
                session = latest
                iosAnnounceSettingsStatus(
                    "Replacement rule was not deleted."
                )
            }
        }
    }
}

private struct IOSMissingReplacementRuleView: View {
    var body: some View {
        ContentUnavailableView {
            Label(
                "Rule Unavailable",
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text("This replacement rule is no longer in the saved Library.")
        }
    }
}

private struct IOSReplacementRuleEditorStatusSection: View {
    let phase: IOSReplacementRuleEditorPhase
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
                Label("Saving", systemImage: "arrow.triangle.2.circlepath")
            }
        case .saved:
            Section {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .saveFailed:
            Section {
                IOSSettingsWarningLabel(
                    "Not Saved — draft retained and saved rule unchanged.",
                    color: .red
                )
            }
        case .changedElsewhere:
            Section {
                IOSSettingsWarningLabel(
                    "Changed Elsewhere — your draft is retained.",
                    color: .orange
                )
                if canReloadLatest {
                    Button("Reload Latest", action: reloadLatest)
                }
                if canReplaceLatest {
                    Button(
                        "Replace Latest",
                        role: .destructive,
                        action: requestReplaceLatest
                    )
                }
            }
        case .deletedElsewhere:
            Section {
                IOSSettingsWarningLabel(
                    "Deleted Elsewhere — this draft cannot recreate the rule.",
                    color: .orange
                )
            }
        case .invalid:
            Section {
                IOSSettingsWarningLabel(
                    "The rule could not be saved.",
                    color: .orange
                )
            }
        }
    }
}

private struct IOSReplacementRuleEditorPersistentStatus: View {
    let phase: IOSReplacementRuleEditorPhase

    @ViewBuilder
    var body: some View {
        switch phase {
        case .saveFailed:
            Label {
                Text("Not Saved — saved rule unchanged")
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
            .accessibilityIdentifier(
                "ios.library.replacement-rule.persistent-save-failed"
            )
        case .changedElsewhere:
            Label {
                Text("Changed Elsewhere — draft retained")
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .foregroundStyle(.orange)
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
        case .deletedElsewhere:
            Label {
                Text("Deleted Elsewhere — Save unavailable")
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "trash")
                    .foregroundStyle(.orange)
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
        case .idle, .saving, .saved, .invalid:
            EmptyView()
        }
    }
}

extension IOSReplacementRuleEditorView: CustomReflectable {
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
