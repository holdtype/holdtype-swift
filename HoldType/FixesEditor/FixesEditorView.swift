import SwiftUI

struct FixesEditorView: View {
    enum FocusedField: Hashable {
        case title
    }

    @ObservedObject var model: FixesEditorModel
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        VStack(spacing: 0) {
            NavigationSplitView {
                FixesEditorSidebarView(model: model)
                    .navigationSplitViewColumnWidth(min: 230, ideal: 280, max: 360)
            } detail: {
                FixesEditorDetailView(model: model, focusedField: $focusedField)
            }
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
        .toolbar(removing: .sidebarToggle)
        .navigationTitle("Manage Fixes")
        .onChange(of: model.titleFocusRequestID) { _, _ in
            focusedField = .title
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
