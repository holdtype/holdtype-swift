//
//  CGEventGlobalHotkeyService.swift
//  HoldType
//
//  Created by Codex on 7/6/26.
//

import Carbon.HIToolbox
import CoreGraphics
import Foundation
import HoldTypeDomain

struct GlobalHotkeyEventMapper {
    private let configuration: ShortcutConfiguration
    private var activeAction: GlobalShortcutAction?
    private var activeOutputIntent: DictationOutputIntent = .standard

    init(configuration: ShortcutConfiguration = .defaults) {
        self.configuration = configuration
    }

    mutating func event(
        type: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags
    ) -> GlobalHotkeyEvent? {
        switch type {
        case .flagsChanged:
            return flagsChangedEvent(keyCode: keyCode, flags: flags)
        case .keyDown:
            return keyDownEvent(keyCode: keyCode, flags: flags)
        case .keyUp:
            return keyUpEvent(keyCode: keyCode)
        default:
            return nil
        }
    }

    mutating func reset() {
        activeAction = nil
        activeOutputIntent = .standard
    }

    private mutating func flagsChangedEvent(
        keyCode: Int64,
        flags: CGEventFlags
    ) -> GlobalHotkeyEvent? {
        if let activeAction,
           configuration[activeAction].isModifierOnly,
           Int64(configuration[activeAction].keyCode) == keyCode,
           !isModifierPressed(keyCode: keyCode, flags: flags) {
            self.activeAction = nil
            let event = GlobalHotkeyEvent.keyUp()
            activeOutputIntent = .standard
            return event
        }

        if let activeAction,
           activeAction == .dictation,
           translationSharesModifierKey,
           matchesTranslationIntent(flags: flags) {
            return outputIntentChangeEventIfNeeded(to: .translate)
        }

        guard activeAction == nil,
              let action = matchingModifierOnlyAction(keyCode: keyCode, flags: flags),
              isModifierPressed(keyCode: keyCode, flags: flags) else {
            return nil
        }

        activeAction = action
        activeOutputIntent = action == .translation ? .translate : .standard
        return .keyDown(outputIntent: activeOutputIntent)
    }

    private mutating func keyDownEvent(
        keyCode: Int64,
        flags: CGEventFlags
    ) -> GlobalHotkeyEvent? {
        guard activeAction == nil,
              let action = matchingKeyAction(keyCode: keyCode, flags: flags) else {
            return nil
        }

        activeAction = action
        activeOutputIntent = action == .translation ? .translate : .standard
        return .keyDown(outputIntent: activeOutputIntent)
    }

    private mutating func keyUpEvent(keyCode: Int64) -> GlobalHotkeyEvent? {
        guard let activeAction,
              !configuration[activeAction].isModifierOnly,
              Int64(configuration[activeAction].keyCode) == keyCode else {
            return nil
        }

        self.activeAction = nil
        let event = GlobalHotkeyEvent.keyUp()
        activeOutputIntent = .standard
        return event
    }

    private func matchingModifierOnlyAction(
        keyCode: Int64,
        flags: CGEventFlags
    ) -> GlobalShortcutAction? {
        let candidates: [GlobalShortcutAction] = [.translation, .dictation]
        return candidates.first { action in
            let shortcut = configuration[action]
            return shortcut.isModifierOnly
                && Int64(shortcut.keyCode) == keyCode
                && flags.contains(shortcut.eventFlags)
                && isModifierPressed(keyCode: keyCode, flags: flags)
        }
    }

    private func matchingKeyAction(
        keyCode: Int64,
        flags: CGEventFlags
    ) -> GlobalShortcutAction? {
        let candidates: [GlobalShortcutAction] = [.translation, .dictation]
        return candidates.first { action in
            let shortcut = configuration[action]
            return !shortcut.isModifierOnly
                && Int64(shortcut.keyCode) == keyCode
                && flags.contains(shortcut.eventFlags)
        }
    }

    private var translationSharesModifierKey: Bool {
        configuration.translation.isModifierOnly
            && configuration.translation.keyCode == configuration.dictation.keyCode
    }

