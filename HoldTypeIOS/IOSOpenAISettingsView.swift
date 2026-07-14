import HoldTypeIOSCore
import SwiftUI
import UIKit

struct IOSAPIKeyDraft: Equatable {
    var value = ""

    var normalizedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func clear() {
        value = ""
    }
}

struct IOSOpenAICredentialEditorDraft {
    private var apiKey = IOSAPIKeyDraft()
    private let clipboardString: @MainActor () -> String?
    private var focusSession = 0
    private var committedFocusSession: Int?

    init(
        clipboardString: @escaping @MainActor () -> String? = {
            UIPasteboard.general.string
        }
    ) {
        self.clipboardString = clipboardString
    }

    var value: String {
        get { apiKey.value }
        set { apiKey.value = newValue }
    }

    var normalizedValue: String { apiKey.normalizedValue }

    mutating func beginFocusSession() {
        focusSession &+= 1
    }

    mutating func candidateForManualCommit() -> String? {
        guard !normalizedValue.isEmpty,
              committedFocusSession != focusSession else {
            return nil
        }
        committedFocusSession = focusSession
        return value
    }

    mutating func suppressManualCommitForCurrentFocusSession() {
        committedFocusSession = focusSession
    }

    @discardableResult
    mutating func pasteFromClipboard() -> Bool {
        guard let clipboardValue = clipboardString(),
              !clipboardValue.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty else {
            return false
        }

        apiKey.value = clipboardValue
        return true
    }

    mutating func clear() {
        apiKey.clear()
    }

    mutating func clear(ifUnchangedFrom candidate: String) {
        guard value == candidate else { return }
        clear()
    }
}

struct IOSOpenAISettingsView: View {
    @Environment(IOSOpenAICredentialSettingsStateOwner.self)
    private var stateOwner

    @Binding private var editorDraft: IOSOpenAICredentialEditorDraft
    @State private var showsRemoveConfirmation = false
    @FocusState private var isKeyFieldFocused: Bool

    init(editorDraft: Binding<IOSOpenAICredentialEditorDraft>) {
        _editorDraft = editorDraft
    }

