//
//  DictationFailurePresentation.swift
//  HoldType
//
//  Created by Codex on 7/7/26.
//

struct DictationFailurePresentation: Equatable {
    let title: String
    let message: String
    let failedAttemptID: FailedTranscriptionAttempt.ID?
    let settingsTarget: SettingsNavigationItem?
    let canRetry: Bool
    let showsRecoveryPrompt: Bool

    init(
        title: String,
        message: String,
        failedAttemptID: FailedTranscriptionAttempt.ID? = nil,
        settingsTarget: SettingsNavigationItem? = nil,
        canRetry: Bool = false,
        showsRecoveryPrompt: Bool = false
    ) {
        self.title = title
        self.message = message
        self.failedAttemptID = failedAttemptID
        self.settingsTarget = settingsTarget
        self.canRetry = canRetry && failedAttemptID != nil
        self.showsRecoveryPrompt = showsRecoveryPrompt
    }
}
