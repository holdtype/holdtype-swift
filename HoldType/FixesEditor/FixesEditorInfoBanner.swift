import SwiftUI

struct FixesEditorInfoBanner: View {
    static let instructions =
        "Fixes transform selected text, or the current text field when nothing is selected.\n"
        + "Press ⌥J to open Fixes; use ↑/↓ to choose, Return to run, and Escape to close."

    var body: some View {
        Text(Self.instructions)
            .font(.caption)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(width: 480, alignment: .leading)
            .accessibilityLabel(Self.instructions)
    }
}

#Preview("Fixes Info") {
    FixesEditorInfoBanner()
        .frame(width: 480)
        .padding()
}