    var body: some View {
        List {
            switch stateOwner.state {
            case .unavailable:
                unavailableSection
            case .notLoaded:
                loadingSection
            case .ready(let status):
                statusSection(status)
                credentialSection(status)
            }

            if let notice = stateOwner.notice {
                Section {
                    Label(notice.message, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .accessibilityIdentifier(
                            "ios.settings.openai.notice"
                        )
                }
            }

            if let failure = stateOwner.failure {
                Section {
                    Label(
                        failure.message,
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.red)
                    .accessibilityIdentifier(
                        "ios.settings.openai.failure"
                    )
                }
            }

            setupSection
            privacySection
        }
        .navigationTitle("OpenAI")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.settings.openai")
        .task {
            await stateOwner.activateForDetailAppearance()
        }
        .onChange(of: isKeyFieldFocused) { wasFocused, isFocused in
            if !wasFocused, isFocused {
                editorDraft.beginFocusSession()
                return
            }
            guard wasFocused, !isFocused,
                  let candidate = editorDraft.candidateForManualCommit()
            else { return }
            commit(candidate)
        }
        .onChange(of: stateOwner.notice) { _, notice in
            guard let notice else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: notice.message
            )
        }
        .onChange(of: stateOwner.failure) { _, failure in
            guard let failure else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: failure.message
            )
        }
        .confirmationDialog(
            "Remove the saved OpenAI API key?",
            isPresented: $showsRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Remove Saved Key", role: .destructive) {
                removeSavedKey()
            }
            .accessibilityIdentifier(
                "ios.settings.openai.remove-confirm"
            )
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "HoldType will no longer be able to make OpenAI voice "
                + "requests until you save another key."
            )
        }
    }

    private var unavailableSection: some View {
        Section("Saved Key") {
            Label(
                "Secure credential storage is unavailable in this build.",
                systemImage: "key.slash"
            )
            .foregroundStyle(.secondary)

            Text(
                "Your other HoldType settings and dictation rules remain available. "
                + "This state does not mean that no key is saved."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("ios.settings.openai.unavailable")
    }

    private var loadingSection: some View {
        Section("Saved Key") {
            HStack(spacing: 12) {
                ProgressView()
                Text("Reading local credential status…")
            }
        }
        .accessibilityIdentifier("ios.settings.openai.loading")
    }

    private func statusSection(
        _ status: IOSOpenAICredentialStatus
    ) -> some View {
        Section("Saved Key") {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(status.primary.title)
                    Text(status.primary.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: status.primary.systemImage)
                    .foregroundStyle(status.primary.tint)
            }
            .accessibilityIdentifier("ios.settings.openai.status")

            if status.primary.showsLastKnownMask {
                LabeledContent("Saved key") {
                    Text("••••••••••••")
                        .font(.body.monospaced())
                        .environment(\.layoutDirection, .leftToRight)
                        .privacySensitive()
                }
                .accessibilityValue("Saved key present")
            }

            if status.statusNeedsRefresh {
                Label(
                    "Credential status needs refresh.",
                    systemImage: "arrow.clockwise.circle"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            if status.localMarkerIssue != nil {
                Label(
                    "The local status record is unavailable. The saved key "
                    + "was not exposed or replaced.",
                    systemImage: "externaldrive.badge.exclamationmark"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }

            Button {
                Task { await stateOwner.refresh() }
            } label: {
                Label("Check Saved Key", systemImage: "arrow.clockwise")
            }
            .disabled(stateOwner.isBusy)
            .accessibilityIdentifier("ios.settings.openai.refresh")

            if stateOwner.isBusy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(stateOwner.operation.progressTitle)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("ios.settings.openai.progress")
            }
        }
    }

    private func credentialSection(
        _ status: IOSOpenAICredentialStatus
    ) -> some View {
        Section {
            SecureField(
                status.primary.keyFieldTitle,
                text: Binding(
                    get: { editorDraft.value },
                    set: { editorDraft.value = $0 }
                )
            )
            .focused($isKeyFieldFocused)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.asciiCapable)
            .submitLabel(.done)
            .privacySensitive()
            .disabled(stateOwner.isBusy)
            .onSubmit {
                guard let candidate =
                    editorDraft.candidateForManualCommit() else {
                    stateOwner.reportEmptyCandidate()
                    return
                }
                isKeyFieldFocused = false
                commit(candidate)
            }
            .accessibilityIdentifier("ios.settings.openai.key-field")

            Button {
                pasteAndSave()
            } label: {
                Label("Paste and Save", systemImage: "doc.on.clipboard")
            }
            .disabled(stateOwner.isBusy)
            .accessibilityIdentifier("ios.settings.openai.paste")

            Button("Remove Saved Key", role: .destructive) {
                editorDraft.suppressManualCommitForCurrentFocusSession()
                isKeyFieldFocused = false
                showsRemoveConfirmation = true
            }
            .disabled(
                stateOwner.isBusy || !status.primary.canAttemptRemove
            )
            .accessibilityIdentifier("ios.settings.openai.remove")
        } header: {
            Text("Add or Replace Key")
        } footer: {
            Text(
                "Press Done or leave the field to save a non-empty key. "
                + "Typing alone never writes to Keychain."
            )
        }
    }

    private var setupSection: some View {
        Section("OpenAI Platform") {
            Text(
                "Create and manage the API key in your OpenAI Platform "
                + "account. API usage is managed separately from HoldType."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)

            Link(
                "Open API Keys",
                destination: URL(
                    string: "https://platform.openai.com/api-keys"
                )!
            )
            Link(
                "Open Billing",
                destination: URL(
                    string:
                        "https://platform.openai.com/account/billing/overview"
                )!
            )
        }
    }

    private var privacySection: some View {
        Section("Privacy") {
            Text(
                "The key is stored in this app’s private Keychain item. It "
                + "is never included in dictation rules, History, diagnostics, "
                + "shared settings, or the keyboard extension."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private func pasteAndSave() {
        guard !stateOwner.isBusy else { return }
        editorDraft.suppressManualCommitForCurrentFocusSession()
        isKeyFieldFocused = false
        guard editorDraft.pasteFromClipboard() else {
            stateOwner.reportEmptyClipboard()
            return
        }
        commit(editorDraft.value)
    }

    private func commit(_ candidate: String) {
        guard !stateOwner.isBusy else { return }
        guard !candidate.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return
        }

        Task {
            if await stateOwner.saveOrReplace(candidate) {
                editorDraft.clear(ifUnchangedFrom: candidate)
            }
        }
    }

    private func removeSavedKey() {
        guard !stateOwner.isBusy else { return }
        Task {
            if await stateOwner.remove() {
                editorDraft.clear()
            }
        }
    }
}

private extension IOSOpenAICredentialPrimaryStatus {
    var title: String {
        switch self {
        case .notConfigured:
            "Not configured"
        case .notCheckedInThisProcess:
            "Not checked in this process"
        case .savedLastKnown:
            "Saved, last known"
        case .availableInThisProcess:
            "Available in this process"
        case .unavailableWhileLocked:
            "Unavailable while locked"
        case .providerRejected:
            "Provider rejected"
        }
    }

    var explanation: String {
        switch self {
        case .notConfigured:
            "No saved key is currently recorded."
        case .notCheckedInThisProcess:
            "HoldType has not read Keychain in this app process."
        case .savedLastKnown:
            "The local marker reports a saved key; Keychain is not checked."
        case .availableInThisProcess:
            "An explicit action read the saved key successfully."
        case .unavailableWhileLocked:
            "Unlock this device, then check the saved key again."
        case .providerRejected:
            "Replace the current key before the next OpenAI request."
        }
    }

    var systemImage: String {
        switch self {
        case .notConfigured:
            "key.slash"
        case .notCheckedInThisProcess, .savedLastKnown:
            "key"
        case .availableInThisProcess:
            "checkmark.circle"
        case .unavailableWhileLocked:
            "lock"
        case .providerRejected:
            "xmark.octagon"
        }
    }

    var tint: Color {
        switch self {
        case .availableInThisProcess:
            .green
        case .unavailableWhileLocked:
            .orange
        case .providerRejected:
            .red
        case .notConfigured, .notCheckedInThisProcess, .savedLastKnown:
            .secondary
        }
    }

    var showsLastKnownMask: Bool {
        switch self {
        case .savedLastKnown, .availableInThisProcess, .providerRejected:
            true
        case .notConfigured, .notCheckedInThisProcess,
             .unavailableWhileLocked:
            false
        }
    }

    var keyFieldTitle: String {
        switch self {
        case .savedLastKnown, .availableInThisProcess,
             .unavailableWhileLocked, .providerRejected:
            "Replace OpenAI API key"
        case .notConfigured, .notCheckedInThisProcess:
            "OpenAI API key"
        }
    }

    var canAttemptRemove: Bool {
        self != .notConfigured
    }
}

private extension IOSOpenAICredentialSettingsOperation {
    var progressTitle: String {
        switch self {
        case .idle:
            "Ready"
        case .loadingStatus:
            "Reading local status…"
        case .refreshing:
            "Checking saved key…"
        case .saving:
            "Saving in HoldType…"
        case .removing:
            "Removing saved key…"
        }
    }
}

extension IOSAPIKeyDraft:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    var description: String { "IOSAPIKeyDraft(<redacted>)" }
    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

extension IOSOpenAICredentialEditorDraft:
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable
{
    var description: String {
        "IOSOpenAICredentialEditorDraft(<redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}
