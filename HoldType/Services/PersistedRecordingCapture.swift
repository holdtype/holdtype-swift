import Foundation

nonisolated struct PersistedRecordingCapture: Codable {
    let schemaVersion: Int
    let id: UUID
    let createdAt: Date
    let audioFileName: String
    let transcriptionModel: String
    let languageCode: String?
    let maximumDuration: TimeInterval
    let transferredRecoveryAttemptID: UUID?

    init(
        _ lease: RecordingCaptureLease,
        transferredRecoveryAttemptID: UUID? = nil
    ) {
        schemaVersion = 1
        id = lease.id
        createdAt = lease.createdAt
        audioFileName = lease.audioFileURL.lastPathComponent
        transcriptionModel = lease.transcriptionModel
        languageCode = lease.languageCode
        maximumDuration = lease.maximumDuration
        self.transferredRecoveryAttemptID = transferredRecoveryAttemptID
    }

    func lease(in directoryURL: URL) -> RecordingCaptureLease? {
        guard schemaVersion == 1,
              audioFileName == URL(fileURLWithPath: audioFileName).lastPathComponent,
              maximumDuration.isFinite,
              maximumDuration > 0 else {
            return nil
        }
        return RecordingCaptureLease(
            id: id,
            createdAt: createdAt,
            audioFileURL: directoryURL.appendingPathComponent(audioFileName, isDirectory: false),
            transcriptionModel: transcriptionModel,
            languageCode: languageCode,
            maximumDuration: maximumDuration
        )
    }
}

