import Foundation
import HoldTypeDomain

extension IOSVoiceStateWireCodec {
    struct PendingWire: Codable {
        let attemptID: String
        let audioRelativeIdentifier: String
        let createdAtMilliseconds: Int64
        let updatedAtMilliseconds: Int64
        let outputIntent: String
        let draftInsertionMode: String?
        let forcesTextCorrection: Bool?
        let transcriptionModel: String
        let transcriptionLanguageCode: String?
        let durationMilliseconds: Int64
        let byteCount: Int64
        let acceptedAudioRetention: String?
        let acceptedTranscriptionID: String?
        let acceptedTranscript: String?
        let checkpointStage: String?
        let checkpointText: String?
        let transcriptionReplayBlocked: Bool?
        private let status: StatusWire

        private enum CodingKeys: String, CodingKey {
            case attemptID
            case audioRelativeIdentifier
            case createdAtMilliseconds
            case updatedAtMilliseconds
            case outputIntent
            case draftInsertionMode
            case forcesTextCorrection
            case transcriptionModel
            case transcriptionLanguageCode
            case durationMilliseconds
            case byteCount
            case acceptedAudioRetention
            case acceptedTranscriptionID
            case acceptedTranscript
            case checkpointStage
            case checkpointText
            case transcriptionReplayBlocked
            case status
        }

        init(_ pending: IOSVoiceStatePending) throws {
            attemptID = pending.attemptID.uuidString
            audioRelativeIdentifier = pending.audioRelativeIdentifier
            createdAtMilliseconds = try IOSVoiceStateValidation.milliseconds(
                from: pending.createdAt
            )
            updatedAtMilliseconds = try IOSVoiceStateValidation.milliseconds(
                from: pending.updatedAt
            )
            outputIntent = pending.outputIntent.rawValue
            draftInsertionMode = pending.draftInsertionMode.rawValue
            forcesTextCorrection = pending.forcesTextCorrection
            transcriptionModel = pending.transcriptionModel
            transcriptionLanguageCode = pending.transcriptionLanguageCode
            durationMilliseconds = pending.durationMilliseconds
            byteCount = pending.byteCount
            acceptedAudioRetention = pending.acceptedAudioRetention.rawValue
            acceptedTranscriptionID = pending.transcriptionCheckpoint?
                .operationID.uuidString
            acceptedTranscript = pending.transcriptionCheckpoint?
                .acceptedTranscript
            checkpointStage = pending.transcriptionCheckpoint?.stage.rawValue
            checkpointText = pending.transcriptionCheckpoint?.text
            transcriptionReplayBlocked = pending.transcriptionReplayBlocked
            status = try StatusWire(pending.status)
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
            try container.encode(
                updatedAtMilliseconds,
                forKey: .updatedAtMilliseconds
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
                transcriptionModel,
                forKey: .transcriptionModel
            )
            if let transcriptionLanguageCode {
                try container.encode(
                    transcriptionLanguageCode,
                    forKey: .transcriptionLanguageCode
                )
            } else {
                try container.encodeNil(forKey: .transcriptionLanguageCode)
            }
            try container.encode(
                durationMilliseconds,
                forKey: .durationMilliseconds
            )
            try container.encode(byteCount, forKey: .byteCount)
            try container.encode(
                acceptedAudioRetention,
                forKey: .acceptedAudioRetention
            )
            if let acceptedTranscriptionID {
                try container.encode(
                    acceptedTranscriptionID,
                    forKey: .acceptedTranscriptionID
                )
            } else {
                try container.encodeNil(forKey: .acceptedTranscriptionID)
            }
            if let acceptedTranscript {
                try container.encode(
                    acceptedTranscript,
                    forKey: .acceptedTranscript
                )
            } else {
                try container.encodeNil(forKey: .acceptedTranscript)
            }
            if let checkpointStage {
                try container.encode(
                    checkpointStage,
                    forKey: .checkpointStage
                )
            } else {
                try container.encodeNil(forKey: .checkpointStage)
            }
            if let checkpointText {
                try container.encode(checkpointText, forKey: .checkpointText)
            } else {
                try container.encodeNil(forKey: .checkpointText)
            }
            try container.encode(
                transcriptionReplayBlocked,
                forKey: .transcriptionReplayBlocked
            )
            try container.encode(status, forKey: .status)
        }

