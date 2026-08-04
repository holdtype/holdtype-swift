import SwiftUI

struct FixesEditorDetailView: View {
    @ObservedObject var model: FixesEditorModel

    var body: some View {
        Group {
            if model.catalog == nil {
                ContentUnavailableView(
                    "Fixes Unavailable",
                    systemImage: "wand.and.stars",
                    description: Text("Load the saved catalog to edit Fixes.")
                )
            } else if let action = model.selectedAction,
                      let presentation = model.selectedBuiltIn {
                FixesEditorBuiltInDetailView(
                    action: action,
                    presentation: presentation
                )
            } else if model.selectedDraft != nil {
                FixesEditorCustomDetailView(model: model)
            } else {
                ContentUnavailableView(
                    "Select a Fix",
                    systemImage: "sidebar.left",
                    description: Text("Choose a Fix from the sidebar to edit it.")
                )
            }
        }
    }
}

#Preview("Fix Detail") {
    let model = makeFixesEditorPreviewModel()
    NavigationStack {
        FixesEditorDetailView(model: model)
    }
    .frame(width: 620, height: 540)
}
