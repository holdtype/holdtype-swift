//
//  GlobalHotkeyService.swift
//  HoldType
//
//  Created by Codex on 6/20/26.
//

import Foundation
import HoldTypeDomain

enum GlobalHotkeyModifier: Equatable {
    case control
    case option
    case command

    var displayName: String {
        switch self {
        case .control:
            return "Control"
        case .option:
            return "Option"
        case .command:
            return "Command"
        }
    }

    var menuSymbol: String {
        switch self {
        case .control:
            return "\u{2303}"
        case .option:
            return "\u{2325}"
        case .command:
            return "\u{2318}"
        }
    }
}

struct GlobalHotkeyShortcut: Equatable {
    static let defaultDictation = GlobalHotkeyShortcut(
        modifiers: [],
        key: "Right Command"
    )

    static let translationDictation = GlobalHotkeyShortcut(
        modifiers: [.option],
        key: "Right Command"
    )

    static let appClipboardPaste = GlobalHotkeyShortcut(
        modifiers: [.control, .command],
        key: "V"
    )

    var modifiers: [GlobalHotkeyModifier]
    var key: String

    var displayText: String {
        (modifiers.map(\.displayName) + [key]).joined(separator: "+")
    }

    var menuKeyEquivalentText: String {
        modifiers.map(\.menuSymbol).joined() + key
    }

    var menuHoldText: String {
        let holdParts = [Self.menuKeyText(for: key)] + modifiers.map(Self.menuHoldModifierText)
        return "Hold " + holdParts.joined(separator: " + ")
    }

    private static func menuKeyText(for key: String) -> String {
        switch key {
        case "Right Command":
            return "Right \u{2318}"
        case "Left Command":
            return "Left \u{2318}"
        case "Right Option":
            return "Right \u{2325}"
        case "Left Option":
            return "Left \u{2325}"
        default:
            return key
        }
    }

    private static func menuHoldModifierText(for modifier: GlobalHotkeyModifier) -> String {
        switch modifier {
        case .option:
            return "Right \u{2325}"
        case .command:
            return "Right \u{2318}"
        case .control:
            return "Control"
        }
    }
}

struct GlobalHotkeyConfiguration: Equatable {
    static let defaultDictation = GlobalHotkeyConfiguration(
        shortcut: .defaultDictation
    )

    var shortcut: GlobalHotkeyShortcut

    var displayText: String {
        "\(shortcut.displayText) - Hold to record"
    }

    func recordingCommand(
        for action: GlobalHotkeyAction,
        isRecording: Bool,
        isShortcutPressed: Bool
    ) -> GlobalHotkeyRecordingCommand? {
        switch action {
        case .keyDown where !isShortcutPressed && !isRecording:
            return .startRecording
        case .keyUp where isShortcutPressed && isRecording:
            return .stopRecording
        default:
            return nil
        }
    }
}

enum GlobalHotkeyAction: Equatable {
    case keyDown
    case keyUp
    case outputIntentChanged
}

struct GlobalHotkeyEvent: Equatable {
    let action: GlobalHotkeyAction
    let outputIntent: DictationOutputIntent

    static func keyDown(outputIntent: DictationOutputIntent = .standard) -> GlobalHotkeyEvent {
        GlobalHotkeyEvent(action: .keyDown, outputIntent: outputIntent)
    }

    static func keyUp(outputIntent: DictationOutputIntent = .standard) -> GlobalHotkeyEvent {
        GlobalHotkeyEvent(action: .keyUp, outputIntent: outputIntent)
    }

    static func outputIntentChanged(to outputIntent: DictationOutputIntent) -> GlobalHotkeyEvent {
        GlobalHotkeyEvent(action: .outputIntentChanged, outputIntent: outputIntent)
    }
}

enum GlobalHotkeyRecordingCommand: Equatable {
    case startRecording
    case stopRecording
}

enum GlobalHotkeyRegistrationStatus: Equatable {
    case notRegistered
    case registered(GlobalHotkeyConfiguration)
    case unavailable(message: String)

    var activeConfiguration: GlobalHotkeyConfiguration? {
        switch self {
        case .registered(let configuration):
            return configuration
        case .notRegistered, .unavailable:
            return nil
        }
    }
}

enum GlobalHotkeyServiceError: Error, Equatable, LocalizedError {
    case registrationUnavailable(message: String)

    var errorDescription: String? {
        switch self {
        case .registrationUnavailable(let message):
            return message
        }
    }
}

typealias GlobalHotkeyActionHandler = (GlobalHotkeyEvent) -> Void

protocol GlobalHotkeyService {
    var currentRegistrationStatus: GlobalHotkeyRegistrationStatus { get }

    func startListening(actionHandler: @escaping GlobalHotkeyActionHandler) throws
    func stopListening()
}
