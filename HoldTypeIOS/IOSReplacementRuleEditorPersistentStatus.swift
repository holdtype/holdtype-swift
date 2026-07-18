import SwiftUI

struct IOSReplacementRuleEditorPersistentStatus: View {
    let phase: IOSReplacementRuleEditorPhase

    @ViewBuilder
    var body: some View {
        switch phase {
        case .saveFailed:
            Label {
                Text("Not Saved — saved rule unchanged")
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
            .accessibilityIdentifier(
                "ios.library.replacement-rule.persistent-save-failed"
            )
        case .changedElsewhere:
            Label {
                Text("Changed Elsewhere — draft retained")
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                    .foregroundStyle(.orange)
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
        case .deletedElsewhere:
            Label {
                Text("Deleted Elsewhere — Save unavailable")
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: "trash")
                    .foregroundStyle(.orange)
            }
            .font(.footnote.weight(.semibold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .overlay(alignment: .top) { Divider() }
        case .idle, .saving, .saved, .invalid:
            EmptyView()
        }
    }
}

#Preview("Replacement rule editor — persistent status") {
    VStack {
        Spacer()
        IOSReplacementRuleEditorPersistentStatus(phase: .saveFailed)
    }
}
