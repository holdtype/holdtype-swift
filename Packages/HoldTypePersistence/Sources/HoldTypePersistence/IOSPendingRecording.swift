import Foundation
import HoldTypeDomain

public enum IOSPendingRecordingAudioFormat: CaseIterable, Equatable, Sendable {
    case m4a
    case wav

    var fileExtension: String {
        switch self {
        case .m4a:
            "m4a"
        case .wav:
            "wav"
        }
    }

    init?(sourceURL: URL) {
        switch sourceURL.pathExtension {
        case "m4a":
            self = .m4a
        case "wav":
            self = .wav
        default:
            return nil
        }
    }
}

public enum IOSPendingRecordingPhase: Equatable, Sendable {
    case readyForTranscription
    case awaitingRecovery
    case transcribing
    case postProcessing
    case outputDelivery

    var requiresTranscriptionID: Bool {
        switch self {
        case .readyForTranscription, .awaitingRecovery:
            false
        case .transcribing, .postProcessing, .outputDelivery:
            true
        }
    }
}

public enum IOSPendingRecordingInitialState: Equatable, Sendable {
    case readyForTranscription
    case awaitingRecovery

    var phase: IOSPendingRecordingPhase {
        switch self {
        case .readyForTranscription:
            .readyForTranscription
        case .awaitingRecovery:
            .awaitingRecovery
        }
    }
}

public struct IOSPendingRecordingPreparation: Equatable, Sendable {
    public let attemptID: UUID
    public let sourceArtifact: AudioRecordingArtifact
    public let initialState: IOSPendingRecordingInitialState
    public let outputIntent: DictationOutputIntent
    public let audioFormat: IOSPendingRecordingAudioFormat
    public let transcriptionModel: String
    public let transcriptionLanguageCode: String?
    public let durationMilliseconds: Int64
    public let byteCount: Int64

    public init(
        attemptID: UUID,
        sourceArtifact: AudioRecordingArtifact,
        initialState: IOSPendingRecordingInitialState,
        outputIntent: DictationOutputIntent,
        transcriptionConfiguration: TranscriptionConfiguration
    ) throws {
        guard !transcriptionConfiguration.customLanguageCodeValidation.isInvalid else {
            throw IOSPendingRecordingError.invalidTranscriptionConfiguration
        }
        guard sourceArtifact.fileURL.isFileURL,
              !sourceArtifact.fileURL.path.isEmpty,
              !sourceArtifact.fileURL.path.utf8.contains(0),
              let audioFormat = IOSPendingRecordingAudioFormat(
            sourceURL: sourceArtifact.fileURL
        ) else {
            throw IOSPendingRecordingError.invalidSourceArtifact
        }
        let durationMilliseconds = try IOSPendingRecordingValidation
            .durationMilliseconds(from: sourceArtifact.duration)
        let model = transcriptionConfiguration.resolvedModel
        let languageCode = transcriptionConfiguration.resolvedLanguageCode
        guard IOSPendingRecordingValidation.isValidModel(model),
              IOSPendingRecordingValidation.isValidLanguageCode(languageCode),
              IOSPendingRecordingValidation.isValidByteCount(
                  sourceArtifact.byteCount
              ) else {
            throw IOSPendingRecordingError.invalidSourceArtifact
        }

        self.attemptID = attemptID
        self.sourceArtifact = sourceArtifact
        self.initialState = initialState
        self.outputIntent = outputIntent
        self.audioFormat = audioFormat
        self.transcriptionModel = model
        self.transcriptionLanguageCode = languageCode
        self.durationMilliseconds = durationMilliseconds
        self.byteCount = sourceArtifact.byteCount
    }
}

extension IOSPendingRecordingPreparation: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSPendingRecordingPreparation(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { IOSPendingRecordingRedaction.mirror(of: self) }
}

