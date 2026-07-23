import SwiftUI

struct FixesEditorView: View {
    @ObservedObject var model: FixesEditorModel

    var body: some View {
        NavigationSplitView {
            FixesEditorSidebarView(model: model)
                .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 360)
        } detail: {
            FixesEditorDetailView(model: model)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if let issue = model.issue {
                FixesEditorIssueBanner(
                    issue: issue,
                    onRetry: {
                        Task {
                            await model.retryLoad()
                        }
                    },
                    onDismiss: model.dismissIssue
                )
            }
        }
        .task {
            await model.loadIfNeeded()
        }
        .frame(minWidth: 760, minHeight: 520)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Fixes Editor")
    }
}

#Preview("Fixes Editor") {
    FixesEditorView(model: makeFixesEditorPreviewModel())
        .frame(width: 900, height: 620)
}
