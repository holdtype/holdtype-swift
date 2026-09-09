import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct WritingContextTests {
    @Test func automaticUsesOnlyExactCodexIdentity() {
        for identifier in [nil, "", "com.apple.mail", "com.openai.codex.helper", "Codex"] {
            #expect(WritingContextMode.automatic.resolved(applicationBundleIdentifier: identifier) == .off)
        }
        #expect(WritingContextMode.automatic.resolved(applicationBundleIdentifier: "com.openai.codex") == .aiTasks)
        #expect(WritingContextMode.off.resolved(applicationBundleIdentifier: "com.openai.codex") == .off)
        #expect(WritingContextMode.aiTasks.resolved(applicationBundleIdentifier: nil) == .aiTasks)
        #expect(WritingContextMode.automatic.profile == nil)
    }

    @Test func recordingSnapshotSurvivesFocusAndPreferenceChangesWithoutSavingResolution() {
        var settings = AppSettings.defaults
        settings.writingContextMode = .automatic
        var identifier = "com.openai.codex"
        var reads = 0
        let captureIdentity = { reads += 1; return Optional(identifier) }
        let first = DictationWritingContextCapture.capture(
            settings, intent: .standard, applicationBundleIdentifier: captureIdentity
        )
        identifier = "com.apple.mail"
        #expect(settings.writingContextMode == .automatic)
        #expect(first.writingContextMode == .aiTasks)
        #expect(reads == 1)

        let second = DictationWritingContextCapture.capture(
            settings, intent: .standard, applicationBundleIdentifier: captureIdentity
        )
        settings.writingContextMode = .off
        #expect(second.writingContextMode == .off)
        #expect(first.writingContextMode == .aiTasks)
        #expect(reads == 2)
    }

    @Test func offForcedAndTranslationDoNotReadApplicationIdentity() {
        for mode in WritingContextMode.allCases {
            var settings = AppSettings.defaults
            settings.writingContextMode = mode
            let translated = DictationWritingContextCapture.capture(
                settings, intent: .translate,
                applicationBundleIdentifier: { Issue.record("Unexpected app read"); return nil }
            )
            #expect(translated.writingContextMode == .off)
            if mode != .automatic {
                let ordinary = DictationWritingContextCapture.capture(
                    settings, intent: .standard,
                    applicationBundleIdentifier: { Issue.record("Unexpected app read"); return nil }
                )
                #expect(ordinary.writingContextMode == mode)
            }
        }
    }

    @Test func preferencePersistsAndInvalidOrMissingValueDefaultsOff() {
        let (defaults, suite) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = AppSettingsStore(userDefaults: defaults)
        #expect(store.load().writingContextMode == .off)
        for mode in WritingContextMode.allCases {
            var settings = AppSettings.defaults
            settings.writingContextMode = mode
            store.save(settings)
            #expect(store.load().writingContextMode == mode)
        }
        defaults.set("future-mode", forKey: AppSettingsStore.keyPrefix + "writingContextMode")
        #expect(store.load().writingContextMode == .off)
    }

    @Test func requestsRequireExplicitCapturedProfileAndDoNotEnableOtherFeatures() throws {
        var settings = AppSettings.defaults
        settings.writingContextMode = .aiTasks
        settings.emojiCommandsEnabled = false
        settings.prompt = "User guidance."
        let url = URL(fileURLWithPath: "/tmp/writing-context-fixture.m4a")
        // Saved retries, Voice Prompt and existing consumers omit the explicit profile.
        let ordinary = try settings.audioTranscriptionRequest(audioFileURL: url, context: nil)
        let profiled = try settings.audioTranscriptionRequest(
            audioFileURL: url, context: nil, writingContext: settings.writingContextMode.profile
        )
        #expect(ordinary.promptComposition.providerPrompt == "User guidance.")
        #expect(profiled.promptComposition.providerPrompt?.contains(
            TranscriptionWritingContext.aiTasks.promptText
        ) == true)
        #expect(settings.prompt == "User guidance.")
        #expect(!settings.useActiveTextContext)
        #expect(!settings.textCorrectionEnabled)
    }
}
