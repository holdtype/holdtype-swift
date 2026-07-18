//
//  GlobalHotkeyServiceTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/20/26.
//

import Carbon.HIToolbox
import CoreGraphics
import HoldTypeDomain
import Testing
@testable import HoldType

struct GlobalHotkeyServiceTests {

    @Test func defaultShortcutIsVisibleAsDisplayData() {
        let configuration = GlobalHotkeyConfiguration.defaultDictation

        #expect(configuration.shortcut == .defaultDictation)
        #expect(configuration.shortcut.displayText == "Right Command")
        #expect(configuration.displayText == "Right Command - Hold to record")
    }

    @Test func appClipboardPasteShortcutUsesControlCommandV() {
        let shortcut = GlobalHotkeyShortcut.appClipboardPaste

        #expect(shortcut.modifiers == [.control, .command])
        #expect(shortcut.key == "V")
        #expect(shortcut.displayText == "Control+Command+V")
        #expect(shortcut.menuKeyEquivalentText == "⌃⌘V")
    }

    @Test func translationShortcutUsesOptionRightCommand() {
        let shortcut = GlobalHotkeyShortcut.translationDictation

        #expect(shortcut.modifiers == [.option])
        #expect(shortcut.key == "Right Command")
        #expect(shortcut.displayText == "Option+Right Command")
        #expect(shortcut.menuHoldText == "Hold Right ⌘ + Right ⌥")
    }

    @Test func dictationShortcutUsesCompactMenuHoldText() {
        let shortcut = GlobalHotkeyShortcut.defaultDictation

        #expect(shortcut.menuHoldText == "Hold Right ⌘")
    }

    @Test func rightCommandMapperEmitsHoldEvents() {
        var mapper = RightCommandHotkeyEventMapper()

        let keyDown = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskCommand]
        )
        let keyUp = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: []
        )
        let repeatedKeyUp = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: []
        )

        #expect(keyDown == .keyDown())
        #expect(keyUp == .keyUp())
        #expect(repeatedKeyUp == nil)
    }

    @Test func rightCommandMapperCarriesOptionAsTranslationIntentOnKeyDown() {
        var mapper = RightCommandHotkeyEventMapper()

        let keyDown = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskCommand, .maskAlternate]
        )
        let keyUp = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskAlternate]
        )

        #expect(keyDown == .keyDown(outputIntent: .translate))
        #expect(keyUp == .keyUp())
    }

    @Test func rightCommandMapperPromotesTranslationWhenOptionIsPressedAfterRightCommand() {
        var mapper = RightCommandHotkeyEventMapper()

        let keyDown = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskCommand]
        )
        let optionDown = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightOption),
            flags: [.maskCommand, .maskAlternate]
        )
        let keyUp = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskAlternate]
        )

        #expect(keyDown == .keyDown())
        #expect(optionDown == .outputIntentChanged(to: .translate))
        #expect(keyUp == .keyUp())
    }

    @Test func rightCommandMapperIgnoresOptionAloneBeforeTranslationKeyDown() {
        var mapper = RightCommandHotkeyEventMapper()

        let optionDown = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightOption),
            flags: [.maskAlternate]
        )
        let keyDown = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskCommand, .maskAlternate]
        )
        let keyUp = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskAlternate]
        )

        #expect(optionDown == nil)
        #expect(keyDown == .keyDown(outputIntent: .translate))
        #expect(keyUp == .keyUp())
    }

    @Test func rightCommandMapperKeepsTranslationIntentAfterOptionRelease() {
        var mapper = RightCommandHotkeyEventMapper()

        let keyDown = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskCommand]
        )
        let optionDown = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightOption),
            flags: [.maskCommand, .maskAlternate]
        )
        let optionUp = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightOption),
            flags: [.maskCommand]
        )
        let keyUp = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: []
        )

        #expect(keyDown == .keyDown())
        #expect(optionDown == .outputIntentChanged(to: .translate))
        #expect(optionUp == nil)
        #expect(keyUp == .keyUp())
    }

    @Test func rightCommandMapperIgnoresLeftCommandAndRepeatedFlags() {
        var mapper = RightCommandHotkeyEventMapper()

        let leftCommand = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_Command),
            flags: [.maskCommand]
        )
        let firstRightCommand = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskCommand]
        )
        let repeatedRightCommand = mapper.event(
            type: .flagsChanged,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskCommand]
        )
        let unrelatedKeyDown = mapper.event(
            type: .keyDown,
            keyCode: Int64(kVK_RightCommand),
            flags: [.maskCommand]
        )

        #expect(leftCommand == nil)
        #expect(firstRightCommand == .keyDown())
        #expect(repeatedRightCommand == nil)
        #expect(unrelatedKeyDown == nil)
    }

    @Test func holdToRecordStartsOnKeyDownAndStopsOnMatchingKeyUp() {
        let configuration = GlobalHotkeyConfiguration.defaultDictation

        #expect(
            configuration.recordingCommand(
                for: .keyDown,
                isRecording: false,
                isShortcutPressed: false
            ) == .startRecording
        )
        #expect(
            configuration.recordingCommand(
                for: .keyDown,
                isRecording: true,
                isShortcutPressed: true
            ) == nil
        )
        #expect(
            configuration.recordingCommand(
                for: .keyUp,
                isRecording: true,
                isShortcutPressed: true
            ) == .stopRecording
        )
        #expect(
            configuration.recordingCommand(
                for: .keyUp,
                isRecording: true,
                isShortcutPressed: false
            ) == nil
        )
    }

    @Test func registrationStatusExposesActiveConfiguration() {
        let configuration = GlobalHotkeyConfiguration.defaultDictation

        #expect(
            GlobalHotkeyRegistrationStatus.registered(configuration).activeConfiguration
                == configuration
        )
    }

}
