import HoldTypeDomain
import SwiftUI

struct FixesEditorIconPicker: View {
    @Binding var selection: TextFixIcon
    let isEnabled: Bool

    var body: some View {
        Picker("Icon", selection: $selection) {
            ForEach(FixesEditorIconOption.all) { option in
                Label(option.title, systemImage: option.systemImageName)
                    .tag(option.icon)
            }
        }
        .pickerStyle(.menu)
        .disabled(!isEnabled)
        .accessibilityHint(
            isEnabled
                ? "Chooses the icon shown for this Fix"
                : "Built-in Fix icons cannot be changed"
        )
    }
}

private struct FixesEditorIconPickerPreview: View {
    @State private var selection = TextFixIcon.improveWriting

    var body: some View {
        Form {
            FixesEditorIconPicker(selection: $selection, isEnabled: true)
            FixesEditorIconPicker(selection: .constant(.fix), isEnabled: false)
        }
        .formStyle(.grouped)
        .frame(width: 360)
    }
}

#Preview("Icon Picker") {
    FixesEditorIconPickerPreview()
}
