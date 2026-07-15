import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSWritingCorrectionSettingsView: View {
    @Environment(IOSAppSettingsStateOwner.self) private var stateOwner

    @State private var session: IOSSettingsEditorSession<
        IOSWritingCorrectionSettingsDraft
    >
    @State private var showsDiscardConfirmation = false
    @State private var advancedIsExpanded: Bool
    @Binding private var hasUnsavedSceneEditor: Bool
    private let attentionTarget: IOSSettingsAttentionTarget?

    init(
        configuration: TextCorrectionConfiguration,
        localTextCleanupEnabled: Bool,
        attentionTarget: IOSSettingsAttentionTarget? = nil,
        hasUnsavedSceneEditor: Binding<Bool> = .constant(false)
    ) {
        _session = State(
            initialValue: IOSSettingsEditorSession(
                value: IOSWritingCorrectionSettingsDraft(
                    configuration: configuration,
                    localTextCleanupEnabled: localTextCleanupEnabled
                )
            )
        )
        _advancedIsExpanded = State(
            initialValue: attentionTarget?.field == .correctionModel
                || attentionTarget?.field == .correctionCustomModel
                || attentionTarget?.field == .correctionInstructions
        )
        self.attentionTarget = attentionTarget
        _hasUnsavedSceneEditor = hasUnsavedSceneEditor
    }

    var body: some View {
        IOSSettingsForm(attentionTarget: attentionTarget) {
            IOSSettingsEditorStatusSection(phase: session.phase)

            Section("Local Cleanup") {
                Toggle(
                    "Use Plain Typography Cleanup",
                    isOn: binding(\.localTextCleanupEnabled)
                )
                .iosSettingsField(
                    .correctionLocalCleanup,
                    attentionTarget: attentionTarget
                )
                Text(
                    "Normalizes smart quotes, long dashes, ellipses, and "
                        + "non-breaking spaces locally."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("OpenAI Correction") {
                Toggle(
                    "Correct Transcript with OpenAI",
                    isOn: configurationBinding(\.isEnabled)
                )
                .iosSettingsField(
                    .correctionEnabled,
                    attentionTarget: attentionTarget
                )

                Text(
                    "Uses OpenAI after transcription. Off by default."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                DisclosureGroup("Advanced", isExpanded: $advancedIsExpanded) {
                    Picker(
                        "Correction Model",
                        selection: configurationBinding(\.modelPreset)
                    ) {
                        ForEach(
                            TextCorrectionModelPreset.allCases,
                            id: \.self
                        ) { preset in
                            Text(preset.iosSettingsDisplayName).tag(preset)
                        }
                    }
                    .iosSettingsField(
                        .correctionModel,
                        attentionTarget: attentionTarget
                    )

                    Text(selectedModelDetail)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if configuration.modelPreset == .custom {
                        TextField(
                            "Custom model ID",
                            text: configurationBinding(\.customModel)
                        )
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .iosSettingsField(
                            .correctionCustomModel,
                            attentionTarget: attentionTarget
                        )

                        if usesDefaultCustomModel {
                            Text("Uses HoldType’s standard correction model.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    IOSSettingsMultilineField(
                        title: "Additional Instructions",
                        prompt: "Optional correction guidance",
                        text: correctionInstructionsBinding,
                        lineLimit: 3...8
                    )
                    .iosSettingsField(
                        .correctionInstructions,
                        attentionTarget: attentionTarget
                    )

                    Button {
                        resetPrompt()
                    } label: {
                        Label(
                            "Use Standard Instructions",
                            systemImage: "arrow.counterclockwise"
                        )
                    }
                    .disabled(usesStandardInstructions)

                    Text("Leave blank to use HoldType’s standard correction.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("ios.settings.correction.advanced")
            }
        }
        .disabled(session.isSaving)
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Writing & Correction")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.settings.correction.screen")
        .onChange(of: durableDraft, initial: true) { _, value in
            observeDurableDraft(value)
        }
        .onChange(of: session.isDirty, initial: true) { _, isDirty in
            hasUnsavedSceneEditor = isDirty
        }
        .iosSettingsEditorChrome(
            isDirty: session.isDirty,
            isSaving: session.isSaving,
            canSave: session.isDirty && !session.isSaving,
            phase: session.phase,
            showsDiscardConfirmation: $showsDiscardConfirmation,
            hasUnsavedSceneEditor: $hasUnsavedSceneEditor,
            save: beginSave,
            discard: { session.discard() }
        )
    }

    private var configuration: TextCorrectionConfiguration {
        session.draft.configuration
    }

    private var durableDraft: IOSWritingCorrectionSettingsDraft {
        guard let settings = stateOwner.state.durableValue else {
            return session.baseline
        }
        return IOSWritingCorrectionSettingsDraft(
            configuration: settings.textCorrectionConfiguration,
            localTextCleanupEnabled: settings.localTextCleanupEnabled
        )
    }

    private var selectedModelDetail: String {
        configuration.modelPreset.iosSettingsDetail
    }

    private var usesDefaultCustomModel: Bool {
        configuration.customModel
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var usesStandardInstructions: Bool {
        IOSProviderInstructionsPresentation.usesStandardBehavior(
            storedValue: configuration.prompt,
            defaultValue: TextCorrectionConfiguration.defaultPrompt
        )
    }

    private var correctionInstructionsBinding: Binding<String> {
        Binding(
            get: {
                IOSProviderInstructionsPresentation.displayedValue(
                    storedValue: configuration.prompt,
                    defaultValue: TextCorrectionConfiguration.defaultPrompt
                )
            },
            set: { value in
                var updated = configuration
                updated.prompt = IOSProviderInstructionsPresentation.storedValue(
                    from: value,
                    defaultValue: TextCorrectionConfiguration.defaultPrompt
                )
                session.set(updated, at: \.configuration)
            }
        )
    }

    private func binding<Field: Equatable>(
        _ keyPath: WritableKeyPath<
            IOSWritingCorrectionSettingsDraft,
            Field
        >
    ) -> Binding<Field> {
        Binding(
            get: { session.draft[keyPath: keyPath] },
            set: { session.set($0, at: keyPath) }
        )
    }

    private func configurationBinding<Field: Equatable>(
        _ keyPath: WritableKeyPath<TextCorrectionConfiguration, Field>
    ) -> Binding<Field> {
        Binding(
            get: { configuration[keyPath: keyPath] },
            set: { value in
                var updated = configuration
                updated[keyPath: keyPath] = value
                session.set(updated, at: \.configuration)
            }
        )
    }

    private func resetPrompt() {
        var updated = configuration
        updated.resetPrompt()
        session.set(updated, at: \.configuration)
        iosAnnounceSettingsStatus(
            "Standard correction instructions restored. Not saved."
        )
    }

    private func observeDurableDraft(
        _ value: IOSWritingCorrectionSettingsDraft
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

    private func beginSave() {
        guard let candidate = session.beginSave() else { return }
        Task { await commit(candidate) }
    }

    private func commit(
        _ candidate: IOSWritingCorrectionSettingsDraft
    ) async {
        do {
            let state = try await stateOwner.update {
                IOSAppSettingsEditorMutation.applyWritingAndCorrection(
                    candidate,
                    to: &$0
                )
            }
            guard let settings = state.durableValue else {
                commitFailed()
                return
            }
            let returned = IOSWritingCorrectionSettingsDraft(
                configuration: settings.textCorrectionConfiguration,
                localTextCleanupEnabled: settings.localTextCleanupEnabled
            )
            session.commitSucceeded(
                returnedDurableValue: returned,
                latestDurableValue: durableDraft
            )
            iosAnnounceSettingsStatus(
                session.phase == .saved
                    ? "Writing settings saved"
                    : "Writing settings changed elsewhere"
            )
        } catch {
            commitFailed()
        }
    }

    private func commitFailed() {
        session.commitFailed(restoring: durableDraft)
        iosAnnounceSettingsStatus("Writing settings were not saved")
    }
}
