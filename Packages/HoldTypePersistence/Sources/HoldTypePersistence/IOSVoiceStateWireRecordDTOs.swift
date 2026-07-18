import Foundation
import HoldTypeDomain

extension IOSVoiceStateWireCodec {
    struct RecordWire: Codable {
        let schemaVersion: Int
        let capture: CaptureWire?
        let pending: PendingWire?
        let latest: ResultWire?

        private enum CodingKeys: String, CodingKey {
            case schemaVersion
            case capture
            case pending
            case latest
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(schemaVersion, forKey: .schemaVersion)
            if let capture {
                try container.encode(capture, forKey: .capture)
            } else {
                try container.encodeNil(forKey: .capture)
            }
            if let pending {
                try container.encode(pending, forKey: .pending)
            } else {
                try container.encodeNil(forKey: .pending)
            }
            if let latest {
                try container.encode(latest, forKey: .latest)
            } else {
                try container.encodeNil(forKey: .latest)
            }
        }
    }

    struct CaptureWire: Codable {
        let attemptID: String
        let audioRelativeIdentifier: String
        let createdAtMilliseconds: Int64
        let outputIntent: String
        let draftInsertionMode: String?
        let forcesTextCorrection: Bool?
        let recordingDurationLimitMinutes: Int?
        let phase: String
        let durationMilliseconds: Int64?
        let byteCount: Int64?

        init(_ capture: IOSVoiceStateCapture) throws {
            attemptID = capture.attemptID.uuidString
            audioRelativeIdentifier = capture.audioRelativeIdentifier
            createdAtMilliseconds = try IOSVoiceStateValidation.milliseconds(
                from: capture.createdAt
            )
            outputIntent = capture.outputIntent.rawValue
            draftInsertionMode = capture.draftInsertionMode.rawValue
            forcesTextCorrection = capture.forcesTextCorrection
            recordingDurationLimitMinutes = capture.recordingDurationLimit.minutes
            phase = capture.phase.rawValue
            durationMilliseconds = capture.durationMilliseconds
            byteCount = capture.byteCount
        }

        func value(schemaVersion: Int) throws -> IOSVoiceStateCapture {
            guard let identifier = UUID(uuidString: attemptID),
                  identifier.uuidString == attemptID,
                  let output = DictationOutputIntent(rawValue: outputIntent),
                  let phase = IOSVoiceStateCapturePhase(rawValue: phase) else {
                throw IOSVoiceStateRepositoryError.invalidRecord
            }
            let insertionMode: IOSVoiceDraftInsertionMode
            let correction: Bool
            if schemaVersion == 1 {
                insertionMode = .append
                correction = false
            } else {
                guard let rawMode = draftInsertionMode,
                      let mode = IOSVoiceDraftInsertionMode(
                          rawValue: rawMode
                      ),
                      let forcesTextCorrection else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                insertionMode = mode
                correction = forcesTextCorrection
            }
            let recordingDurationLimit: RecordingDurationLimit
            if schemaVersion < 5 {
                recordingDurationLimit = .default
            } else {
                guard
                    let recordingDurationLimitMinutes,
                    let value = RecordingDurationLimit(
                        validatingMinutes: recordingDurationLimitMinutes
                    )
                else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                recordingDurationLimit = value
            }
            return try IOSVoiceStateCapture(
                attemptID: identifier,
                audioRelativeIdentifier: audioRelativeIdentifier,
                createdAt: IOSVoiceStateValidation.date(
                    from: createdAtMilliseconds
                ),
                outputIntent: output,
                draftInsertionMode: insertionMode,
                forcesTextCorrection: correction,
                recordingDurationLimit: recordingDurationLimit,
                phase: phase,
                durationMilliseconds: durationMilliseconds,
                byteCount: byteCount
            )
        }

        private enum CodingKeys: String, CodingKey {
            case attemptID
            case audioRelativeIdentifier
            case createdAtMilliseconds
            case outputIntent
            case draftInsertionMode
            case forcesTextCorrection
            case recordingDurationLimitMinutes
            case phase
            case durationMilliseconds
            case byteCount
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(attemptID, forKey: .attemptID)
            try container.encode(
                audioRelativeIdentifier,
                forKey: .audioRelativeIdentifier
            )
            try container.encode(
                createdAtMilliseconds,
                forKey: .createdAtMilliseconds
            )
            try container.encode(outputIntent, forKey: .outputIntent)
            try container.encode(
                draftInsertionMode,
                forKey: .draftInsertionMode
            )
            try container.encode(
                forcesTextCorrection,
                forKey: .forcesTextCorrection
            )
            try container.encode(
                recordingDurationLimitMinutes,
                forKey: .recordingDurationLimitMinutes
            )
            try container.encode(phase, forKey: .phase)
            if let durationMilliseconds {
                try container.encode(
                    durationMilliseconds,
                    forKey: .durationMilliseconds
                )
            } else {
                try container.encodeNil(forKey: .durationMilliseconds)
            }
            if let byteCount {
                try container.encode(byteCount, forKey: .byteCount)
            } else {
                try container.encodeNil(forKey: .byteCount)
            }
        }
    }

    struct ResultWire: Codable {
        let resultID: String
        let sourceAttemptID: String
        let text: String
        let createdAtMilliseconds: Int64

        init(_ latest: IOSVoiceStateLatest) throws {
            resultID = latest.resultID.uuidString
            sourceAttemptID = latest.sourceAttemptID.uuidString
            text = latest.text
            createdAtMilliseconds = try IOSVoiceStateValidation.milliseconds(
                from: latest.createdAt
            )
        }

        init(_ result: IOSVoiceStateAcceptedResult) throws {
            resultID = result.resultID.uuidString
            sourceAttemptID = result.sourceAttemptID.uuidString
            text = result.text
            createdAtMilliseconds = try IOSVoiceStateValidation.milliseconds(
                from: result.createdAt
            )
        }

        func latestValue() throws -> IOSVoiceStateLatest {
            let values = try commonValues()
            return try IOSVoiceStateLatest(
                resultID: values.resultID,
                sourceAttemptID: values.sourceAttemptID,
                text: text,
                createdAt: values.createdAt
            )
        }

        func acceptedValue() throws -> IOSVoiceStateAcceptedResult {
            let values = try commonValues()
            guard IOSVoiceStateValidation.isStoredText(text) else {
                throw IOSVoiceStateRepositoryError.invalidAcceptedText
            }
            return IOSVoiceStateAcceptedResult(
                resultID: values.resultID,
                sourceAttemptID: values.sourceAttemptID,
                text: text,
                createdAt: values.createdAt
            )
        }

        private func commonValues() throws -> (
            resultID: UUID,
            sourceAttemptID: UUID,
            createdAt: Date
        ) {
            guard let resultID = UUID(uuidString: resultID),
                  resultID.uuidString == self.resultID,
                  let sourceAttemptID = UUID(uuidString: sourceAttemptID),
                  sourceAttemptID.uuidString == self.sourceAttemptID else {
                throw IOSVoiceStateRepositoryError.invalidRecord
            }
            return (
                resultID,
                sourceAttemptID,
                try IOSVoiceStateValidation.date(
                    from: createdAtMilliseconds
                )
            )
        }
    }
}
