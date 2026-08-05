import SwiftUI

struct FixesEditorInfoBanner: View {
    static let copy =
        "Fixes transform selected text using a prompt. Create or edit custom Fixes here."

    var body: some View {
        Text(Self.copy)
            .font(.callout)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel(Self.copy)
    }
}

#Preview("Fixes Info") {
    FixesEditorInfoBanner()
        .frame(width: 480)
        .padding()
}
