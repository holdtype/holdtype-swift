import Foundation
import Testing
@testable import HoldType

@MainActor
struct AudioInputPreferenceTests {
    @Test func systemDefaultIsTheInitialAndPersistedFallback() {
        let (defaults, suiteName) = makeUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        #expect(AppSettings.defaults.audioInputPreference == .systemDefault)
        #expect(store.load().audioInputPreference == .systemDefault)

        store.save(.defaults)
        #expect(defaults.string(forKey: preferenceIDKey) == nil)
        #expect(defaults.string(forKey: preferenceNameKey) == nil)
    }

    @Test func concreteMicrophoneIdentityAndNamePersistAcrossReloads() {
        let (defaults, suiteName) = makeUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        var settings = AppSettings.defaults
        settings.audioInputPreference = AudioInputPreference(
            deviceID: "stable-device-id",
            deviceName: "Studio Microphone"
        )
        store.save(settings)

        #expect(
            store.load().audioInputPreference == AudioInputPreference(
                deviceID: "stable-device-id",
                deviceName: "Studio Microphone"
            )
        )

        settings.audioInputPreference = .systemDefault
        store.save(settings)
        #expect(store.load().audioInputPreference == .systemDefault)
        #expect(defaults.string(forKey: preferenceIDKey) == nil)
        #expect(defaults.string(forKey: preferenceNameKey) == nil)
    }

    @Test func deviceListRefreshUsesTheLatestConnectedInputs() {
        let provider = MutableAudioInputDeviceProvider(
            devices: [AudioInputDevice(id: "built-in", name: "Mac Microphone")]
        )
        let model = AudioInputDeviceListModel(provider: provider)
        #expect(model.devices.map(\.id) == ["built-in"])

        provider.devices = [AudioInputDevice(id: "usb", name: "USB Microphone")]
        model.refresh()
        #expect(model.devices.map(\.id) == ["usb"])
    }

    @Test func recorderFactoryReceivesThePinnedPreferenceAtStart() async throws {
        let preference = AudioInputPreference(
            deviceID: "stable-device-id",
            deviceName: "Studio Microphone"
        )
        let factory = PreferenceCapturingRecorderFactory()
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            audioInputPreferenceProvider: { preference },
            recorderFactory: factory,
            makeRecordingFileURL: { temporaryRecordingURL() }
        )
        defer { recorder.cancelRecording() }

        try await recorder.startRecording()

        #expect(factory.inputPreference == preference)
        #expect(recorder.currentStatus == .recording)
    }

    @Test func unavailablePinnedMicrophoneFailsBeforeRecordingBegins() async {
        let expectedError = AudioRecorderServiceError.selectedMicrophoneUnavailable
        let factory = PreferenceCapturingRecorderFactory(error: expectedError)
        let recorder = AVFoundationAudioRecorderService(
            permissionStatusProvider: { .allowed },
            audioInputPreferenceProvider: {
                AudioInputPreference(
                    deviceID: "disconnected-device",
                    deviceName: "Studio Microphone"
                )
            },
            recorderFactory: factory,
            makeRecordingFileURL: { temporaryRecordingURL() }
        )

        do {
            try await recorder.startRecording()
            Issue.record("Expected the disconnected microphone to block recording")
        } catch let error as AudioRecorderServiceError {
            #expect(error == expectedError)
        } catch {
            Issue.record("Expected AudioRecorderServiceError, got \(error)")
        }

        #expect(
            recorder.currentStatus == .failed(
                message: expectedError.errorDescription ?? ""
            )
        )
    }

    @Test func unavailablePinnedMicrophoneRecoveryOpensBehaviorSettings() {
        let reason = FailedTranscriptionReason(
            error: AudioRecorderServiceError.selectedMicrophoneUnavailable
        )

        #expect(reason == .selectedMicrophoneUnavailable)
        #expect(reason.settingsTarget == .behavior)
        #expect(reason.canRetry == false)
        #expect(reason.shouldRecordFailedAttempt == false)
    }

    private var preferenceIDKey: String {
        AppSettingsStore.keyPrefix + "preferredAudioInputDeviceID"
    }

    private var preferenceNameKey: String {
        AppSettingsStore.keyPrefix + "preferredAudioInputDeviceName"
    }

    private func makeUserDefaults() -> (UserDefaults, String) {
        let suiteName = "AudioInputPreferenceTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}

@MainActor
private final class MutableAudioInputDeviceProvider: AudioInputDeviceProviding {
    var devices: [AudioInputDevice]

    init(devices: [AudioInputDevice]) {
        self.devices = devices
    }

    func availableDevices() -> [AudioInputDevice] {
        devices
    }
}

@MainActor
private final class PreferenceCapturingRecorderFactory: AudioRecorderEngineFactory {
    private let engine = PreferenceTestRecorderEngine()
    private let error: AudioRecorderServiceError?
    private(set) var inputPreference: AudioInputPreference?

    init(error: AudioRecorderServiceError? = nil) {
        self.error = error
    }

    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any]
    ) throws -> any AudioRecorderEngine {
        engine
    }

    func makeRecorder(
        outputFileURL: URL,
        settings: [String: Any],
        inputPreference: AudioInputPreference
    ) throws -> any AudioRecorderEngine {
        self.inputPreference = inputPreference
        if let error {
            throw error
        }
        return engine
    }
}

@MainActor
private final class PreferenceTestRecorderEngine: AudioRecorderEngine {
    var currentTime: TimeInterval { 0 }

    func record(forDuration duration: TimeInterval) -> Bool { true }
    func stop() {}
    func deleteRecording() -> Bool { true }
    func setRecordingFinishedHandler(_ handler: ((Bool) -> Void)?) {}
}

private func temporaryRecordingURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("holdtype-audio-input-\(UUID().uuidString).m4a")
}
