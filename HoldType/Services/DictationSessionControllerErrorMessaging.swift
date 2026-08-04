//
//  DictationSessionControllerErrorMessaging.swift
//  HoldType
//

import Foundation
import HoldTypeDomain

extension DictationSessionController {
    static func userFacingMessage(for error: Error) -> String {
        if let localizedError = error as? LocalizedError,
           let description = localizedError.errorDescription,
           !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return description
        }

        return error.localizedDescription
    }

    static func isNonRecordingFinalizationFailure(_ error: Error) -> Bool {
        guard let recorderError = error as? AudioRecorderServiceError else {
            return false
        }

        switch recorderError {
        case .missingRecordingFile, .emptyRecording, .recordingTooShort:
            return true
        default:
            return false
        }
    }
}
