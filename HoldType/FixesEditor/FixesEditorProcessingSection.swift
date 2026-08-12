import HoldTypeDomain
import SwiftUI

struct FixesEditorProcessingSection: View {
    static let premiumWarning =
        "Higher cost and slower. A medium social post typically costs about "
        + "$0.08–$0.14. Uses your OpenAI API account; actual charges vary."

    @ObservedObject var model: FixesEditorModel

    var body: some View {
        Section("Processing") {
            Picker(
                "Model",
                selection: Binding(
                    get: { model.selectedDraft?.processingPreset ?? .inherit },
                    set: model.setSelectedProcessingPreset
                )
            ) {
                ForEach(TextFixProcessingProfile.Preset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .disabled(model.activity.isBusy)

            Text(selectedDetail)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if model.selectedDraft?.processingPreset == .gpt56SolMax {
                Label(
                    Self.premiumWarning,
                    systemImage: "dollarsign.circle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
            }

            if model.selectedDraft?.processingPreset == .custom {
                SettingsTechnicalTextField(
                    title: "Custom model",
                    text: Binding(
                        get: { model.selectedDraft?.customModel ?? "" },
                        set: model.setSelectedCustomModel
                    )
                )
                .disabled(model.activity.isBusy)

                if let message = model.selectedDraftValidation?.customModelMessage {
                    Label(message, systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Picker(
                    "Reasoning",
                    selection: Binding(
                        get: { model.selectedDraft?.reasoningEffort ?? .low },
                        set: model.setSelectedReasoningEffort
                    )
                ) {
                    ForEach(TextFixReasoningEffort.allCases, id: \.self) { effort in
                        Text(effort.displayName).tag(effort)
                    }
                }
                .disabled(model.activity.isBusy)
            }
        }
    }

    private var selectedDetail: String {
        guard let draft = model.selectedDraft else {
            return "Uses the Writing & Correction model with low reasoning."
        }
        switch draft.processingPreset {
        case .inherit:
            return "Uses the model from Writing & Correction with low reasoning."
        case .gpt56Terra:
            return "gpt-5.6-terra · medium reasoning · 20-second timeout"
        case .gpt56SolMax:
            return "gpt-5.6-sol · maximum reasoning · 60-second timeout"
        case .custom:
            let modelName = draft.customModel.isEmpty ? "Custom model" : draft.customModel
            return "\(modelName) · \(draft.reasoningEffort.displayName.lowercased()) reasoning"
        }
    }
}

private extension TextFixProcessingProfile.Preset {
    var displayName: String {
        switch self {
        case .inherit: "Use Writing & Correction Settings"
        case .gpt56Terra: "GPT-5.6 Terra"
        case .gpt56SolMax: "GPT-5.6 Sol — Best Quality"
        case .custom: "Custom"
        }
    }
}

private extension TextFixReasoningEffort {
    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .xhigh: "Extra High"
        case .max: "Maximum"
        }
    }
}

#Preview("Processing") {
    Form {
        FixesEditorProcessingSection(
            model: makeFixesEditorPreviewModel(
                selectedActionID: TextFixCatalog.defaults.customActions[0].id
            )
        )
    }
    .formStyle(.grouped)
    .frame(width: 620, height: 320)
}