public struct IOSPendingRecording: Equatable, Sendable {
    public let attemptID: UUID
    public let audioRelativeIdentifier: String
    public let createdAt: Date
    public let updatedAt: Date
    public let phase: IOSPendingRecordingPhase
    public let outputIntent: DictationOutputIntent
    public let transcriptionID: UUID?
    public let transcriptionModel: String
    public let transcriptionLanguageCode: String?
    public let durationMilliseconds: Int64
    public let byteCount: Int64

    init(
        attemptID: UUID,
        audioRelativeIdentifier: String,
        createdAt: Date,
        updatedAt: Date,
        phase: IOSPendingRecordingPhase,
        outputIntent: DictationOutputIntent,
        transcriptionID: UUID?,
        transcriptionModel: String,
        transcriptionLanguageCode: String?,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) throws {
        guard createdAt.timeIntervalSinceReferenceDate.isFinite,
              updatedAt.timeIntervalSinceReferenceDate.isFinite,
              updatedAt >= createdAt,
              phase.requiresTranscriptionID == (transcriptionID != nil),
              IOSPendingRecordingValidation.isValidModel(transcriptionModel),
              IOSPendingRecordingValidation.isValidLanguageCode(
                  transcriptionLanguageCode
              ),
              IOSPendingRecordingValidation.isValidDurationMilliseconds(
                  durationMilliseconds
              ),
              IOSPendingRecordingValidation.isValidByteCount(byteCount),
              let parsed = IOSPendingRecordingStorageLocation
                  .parseRelativeAudioIdentifier(audioRelativeIdentifier),
              parsed.attemptID == attemptID else {
            throw IOSPendingRecordingError.invalidJournal
        }

        self.attemptID = attemptID
        self.audioRelativeIdentifier = audioRelativeIdentifier
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.phase = phase
        self.outputIntent = outputIntent
        self.transcriptionID = transcriptionID
        self.transcriptionModel = transcriptionModel
        self.transcriptionLanguageCode = transcriptionLanguageCode
        self.durationMilliseconds = durationMilliseconds
        self.byteCount = byteCount
    }

    var audioFormat: IOSPendingRecordingAudioFormat {
        // Construction validates this exact grammar.
        audioRelativeIdentifier.hasSuffix(".m4a") ? .m4a : .wav
    }
}

extension IOSPendingRecording: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSPendingRecording(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { IOSPendingRecordingRedaction.mirror(of: self) }
}

public struct IOSPendingRecordingCASExpectation: Equatable, Sendable {
    public let attemptID: UUID
    public let phase: IOSPendingRecordingPhase
    public let transcriptionID: UUID?

    public init(recording: IOSPendingRecording) {
        attemptID = recording.attemptID
        phase = recording.phase
        transcriptionID = recording.transcriptionID
    }
}

extension IOSPendingRecordingCASExpectation: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSPendingRecordingCASExpectation(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { IOSPendingRecordingRedaction.mirror(of: self) }
}

public enum IOSPendingRecordingAvailability: Equatable, Sendable {
    case available
    case temporarilyUnavailable
    case missing
    case invalid
}

public struct IOSPendingRecordingObservation: Equatable, Sendable {
    public let recording: IOSPendingRecording
    public let availability: IOSPendingRecordingAvailability

    init(
        recording: IOSPendingRecording,
        availability: IOSPendingRecordingAvailability
    ) {
        self.recording = recording
        self.availability = availability
    }

    public var expectation: IOSPendingRecordingCASExpectation {
        IOSPendingRecordingCASExpectation(recording: recording)
    }
}

public enum IOSPendingRecordingDiscardResult: Equatable, Sendable {
    case discarded
    case alreadyAbsent
}

extension IOSPendingRecordingObservation: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSPendingRecordingObservation(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { IOSPendingRecordingRedaction.mirror(of: self) }
}

public struct IOSPendingTranscriptionDispatch: Equatable, Sendable {
    public let recording: IOSPendingRecording
    public let audioArtifact: AudioRecordingArtifact

    init(
        recording: IOSPendingRecording,
        audioArtifact: AudioRecordingArtifact
    ) {
        self.recording = recording
        self.audioArtifact = audioArtifact
    }
}

