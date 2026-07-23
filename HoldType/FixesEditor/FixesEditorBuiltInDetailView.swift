import HoldTypeDomain
import SwiftUI

struct FixesEditorBuiltInDetailView: View {
    let action: TextFixAction
    let presentation: FixesEditorBuiltInPresentation

    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Built-in Fix")
                            .fontWeight(.semibold)
                        Text(presentation.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Fix") {
                TextField("Title", text: .constant(action.title))
                    .disabled(true)

                FixesEditorIconPicker(
                    selection: .constant(action.icon),
                    isEnabled: false
                )

                Toggle("Enabled", isOn: .constant(true))
                    .disabled(true)
            }

            Section("Behavior") {
                Text(presentation.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Section("Order") {
                HStack {
                    Button {
                    } label: {
                        Label("Move Up", systemImage: "arrow.up")
                    }
                    .disabled(true)

                    Button {
                    } label: {
                        Label("Move Down", systemImage: "arrow.down")
                    }
                    .disabled(true)

                    Spacer()

                    Text("Built-in Fixes are pinned first.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .navigationTitle(presentation.title)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actionBar
        }
    }

    private var actionBar: some View {
        HStack {
            Button("Delete", role: .destructive) {}
                .disabled(true)

            Spacer()

            Button("Save") {}
                .disabled(true)
        }
        .padding(.horizontal, 16)
        .frame(height: 50)
        .background(.bar)
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

#Preview("Built-in Translate") {
    let action = TextFixCatalog.defaults.actions[0]
    if let presentation = FixesEditorBuiltInPresentation(action: action) {
        NavigationStack {
            FixesEditorBuiltInDetailView(
                action: action,
                presentation: presentation
            )
        }
        .frame(width: 620, height: 540)
    }
}
