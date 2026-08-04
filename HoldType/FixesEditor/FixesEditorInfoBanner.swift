import SwiftUI

struct FixesEditorInfoBanner: View {
    static let instructions =
        "Fixes transform text in the app you’re using. Press ⌥J to open the Fixes palette, "
        + "use ↑/↓ to choose an action, and press Return to run it. Press Escape to close. "
        + "If nothing is selected, HoldType uses the complete compatible text field."

    var body: some View {
        Text(Self.instructions)
            .font(.callout)
            .fixedSize(horizontal: false, vertical: true)
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
