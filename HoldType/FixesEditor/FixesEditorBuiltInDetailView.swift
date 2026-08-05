import HoldTypeDomain
import SwiftUI

struct FixesEditorBuiltInDetailView: View {
    @Environment(\.openSettings) private var openSettings
    let presentation: FixesEditorBuiltInPresentation

    var body: some View {
        Form {
            Section {
                Label {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Built-in \(presentation.title)")
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

            Section {
                Button(presentation.settingsButtonTitle) {
                    SettingsPresentationCoordinator.shared.navigation.focus(
                        presentation.settingsNavigationItem
                    )
                    openSettings()
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview("Built-in Translate") {
    let action = TextFixCatalog.defaults.actions[0]
    if let presentation = FixesEditorBuiltInPresentation(action: action) {
        NavigationStack {
            FixesEditorBuiltInDetailView(presentation: presentation)
        }
        .frame(width: 620, height: 540)
    }
}
