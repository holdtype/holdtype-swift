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
    let preferredConfiguration: GlobalHotkeyConfiguration

    var body: some View {
        Section("Keyboard Shortcut") {
            HotkeySettingsRow(
                presentation: HotkeySettingsPresentation(
                    status: status,
                    preferredConfiguration: preferredConfiguration
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

private struct HotkeySettingsPresentation {
    let shortcutText: String
    let statusText: String
    let detailText: String
    let systemImage: String
    let statusTint: Color

    init(
        status: GlobalHotkeyRegistrationStatus,
        preferredConfiguration: GlobalHotkeyConfiguration
    ) {
        switch status {
        case .registered(let configuration):
            shortcutText = configuration.displayText
            statusText = "Global hotkey active."
            detailText = Self.activeDetailText(for: configuration)
            systemImage = "keyboard"
            statusTint = .secondary
        case .fallbackRegistered(let configuration):
            shortcutText = configuration.displayText
            statusText = "Fallback hotkey active."
            detailText = "The default shortcut was unavailable. This shortcut records from any app."
            systemImage = "keyboard.badge.ellipsis"
            statusTint = .secondary
        case .notRegistered:
            shortcutText = preferredConfiguration.displayText
            statusText = "Global hotkey not active."
            detailText = "Use Transcribe in the menu until a shortcut is available."
            systemImage = "keyboard"
            statusTint = .secondary
        case .unavailable(let message):
            shortcutText = preferredConfiguration.displayText
            statusText = "Global hotkey unavailable."
            detailText = "\(message) Use Transcribe in the menu."
            systemImage = "keyboard.badge.exclamationmark"
            statusTint = .red
        }
    }

    private static func activeDetailText(for configuration: GlobalHotkeyConfiguration) -> String {
        switch configuration.activationMode {
        case .holdToRecord:
            return "Hold the shortcut to record from any app."
        case .toggle:
            return "Press the shortcut once to start recording and again to stop."
        }
    }
}

#Preview {
    Form {
        KeyboardShortcutSettingsSection(
            settings: .constant(.defaults),
            status: .registered(.defaultDictation),
            preferredConfiguration: .defaultDictation
        )
    }
    .formStyle(.grouped)
    .padding()
}
