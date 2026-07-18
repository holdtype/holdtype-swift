import CoreFoundation
import Foundation
import HoldTypeDomain

enum IOSVoiceStateRepositoryError: Error, Equatable, Sendable {
    case readFailed
    case sourceTooLarge
    case malformedData
    case unsupportedSchemaVersion
    case invalidRecord
    case pendingSlotOccupied
    case stalePending
    case invalidTransition
    case invalidAcceptedText
    case writeFailed
}

/// One bounded atomic owner for the V1.1 Pending and Latest Result metadata.
/// Audio ownership is represented by the exact relative identifier, while the
/// capture/audio boundary owns descriptor validation and physical removal.
actor IOSVoiceStateRepository {
    static let maximumByteCount = 256 * 1_024

    private static let filePolicy = ProtectedAtomicMetadataFilePolicy(
        maximumByteCount: maximumByteCount,
        fileProtection: .complete,
        excludesFromBackup: true
    )

    private let fileURL: URL
    private let fileSystem: any ProtectedAtomicMetadataFileSystem
    private let now: @Sendable () -> Date

    init(applicationSupportDirectoryURL: URL) {
        fileURL = IOSVoiceStateStorageLocation.fileURL(
            in: applicationSupportDirectoryURL
        )
        fileSystem = FoundationProtectedAtomicMetadataFileSystem()
        now = { Date() }
    }

    init(
        fileURL: URL,
        fileSystem: any ProtectedAtomicMetadataFileSystem =
            FoundationProtectedAtomicMetadataFileSystem(),
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.fileURL = fileURL
        self.fileSystem = fileSystem
        self.now = now
    }

    func load() throws -> IOSVoiceStateSnapshot {
        let data: Data?
        do {
            data = try fileSystem.readFileIfPresent(
                at: fileURL,
                policy: Self.filePolicy
            )
        } catch ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded {
            throw IOSVoiceStateRepositoryError.sourceTooLarge
        } catch {
            throw IOSVoiceStateRepositoryError.readFailed
        }
        guard let data else { return .empty }
        return try IOSVoiceStateWireCodec.decode(
            data,
            maximumInputByteCount: Self.maximumByteCount
        )
    }

    @discardableResult
    func installPending(
        _ pending: IOSVoiceStatePending
    ) throws -> IOSVoiceStateSnapshot {
        var snapshot = try load()
        guard snapshot.capture == nil, snapshot.pending == nil else {
            throw IOSVoiceStateRepositoryError.pendingSlotOccupied
        }
        snapshot.pending = pending
        try replace(snapshot)
        return snapshot
    }

    @discardableResult
    func installCapture(
        _ capture: IOSVoiceStateCapture
    ) throws -> IOSVoiceStateSnapshot {
        var snapshot = try load()
        guard snapshot.capture == nil, snapshot.pending == nil else {
            throw IOSVoiceStateRepositoryError.pendingSlotOccupied
        }
        snapshot.capture = capture
        try replace(snapshot)
        return snapshot
    }

    @discardableResult
    func transitionCapture(
        attemptID: UUID,
        to phase: IOSVoiceStateCapturePhase
    ) throws -> IOSVoiceStateCapture {
        var snapshot = try load()
        guard let capture = snapshot.capture,
              capture.attemptID == attemptID else {
            throw IOSVoiceStateRepositoryError.stalePending
        }
        let isAllowed: Bool
        switch (capture.phase, phase) {
        case (.recording, .finalizing),
             (.recording, .discarding),
             (.finalizing, .discarding),
             (.completed, .discarding):
            isAllowed = true
        default:
            isAllowed = capture.phase == phase
        }
        guard isAllowed else {
            throw IOSVoiceStateRepositoryError.invalidTransition
        }
        if capture.phase == phase { return capture }
        let updated = try capture.replacing(phase: phase)
        snapshot.capture = updated
        try replace(snapshot)
        return updated
    }

    @discardableResult
    func completeCapture(
        attemptID: UUID,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) throws -> IOSVoiceStateCapture {
        var snapshot = try load()
        guard let capture = snapshot.capture,
              capture.attemptID == attemptID,
              capture.phase == .finalizing else {
            throw IOSVoiceStateRepositoryError.invalidTransition
        }
        let completed = try capture.replacing(
            phase: .completed,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount
        )
        snapshot.capture = completed
        try replace(snapshot)
        return completed
    }

    @discardableResult
    func promoteCapture(
        attemptID: UUID,
        transcriptionConfiguration: TranscriptionConfiguration,
        acceptedAudioRetention: IOSAcceptedAudioRetention =
            .recordingCachePolicy,
        initialStatus: IOSVoiceStatePendingStatus = .ready
    ) throws -> IOSVoiceStatePending {
        var snapshot = try load()
        guard snapshot.pending == nil,
              let capture = snapshot.capture,
              capture.attemptID == attemptID,
              capture.phase == .completed,
              let durationMilliseconds = capture.durationMilliseconds,
              let byteCount = capture.byteCount,
              !transcriptionConfiguration.customLanguageCodeValidation
                .isInvalid else {
            throw IOSVoiceStateRepositoryError.invalidTransition
        }
        switch initialStatus {
        case .ready, .failed:
            break
        case .processing, .acceptedCleanup:
            throw IOSVoiceStateRepositoryError.invalidTransition
        }
        let pending = try IOSVoiceStatePending(
            attemptID: capture.attemptID,
            audioRelativeIdentifier: capture.audioRelativeIdentifier,
            createdAt: capture.createdAt,
            updatedAt: mutationDate(after: capture.createdAt),
            outputIntent: capture.outputIntent,
            draftInsertionMode: capture.draftInsertionMode,
            forcesTextCorrection: capture.forcesTextCorrection,
            transcriptionModel: transcriptionConfiguration.resolvedModel,
            transcriptionLanguageCode:
                transcriptionConfiguration.resolvedLanguageCode,
            durationMilliseconds: durationMilliseconds,
            byteCount: byteCount,
            acceptedAudioRetention: acceptedAudioRetention,
            status: initialStatus
        )
        snapshot.capture = nil
        snapshot.pending = pending
        try replace(snapshot)
        return pending
    }

    @discardableResult
    func clearCapture(
        attemptID: UUID
    ) throws -> IOSVoiceStateMutationResult {
        var snapshot = try load()
        guard let capture = snapshot.capture else {
            return .unchanged(snapshot)
        }
        guard capture.attemptID == attemptID else {
            throw IOSVoiceStateRepositoryError.stalePending
        }
        guard capture.phase == .discarding else {
            throw IOSVoiceStateRepositoryError.invalidTransition
        }
        snapshot.capture = nil
        try replace(snapshot)
        return .changed(snapshot)
    }

    func mutationDate(after prior: Date) -> Date {
        let candidate = now()
        return candidate >= prior ? candidate : prior
    }

    func replace(_ snapshot: IOSVoiceStateSnapshot) throws {
        let data = try IOSVoiceStateWireCodec.encode(snapshot)
        guard data.count <= Self.maximumByteCount else {
            throw IOSVoiceStateRepositoryError.writeFailed
        }
        do {
            try fileSystem.replaceFileAtomically(
                at: fileURL,
                with: data,
                policy: Self.filePolicy
            )
        } catch {
            throw IOSVoiceStateRepositoryError.writeFailed
        }
    }
}