extension IOSPendingTranscriptionDispatch: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSPendingTranscriptionDispatch(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { IOSPendingRecordingRedaction.mirror(of: self) }
}

/// One process-local dispatch authorization. It cannot be reconstructed from disk.
public final class IOSPendingTranscriptionHandoff: @unchecked Sendable {
    private let lock = NSLock()
    private var pendingDispatch: IOSPendingTranscriptionDispatch?

    init(dispatch: IOSPendingTranscriptionDispatch) {
        pendingDispatch = dispatch
    }

    public func consume() -> IOSPendingTranscriptionDispatch? {
        lock.withLock {
            defer { pendingDispatch = nil }
            return pendingDispatch
        }
    }
}

extension IOSPendingTranscriptionHandoff: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSPendingTranscriptionHandoff(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { IOSPendingRecordingRedaction.mirror(of: self) }
}

public enum IOSPendingRecordingError: Error, Equatable, Sendable {
    case cancelledBeforeOperation
    case reentrantOperation
    case pendingSlotOccupied
    case orphanedAudio
    case journalUnreadable
    case journalTooLarge
    case journalMalformed
    case unsupportedJournalVersion
    case invalidJournal
    case invalidSourceArtifact
    case invalidTranscriptionConfiguration
    case sourceUnavailable
    case sourceChanged
    case protectedAudioConflict
    case audioPublicationFailed
    case audioPublicationTimedOut
    case mediaValidationFailed
    case mediaValidationTimedOut
    case dataProtectionUnavailable
    case linkedAudioMissing
    case linkedAudioInvalid
    case journalWriteFailed
    case audioRemoveFailed
    case journalRemoveFailed
    case compareAndSwapFailed
    case invalidTransition
    case dispatchAlreadyCommitted
}

extension IOSPendingRecordingError: CustomStringConvertible,
    CustomDebugStringConvertible, CustomReflectable {
    public var description: String { "IOSPendingRecordingError(redacted)" }
    public var debugDescription: String { description }
    public var customMirror: Mirror { IOSPendingRecordingRedaction.mirror(of: self) }
}

enum IOSPendingRecordingValidation {
    static let maximumAudioByteCountExclusive: Int64 = 25_000_000
    static let maximumDurationMillisecondsExclusive: Int64 = 300_000

    static func durationMilliseconds(from duration: TimeInterval) throws -> Int64 {
        guard duration.isFinite,
              duration > 0,
              duration < TimeInterval(maximumDurationMillisecondsExclusive) / 1_000 else {
            throw IOSPendingRecordingError.invalidSourceArtifact
        }
        let milliseconds = duration * 1_000
        guard milliseconds.isFinite,
              milliseconds >= TimeInterval(Int64.min),
              milliseconds <= TimeInterval(Int64.max) else {
            throw IOSPendingRecordingError.invalidSourceArtifact
        }
        let rounded = Int64(milliseconds.rounded(.toNearestOrAwayFromZero))
        guard isValidDurationMilliseconds(rounded) else {
            throw IOSPendingRecordingError.invalidSourceArtifact
        }
        return rounded
    }

    static func isValidDurationMilliseconds(_ value: Int64) -> Bool {
        value > 0 && value < maximumDurationMillisecondsExclusive
    }

    static func isValidByteCount(_ value: Int64) -> Bool {
        value > 0 && value < maximumAudioByteCountExclusive
    }

    static func isValidModel(_ value: String) -> Bool {
        !value.isEmpty && value == value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func isValidLanguageCode(_ value: String?) -> Bool {
        guard let value else {
            return true
        }
        guard value.count == 2 || value.count == 3 else {
            return false
        }
        return value.unicodeScalars.allSatisfy { scalar in
            scalar.isASCII && (97...122).contains(scalar.value)
        }
    }
}

private enum IOSPendingRecordingRedaction {
    static func mirror(of value: Any) -> Mirror {
        Mirror(value, children: ["state": "redacted"])
    }
}
