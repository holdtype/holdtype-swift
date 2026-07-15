import HoldTypeDomain
import HoldTypePersistence
import SwiftUI

struct IOSTranslationSettingsView: View {
    @Environment(IOSAppSettingsStateOwner.self) private var stateOwner

    @State private var session: IOSSettingsEditorSession<
        TranslationConfiguration
    >
    @State private var advancedIsExpanded: Bool
    private let attentionTarget: IOSSettingsAttentionTarget?

    init(
        configuration: TranslationConfiguration,
        attentionTarget: IOSSettingsAttentionTarget? = nil
    ) {
        var configuration = configuration
        configuration.actionPreferenceEnabled = true
        _session = State(
            initialValue: IOSSettingsEditorSession(value: configuration)
        )
        _advancedIsExpanded = State(
            initialValue: attentionTarget?.field == .translationModel
                || attentionTarget?.field == .translationInstructions
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

            Section("Languages") {
                Picker("Source", selection: binding(\.sourceMode)) {
                    ForEach(TranslationSourceMode.allCases, id: \.self) {
                        mode in
                        Text(mode.iosSettingsDisplayName).tag(mode)
                    }
                }
                .iosSettingsField(
                    .translationSourceMode,
                    attentionTarget: activeAttentionTarget
                )

                if configuration.sourceMode == .override {
                    NavigationLink {
                        IOSLanguageSelectionView(
                            title: "Source Language",
                            options: [TranscriptionLanguage.automatic]
                                + TranscriptionLanguage
                                    .iosTranslationCases,
                            automaticTitle: "Choose Source",
                            selection: binding(\.sourceLanguage)
                        )
                    } label: {
                        LabeledContent(
                            "Source Language",
                            value: IOSLanguageSelectionPresentation.title(
                                for: configuration.sourceLanguage,
                                automaticTitle: "Choose Source"
                            )
                        )
                    }
                    .iosSettingsField(
                        .translationSourceLanguage,
                        attentionTarget: activeAttentionTarget
                    )

                    if configuration.sourceLanguage == .custom {
                        customCodeField(
                            title: "Custom Source Code",
                            text: binding(\.customSourceLanguageCode),
                            value: configuration.customSourceLanguageCode,
                            field: .translationCustomSource
                        )
                    }
                }

                NavigationLink {
                    IOSLanguageSelectionView(
                        title: "Target Language",
                        options: [TranscriptionLanguage.automatic]
                            + TranscriptionLanguage.iosTranslationCases,
                        automaticTitle: "Choose Target",
                        selection: binding(\.targetLanguage)
                    )
                } label: {
                    LabeledContent(
                        "Target Language",
                        value: IOSLanguageSelectionPresentation.title(
                            for: configuration.targetLanguage,
                            automaticTitle: "Choose Target"
                        )
                    )
                }
                .iosSettingsField(
                    .translationTargetLanguage,
                    attentionTarget: activeAttentionTarget
                )

                if configuration.targetLanguage == .custom {
                    customCodeField(
                        title: "Custom Target Code",
                        text: binding(\.customTargetLanguageCode),
                        value: configuration.customTargetLanguageCode,
                        field: .translationCustomTarget
                    )
                }

                routeStatus
            }

            Section {
                DisclosureGroup("Advanced", isExpanded: $advancedIsExpanded) {
                    TextField("Model ID", text: binding(\.model))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .iosSettingsField(
                            .translationModel,
                            attentionTarget: activeAttentionTarget
                        )

                    if usesDefaultModel {
                        Text("Uses HoldType’s standard translation model.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    IOSSettingsMultilineField(
                        title: "Additional Instructions",
                        prompt: "Optional translation guidance",
                        text: translationInstructionsBinding,
                        lineLimit: 3...8
                    )
                    .iosSettingsField(
                        .translationInstructions,
                        attentionTarget: activeAttentionTarget
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

                    Text("Leave blank to use HoldType’s standard translation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .accessibilityIdentifier("ios.settings.translation.advanced")
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Translation")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("ios.settings.translation.screen")
        .onChange(of: durableConfiguration, initial: true) { _, value in
            observeDurableConfiguration(value)
        }
        .onChange(of: sourceCodeInputState) { oldValue, newValue in
            announceCustomCodeTransition(
                from: oldValue,
                to: newValue,
                role: "Source"
            )
        }
        .onChange(of: targetCodeInputState) { oldValue, newValue in
            announceCustomCodeTransition(
                from: oldValue,
                to: newValue,
                role: "Target"
            )
        }
        .iosSettingsAutosaveChrome(phase: session.phase)
    }

    private var configuration: TranslationConfiguration { session.draft }

    private var activeAttentionTarget: IOSSettingsAttentionTarget? {
        guard attentionTarget?.attention == .translation,
              configuration.routeConfigurationIssue != nil else {
            return nil
        }
        return attentionTarget
    }

    private var durableConfiguration: TranslationConfiguration {
        var configuration = stateOwner.state.durableValue?.translationConfiguration
            ?? session.baseline
        configuration.actionPreferenceEnabled = true
        return configuration
    }

    private var usesDefaultModel: Bool {
        configuration.model
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }

    private var isValidForAutosave: Bool {
        IOSAppSettingsEditorValidation.canSaveTranslation(configuration)
    }

    private var usesStandardInstructions: Bool {
        IOSProviderInstructionsPresentation.usesStandardBehavior(
            storedValue: configuration.prompt,
            defaultValue: TranslationConfiguration.defaultPrompt
        )
    }

    private var translationInstructionsBinding: Binding<String> {
        Binding(
            get: {
                IOSProviderInstructionsPresentation.displayedValue(
                    storedValue: configuration.prompt,
                    defaultValue: TranslationConfiguration.defaultPrompt
                )
            },
            set: { value in
                guard session.set(
                    IOSProviderInstructionsPresentation.storedValue(
                        from: value,
                        defaultValue: TranslationConfiguration.defaultPrompt
                    ),
                    at: \.prompt
                ) else { return }
                startAutosaveIfNeeded()
            }
        )
    }

    private var sourceCodeInputState: IOSCustomLanguageCodeInputState? {
        guard configuration.sourceMode == .override,
              configuration.sourceLanguage == .custom else {
            return nil
        }
        return .resolve(configuration.customSourceLanguageCode)
    }

    private var targetCodeInputState: IOSCustomLanguageCodeInputState? {
        guard configuration.targetLanguage == .custom else { return nil }
        return .resolve(configuration.customTargetLanguageCode)
    }

    @ViewBuilder
    private var routeStatus: some View {
        switch configuration.routeConfigurationIssue {
        case .invalidSourceLanguage:
            IOSSettingsWarningLabel(
                "Choose a valid source override or use Same as Transcription.",
                color: .orange
            )
        case .missingTargetLanguage:
            IOSSettingsWarningLabel(
                "Choose a target language to make Translate available.",
                color: .orange
            )
        case nil:
            Label(readyRouteDescription, systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var readyRouteDescription: String {
        let target = IOSLanguageSelectionPresentation.title(
            for: configuration.targetLanguage,
            automaticTitle: "selected language"
        )
        return "Ready to translate to \(target)."
    }

    @ViewBuilder
    private func customCodeField(
        title: String,
        text: Binding<String>,
        value: String,
        field: IOSSettingsField
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField(title, text: text)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityHint(customCodeAccessibilityHint(for: value))

            let trimmed = value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if trimmed.isEmpty {
                Label(
                    "Enter two or three letters to complete this route.",
                    systemImage: "info.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else if TranscriptionLanguage
                .isWellFormedCustomLanguageCode(trimmed) {
                Label(
                    "Language code: \(trimmed.lowercased())",
                    systemImage: "checkmark.circle"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            } else {
                IOSSettingsWarningLabel(
                    "Use two or three letters, such as es or ja.",
                    color: .red
                )
                .accessibilityIdentifier(
                    "ios.settings.translation.language-invalid"
                )
            }
        }
        .iosSettingsField(field, attentionTarget: activeAttentionTarget)
    }

    private func binding<Field: Equatable>(
        _ keyPath: WritableKeyPath<TranslationConfiguration, Field>
    ) -> Binding<Field> {
        Binding(
            get: { session.draft[keyPath: keyPath] },
            set: { value in
                guard session.set(value, at: keyPath) else { return }
                startAutosaveIfNeeded()
            }
        )
    }

    private func resetPrompt() {
        var updated = configuration
        updated.resetPrompt()
        guard session.set(updated.prompt, at: \.prompt) else { return }
        startAutosaveIfNeeded()
        iosAnnounceSettingsStatus("Standard translation instructions restored")
    }

    private func customCodeAccessibilityHint(for code: String) -> String {
        switch IOSCustomLanguageCodeInputState.resolve(code) {
        case .empty:
            return "Empty. Enter two or three letters to complete the route."
        case .valid:
            return "Valid language code."
        case .invalid:
            return "Invalid. Use two or three letters."
        }
    }

    private func observeDurableConfiguration(
        _ value: TranslationConfiguration
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

    private func announceCustomCodeTransition(
        from oldValue: IOSCustomLanguageCodeInputState?,
        to newValue: IOSCustomLanguageCodeInputState?,
        role: String
    ) {
        guard IOSCustomLanguageCodeInputState
            .shouldAnnounceValidityRecovery(from: oldValue, to: newValue)
        else { return }
        iosAnnounceSettingsStatus("\(role) language code is valid")
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

    private func commit(_ candidate: TranslationConfiguration) async {
        do {
            let state = try await stateOwner.update {
                IOSAppSettingsEditorMutation.applyTranslation(
                    candidate,
                    to: &$0
                )
            }
            guard let settings = state.durableValue else {
                commitFailed()
                return
            }
            let returned = settings.translationConfiguration
            session.commitSucceeded(
                returnedDurableValue: returned,
                latestDurableValue: durableConfiguration
            )
            if session.phase == .changedElsewhere {
                iosAnnounceSettingsStatus(
                    "Translation settings changed elsewhere"
                )
            } else {
                startAutosaveIfNeeded()
            }
        } catch {
            commitFailed()
        }
    }

    private func commitFailed() {
        session.commitFailed(restoring: durableConfiguration)
        iosAnnounceSettingsStatus("Translation settings were not saved")
    }
}
