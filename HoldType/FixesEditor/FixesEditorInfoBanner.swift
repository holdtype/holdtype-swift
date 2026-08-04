import SwiftUI

struct FixesEditorInfoBanner: View {
    static let instructions =
        "Fixes transform selected text, or the current text field when nothing is selected.\n"
        + "Press ⌥J to open Fixes; use ↑/↓ to choose, Return to run, and Escape to close."

    var body: some View {
        HStack(spacing: 0) {
            Text(Self.instructions)
                .font(.caption)
                .multilineTextAlignment(.leading)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityLabel(Self.instructions)
    }
}

#Preview("Fixes Info") {
    FixesEditorInfoBanner()
        .frame(width: 480)
        .padding()
}
