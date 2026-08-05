import SwiftUI

struct FixesEditorDetailView: View {
    @ObservedObject var model: FixesEditorModel
    @FocusState.Binding var focusedField: FixesEditorView.FocusedField?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FixesEditorInfoBanner()
                .padding(.horizontal, 28)
                .padding(.vertical, 20)

            Divider()

            Group {
                if model.catalog == nil {
                    ContentUnavailableView(
                        "Fixes Unavailable",
                        systemImage: "wand.and.stars",
                        description: Text("Load the saved catalog to edit Fixes.")
                    )
                } else if let presentation = model.selectedBuiltIn {
                    FixesEditorBuiltInDetailView(presentation: presentation)
                } else if model.selectedDraft != nil {
                    FixesEditorCustomDetailView(model: model, focusedField: $focusedField)
                } else {
                    ContentUnavailableView(
                        "Select a Fix",
                        systemImage: "sidebar.left",
                        description: Text("Choose a Fix from the sidebar to edit it.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview("Fix Detail") {
    FixesEditorDetailPreview()
}

private struct FixesEditorDetailPreview: View {
    @FocusState private var focusedField: FixesEditorView.FocusedField?
    private let model = makeFixesEditorPreviewModel()

    var body: some View {
        NavigationStack {
            FixesEditorDetailView(model: model, focusedField: $focusedField)
        }
        .frame(width: 620, height: 540)
    }
}
