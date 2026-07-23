import SwiftUI

struct FixesEditorSidebarView: View {
    @ObservedObject var model: FixesEditorModel

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
        .navigationTitle("Fixes")
        .searchable(
            text: Binding(
                get: { model.searchText },
                set: model.setSearchText
            ),
            placement: .sidebar,
            prompt: "Search Fixes"
        )
        .toolbar {
            ToolbarItem {
                Button(action: model.addFix) {
                    Label("Add Fix", systemImage: "plus")
                }
                .disabled(!model.canAddFix)
                .help("Add Fix")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            restoreDefaultsBar
        }
    }

    private var actionList: some View {
        List(
            selection: Binding(
                get: { model.selectedActionID },
                set: model.selectAction
            )
        ) {
            ForEach(model.visibleActions) { action in
                FixesEditorSidebarRow(action: action)
                    .tag(action.id)
            }
        }
        .listStyle(.sidebar)
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

    private var restoreDefaultsBar: some View {
        VStack(spacing: 0) {
            Divider()

            Button {
                Task {
                    await model.restoreDefaults()
                }
            } label: {
                Label("Restore Defaults", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .disabled(!model.canRestoreDefaults)
            .padding(12)
        }
        .background(.bar)
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
            } else if action.isPending {
                Image(systemName: "circle.dashed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Not saved")
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
