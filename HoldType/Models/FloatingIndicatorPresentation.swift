//
//  FloatingIndicatorPresentation.swift
//  HoldType
//
//  Created by Codex on 6/21/26.
//

import Foundation
import HoldTypeDomain

struct FloatingIndicatorPresentation: Equatable {
    enum Phase: Equatable {
        case recording
        case transcribing
    }

    let phase: Phase
    let title: String
    let countdown: VoiceSessionCountdown?

    init(
        phase: Phase,
        title: String,
        countdown: VoiceSessionCountdown? = nil
    ) {
        self.phase = phase
        self.title = title
        self.countdown = countdown
    }

    var accessibilityLabel: String {
        guard let countdown else {
            return "HoldType \(title)"
        }
        return "HoldType \(title), \(countdown.remainingWholeSeconds) seconds remaining"
    }

    var showsWarningOrbit: Bool {
        guard phase == .recording, let countdown else {
            return false
        }

        return (1...10).contains(countdown.remainingWholeSeconds)
    }

    static func presentation(
        for status: DictationStatus,
        settings: AppSettings,
        recordingCountdown: VoiceSessionCountdown? = nil
    ) -> FloatingIndicatorPresentation? {
        guard settings.showFloatingIndicator else {
            return nil
        }

        switch status {
        case .idle:
            return nil
        case .recording:
            return FloatingIndicatorPresentation(
                phase: .recording,
                title: "Recording",
                countdown: recordingCountdown
            )
        case .transcribing:
            return FloatingIndicatorPresentation(
                phase: .transcribing,
                title: "Transcribing"
            )
        case .success, .failure:
            return nil
        }
    }
}
