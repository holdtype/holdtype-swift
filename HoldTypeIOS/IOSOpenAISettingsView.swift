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

struct IOSOpenAICredentialPresentation: Equatable {
    enum State: Equatable {
        case notConnected
        case connected
        case needsAttention
    }

    enum Tone: Equatable {
        case neutral
        case success
        case warning
        case failure
    }

    let state: State
    let title: String
    let explanation: String
    let systemImage: String
    let tone: Tone
    let showsSavedKeyMask: Bool
    let offersVerification: Bool

    private init(
        state: State,
        title: String,
        explanation: String,
        systemImage: String,
        tone: Tone,
        showsSavedKeyMask: Bool,
        offersVerification: Bool
    ) {
        self.state = state
        self.title = title
        self.explanation = explanation
        self.systemImage = systemImage
        self.tone = tone
        self.showsSavedKeyMask = showsSavedKeyMask
        self.offersVerification = offersVerification
    }

    init(status: IOSOpenAICredentialStatus) {
        let showsSavedKeyMask = switch status.primary {
        case .savedLastKnown, .availableInThisProcess,
             .unavailableWhileLocked, .providerRejected:
            true
        case .notConfigured, .notCheckedInThisProcess:
            false
        }

        if status.statusNeedsRefresh || status.localMarkerIssue != nil {
            self.init(
                state: .needsAttention,
                title: "Key needs attention",
                explanation: "HoldType couldn’t confirm the saved key.",
                systemImage: "exclamationmark.triangle",
                tone: .warning,
                showsSavedKeyMask: showsSavedKeyMask,
                offersVerification: true
            )
            return
        }

        switch status.primary {
        case .notConfigured:
            self.init(
                state: .notConnected,
                title: "Add your API key",
                explanation: "Connect OpenAI to use Voice.",
                systemImage: "key.slash",
                tone: .neutral,
                showsSavedKeyMask: false,
                offersVerification: false
            )
        case .notCheckedInThisProcess:
            self.init(
                state: .needsAttention,
                title: "Key status unavailable",
                explanation: "HoldType couldn’t confirm whether a key is saved.",
                systemImage: "exclamationmark.triangle",
                tone: .warning,
                showsSavedKeyMask: false,
                offersVerification: true
            )
        case .savedLastKnown, .availableInThisProcess:
            self.init(
                state: .connected,
                title: "API key saved",
                explanation: "Stored securely on this iPhone.",
                systemImage: "checkmark.circle",
                tone: .success,
                showsSavedKeyMask: true,
                offersVerification: false
            )
        case .unavailableWhileLocked:
            self.init(
                state: .needsAttention,
                title: "Unlock iPhone to continue",
                explanation: "HoldType can’t access the saved key while this iPhone is locked.",
                systemImage: "lock",
                tone: .warning,
                showsSavedKeyMask: true,
                offersVerification: true
            )
        case .providerRejected:
            self.init(
                state: .needsAttention,
                title: "Replace this API key",
                explanation: "OpenAI rejected the saved key.",
                systemImage: "xmark.octagon",
                tone: .failure,
                showsSavedKeyMask: true,
                offersVerification: false
            )
        }
    }

    var settingsSummary: String {
        switch state {
        case .notConnected:
            "Not connected"
        case .connected:
            "Connected"
        case .needsAttention:
            "Needs attention"
        }
    }
}

struct IOSOpenAISettingsView: View {
    @Environment(IOSOpenAICredentialSettingsStateOwner.self)
    private var stateOwner

    @Binding private var editorDraft: IOSOpenAICredentialEditorDraft
    @State private var showsRemoveConfirmation = false
    @FocusState private var isKeyFieldFocused: Bool
    private let attentionTarget: IOSSettingsAttentionTarget?

    init(
        editorDraft: Binding<IOSOpenAICredentialEditorDraft>,
        attentionTarget: IOSSettingsAttentionTarget? = nil
    ) {
        _editorDraft = editorDraft
        self.attentionTarget = attentionTarget
    }

