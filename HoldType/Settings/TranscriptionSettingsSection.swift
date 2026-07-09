//
//  TranscriptionSettingsSection.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import HoldTypeDomain
import SwiftUI

struct TranscriptionSettingsSection: View {
    @Binding var settings: AppSettings

    var body: some View {
        Section("Transcription") {
            SettingsTechnicalTextField(
                title: "Model",
                text: $settings.transcriptionModel
            )

            if isUsingDefaultTranscriptionModelFallback {
                Label(
                    "Empty model uses \(AppSettings.defaultTranscriptionModel).",
                    systemImage: "info.circle"
                )
                .foregroundStyle(.secondary)
            }

            Picker("Language", selection: $settings.language) {
                ForEach(TranscriptionLanguage.allCases, id: \.self) { language in
                    Text(language.displayName).tag(language)
                }
            }

            if settings.language == .custom {
                SettingsTechnicalTextField(
                    title: "Custom language code",
                    text: $settings.customLanguageCode
                )

                Label(
                    customLanguageCodeStatusMessage,
                    systemImage: customLanguageCodeStatusImage
                )
                .foregroundStyle(customLanguageCodeStatusTint)
            }

            SettingsTechnicalTextArea(
                title: "Prompt",
                text: $settings.prompt,
                minLines: 2,
                maxLines: 4
            )

            Toggle("Use nearby text as transcription context", isOn: $settings.useActiveTextContext)

            Text(
                "When enabled, HoldType can read a short excerpt near the active cursor and send it to OpenAI with the recording."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
    }

    private var isUsingDefaultTranscriptionModelFallback: Bool {
        settings.transcriptionModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var customLanguageCodeStatusMessage: String {
        switch settings.customLanguageCodeValidation {
        case .notRequired:
            return ""
        case .emptyFallsBackToAutomatic:
            return "Empty custom language uses Auto."
        case .valid(let normalizedCode):
            return "Language code: \(normalizedCode)"
        case .invalid:
            return "Use a two- or three-letter code, such as en or ru."
        }
    }

    private var customLanguageCodeStatusImage: String {
        settings.customLanguageCodeValidation.isInvalid ? "exclamationmark.triangle" : "info.circle"
    }

    private var customLanguageCodeStatusTint: Color {
        settings.customLanguageCodeValidation.isInvalid ? .red : .secondary
    }
}

#Preview {
    Form {
        TranscriptionSettingsSection(
            settings: .constant(
                AppSettings(
                    transcriptionModel: "",
                    language: .custom,
                    customLanguageCode: "ru",
                    prompt: "Prefer product vocabulary.",
                    customDictionary: ["OpenWhispr", "Synty", "The word is HoldType"],
                    useActiveTextContext: true,
                    automaticallyInsertTranscripts: true,
                    saveTranscriptsToAppClipboard: true,
                    soundEnabled: true,
                    showFloatingIndicator: true,
                    saveTranscriptHistory: false
                )
            )
        )
    }
    .formStyle(.grouped)
    .padding()
}
