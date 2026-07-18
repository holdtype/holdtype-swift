import SwiftUI

struct IOSReplacementRuleEditorStatusSection: View {
    let phase: IOSReplacementRuleEditorPhase
    let canReloadLatest: Bool
    let canReplaceLatest: Bool
    let reloadLatest: () -> Void
    let requestReplaceLatest: () -> Void

    @ViewBuilder
    var body: some View {
        switch phase {
        case .idle:
            EmptyView()
        case .saving:
            Section {
                Label("Saving", systemImage: "arrow.triangle.2.circlepath")
            }
        case .saved:
            Section {
                Label("Saved", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        case .saveFailed:
            Section {
                IOSSettingsWarningLabel(
                    "Not Saved — draft retained and saved rule unchanged.",
                    color: .red
                )
            }
        case .changedElsewhere:
            Section {
                IOSSettingsWarningLabel(
                    "Changed Elsewhere — your draft is retained.",
                    color: .orange
                )
                if canReloadLatest {
                    Button("Reload Latest", action: reloadLatest)
                }
                if canReplaceLatest {
                    Button(
                        "Replace Latest",
                        role: .destructive,
                        action: requestReplaceLatest
                    )
                }
            }
        case .deletedElsewhere:
            Section {
                IOSSettingsWarningLabel(
                    "Deleted Elsewhere — this draft cannot recreate the rule.",
                    color: .orange
                )
            }
        case .invalid:
            Section {
                IOSSettingsWarningLabel(
                    "The rule could not be saved.",
                    color: .orange
                )
            }
        }
    }
}

#Preview("Replacement rule editor — changed elsewhere") {
    Form {
        IOSReplacementRuleEditorStatusSection(
            phase: .changedElsewhere,
            canReloadLatest: true,
            canReplaceLatest: true,
            reloadLatest: {},
            requestReplaceLatest: {}
        )
    }
}
