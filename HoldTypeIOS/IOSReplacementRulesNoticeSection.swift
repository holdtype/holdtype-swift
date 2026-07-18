import SwiftUI

struct IOSReplacementRulesNoticeSection: View {
    let notice: IOSReplacementRulesNotice

    var body: some View {
        Section {
            switch notice {
            case .saved:
                Label(
                    "Replacement Rule Updated",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
            case .deleted:
                Label("Replacement Rule Deleted", systemImage: "trash")
            case .reordered:
                Label(
                    "Rule Order Updated",
                    systemImage: "line.3.horizontal"
                )
            case .changedElsewhere:
                IOSSettingsWarningLabel(
                    "Saved rules changed elsewhere. The latest order and rows are shown.",
                    color: .orange
                )
            case .invalid:
                IOSSettingsWarningLabel(
                    "The replacement rule change was invalid.",
                    color: .orange
                )
            case .notSaved:
                IOSSettingsWarningLabel(
                    "Replacement rules were not saved. Saved rules remain unchanged.",
                    color: .red
                )
            }
        }
    }
}

#Preview("Replacement rules — notice") {
    Form {
        IOSReplacementRulesNoticeSection(notice: .changedElsewhere)
    }
}
