import SwiftUI

struct FixesEditorTitlebarContent: View {
    @ObservedObject var model: FixesEditorModel

    var body: some View {
        HStack(spacing: 12) {
            Button(action: model.addFix) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .medium))
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .background {
                Circle()
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.14), radius: 5, y: 2)
            }
            .disabled(!model.canAddFix)
            .help("Add Fix")
            .accessibilityLabel("Add Fix")

            FixesEditorInfoBanner()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview("Fixes Title Bar") {
    FixesEditorTitlebarContent(model: makeFixesEditorPreviewModel())
        .frame(width: 600, height: 52)
        .padding()
}
