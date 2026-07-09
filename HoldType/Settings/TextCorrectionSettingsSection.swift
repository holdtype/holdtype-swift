//
//  TextCorrectionSettingsSection.swift
//  HoldType
//
//  Created by Codex on 7/5/26.
//

import HoldTypeDomain
import SwiftUI

struct TextCorrectionSettingsSection: View {
    @Binding var settings: AppSettings

    var body: some View {
        Section("OpenAI Correction") {
            Toggle("Correct transcript with OpenAI", isOn: $settings.textCorrectionEnabled)

            Text("Runs one additional OpenAI request after transcription. Off by default.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Picker("Correction model", selection: $settings.textCorrectionModelPreset) {
                ForEach(TextCorrectionModelPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .disabled(!settings.textCorrectionEnabled)

            Label(selectedModelDetail, systemImage: "info.circle")
                .foregroundStyle(.secondary)

            if settings.textCorrectionModelPreset == .custom {
                SettingsTechnicalTextField(
                    title: "Custom model",
                    text: $settings.customTextCorrectionModel
                )
                .disabled(!settings.textCorrectionEnabled)
            }

            SettingsTechnicalPromptTextArea(
                title: "Correction system prompt",
                text: $settings.textCorrectionPrompt,
                minLines: 6,
                maxLines: 10
            ) {
                Button {
                    settings.resetTextCorrectionPrompt()
                } label: {
                    Label("Reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(settings.isTextCorrectionPromptDefault)
                .help("Restore the standard correction prompt")
            }

            Text(
                "This prompt is sent as the OpenAI correction instructions. Reset restores HoldType's standard minimal-correction prompt."
            )
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Section("Local Cleanup") {
            Toggle("Use plain typography cleanup", isOn: $settings.localTextCleanupEnabled)

            Text("Normalizes long dashes, smart quotes, ellipses, and non-breaking spaces locally.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }

        Section("Replacement Rules") {
            if settings.textReplacementRules.isEmpty {
                Label("No replacement rules.", systemImage: "text.badge.plus")
                    .foregroundStyle(.secondary)
            }

            ForEach($settings.textReplacementRules) { $rule in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Toggle("", isOn: $rule.isEnabled)
                        .labelsHidden()

                    SettingsTechnicalTextFieldInput(
                        placeholder: "Search",
                        text: $rule.search
                    )

                    Image(systemName: "arrow.right")
                        .foregroundStyle(.secondary)

                    SettingsTechnicalTextFieldInput(
                        placeholder: "Replace",
                        text: $rule.replacement
                    )

                    Button {
                        removeRule(id: rule.id)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove rule")
                }
            }

            Button {
                settings.textReplacementRules.append(
                    TextReplacementRule(search: "", replacement: "")
                )
            } label: {
                Label("Add Replacement Rule", systemImage: "plus")
            }
        }
    }

    private var selectedModelDetail: String {
        "\(settings.textCorrectionModelPreset.detail): \(settings.resolvedTextCorrectionModel)"
    }

    private func removeRule(id: UUID) {
        settings.textReplacementRules.removeAll { $0.id == id }
    }
}

#Preview {
    Form {
        TextCorrectionSettingsSection(
            settings: .constant(
                AppSettings(
                    transcriptionModel: AppSettings.defaultTranscriptionModel,
                    language: .automatic,
                    customLanguageCode: "",
                    prompt: "",
                    customDictionary: [],
                    useActiveTextContext: false,
                    textCorrectionEnabled: true,
                    textCorrectionModelPreset: .quality,
                    customTextCorrectionModel: "",
                    textCorrectionPrompt: AppSettings.defaultTextCorrectionPrompt,
                    localTextCleanupEnabled: true,
                    textReplacementRules: [
                        TextReplacementRule(search: "—", replacement: "-")
                    ],
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