enum IOSVoiceStateWireCodec {
    private static let schemaVersion = 5
    private static let rootKeys: Set<String> = [
        "schemaVersion", "capture", "pending", "latest",
    ]
    private static let captureV1Keys: Set<String> = [
        "attemptID", "audioRelativeIdentifier", "createdAtMilliseconds",
        "outputIntent", "phase", "durationMilliseconds", "byteCount",
    ]
    private static let captureV2Keys = captureV1Keys.union([
        "draftInsertionMode", "forcesTextCorrection",
    ])
    private static let captureKeys = captureV2Keys.union([
        "recordingDurationLimitMinutes",
    ])
    private static let pendingV1Keys: Set<String> = [
        "attemptID", "audioRelativeIdentifier", "createdAtMilliseconds",
        "updatedAtMilliseconds", "outputIntent", "transcriptionModel",
        "transcriptionLanguageCode", "durationMilliseconds", "byteCount",
        "status",
    ]
    private static let pendingV2Keys = pendingV1Keys.union([
        "draftInsertionMode", "forcesTextCorrection",
    ])
    private static let pendingV3Keys = pendingV2Keys.union([
        "acceptedAudioRetention",
    ])
    private static let pendingKeys = pendingV3Keys.union([
        "acceptedTranscriptionID", "acceptedTranscript", "checkpointStage",
        "checkpointText", "transcriptionReplayBlocked",
    ])
    private static let statusKeys: Set<String> = [
        "kind", "stage", "operationID", "accepted",
    ]
    private static let resultKeys: Set<String> = [
        "resultID", "sourceAttemptID", "text", "createdAtMilliseconds",
    ]

