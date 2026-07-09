//
//  DictationSessionControllerRecordingActions.swift
//  HoldType
//
//  Created by Codex on 6/22/26.
//

import HoldTypeDomain

extension DictationSessionController {
    func startRecordingAction() async {
        guard status.voiceWorkPhase == .inactive else {
            return
        }

        await performRecordingAction()
    }

    func stopRecordingAction() async {
        guard status.voiceWorkPhase == .listening else {
            return
        }

        await performRecordingAction()
    }
}
