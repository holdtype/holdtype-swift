import SwiftUI

struct FixesEditorSidebarView: View {
    @ObservedObject var model: FixesEditorModel

    @State private var deletionAction: FixesEditorActionPresentation?

    var body: some View {
        Group {
            if model.catalog == nil {
                unloadedContent
            } else if model.visibleActions.isEmpty {
                ContentUnavailableView(
                    "No Matching Fixes",
                    systemImage: "magnifyingglass",
                    description: Text("Try another search.")
                )
            } else {
                actionList
            }
        }
        .searchable(
            text: Binding(
                get: { model.searchText },
                set: model.setSearchText
            ),
            placement: .sidebar,
            prompt: "Search Fixes"
        )
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: model.addFix) {
                    Image(systemName: "plus")
                }
                .disabled(!model.canAddFix)
                .help("Add Fix")
                .accessibilityLabel("Add Fix")
            }
        }
        .alert("Delete this Fix?", isPresented: deletionAlertIsPresented) {
            Button("Delete", role: .destructive) {
                if let id = deletionAction?.id {
                    Task {
                        await model.deleteAction(id: id)
                    }
                }
                deletionAction = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the Fix from the macOS catalog.")
        }
    }

    private var actionList: some View {
        List(
            selection: Binding(
                get: { model.selectedActionID },
                set: model.selectAction
            )
        ) {
            if model.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                ForEach(model.builtInActionPresentations) { action in
                    sidebarRow(for: action)
                }

                if model.canReorderCustomActions {
                    ForEach(model.customActionPresentations) { action in
                        sidebarRow(for: action)
                    }
                    .onMove { source, destination in
                        Task {
                            await model.moveCustomActions(from: source, toOffset: destination)
                        }
                    }
                } else {
                    ForEach(model.customActionPresentations) { action in
                        sidebarRow(for: action)
                    }
                }
            } else {
                ForEach(model.visibleActions) { action in
                    sidebarRow(for: action)
                }
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarRow(for action: FixesEditorActionPresentation) -> some View {
        FixesEditorSidebarRow(action: action)
            .tag(action.id)
            .contextMenu {
                if !action.isBuiltIn {
                    Button("Delete", role: .destructive) {
                        deletionAction = action
                    }
                    .disabled(!model.canDeleteAction(id: action.id))
                }
            }
    }

    @ViewBuilder
    private var unloadedContent: some View {
        if model.activity == .loading {
            VStack(spacing: 10) {
                ProgressView()
                Text("Loading Fixes…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView {
                Label("Fixes Couldn’t Load", systemImage: "exclamationmark.triangle")
            } description: {
                Text("The saved catalog was left unchanged.")
            } actions: {
                Button("Try Again") {
                    Task {
                        await model.retryLoad()
                    }
                }
            }
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { deletionAction != nil },
            set: { isPresented in
                if !isPresented {
                    deletionAction = nil
                }
            }
        )
    }
}

private struct FixesEditorSidebarRow: View {
    let action: FixesEditorActionPresentation

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: action.systemImageName)
                .foregroundStyle(action.isEnabled ? Color.accentColor : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .lineLimit(1)

                Text(action.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if action.isBuiltIn {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel("Pinned built-in Fix")
            } else if !action.isEnabled {
                Image(systemName: "slash.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Disabled")
            }
        }
        .opacity(action.isEnabled || action.isBuiltIn ? 1 : 0.62)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Fixes Sidebar") {
    NavigationSplitView {
        FixesEditorSidebarView(model: makeFixesEditorPreviewModel())
            .navigationSplitViewColumnWidth(280)
    } detail: {
        Text("Select a Fix")
    }
    .frame(width: 820, height: 560)
}
