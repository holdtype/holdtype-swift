//
//  MenuBarPresentation.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import Foundation
import HoldTypeDomain

enum HoldTypeMenuBarIdentity {
    static let title = "HoldType"
    static let visibleTitle: String? = nil
    static let iconAssetName = "HoldTypeMenuBarIcon"
    static let helpText = "HoldType Dictation"
}

enum HoldTypeWindowTitle {
    static let history = titled("History")

    static func titled(_ title: String) -> String {
        "\(HoldTypeMenuBarIdentity.title): \(title)"
    }
}

struct MenuBarPresentation: Equatable {
    enum UtilityAction: CaseIterable, Hashable {
        case editFixes
        case history
        case settings

        var title: String {
            switch self {
            case .editFixes:
                return MenuBarPresentation.editFixesTitle
            case .history:
                return MenuBarPresentation.historyTitle
            case .settings:
                return MenuBarPresentation.settingsTitle
            }
        }
    }

    static let projectTitle = "View Project on GitHub"
    static let projectURLString = "https://github.com/holdtype/holdtype-swift"
    static let translationActionTitle = "Transcribe & Translate"
    static let pasteLastResultTitle = "Paste Last Result"
    static let translationShortcutHint = GlobalHotkeyShortcut.translationDictation.menuHoldText
    static let pasteLastResultShortcutHint = GlobalHotkeyShortcut.appClipboardPaste.menuKeyEquivalentText
    static let editFixesTitle = "Manage Fixes…"
    static let historyTitle = "Transcript History"
    static let settingsTitle = "Settings\u{2026}"
    static let checkForUpdatesTitle = "Check for Updates..."
    static let quitTitle = "Quit HoldType"
    static let utilityActions = UtilityAction.allCases

    let appTitle: String
    let statusText: String
    let recordingActionTitle: String
    let recordingActionShortcutHint: String?
    let isRecordingActionEnabled: Bool
    let translationActionTitle: String
    let translationActionShortcutHint: String
    let isTranslationActionEnabled: Bool
    let pasteLastResultTitle: String
    let pasteLastResultActionShortcutHint: String
    let isPasteLastResultEnabled: Bool
    let showsFailureRecoveryActions: Bool

    init(
        dictationStatus: DictationStatus,
        failurePresentation: DictationFailurePresentation? = nil,
        outputStatusText: String? = nil,
        recordingCountdown: VoiceSessionCountdown? = nil,
        settings: AppSettings = .defaults,
        shortcutConfiguration: ShortcutConfiguration = .defaults,
        isLastResultPasteAvailable: Bool = false
    ) {
        appTitle = HoldTypeMenuBarIdentity.title
        statusText = Self.statusText(
            for: dictationStatus,
            failurePresentation: failurePresentation,
            outputStatusText: outputStatusText,
            recordingCountdown: recordingCountdown
        )
        recordingActionTitle = dictationStatus.recordingActionTitle
        recordingActionShortcutHint = dictationStatus.voiceWorkPhase == .listening
            ? nil
            : shortcutConfiguration.dictation.menuHoldText
        isRecordingActionEnabled = dictationStatus.isRecordingActionEnabled
        translationActionTitle = Self.translationActionTitle
        translationActionShortcutHint = shortcutConfiguration.translation.menuHoldText
        isTranslationActionEnabled = Self.canStartNewRecording(from: dictationStatus)
            && settings.translationShortcutEnabled
        pasteLastResultTitle = Self.pasteLastResultTitle
        pasteLastResultActionShortcutHint = shortcutConfiguration.pasteLastResult.menuKeyEquivalentText
        isPasteLastResultEnabled = settings.saveTranscriptsToAppClipboard
            && isLastResultPasteAvailable
        showsFailureRecoveryActions = Self.isFailure(dictationStatus)
            || failurePresentation != nil
    }

    private static func statusText(
        for dictationStatus: DictationStatus,
        failurePresentation: DictationFailurePresentation?,
        outputStatusText: String?,
        recordingCountdown: VoiceSessionCountdown?
    ) -> String {
        if dictationStatus.voiceWorkPhase == .listening,
           let recordingCountdown {
            return "Recording — \(recordingCountdown.remainingWholeSeconds)s remaining"
        }

        if case .failure = dictationStatus,
           let failurePresentation {
            return DictationStatus.compactFailureStatusText(
                for: failurePresentation.title
            )
        }

        let trimmedOutputStatusText = outputStatusText?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedOutputStatusText,
           !trimmedOutputStatusText.isEmpty {
            return trimmedOutputStatusText
        }

        return dictationStatus.menuStatusText
    }

    private static func isFailure(_ dictationStatus: DictationStatus) -> Bool {
        if case .failure = dictationStatus {
            return true
        }

        return false
    }

    private static func canStartNewRecording(from dictationStatus: DictationStatus) -> Bool {
        dictationStatus.voiceWorkPhase == .inactive
    }
}