        func value(schemaVersion: Int) throws -> IOSVoiceStatePending {
            guard let attemptID = UUID(uuidString: attemptID),
                  attemptID.uuidString == self.attemptID,
                  let outputIntent = DictationOutputIntent(
                      rawValue: outputIntent
                  ) else {
                throw IOSVoiceStateRepositoryError.invalidRecord
            }
            let insertionMode: IOSVoiceDraftInsertionMode
            let correction: Bool
            let retention: IOSAcceptedAudioRetention
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
            if schemaVersion < 3 {
                retention = .recordingCachePolicy
            } else {
                guard let rawRetention = acceptedAudioRetention,
                      let decodedRetention = IOSAcceptedAudioRetention(
                          rawValue: rawRetention
                      ) else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                retention = decodedRetention
            }
            let checkpoint: IOSVoiceStateTranscriptionCheckpoint?
            let replayBlocked: Bool
            if schemaVersion < 4 {
                checkpoint = nil
                replayBlocked = false
            } else {
                guard let transcriptionReplayBlocked else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                replayBlocked = transcriptionReplayBlocked
                switch (
                    acceptedTranscriptionID,
                    acceptedTranscript,
                    checkpointStage,
                    checkpointText
                ) {
                case (nil, nil, nil, nil):
                    checkpoint = nil
                case (
                    .some(let rawIdentifier),
                    .some(let acceptedTranscript),
                    .some(let rawStage),
                    .some(let text)
                ):
                    guard let identifier = UUID(uuidString: rawIdentifier),
                          identifier.uuidString == rawIdentifier,
                          let stage = IOSVoiceStateTextCheckpointStage(
                              rawValue: rawStage
                          ) else {
                        throw IOSVoiceStateRepositoryError.invalidRecord
                    }
                    checkpoint = try IOSVoiceStateTranscriptionCheckpoint(
                        operationID: identifier,
                        acceptedTranscript: acceptedTranscript,
                        stage: stage,
                        text: text
                    )
                default:
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
            }
            return try IOSVoiceStatePending(
                attemptID: attemptID,
                audioRelativeIdentifier: audioRelativeIdentifier,
                createdAt: IOSVoiceStateValidation.date(
                    from: createdAtMilliseconds
                ),
                updatedAt: IOSVoiceStateValidation.date(
                    from: updatedAtMilliseconds
                ),
                outputIntent: outputIntent,
                draftInsertionMode: insertionMode,
                forcesTextCorrection: correction,
                transcriptionModel: transcriptionModel,
                transcriptionLanguageCode: transcriptionLanguageCode,
                durationMilliseconds: durationMilliseconds,
                byteCount: byteCount,
                acceptedAudioRetention: retention,
                transcriptionReplayBlocked: replayBlocked,
                transcriptionCheckpoint: checkpoint,
                status: try status.value(attemptID: attemptID)
            )
        }
    }

    private struct StatusWire: Codable {
        let kind: String
        let stage: String?
        let operationID: String?
        let accepted: ResultWire?

        private enum CodingKeys: String, CodingKey {
            case kind
            case stage
            case operationID
            case accepted
        }

        init(_ status: IOSVoiceStatePendingStatus) throws {
            switch status {
            case .ready:
                kind = "ready"
                stage = nil
                operationID = nil
                accepted = nil
            case .processing(let stageValue, let identifier):
                kind = "processing"
                stage = stageValue.rawValue
                operationID = identifier.uuidString
                accepted = nil
            case .failed:
                kind = "failed"
                stage = nil
                operationID = nil
                accepted = nil
            case .acceptedCleanup(let result):
                kind = "acceptedCleanup"
                stage = nil
                operationID = nil
                accepted = try ResultWire(result)
            }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(kind, forKey: .kind)
            if let stage {
                try container.encode(stage, forKey: .stage)
            } else {
                try container.encodeNil(forKey: .stage)
            }
            if let operationID {
                try container.encode(operationID, forKey: .operationID)
            } else {
                try container.encodeNil(forKey: .operationID)
            }
            if let accepted {
                try container.encode(accepted, forKey: .accepted)
            } else {
                try container.encodeNil(forKey: .accepted)
            }
        }

        func value(attemptID: UUID) throws -> IOSVoiceStatePendingStatus {
            switch kind {
            case "ready":
                guard stage == nil, operationID == nil, accepted == nil else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                return .ready
            case "processing":
                guard let stage,
                      let processingStage = IOSVoiceStateProcessingStage(
                          rawValue: stage
                      ),
                      let operationID,
                      let identifier = UUID(uuidString: operationID),
                      identifier.uuidString == operationID,
                      accepted == nil else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                return .processing(processingStage, operationID: identifier)
            case "failed":
                guard stage == nil, operationID == nil, accepted == nil else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                return .failed
            case "acceptedCleanup":
                guard stage == nil, operationID == nil,
                      let accepted else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                let result = try accepted.acceptedValue()
                guard result.sourceAttemptID == attemptID else {
                    throw IOSVoiceStateRepositoryError.invalidRecord
                }
                return .acceptedCleanup(result)
            default:
                throw IOSVoiceStateRepositoryError.invalidRecord
            }
        }
    }
}
