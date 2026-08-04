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
        VStack(alignment: .leading, spacing: 8) {
            Label(Self.title, systemImage: "wand.and.stars")
                .font(.headline)

            Text(Self.instructions)
                .fixedSize(horizontal: false, vertical: true)

            Text(Self.managementNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text(Self.privacyNote)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            .quaternary.opacity(0.45),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Fixes Info") {
    FixesEditorInfoBanner()
        .frame(width: 620)
        .padding()
}
