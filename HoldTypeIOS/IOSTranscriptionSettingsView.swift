import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSTranscriptionSettingsView: View {
    @Environment(IOSAppSettingsStateOwner.self) private var stateOwner

    @State private var session: IOSSettingsEditorSession<
        TranscriptionConfiguration
    >
    @State private var advancedIsExpanded: Bool
    private let attentionTarget: IOSSettingsAttentionTarget?

    init(
        configuration: TranscriptionConfiguration,
        attentionTarget: IOSSettingsAttentionTarget? = nil
    ) {
        _session = State(
            initialValue: IOSSettingsEditorSession(value: configuration)
        )
        _advancedIsExpanded = State(
            initialValue: attentionTarget?.field == .transcriptionModel
                || attentionTarget?.field == .transcriptionInstructions
        )
        self.attentionTarget = attentionTarget
    }

    var body: some View {
        IOSSettingsForm(attentionTarget: activeAttentionTarget) {
            IOSSettingsEditorStatusSection(
                phase: session.phase,
                retry: retryAutosave,
                useSavedValue: { session.discard() }
            )

            Section("Language") {
                NavigationLink {
                    IOSLanguageSelectionView(
                        title: "Dictation Language",
                        options: TranscriptionLanguage.allCases,
                        automaticTitle: "Auto",
                        selection: binding(\.language)
                    )
                } label: {
                    LabeledContent(
                        "Dictation Language",
                        value: IOSLanguageSelectionPresentation.title(
                            for: session.draft.language,
                            automaticTitle: "Auto"
                        )
                    )
                }
                .iosSettingsField(
                    .transcriptionLanguage,
                    attentionTarget: activeAttentionTarget
                )

                if session.draft.language == .custom {
                    TextField(
                        "Custom language code",
                        text: binding(\.customLanguageCode)
                    )
                    .keyboardType(.asciiCapable)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityHint(customLanguageCodeAccessibilityHint)
                    .iosSettingsField(
                        .transcriptionCustomLanguage,
                        attentionTarget: activeAttentionTarget
                    )

                    customLanguageStatus
                }
            }

            Section {
                DisclosureGroup("Advanced", isExpanded: $advancedIsExpanded) {
                    TextField("Model ID", text: binding(\.model))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .iosSettingsField(
                            .transcriptionModel,
                            attentionTarget: activeAttentionTarget
                        )

                    if usesDefaultModel {
                        Text("Uses HoldType’s standard model.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    IOSSettingsMultilineField(
                        title: "Additional Instructions",
                        prompt: "Optional vocabulary or style guidance",
                        text: binding(\.freeformPrompt),
                        lineLimit: 3...10
                    )
                    .iosSettingsField(
                        .transcriptionInstructions,
                        attentionTarget: activeAttentionTarget
                    )

                    Text("Instructions are sent only with your transcriptions.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier(
                    "ios.settings.transcription.advanced"
                )
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Transcription")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.settings.transcription.screen")
        .onChange(of: durableConfiguration, initial: true) { _, value in
            observeDurableConfiguration(value)
        }
        .onChange(of: customLanguageCodeInputState) {
            oldValue,
            newValue in
            announceCustomLanguageValidation(
                from: oldValue,
                to: newValue
            )
        }
        .iosSettingsAutosaveChrome(phase: session.phase)
    }

    private var activeAttentionTarget: IOSSettingsAttentionTarget? {
        guard attentionTarget?.attention == .transcription else {
            return attentionTarget
        }
        return session.draft.language == .custom
            && session.draft.customLanguageCodeValidation.isInvalid
            ? attentionTarget
            : nil
    }

    @ViewBuilder
    private var customLanguageStatus: some View {
        switch session.draft.customLanguageCodeValidation {
        case .notRequired:
            EmptyView()
        case .emptyFallsBackToAutomatic:
            Label(
                "Blank custom code uses Auto.",
                systemImage: "info.circle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        case .valid(let normalizedCode):
            Label(
                "Language code: \(normalizedCode)",
                systemImage: "checkmark.circle"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        case .invalid:
            IOSSettingsWarningLabel(
                "Use two or three letters, such as en or ru.",
                color: .red
            )
            .accessibilityIdentifier(
                "ios.settings.transcription.language-invalid"
            )
        }
    }

    private var durableConfiguration: TranscriptionConfiguration {
        stateOwner.state.durableValue?.transcriptionConfiguration
            ?? session.baseline
    }

    private var usesDefaultModel: Bool {
        session.draft.model
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var isValidForAutosave: Bool {
        IOSAppSettingsEditorValidation.canSaveTranscription(session.draft)
    }

    private var customLanguageCodeAccessibilityHint: String {
        switch session.draft.customLanguageCodeValidation {
        case .notRequired:
            return ""
        case .emptyFallsBackToAutomatic:
            return "Blank uses Auto."
        case .valid:
            return "Valid language code."
        case .invalid:
            return "Invalid. Use two or three letters."
        }
    }

    private var customLanguageCodeInputState:
        IOSCustomLanguageCodeInputState? {
        guard session.draft.language == .custom else { return nil }
        return .resolve(session.draft.customLanguageCode)
    }

    private func binding<Field: Equatable>(
        _ keyPath: WritableKeyPath<TranscriptionConfiguration, Field>
    ) -> Binding<Field> {
        Binding(
            get: { session.draft[keyPath: keyPath] },
            set: { value in
                guard session.set(value, at: keyPath) else { return }
                startAutosaveIfNeeded()
            }
        )
    }

    private func startAutosaveIfNeeded() {
        guard isValidForAutosave else {
            session.markValidationBlocked()
            return
        }
        guard let candidate = session.beginSave() else { return }

        Task { await commit(candidate) }
    }

    private func retryAutosave() {
        session.retry()
        startAutosaveIfNeeded()
    }

    private func observeDurableConfiguration(
        _ value: TranscriptionConfiguration
    ) {
        let previousPhase = session.phase
        session.observeDurableValue(value)
        if session.phase == .changedElsewhere,
           previousPhase != .changedElsewhere {
            iosAnnounceSettingsStatus(
                "Settings changed elsewhere. This draft is not saved."
            )
        }
    }

    private func announceCustomLanguageValidation(
        from oldValue: IOSCustomLanguageCodeInputState?,
        to newValue: IOSCustomLanguageCodeInputState?
    ) {
        guard IOSCustomLanguageCodeInputState
            .shouldAnnounceValidityRecovery(from: oldValue, to: newValue)
        else { return }
        iosAnnounceSettingsStatus("Custom language code is valid")
    }

    private func commit(
        _ candidate: TranscriptionConfiguration
    ) async {
        do {
            let state = try await stateOwner.update {
                IOSAppSettingsEditorMutation.applyTranscription(
                    candidate,
                    to: &$0
                )
            }
            guard let value = state.durableValue else {
                commitFailed()
                return
            }
            let returned = value.transcriptionConfiguration
            let latest = durableConfiguration
            session.commitSucceeded(
                returnedDurableValue: returned,
                latestDurableValue: latest
            )
            if session.phase == .changedElsewhere {
                iosAnnounceSettingsStatus(
                    "Transcription settings changed elsewhere"
                )
            } else {
                startAutosaveIfNeeded()
            }
        } catch {
            commitFailed()
        }
    }

    private func commitFailed() {
        let durable = stateOwner.state.durableValue?
            .transcriptionConfiguration ?? session.baseline
        session.commitFailed(restoring: durable)
        iosAnnounceSettingsStatus("Transcription settings were not saved")
    }
}
