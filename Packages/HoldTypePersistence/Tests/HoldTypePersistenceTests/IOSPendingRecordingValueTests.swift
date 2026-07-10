import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

struct IOSPendingRecordingValueTests {
    @Test func storageLocationUsesOnlyTheCanonicalAttemptOwnedGrammar() {
        let root = URL(fileURLWithPath: "/Application Support", isDirectory: true)
        let attemptID = UUID(uuidString: "01234567-89AB-CDEF-8123-456789ABCDEF")!
        let relative = IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
            for: attemptID,
            format: .m4a
        )

        #expect(
            relative
                == "Recordings/Pending/recording-v1-01234567-89ab-cdef-8123-456789abcdef.m4a"
        )
        #expect(
            IOSPendingRecordingStorageLocation.journalFileURL(in: root).path
                == "/Application Support/HoldType/ios-pending-recording.json"
        )
        #expect(
            IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier: relative,
                in: root
            )?.path
                == "/Application Support/HoldType/Recordings/Pending/recording-v1-01234567-89ab-cdef-8123-456789abcdef.m4a"
        )

        for invalid in [
            "Recordings/Pending/recording-v1-01234567-89AB-CDEF-8123-456789ABCDEF.m4a",
            "Recordings/Pending/recording-v1-01234567-89ab-cdef-8123-456789abcdef.M4A",
            "Recordings/Pending/../recording-v1-01234567-89ab-cdef-8123-456789abcdef.m4a",
            "/Recordings/Pending/recording-v1-01234567-89ab-cdef-8123-456789abcdef.m4a",
            "Recordings//Pending/recording-v1-01234567-89ab-cdef-8123-456789abcdef.m4a",
            "Recordings/Pending/recording-v1-01234567-89ab-cdef-8123-456789abcdef.mp3",
            "Recordings%2FPending%2Frecording-v1-01234567-89ab-cdef-8123-456789abcdef.m4a",
        ] {
            #expect(
                IOSPendingRecordingStorageLocation.audioFileURL(
                    forRelativeIdentifier: invalid,
                    in: root
                ) == nil
            )
        }
    }

    @Test func preparationCapturesOnlyResolvedCompactConfiguration() throws {
        let attemptID = UUID()
        let source = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/private/source.m4a"),
            duration: 1.2345,
            byteCount: 42
        )
        let preparation = try IOSPendingRecordingPreparation(
            attemptID: attemptID,
            sourceArtifact: source,
            initialState: .readyForTranscription,
            outputIntent: .translate,
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "  ",
                language: .custom,
                customLanguageCode: "SR",
                freeformPrompt: "forbidden durable prompt"
            )
        )

        #expect(preparation.attemptID == attemptID)
        #expect(preparation.audioFormat == .m4a)
        #expect(preparation.transcriptionModel == TranscriptionConfiguration.defaultModel)
        #expect(preparation.transcriptionLanguageCode == "sr")
        #expect(preparation.durationMilliseconds == 1_235)
        #expect(preparation.byteCount == 42)
        #expect(!String(describing: preparation).contains("source.m4a"))
        #expect(!String(reflecting: preparation).contains("forbidden durable prompt"))
    }

    @Test func preparationUsesExactDurationSizeAndFormatBounds() {
        let validDurations: [(TimeInterval, Int64)] = [
            (0.0005, 1),
            (0.001, 1),
            (299.9994, 299_999),
        ]
        for (duration, expectedMilliseconds) in validDurations {
            let preparation = try? IOSPendingRecordingPreparation(
                attemptID: UUID(),
                sourceArtifact: AudioRecordingArtifact(
                    fileURL: URL(fileURLWithPath: "/source.wav"),
                    duration: duration,
                    byteCount: 24_999_999
                ),
                initialState: .awaitingRecovery,
                outputIntent: .standard,
                transcriptionConfiguration: .defaults
            )
            #expect(preparation?.durationMilliseconds == expectedMilliseconds)
        }

        for artifact in [
            AudioRecordingArtifact(
                fileURL: URL(fileURLWithPath: "/source.wav"),
                duration: 0,
                byteCount: 1
            ),
            AudioRecordingArtifact(
                fileURL: URL(fileURLWithPath: "/source.wav"),
                duration: 299.9995,
                byteCount: 1
            ),
            AudioRecordingArtifact(
                fileURL: URL(fileURLWithPath: "/source.wav"),
                duration: 300,
                byteCount: 1
            ),
            AudioRecordingArtifact(
                fileURL: URL(fileURLWithPath: "/source.wav"),
                duration: 1,
                byteCount: 0
            ),
            AudioRecordingArtifact(
                fileURL: URL(fileURLWithPath: "/source.wav"),
                duration: 1,
                byteCount: 25_000_000
            ),
            AudioRecordingArtifact(
                fileURL: URL(fileURLWithPath: "/source.M4A"),
                duration: 1,
                byteCount: 1
            ),
        ] {
            #expect(throws: IOSPendingRecordingError.invalidSourceArtifact) {
                _ = try IOSPendingRecordingPreparation(
                    attemptID: UUID(),
                    sourceArtifact: artifact,
                    initialState: .readyForTranscription,
                    outputIntent: .standard,
                    transcriptionConfiguration: .defaults
                )
            }
        }
    }

    @Test func preparationRejectsInvalidCustomLanguageBeforeStorageWork() {
        #expect(
            throws: IOSPendingRecordingError.invalidTranscriptionConfiguration
        ) {
            _ = try IOSPendingRecordingPreparation(
                attemptID: UUID(),
                sourceArtifact: AudioRecordingArtifact(
                    fileURL: URL(fileURLWithPath: "/source.m4a"),
                    duration: 1,
                    byteCount: 1
                ),
                initialState: .readyForTranscription,
                outputIntent: .standard,
                transcriptionConfiguration: TranscriptionConfiguration(
                    language: .custom,
                    customLanguageCode: "not-a-language"
                )
            )
        }
    }

    @Test func recordRejectsEveryPhaseIdentifierMismatch() throws {
        let attemptID = UUID()
        let relative = IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
            for: attemptID,
            format: .wav
        )
        let date = Date(timeIntervalSinceReferenceDate: 1_000)

        for phase in [
            IOSPendingRecordingPhase.readyForTranscription,
            .awaitingRecovery,
        ] {
            #expect(
                try makeRecording(
                    attemptID: attemptID,
                    relativeIdentifier: relative,
                    date: date,
                    phase: phase,
                    transcriptionID: nil
                ).phase == phase
            )
            #expect(throws: IOSPendingRecordingError.invalidJournal) {
                _ = try makeRecording(
                    attemptID: attemptID,
                    relativeIdentifier: relative,
                    date: date,
                    phase: phase,
                    transcriptionID: UUID()
                )
            }
        }

        for phase in [
            IOSPendingRecordingPhase.transcribing,
            .postProcessing,
            .outputDelivery,
        ] {
            #expect(
                try makeRecording(
                    attemptID: attemptID,
                    relativeIdentifier: relative,
                    date: date,
                    phase: phase,
                    transcriptionID: UUID()
                ).phase == phase
            )
            #expect(throws: IOSPendingRecordingError.invalidJournal) {
                _ = try makeRecording(
                    attemptID: attemptID,
                    relativeIdentifier: relative,
                    date: date,
                    phase: phase,
                    transcriptionID: nil
                )
            }
        }
    }

    @Test func dispatchAuthorizationCanBeConsumedExactlyOnceConcurrently() async throws {
        let recording = try sampleRecording(phase: .transcribing, transcriptionID: UUID())
        let artifact = AudioRecordingArtifact(
            fileURL: URL(fileURLWithPath: "/protected/secret.m4a"),
            duration: 1,
            byteCount: 10
        )
        let handoff = IOSPendingTranscriptionHandoff(
            dispatch: IOSPendingTranscriptionDispatch(
                recording: recording,
                audioArtifact: artifact
            )
        )

        let successfulConsumptionCount = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<32 {
                group.addTask {
                    handoff.consume() != nil
                }
            }
            var count = 0
            for await didConsume in group where didConsume {
                count += 1
            }
            return count
        }

        #expect(successfulConsumptionCount == 1)
        #expect(handoff.consume() == nil)
        #expect(!String(describing: handoff).contains("secret.m4a"))
        #expect(!String(reflecting: recording).contains(recording.audioRelativeIdentifier))
    }

    private func sampleRecording(
        phase: IOSPendingRecordingPhase,
        transcriptionID: UUID?
    ) throws -> IOSPendingRecording {
        let attemptID = UUID()
        return try makeRecording(
            attemptID: attemptID,
            relativeIdentifier: IOSPendingRecordingStorageLocation
                .relativeAudioIdentifier(for: attemptID, format: .m4a),
            date: Date(timeIntervalSinceReferenceDate: 1_000),
            phase: phase,
            transcriptionID: transcriptionID
        )
    }

    private func makeRecording(
        attemptID: UUID,
        relativeIdentifier: String,
        date: Date,
        phase: IOSPendingRecordingPhase,
        transcriptionID: UUID?
    ) throws -> IOSPendingRecording {
        try IOSPendingRecording(
            attemptID: attemptID,
            audioRelativeIdentifier: relativeIdentifier,
            createdAt: date,
            updatedAt: date,
            phase: phase,
            outputIntent: .standard,
            transcriptionID: transcriptionID,
            transcriptionModel: TranscriptionConfiguration.defaultModel,
            transcriptionLanguageCode: nil,
            durationMilliseconds: 1_000,
            byteCount: 10
        )
    }
}
