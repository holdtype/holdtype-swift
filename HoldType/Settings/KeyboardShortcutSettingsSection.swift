//
//  KeyboardShortcutSettingsSection.swift
//  HoldType
//

import Carbon.HIToolbox
import AppKit
import Combine
import SwiftUI

struct KeyboardShortcutSettingsSection: View {
    @Binding var settings: AppSettings
    @Binding var configuration: ShortcutConfiguration

    let configurationStore: ShortcutConfigurationStore
    let status: GlobalHotkeyRegistrationStatus
    let fixesStatus: FixesHotkeyRegistrationStatus

    @StateObject private var captureModel = ShortcutCaptureModel()
    @State private var errorMessage: String?

    var body: some View {
        Section("Keyboard Shortcuts") {
            ForEach(GlobalShortcutAction.allCases, id: \.self) { action in
                ShortcutEditorRow(
                    action: action,
                    shortcut: binding(for: action),
                    statusText: statusText(for: action),
                    statusTint: statusTint(for: action),
                    isCapturing: captureModel.action == action,
                    onCapture: { beginCapture(for: action) }
                )
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.red)
            }

            Text("Shortcuts are stored locally. Choose a different assignment if two actions would conflict.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onDisappear {
            captureModel.stop()
        }
    }

    private func binding(for action: GlobalShortcutAction) -> Binding<GlobalHotkeyShortcut> {
        Binding(
            get: { configuration[action] },
            set: { configuration[action] = $0 }
        )
    }

    private func beginCapture(for action: GlobalShortcutAction) {
        errorMessage = nil
        captureModel.start(action: action) { shortcut in
            var candidate = configuration
            candidate[action] = shortcut

            do {
                try configurationStore.save(candidate)
                configuration = candidate
            } catch {
                errorMessage = Self.userFacingMessage(for: error)
            }
        }
    }

    private func statusText(for action: GlobalShortcutAction) -> String {
        switch action {
        case .dictation, .translation:
            switch status {
            case .registered:
                return "Global hotkey active."
            case .notRegistered:
                return "Global hotkey not active."
            case .unavailable:
                return "Global hotkey unavailable."
            }
        case .fixes:
            switch fixesStatus {
            case .registered:
                return "Fixes shortcut active."
            case .notRegistered:
                return "Fixes shortcut not active."
            case .unavailable:
                return "Fixes shortcut unavailable."
            }
        case .pasteLastResult:
            return settings.saveTranscriptsToAppClipboard
                ? "Paste Last Result active."
                : "Paste Last Result disabled."
        }
    }

    private func statusTint(for action: GlobalShortcutAction) -> Color {
        switch action {
        case .dictation, .translation:
            if case .unavailable = status {
                return .red
            }
        case .fixes:
            if case .unavailable = fixesStatus {
                return .red
            }
        case .pasteLastResult:
            break
        }
        return .secondary
    }

    private static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }
        return error.localizedDescription
    }
}

private struct ShortcutEditorRow: View {
    let action: GlobalShortcutAction
    @Binding var shortcut: GlobalHotkeyShortcut
    let statusText: String
    let statusTint: Color
    let isCapturing: Bool
    let onCapture: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Label(action.title, systemImage: action.systemImage)
                    .font(.headline)

                Spacer(minLength: 12)

                Text(shortcut.displayText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                Button(isCapturing ? "Press shortcut…" : "Change…", action: onCapture)
                    .buttonStyle(.bordered)
                    .disabled(isCapturing)
            }

            Text(action.activationText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(statusTint)

            Text(action.detail)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

@MainActor
private final class ShortcutCaptureModel: ObservableObject {
    @Published private(set) var action: GlobalShortcutAction?

    private var monitor: Any?
    private var onCapture: ((GlobalHotkeyShortcut) -> Void)?

    func start(
        action: GlobalShortcutAction,
        onCapture: @escaping (GlobalHotkeyShortcut) -> Void
    ) {
        stop()
        self.action = action
        self.onCapture = onCapture
        monitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .flagsChanged]
        ) { [weak self] event in
            guard let self,
                  let shortcut = Self.shortcut(from: event) else {
                return event
            }

            self.onCapture?(shortcut)
            self.stop()
            return nil
        }
    }

    func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        action = nil
        onCapture = nil
    }

    private static func shortcut(from event: NSEvent) -> GlobalHotkeyShortcut? {
        let keyCode = event.keyCode
        let modifierFlags = event.modifierFlags.intersection([
            .control,
            .option,
            .command
        ])
        let modifiers: [GlobalHotkeyModifier] = [
            modifierFlags.contains(.control) ? .control : nil,
            modifierFlags.contains(.option) ? .option : nil,
            modifierFlags.contains(.command) ? .command : nil
        ].compactMap { $0 }

        if event.type == .flagsChanged,
           !GlobalHotkeyShortcut.isModifierKey(keyCode: keyCode) {
            return nil
        }

        guard let key = keyName(for: keyCode, event: event) else {
            return nil
        }

        return GlobalHotkeyShortcut(
            modifiers: modifiers,
            key: key,
            keyCode: keyCode
        )
    }

    private static func keyName(for keyCode: UInt16, event: NSEvent) -> String? {
        switch Int(keyCode) {
        case kVK_RightCommand:
            return "Right Command"
        case kVK_RightOption:
            return "Right Option"
        case kVK_RightControl:
            return "Right Control"
        case kVK_Space:
            return "Space"
        case kVK_Return:
            return "Return"
        case kVK_Tab:
            return "Tab"
        case kVK_Delete:
            return "Delete"
        case kVK_Escape:
            return "Escape"
        case kVK_UpArrow:
            return "Up Arrow"
        case kVK_DownArrow:
            return "Down Arrow"
        case kVK_LeftArrow:
            return "Left Arrow"
        case kVK_RightArrow:
            return "Right Arrow"
        default:
            guard let characters = event.charactersIgnoringModifiers,
                  !characters.isEmpty else {
                return nil
            }
            return characters.uppercased()
        }
    }
}

private extension GlobalHotkeyShortcut {
    static func isModifierKey(keyCode: UInt16) -> Bool {
        switch Int(keyCode) {
        case kVK_RightCommand, kVK_Command,
             kVK_RightOption, kVK_Option,
             kVK_RightControl, kVK_Control:
            return true
        default:
            return false
        }
    }
}

#Preview {
    Form {
        KeyboardShortcutSettingsSection(
            settings: .constant(.defaults),
            configuration: .constant(.defaults),
            configurationStore: ShortcutConfigurationStore(),
            status: .registered(.defaultDictation),
            fixesStatus: .registered
        )
    }
    .formStyle(.grouped)
    .padding()
}