    var body: some View {
        IOSSettingsAttentionScrollView(
            attentionTarget: activeAttentionTarget
        ) {
            List {
                switch stateOwner.state {
                case .unavailable:
                    unavailableSection
                case .notLoaded:
                    loadingSection
                case .ready(let status):
                    credentialSection(status)
                }

                setupSection
                privacySection

                if case .ready(let status) = stateOwner.state,
                   status.primary.canAttemptRemove {
                    removeSection
                }
            }
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

    private var activeAttentionTarget: IOSSettingsAttentionTarget? {
        guard attentionTarget?.attention == .openAI else {
            return attentionTarget
        }
        guard case .ready(let status) = stateOwner.state,
              status.primary == .availableInThisProcess else {
            return attentionTarget
        }
        return nil
    }

    private var unavailableSection: some View {
        Section("OpenAI API Key") {
            Label(
                "Saved key unavailable",
                systemImage: "key.slash"
            )
            .foregroundStyle(.secondary)

            Text(
                "Other HoldType settings remain available. Try again later."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .accessibilityIdentifier("ios.settings.openai.unavailable")
    }

    private var loadingSection: some View {
        Section("OpenAI API Key") {
            HStack(spacing: 12) {
                ProgressView()
                Text("Loading key status…")
            }
        }
        .accessibilityIdentifier("ios.settings.openai.loading")
    }

    private func credentialSection(
        _ status: IOSOpenAICredentialStatus
    ) -> some View {
        let presentation = IOSOpenAICredentialPresentation(status: status)

        return Section {
            apiKeyField(presentation)

            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(presentation.title)
                    Text(presentation.explanation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: presentation.systemImage)
                    .foregroundStyle(presentation.tone.color)
            }
            .accessibilityIdentifier("ios.settings.openai.status")

            if let failure = stateOwner.failure,
               shouldPresentFailure(failure, over: status.primary) {
                Label(
                    failure.message,
                    systemImage: "exclamationmark.triangle"
                )
                .font(.footnote)
                .foregroundStyle(.red)
                .accessibilityIdentifier("ios.settings.openai.failure")
            }

            if presentation.offersVerification {
                Button {
                    Task { await stateOwner.refresh() }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .disabled(stateOwner.isBusy)
                .accessibilityIdentifier("ios.settings.openai.refresh")
            }

            if stateOwner.isBusy {
                HStack(spacing: 10) {
                    ProgressView()
                    Text(stateOwner.operation.progressTitle)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("ios.settings.openai.progress")
            }
        } header: {
            Text("OpenAI API Key")
        } footer: {
            Text(
                presentation.showsSavedKeyMask
                    ? "Enter a new key to replace the saved one."
                    : "Paste a key, or enter one and tap Done."
            )
        }
    }

    private func apiKeyField(
        _ presentation: IOSOpenAICredentialPresentation
    ) -> some View {
        HStack(spacing: 12) {
            ZStack(alignment: .leading) {
                SecureField(
                    presentation.showsSavedKeyMask
                        && editorDraft.value.isEmpty
                        ? ""
                        : "Enter OpenAI API key",
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
                .accessibilityLabel("OpenAI API key")
                .accessibilityValue(
                    presentation.showsSavedKeyMask
                        && editorDraft.value.isEmpty
                        ? "Saved API key present"
                        : editorDraft.value.isEmpty
                            ? "No API key entered"
                            : "API key entered"
                )
                .accessibilityIdentifier("ios.settings.openai.key-field")
                .iosSettingsField(
                    .openAIKey,
                    attentionTarget: activeAttentionTarget
                )

                if presentation.showsSavedKeyMask,
                   editorDraft.value.isEmpty {
                    Text("••••••••••••")
                        .font(.body.monospaced())
                        .environment(\.layoutDirection, .leftToRight)
                        .foregroundStyle(.secondary)
                        .privacySensitive()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }

            Button {
                pasteAndSave()
            } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(.borderless)
            .disabled(stateOwner.isBusy)
            .accessibilityLabel("Paste API key")
            .accessibilityHint("Pastes and saves the API key from Clipboard")
            .accessibilityIdentifier("ios.settings.openai.paste")
        }
    }

    private var removeSection: some View {
        Section {
            Button("Remove API Key", role: .destructive) {
                editorDraft.suppressManualCommitForCurrentFocusSession()
                isKeyFieldFocused = false
                showsRemoveConfirmation = true
            }
            .disabled(stateOwner.isBusy)
            .accessibilityIdentifier("ios.settings.openai.remove")
        }
    }

    private func shouldPresentFailure(
        _ failure: IOSOpenAICredentialSettingsFailure,
        over primary: IOSOpenAICredentialPrimaryStatus
    ) -> Bool {
        switch (failure, primary) {
        case (.unavailableWhileLocked, .unavailableWhileLocked),
             (.providerRejected, .providerRejected):
            false
        default:
            true
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
                "Your key is stored securely on this iPhone. The keyboard "
                    + "doesn’t receive it."
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
    var canAttemptRemove: Bool {
        self != .notConfigured
    }
}

private extension IOSOpenAICredentialPresentation.Tone {
    var color: Color {
        switch self {
        case .neutral:
            .secondary
        case .success:
            .green
        case .warning:
            .orange
        case .failure:
            .red
        }
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
