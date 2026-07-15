import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSWritingCorrectionSettingsView: View {
    @Environment(IOSAppSettingsStateOwner.self) private var stateOwner

    @State private var session: IOSSettingsEditorSession<
        IOSWritingCorrectionSettingsDraft
    >
    @State private var advancedIsExpanded: Bool
    private let attentionTarget: IOSSettingsAttentionTarget?

    init(
        configuration: TextCorrectionConfiguration,
        localTextCleanupEnabled: Bool,
        attentionTarget: IOSSettingsAttentionTarget? = nil
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
    }

    var body: some View {
        IOSSettingsForm(attentionTarget: attentionTarget) {
            IOSSettingsEditorStatusSection(
                phase: session.phase,
                retry: retryAutosave,
                useSavedValue: { session.discard() }
            )

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
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Writing & Correction")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.settings.correction.screen")
        .onChange(of: durableDraft, initial: true) { _, value in
            observeDurableDraft(value)
        }
        .iosSettingsAutosaveChrome(phase: session.phase)
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
                guard session.set(updated, at: \.configuration) else { return }
                startAutosaveIfNeeded()
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
            set: { value in
                guard session.set(value, at: keyPath) else { return }
                startAutosaveIfNeeded()
            }
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
                guard session.set(updated, at: \.configuration) else { return }
                startAutosaveIfNeeded()
            }
        )
    }

    private func resetPrompt() {
        var updated = configuration
        updated.resetPrompt()
        guard session.set(updated, at: \.configuration) else { return }
        startAutosaveIfNeeded()
        iosAnnounceSettingsStatus("Standard correction instructions restored")
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

    private func startAutosaveIfNeeded() {
        guard let candidate = session.beginSave() else { return }
        Task { await commit(candidate) }
    }

    private func retryAutosave() {
        session.retry()
        startAutosaveIfNeeded()
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
            if session.phase == .changedElsewhere {
                iosAnnounceSettingsStatus(
                    "Writing settings changed elsewhere"
                )
            } else {
                startAutosaveIfNeeded()
            }
        } catch {
            commitFailed()
        }
    }

    private func commitFailed() {
        session.commitFailed(restoring: durableDraft)
        iosAnnounceSettingsStatus("Writing settings were not saved")
    }
}
