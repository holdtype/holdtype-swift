import SwiftUI

struct FixesEditorInfoBanner: View {
    static let title = "What are Fixes?"
    static let instructions =
        "Fixes transform text in the app you’re using. Press ⌥J to open the Fixes palette, "
        + "use ↑/↓ to choose an action, and press Return to run it. Press Escape to close. "
        + "If nothing is selected, HoldType uses the complete compatible text field."
    static let managementNote =
        "Use Manage Fixes… to add, edit, reorder, enable, or delete custom actions. "
        + "Built-in Translate and Fix stay at the top."
    static let privacyNote =
        "When you run a Fix, only the captured text and chosen instruction are sent to OpenAI."

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "wand.and.stars")
                .foregroundStyle(.tint)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(Self.title)
                    .font(.headline)

                Text(Self.instructions)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)

                Text(Self.managementNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview("Fixes Info") {
    FixesEditorInfoBanner()
        .frame(width: 620)
        .padding()
}
