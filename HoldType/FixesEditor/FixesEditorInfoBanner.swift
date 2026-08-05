import SwiftUI

struct FixesEditorInfoBanner: View {
    static let copy =
        "Fixes transform selected text, or the current text field when nothing is selected.\n"
        + "Press ⌥J to open Fixes; use ↑/↓ to choose, Return to run, and Escape to close."

    var body: some View {
        Text(Self.copy)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
            .lineSpacing(2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Self.copy)
    }
}

#Preview("Fixes Info") {
    FixesEditorInfoBanner()
        .frame(width: 480)
        .padding()
}
