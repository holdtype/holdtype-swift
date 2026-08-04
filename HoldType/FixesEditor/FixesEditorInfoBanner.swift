import SwiftUI

struct FixesEditorInfoBanner: View {
    static let instructions =
        "Fixes transform text. ⌥J opens the palette; ↑/↓ choose, Return runs, Escape closes."

    var body: some View {
        Text(Self.instructions)
            .font(.caption)
            .lineLimit(1)
            .truncationMode(.tail)
            .accessibilityLabel(Self.instructions)
    }
}

#Preview("Fixes Info") {
    FixesEditorInfoBanner()
        .frame(width: 620)
        .padding()
}