    private func matchesTranslationIntent(flags: CGEventFlags) -> Bool {
        let translation = configuration.translation
        return flags.contains(translation.eventFlags)
            && isModifierPressed(
                keyCode: Int64(translation.keyCode),
                flags: flags
            )
    }

    private func isModifierPressed(keyCode: Int64, flags: CGEventFlags) -> Bool {
        switch Int(keyCode) {
        case kVK_RightCommand, kVK_Command:
            return flags.contains(.maskCommand)
        case kVK_RightOption, kVK_Option:
            return flags.contains(.maskAlternate)
        case kVK_RightControl, kVK_Control:
            return flags.contains(.maskControl)
        default:
            return false
        }
    }

    private mutating func outputIntentChangeEventIfNeeded(
        to outputIntent: DictationOutputIntent
    ) -> GlobalHotkeyEvent? {
        let updatedOutputIntent = activeOutputIntent.merged(with: outputIntent)
        guard updatedOutputIntent != activeOutputIntent else {
            return nil
        }

        activeOutputIntent = updatedOutputIntent
        return .outputIntentChanged(to: updatedOutputIntent)
    }
}

typealias RightCommandHotkeyEventMapper = GlobalHotkeyEventMapper

final class CGEventGlobalHotkeyService: GlobalHotkeyService {
    private(set) var currentRegistrationStatus: GlobalHotkeyRegistrationStatus = .notRegistered

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var actionHandler: GlobalHotkeyActionHandler?
    private let configurationStore: ShortcutConfigurationStore
    private var eventMapper = RightCommandHotkeyEventMapper()

    init(configurationStore: ShortcutConfigurationStore = ShortcutConfigurationStore()) {
        self.configurationStore = configurationStore
    }

    func startListening(actionHandler: @escaping GlobalHotkeyActionHandler) throws {
        stopListening()

        let configuration = configurationStore.load()
        eventMapper = RightCommandHotkeyEventMapper(configuration: configuration)

        self.actionHandler = actionHandler

        let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
        guard let newEventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: dictationHotkeyEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            let message = "Input Monitoring is required for global dictation shortcuts."
            currentRegistrationStatus = .unavailable(message: message)
            self.actionHandler = nil
            throw GlobalHotkeyServiceError.registrationUnavailable(message: message)
        }

        guard let newRunLoopSource = CFMachPortCreateRunLoopSource(
            kCFAllocatorDefault,
            newEventTap,
            0
        ) else {
            CFMachPortInvalidate(newEventTap)
            let message = "Could not start the global dictation shortcut listener."
            currentRegistrationStatus = .unavailable(message: message)
            self.actionHandler = nil
            throw GlobalHotkeyServiceError.registrationUnavailable(message: message)
        }

        eventTap = newEventTap
        runLoopSource = newRunLoopSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newRunLoopSource, .commonModes)
        CGEvent.tapEnable(tap: newEventTap, enable: true)
        currentRegistrationStatus = .registered(
            GlobalHotkeyConfiguration(shortcut: configuration.dictation)
        )
    }

    func stopListening() {
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        if let eventTap {
            CFMachPortInvalidate(eventTap)
        }

        self.runLoopSource = nil
        self.eventTap = nil
        actionHandler = nil
        eventMapper.reset()
        currentRegistrationStatus = .notRegistered
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }

            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let hotkeyEvent = eventMapper.event(
            type: type,
            keyCode: keyCode,
            flags: event.flags
        )

        if let hotkeyEvent {
            actionHandler?(hotkeyEvent)
        }

        return Unmanaged.passUnretained(event)
    }

    deinit {
        stopListening()
    }
}

private func dictationHotkeyEventTapCallback(
    _ proxy: CGEventTapProxy,
    _ type: CGEventType,
    event: CGEvent,
    _ userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let service = Unmanaged<CGEventGlobalHotkeyService>
        .fromOpaque(userInfo)
        .takeUnretainedValue()
    return service.handle(type: type, event: event)
}
