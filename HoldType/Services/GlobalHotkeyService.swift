//
//  GlobalHotkeyService.swift
//  HoldType
//
//  Created by Codex on 6/20/26.
//

import Carbon.HIToolbox
import CoreGraphics
import Foundation
import HoldTypeDomain

enum GlobalHotkeyModifier: String, Codable, CaseIterable, Equatable, Hashable {
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
        key: "Right Command",
        keyCode: UInt16(kVK_RightCommand)
    )

    static let translationDictation = GlobalHotkeyShortcut(
        modifiers: [.option],
        key: "Right Command",
        keyCode: UInt16(kVK_RightCommand)
    )

    static let appClipboardPaste = GlobalHotkeyShortcut(
        modifiers: [.control, .command],
        key: "V",
        keyCode: UInt16(kVK_ANSI_V)
    )

    static let fixesPalette = GlobalHotkeyShortcut(
        modifiers: [.option],
        key: "J",
        keyCode: UInt16(kVK_ANSI_J)
    )

    var modifiers: [GlobalHotkeyModifier]
    var key: String
    var keyCode: UInt16

    init(modifiers: [GlobalHotkeyModifier], key: String, keyCode: UInt16) {
        self.modifiers = modifiers
        self.key = key
        self.keyCode = keyCode
    }

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

    var isModifierOnly: Bool {
        switch Int(keyCode) {
        case kVK_RightCommand, kVK_Command,
             kVK_RightOption, kVK_Option,
             kVK_RightControl, kVK_Control:
            return true
        default:
            return false
        }
    }

    var carbonModifiers: UInt32 {
        modifiers.reduce(into: UInt32(0)) { result, modifier in
            switch modifier {
            case .control:
                result |= UInt32(controlKey)
            case .option:
                result |= UInt32(optionKey)
            case .command:
                result |= UInt32(cmdKey)
            }
        }
    }

    var eventFlags: CGEventFlags {
        modifiers.reduce(into: CGEventFlags()) { result, modifier in
            switch modifier {
            case .control:
                result.insert(.maskControl)
            case .option:
                result.insert(.maskAlternate)
            case .command:
                result.insert(.maskCommand)
            }
        }
    }
}

extension GlobalHotkeyShortcut: Codable {}

enum GlobalShortcutAction: String, CaseIterable, Codable, Equatable, Hashable {
    case dictation
    case translation
    case fixes
    case pasteLastResult

    var title: String {
        switch self {
        case .dictation:
            return "Dictation"
        case .translation:
            return "Translation"
        case .fixes:
            return "Fixes"
        case .pasteLastResult:
            return "Paste Last Result"
        }
    }

    var detail: String {
        switch self {
        case .dictation:
            return "Hold to record from any app."
        case .translation:
            return "Hold to record and translate using Translation settings."
        case .fixes:
            return "Press to open Fixes for the current text field."
        case .pasteLastResult:
            return "Press to insert the app-owned Last Result."
        }
    }

    var systemImage: String {
        switch self {
        case .dictation:
            return "waveform"
        case .translation:
            return "character.bubble"
        case .fixes:
            return "wand.and.stars"
        case .pasteLastResult:
            return "arrow.down.doc"
        }
    }

    var activationText: String {
        switch self {
        case .dictation, .translation:
            return "Hold to record"
        case .fixes, .pasteLastResult:
            return "Press to activate"
        }
    }
}

struct ShortcutConfiguration: Codable, Equatable {
    static let defaults = ShortcutConfiguration(
        dictation: .defaultDictation,
        translation: .translationDictation,
        fixes: .fixesPalette,
        pasteLastResult: .appClipboardPaste
    )

    var dictation: GlobalHotkeyShortcut
    var translation: GlobalHotkeyShortcut
    var fixes: GlobalHotkeyShortcut
    var pasteLastResult: GlobalHotkeyShortcut

    subscript(action: GlobalShortcutAction) -> GlobalHotkeyShortcut {
        get {
            switch action {
            case .dictation:
                return dictation
            case .translation:
                return translation
            case .fixes:
                return fixes
            case .pasteLastResult:
                return pasteLastResult
            }
        }
        set {
            switch action {
            case .dictation:
                dictation = newValue
            case .translation:
                translation = newValue
            case .fixes:
                fixes = newValue
            case .pasteLastResult:
                pasteLastResult = newValue
            }
        }
    }

    var duplicateAction: GlobalShortcutAction? {
        for action in GlobalShortcutAction.allCases {
            for otherAction in GlobalShortcutAction.allCases where action != otherAction {
                if self[action] == self[otherAction] {
                    return action
                }
            }
        }
        return nil
    }
}

enum ShortcutConfigurationError: Error, Equatable, LocalizedError {
    case duplicate(GlobalShortcutAction)
    case unsupported(GlobalShortcutAction)
    case requiresModifier(GlobalShortcutAction)

    var errorDescription: String? {
        switch self {
        case .duplicate(let action):
            return "The \(action.title) shortcut is already assigned to another action."
        case .unsupported(let action):
            return "Choose a regular key for the \(action.title) shortcut."
        case .requiresModifier(let action):
            return "Add a modifier such as Command, Option, or Control to the \(action.title) shortcut."
        }
    }
}

struct ShortcutConfigurationStore {
    static let key = "holdtype.shortcuts.v1"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func load() -> ShortcutConfiguration {
        guard let data = userDefaults.data(forKey: Self.key),
              let configuration = try? JSONDecoder().decode(
                  ShortcutConfiguration.self,
                  from: data
              ),
              configuration.duplicateAction == nil,
              !configuration.fixes.isModifierOnly,
              !configuration.pasteLastResult.isModifierOnly,
              configuration.dictation.isModifierOnly || !configuration.dictation.modifiers.isEmpty,
              configuration.translation.isModifierOnly || !configuration.translation.modifiers.isEmpty,
              !configuration.fixes.modifiers.isEmpty,
              !configuration.pasteLastResult.modifiers.isEmpty else {
            if userDefaults.data(forKey: Self.key) == nil,
               let data = try? JSONEncoder().encode(ShortcutConfiguration.defaults) {
                userDefaults.set(data, forKey: Self.key)
            }
            return .defaults
        }

        return configuration
    }

    func save(_ configuration: ShortcutConfiguration) throws {
        if let duplicateAction = configuration.duplicateAction {
            throw ShortcutConfigurationError.duplicate(duplicateAction)
        }

        for action in [GlobalShortcutAction.fixes, .pasteLastResult]
            where configuration[action].isModifierOnly {
            throw ShortcutConfigurationError.unsupported(action)
        }

        for action in [GlobalShortcutAction.dictation, .translation, .fixes, .pasteLastResult]
            where !configuration[action].isModifierOnly && configuration[action].modifiers.isEmpty {
            throw ShortcutConfigurationError.requiresModifier(action)
        }

        let data = try JSONEncoder().encode(configuration)
        userDefaults.set(data, forKey: Self.key)
        NotificationCenter.default.post(
            name: .shortcutConfigurationDidChange,
            object: nil
        )
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
