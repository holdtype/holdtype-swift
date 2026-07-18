import SwiftUI

struct IOSEmojiCommandsNoticeSection: View {
    let notice: IOSEmojiCommandsNotice

    var body: some View {
        Section {
            switch notice {
            case .saved:
                Label(
                    "Dictation Rules Updated",
                    systemImage: "checkmark.circle.fill"
                )
                .foregroundStyle(.green)
            case .deleted:
                Label("Custom Command Deleted", systemImage: "trash")
            case .changedElsewhere:
                IOSSettingsWarningLabel(
                    "Dictation rules changed elsewhere. No conflicting change "
                        + "was made.",
                    color: .orange
                )
            case .invalid:
                IOSSettingsWarningLabel(
                    "That command is invalid or conflicts with another custom phrase.",
                    color: .orange
                )
            case .notSaved:
                IOSSettingsWarningLabel(
                    "Dictation rules were not saved. The last saved commands "
                        + "remain active.",
                    color: .red
                )
            }
        }
    }
}

#Preview("Emoji commands — notice") {
    Form {
        IOSEmojiCommandsNoticeSection(notice: .changedElsewhere)
    }
}
