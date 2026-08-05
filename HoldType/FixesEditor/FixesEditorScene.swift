import SwiftUI

struct FixesEditorScene: Scene {
    static let identifier = "holdtype.manage-fixes"

    var body: some Scene {
        Window("Manage Fixes", id: Self.identifier) {
            FixesEditorWindowRoot()
        }
        .defaultSize(width: 900, height: 620)
        .windowResizability(.contentMinSize)
    }
}

private struct FixesEditorWindowRoot: View {
    @StateObject private var model = FixesEditorModel(store: MacOSTextFixCatalogStore())

    var body: some View {
        FixesEditorView(model: model)
            .onDisappear {
                model.savePendingChangesBeforeClosing()
            }
    }
}