    static func encode(_ snapshot: IOSVoiceStateSnapshot) throws -> Data {
        let wire = try RecordWire(
            schemaVersion: schemaVersion,
            capture: snapshot.capture.map(CaptureWire.init),
            pending: snapshot.pending.map(PendingWire.init),
            latest: snapshot.latest.map(ResultWire.init)
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        do {
            return try encoder.encode(wire)
        } catch {
            throw IOSVoiceStateRepositoryError.writeFailed
        }
    }

    static func decode(
        _ data: Data,
        maximumInputByteCount: Int
    ) throws -> IOSVoiceStateSnapshot {
        do {
            try BoundedJSONMemberValidator.validate(
                data,
                limits: .metadataFile(
                    maximumInputByteCount: maximumInputByteCount
                )
            )
        } catch BoundedJSONMemberValidationError.inputTooLarge {
            throw IOSVoiceStateRepositoryError.sourceTooLarge
        } catch {
            throw IOSVoiceStateRepositoryError.malformedData
        }

        let object: [String: Any]
        do {
            guard let decoded = try JSONSerialization.jsonObject(
                with: data,
                options: [.fragmentsAllowed]
            ) as? [String: Any] else {
                throw IOSVoiceStateRepositoryError.malformedData
            }
            object = decoded
        } catch let error as IOSVoiceStateRepositoryError {
            throw error
        } catch {
            throw IOSVoiceStateRepositoryError.malformedData
        }
        guard Set(object.keys) == rootKeys else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        let version = try integer(object["schemaVersion"])
        guard (1...schemaVersion).contains(version) else {
            throw IOSVoiceStateRepositoryError.unsupportedSchemaVersion
        }
        let captureValidationKeys: Set<String> = switch version {
        case 1: captureV1Keys
        case 2...4: captureV2Keys
        default: captureKeys
        }
        try validateOptionalObject(
            object["capture"],
            keys: captureValidationKeys
        )
        let pendingValidationKeys: Set<String> = switch version {
        case 1: pendingV1Keys
        case 2: pendingV2Keys
        case 3: pendingV3Keys
        default: pendingKeys
        }
        try validateOptionalObject(
            object["pending"],
            keys: pendingValidationKeys,
            nested: { pending in
                try validateOptionalObject(
                    pending["status"],
                    keys: statusKeys,
                    nested: { status in
                        try validateOptionalObject(
                            status["accepted"],
                            keys: resultKeys
                        )
                    }
                )
            }
        )
        try validateOptionalObject(object["latest"], keys: resultKeys)

        let decoder = JSONDecoder()
        let wire: RecordWire
        do {
            wire = try decoder.decode(RecordWire.self, from: data)
        } catch {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        guard (1...schemaVersion).contains(wire.schemaVersion) else {
            throw IOSVoiceStateRepositoryError.unsupportedSchemaVersion
        }
        do {
            let snapshot = IOSVoiceStateSnapshot(
                capture: try wire.capture?.value(
                    schemaVersion: wire.schemaVersion
                ),
                pending: try wire.pending?.value(
                    schemaVersion: wire.schemaVersion
                ),
                latest: try wire.latest?.latestValue()
            )
            guard snapshot.capture == nil || snapshot.pending == nil else {
                throw IOSVoiceStateRepositoryError.invalidRecord
            }
            return snapshot
        } catch let error as IOSVoiceStateRepositoryError {
            throw error
        } catch {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
    }

    private static func validateOptionalObject(
        _ value: Any?,
        keys: Set<String>,
        nested: (([String: Any]) throws -> Void)? = nil
    ) throws {
        guard let value, !(value is NSNull) else { return }
        guard let object = value as? [String: Any],
              Set(object.keys) == keys else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        try nested?(object)
    }

    private static func integer(_ value: Any?) throws -> Int {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !["f", "d"].contains(String(cString: number.objCType)),
              let integer = Int(number.stringValue) else {
            throw IOSVoiceStateRepositoryError.invalidRecord
        }
        return integer
    }

}
