//
//  KeyboardShortcutSettingsSection.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import SwiftUI

struct KeyboardShortcutSettingsSection: View {
    @Binding var settings: AppSettings

    let status: GlobalHotkeyRegistrationStatus
    let fixesStatus: FixesHotkeyRegistrationStatus

    var body: some View {
        Section("Keyboard Shortcuts") {
            HotkeySettingsRow(
                presentation: HotkeySettingsPresentation(status: status)
            )

            HotkeySettingsRow(
                presentation: HotkeySettingsPresentation(
                    fixesStatus: fixesStatus
                )
            )

            Toggle(
                "Enable translation with Option+Right Command",
                isOn: $settings.translationShortcutEnabled
            )

            Text("Hold Option+Right Command to record and translate using the Translation settings.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HotkeySettingsRow: View {
    let presentation: HotkeySettingsPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(presentation.shortcutText, systemImage: presentation.systemImage)

            Text(presentation.statusText)
                .font(.footnote)
                .foregroundStyle(presentation.statusTint)

            Text(presentation.detailText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct HotkeySettingsPresentation {
    let shortcutText: String
    let statusText: String
    let detailText: String
    let systemImage: String
    let statusTint: Color

    init(status: GlobalHotkeyRegistrationStatus) {
        switch status {
        case .registered(let configuration):
            shortcutText = configuration.displayText
            statusText = "Global hotkey active."
            detailText = "Hold the shortcut to record from any app."
            systemImage = "keyboard"
            statusTint = .secondary
        case .notRegistered:
            shortcutText = GlobalHotkeyConfiguration.defaultDictation.displayText
            statusText = "Global hotkey not active."
            detailText = "Use Transcribe in the menu until a shortcut is available."
            systemImage = "keyboard"
            statusTint = .secondary
        case .unavailable(let message):
            shortcutText = GlobalHotkeyConfiguration.defaultDictation.displayText
            statusText = "Global hotkey unavailable."
            detailText = "\(message) Use Transcribe in the menu."
            systemImage = "keyboard.badge.exclamationmark"
            statusTint = .red
        }
    }

    init(fixesStatus: FixesHotkeyRegistrationStatus) {
        shortcutText =
            GlobalHotkeyShortcut.fixesPalette.menuKeyEquivalentText
        systemImage = "wand.and.stars"

        switch fixesStatus {
        case .registered:
            statusText = "Fixes shortcut active."
            detailText =
                "Press the shortcut to open Fixes for the current text field."
            statusTint = .secondary
        case .notRegistered:
            statusText = "Fixes shortcut not active."
            detailText =
                "Use Fixes… in the menu until the shortcut is available."
            statusTint = .secondary
        case .unavailable(let message):
            statusText = "Fixes shortcut unavailable."
            detailText = "\(message) Use Fixes… in the menu."
            statusTint = .red
        }
    }
}

#Preview {
    Form {
        KeyboardShortcutSettingsSection(
            settings: .constant(.defaults),
            status: .registered(.defaultDictation),
            fixesStatus: .registered
        )
    }
    .formStyle(.grouped)
    .padding()
}
