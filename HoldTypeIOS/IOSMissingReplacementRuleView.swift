import SwiftUI

struct IOSMissingReplacementRuleView: View {
    var body: some View {
        ContentUnavailableView {
            Label(
                "Rule Unavailable",
                systemImage: "exclamationmark.triangle"
            )
        } description: {
            Text("This replacement rule is no longer saved.")
        }
    }
}

#Preview("Replacement rule unavailable") {
    NavigationStack {
        IOSMissingReplacementRuleView()
            .navigationTitle("Replacement Rule")
    }
}
