#if DEBUG
import Foundation
import HoldTypeDomain
import HoldTypeOpenAI

/// Explicit, disposable local QA. Both modes stub every provider/output; real
/// mode additionally opts into the normal microphone permission and recorder.
@MainActor
enum DictationStartQAAutomation {
    static var mode: String? {
        let env = ProcessInfo.processInfo.environment
        guard env["HOLDTYPE_AUTOMATION"] == "1",
              ["fake", "real"].contains(env["HOLDTYPE_START_QA"] ?? ""),
              env["HOLDTYPE_START_QA_DIRECTORY"]?.hasPrefix("/tmp/holdtype-responsiveness.") == true
        else { return nil }
        return env["HOLDTYPE_START_QA"]
    }

    static var settings: AppSettings {
        var value = AppSettings.defaults
        value.automaticallyInsertTranscripts = false
        value.useActiveTextContext = false
        value.saveTranscriptHistory = false
        value.saveTranscriptsToAppClipboard = false
        value.textCorrectionEnabled = false
        value.soundEnabled = ProcessInfo.processInfo.environment["HOLDTYPE_START_QA_SOUND"] == "1"
        return value
    }

    static func controller() -> DictationSessionController? {
        guard let mode, let path = ProcessInfo.processInfo.environment["HOLDTYPE_START_QA_DIRECTORY"] else { return nil }
        let root = URL(fileURLWithPath: path)
        let recorder: any AudioRecorderService = mode == "real"
            ? AVFoundationAudioRecorderService(audioInputPreferenceProvider: { settings.audioInputPreference })
            : StartQAFakeRecorder()
        return DictationSessionController(
            recorder: recorder,
            transcriptionService: DevVlogsFinalQATranscriptionService(),
            textCorrectionService: DevVlogsFinalQATextCorrectionService(),
            translationService: DevVlogsFinalQATranslationService(),
            settingsProvider: { settings },
            transcriptOutput: DevVlogsFinalQATranscriptOutput(),
            transcriptHistory: StartQAHistory(),
            transcriptionFailureRecovery: TranscriptionFailureRecoveryStore(directoryURL: root.appendingPathComponent("recovery", isDirectory: true)),
            transcriptionUsageRecorder: StartQAUsage(),
            recordingCache: RecordingCacheService(directoryURL: root.appendingPathComponent("cache", isDirectory: true)),
            recordingCaptureJournal: RecordingCaptureJournal(directoryURL: root.appendingPathComponent("active", isDirectory: true), releasedDirectoryURL: root.appendingPathComponent("cache", isDirectory: true)),
            devVlogsCapture: StartQAVlog(), voiceWorkReservation: VoiceWorkReservation()
        )
    }

    static func preflight() -> RecordingSetupPreflight? {
        guard let mode else { return nil }
        return RecordingSetupPreflight(
            setupStatusProvider: AppSetupStatusProvider(microphonePermissionService: mode == "real"
                ? MicrophonePermissionService() : MicrophonePermissionService(client: StartQAMicrophone())),
            credentialResolver: DevVlogsFinalQACredentialResolver()
        )
    }
}

private struct StartQAMicrophone: MicrophonePermissionClient {
    var hasAvailableAudioInput: Bool { true }
    func authorizationStatus() -> MicrophoneAuthorizationStatus { .allowed }
    func requestAccess(completion: @escaping (Bool) -> Void) { completion(true) }
}

@MainActor
private final class StartQAFakeRecorder: AudioRecorderService {
    var currentStatus: AudioRecorderStatus = .idle
    func startRecording(maximumDuration: TimeInterval) async throws { currentStatus = .recording }
    func stopRecording() async throws -> AudioRecordingArtifact {
        currentStatus = .idle
        throw AudioRecorderServiceError.recordingTooShort(duration: 0, minimumDuration: 1)
    }
    func cancelRecording() { currentStatus = .cancelled }
}
private final class StartQAHistory: TranscriptRecoveryHistoryRecording {
    func recordAcceptedTranscript(_ request: AcceptedTranscriptHistoryRequest) throws {}
}
private final class StartQAUsage: TranscriptionUsageRecording {
    func recordSuccessfulTranscriptionUsage(_ usage: SuccessfulTranscriptionUsage) {}
}
private final class StartQAVlog: DevVlogsCaptureCoordinating {
    var state: DevVlogsCaptureState { .idle }
    func beginAttempt() async {}
    func dictationDidStart() {}
    func finishAttempt(audioArtifact: AudioRecordingArtifact) async {}
    func endAttemptWithoutAudio(reason: DevVlogsCaptureSkipReason) {}
    func featureDidDisable() {}
}
#endif
