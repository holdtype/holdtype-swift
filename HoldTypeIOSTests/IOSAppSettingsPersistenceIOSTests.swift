import Foundation
import HoldTypeDomain
import HoldTypePersistence
import Testing

struct IOSAppSettingsPersistenceIOSTests {
    @Test func publicRepositoryUsesStableLocationAndProtectedBackupEligibleFiles() async throws {
        let containerURL = makeTemporaryDirectoryURL()
        defer { try? FileManager.default.removeItem(at: containerURL) }
        let applicationSupportURL = containerURL.appendingPathComponent(
            "Library/Application Support",
            isDirectory: true
        )
        let expectedFileURL = applicationSupportURL
            .appendingPathComponent("HoldType", isDirectory: true)
            .appendingPathComponent("ios-app-settings.json", isDirectory: false)
        #expect(
            IOSAppSettingsStorageLocation.fileURL(in: applicationSupportURL) ==
                expectedFileURL
        )

        let repository = IOSAppSettingsRepository(
            applicationSupportDirectoryURL: applicationSupportURL
        )
        #expect(try await repository.load() == .defaults)
        #expect(!FileManager.default.fileExists(atPath: expectedFileURL.path))

        let settings = fixtureSettings()
        try await repository.save(settings)
        #expect(try await repository.load() == settings)
        #expect(FileManager.default.fileExists(atPath: expectedFileURL.path))
        #expect(
            try expectedFileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
                .isExcludedFromBackup == false
        )

        let attributes = try FileManager.default.attributesOfItem(
            atPath: expectedFileURL.path
        )
        #if targetEnvironment(simulator)
        if let protection = attributes[.protectionKey] as? FileProtectionType {
            #expect(protection == .complete)
        }
        #else
        #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
        #endif
    }

    private func fixtureSettings() -> IOSAppSettings {
        IOSAppSettings(
            transcriptionConfiguration: TranscriptionConfiguration(
                model: "ios-model",
                language: .german,
                customLanguageCode: "",
                freeformPrompt: "iOS prompt"
            ),
            textCorrectionConfiguration: TextCorrectionConfiguration(
                isEnabled: true,
                modelPreset: .balanced,
                customModel: "",
                prompt: "correct"
            ),
            localTextCleanupEnabled: false,
            translationConfiguration: TranslationConfiguration(
                actionPreferenceEnabled: true,
                sourceMode: .override,
                sourceLanguage: .german,
                targetLanguage: .english,
                model: "translate-model",
                prompt: "translate"
            ),
            voiceSessionPreferences: VoiceSessionPreferences(
                audioCuesEnabled: false,
                recordingStopTailDuration: .seconds1,
                recordingDurationLimit: RecordingDurationLimit(minutes: 15)
            ),
            recordingCachePolicy: .unlimited
        )
    }

    private func makeTemporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-ios-settings-tests-\(UUID().uuidString)",
            isDirectory: true
        )
    }
}
