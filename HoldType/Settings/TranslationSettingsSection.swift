//
//  TranslationSettingsSection.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import HoldTypeDomain
import SwiftUI

struct TranslationSettingsSection: View {
    @Binding var settings: AppSettings

    var body: some View {
        Section("Translation Shortcut") {
            Toggle("Translate with Option+Right Command", isOn: $settings.translationShortcutEnabled)

            Text("When a target language is selected, runs one additional OpenAI request after transcription and correction.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Section("Languages") {
            Toggle("Override source language", isOn: isSourceOverrideEnabled)
                .toggleStyle(.switch)

            if settings.translationSourceMode == .override {
                Picker("Source language", selection: $settings.translationSourceLanguage) {
                    Text("Choose source language").tag(TranscriptionLanguage.automatic)

                    ForEach(TranscriptionLanguage.translationCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
            }

            if settings.translationSourceMode == .override,
               settings.translationSourceLanguage == .custom {
                customLanguageCodeField(
                    title: "Custom source code",
                    code: $settings.customTranslationSourceLanguageCode
                )
            }

            Picker("Target language", selection: $settings.translationTargetLanguage) {
                Text("Choose target language").tag(TranscriptionLanguage.automatic)

                ForEach(TranscriptionLanguage.translationCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }

            if settings.translationTargetLanguage == .custom {
                customLanguageCodeField(
                    title: "Custom target code",
                    code: $settings.customTranslationTargetLanguageCode
                )
            }

            Label(translationRouteText, systemImage: translationRouteStatusImage)
                .foregroundStyle(translationRouteStatusTint)
        }

        Section("OpenAI Translation") {
            SettingsTechnicalTextField(
                title: "Model",
                text: $settings.translationModel
            )

            if isUsingDefaultTranslationModelFallback {
                Label(
                    "Empty model uses \(AppSettings.defaultTranslationModel).",
                    systemImage: "info.circle"
                )
                .foregroundStyle(.secondary)
            }

            SettingsTechnicalPromptTextArea(
                title: "Translation prompt",
                text: $settings.translationPrompt,
                minLines: 6,
                maxLines: 10
            ) {
                Button {
                    settings.resetTranslationPrompt()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(settings.isTranslationPromptDefault)
                .help("Restore the standard translation prompt")
            }

            Text(
                "This prompt is sent as OpenAI translation instructions. Target language is added separately; source language is added only when known."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var isUsingDefaultTranslationModelFallback: Bool {
        settings.translationModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isSourceOverrideEnabled: Binding<Bool> {
        Binding(
            get: { settings.translationSourceMode == .override },
            set: { isEnabled in
                settings.translationSourceMode = isEnabled ? .override : .sameAsTranscription
            }
        )
    }

    private var translationRouteText: String {
        guard settings.isTranslationSourceConfigurationValid else {
            return "Choose a valid source override or use Same as Transcription."
        }

        guard let targetCode = settings.resolvedTranslationTargetLanguageCode else {
            return "Choose a target language."
        }

        guard let sourceCode = settings.resolvedTranslationSourceLanguageCode else {
            return "Translation route: transcription output -> \(targetCode)"
        }

        return "Translation route: \(sourceCode) -> \(targetCode)"
    }

    private var translationRouteStatusImage: String {
        !settings.isTranslationSourceConfigurationValid
            || settings.resolvedTranslationTargetLanguageCode == nil
            ? "exclamationmark.triangle"
            : "arrow.right.circle"
    }

    private var translationRouteStatusTint: Color {
        !settings.isTranslationSourceConfigurationValid
            || settings.resolvedTranslationTargetLanguageCode == nil
            ? .red
            : .secondary
    }

    @ViewBuilder
    private func customLanguageCodeField(title: String, code: Binding<String>) -> some View {
        SettingsTechnicalTextField(
            title: title,
            text: code
        )

        Label(
            customLanguageCodeStatusMessage(for: code.wrappedValue),
            systemImage: customLanguageCodeStatusImage(for: code.wrappedValue)
        )
        .foregroundStyle(customLanguageCodeStatusTint(for: code.wrappedValue))
    }

    private func customLanguageCodeStatusMessage(for code: String) -> String {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty else {
            return "Enter a two- or three-letter language code."
        }

        guard AppSettings.isSupportedCustomLanguageCode(trimmedCode) else {
            return "Use a two- or three-letter code, such as es or ja."
        }

        return "Language code: \(trimmedCode.lowercased())"
    }

    private func customLanguageCodeStatusImage(for code: String) -> String {
        AppSettings.isSupportedCustomLanguageCode(code) ? "info.circle" : "exclamationmark.triangle"
    }

    private func customLanguageCodeStatusTint(for code: String) -> Color {
        AppSettings.isSupportedCustomLanguageCode(code) ? .secondary : .red
    }
}

#Preview {
    Form {
        TranslationSettingsSection(
            settings: .constant(
                AppSettings(
                    transcriptionModel: AppSettings.defaultTranscriptionModel,
                    language: .automatic,
                    customLanguageCode: "",
                    prompt: "",
                    customDictionary: [],
                    useActiveTextContext: false,
                    translationShortcutEnabled: true,
                    translationSourceMode: .sameAsTranscription,
                    translationSourceLanguage: .automatic,
                    translationTargetLanguage: .english,
                    automaticallyInsertTranscripts: true,
                    saveTranscriptsToAppClipboard: true,
                    soundEnabled: true,
                    showFloatingIndicator: true,
                    saveTranscriptHistory: true
                )
            )
        )
    }
    .formStyle(.grouped)
    .padding()
}
