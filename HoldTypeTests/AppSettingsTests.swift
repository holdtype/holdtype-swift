//
//  AppSettingsTests.swift
//  HoldTypeTests
//
//  Created by Codex on 6/20/26.
//

import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct AppSettingsTests {

    @Test func defaultsMatchMVPContracts() {
        let settings = AppSettings.defaults

        #expect(settings.transcriptionModel == "gpt-4o-transcribe")
        #expect(settings.transcriptionConfiguration == .defaults)
        #expect(settings.resolvedTranscriptionModel == "gpt-4o-transcribe")
        #expect(settings.language == .automatic)
        #expect(settings.resolvedLanguageCode == nil)
        #expect(settings.customLanguageCode.isEmpty)
        #expect(settings.customDictionary.isEmpty)
        #expect(settings.resolvedCustomDictionary == .empty)
        #expect(settings.resolvedCustomDictionaryEntries.isEmpty)
        #expect(settings.resolvedCustomDictionary.promptText == nil)
        #expect(settings.emojiCommandsEnabled)
        #expect(settings.enabledEmojiCommandSetIDs == ["en"])
        #expect(settings.emojiCommandsConfiguration == .defaults)
        #expect(settings.customEmojiCommands.isEmpty)
        #expect(settings.resolvedPrompt?.contains("Emoji command vocabulary") == true)
        #expect(settings.useActiveTextContext == false)
        #expect(settings.textCorrectionEnabled == false)
        #expect(settings.textCorrectionModelPreset == .quality)
        #expect(settings.customTextCorrectionModel.isEmpty)
        #expect(settings.textCorrectionConfiguration == .defaults)
        #expect(settings.resolvedTextCorrectionModel == "gpt-5.5")
        #expect(settings.textCorrectionPrompt == AppSettings.defaultTextCorrectionPrompt)
        #expect(
            settings.textCorrectionConfiguration.resolvedPrompt
                == AppSettings.defaultTextCorrectionPrompt
        )
        #expect(settings.isTextCorrectionPromptDefault)
        #expect(settings.localTextCleanupEnabled)
        #expect(settings.textReplacementRules.isEmpty)
        #expect(settings.transcriptPostProcessingConfiguration == TranscriptPostProcessingConfiguration())
        #expect(settings.translationShortcutEnabled)
        #expect(settings.translationSourceMode == .sameAsTranscription)
        #expect(settings.translationSourceLanguage == .automatic)
        #expect(settings.translationConfiguration == .defaults)
        #expect(settings.resolvedTranslationSourceLanguageCode == nil)
        #expect(settings.isTranslationSourceConfigurationValid)
        #expect(settings.translationTargetLanguage == .automatic)
        #expect(settings.resolvedTranslationTargetLanguageCode == nil)
        #expect(settings.translationModel == AppSettings.defaultTranslationModel)
        #expect(settings.translationConfiguration.resolvedModel == "gpt-5.4-mini")
        #expect(settings.translationPrompt == AppSettings.defaultTranslationPrompt)
        #expect(
            settings.translationConfiguration.resolvedPrompt
                == AppSettings.defaultTranslationPrompt
        )
        #expect(settings.isTranslationPromptDefault)
        #expect(settings.translationConfigurationIssue == .missingTargetLanguage)
        #expect(settings.canRunTranslation == false)
        #expect(settings.automaticallyInsertTranscripts)
        #expect(settings.saveTranscriptsToAppClipboard)
        #expect(settings.outputDeliveryPreferences == .defaults)
        #expect(settings.soundEnabled)
        #expect(settings.showFloatingIndicator)
        #expect(settings.recordingStopTailDuration == .off)
        #expect(settings.recordingStopTailDuration.duration == 0)
        #expect(settings.recordingDurationLimit == .default)
        #expect(settings.recordingDurationLimit.minutes == 5)
        #expect(settings.saveTranscriptHistory)
        #expect(settings.recordingCachePolicy == .deleteImmediately)
        #expect(settings.recordingCachePolicy.keepsRecordings == false)
        #expect(settings.retentionConfiguration == .defaults)
    }

    @Test func resolvesTextCorrectionModelAndRules() {
        var settings = AppSettings.defaults

        #expect(settings.resolvedTextCorrectionModel == "gpt-5.5")

        settings.textCorrectionModelPreset = .balanced
        #expect(settings.resolvedTextCorrectionModel == "gpt-5.4")

        settings.textCorrectionModelPreset = .fast
        #expect(settings.resolvedTextCorrectionModel == "gpt-5.4-mini")

        settings.textCorrectionModelPreset = .custom
        settings.customTextCorrectionModel = "  custom-correction-model  "
        settings.textCorrectionPrompt = "  Fix only punctuation.  "
        settings.textReplacementRules = [
            TextReplacementRule(search: "AI-looking", replacement: "plain", isEnabled: true),
            TextReplacementRule(search: "ignored", replacement: "value", isEnabled: false),
            TextReplacementRule(search: "  ", replacement: "empty search", isEnabled: true),
        ]

        #expect(settings.resolvedTextCorrectionModel == "custom-correction-model")
        #expect(settings.textCorrectionConfiguration.resolvedPrompt == "Fix only punctuation.")
        #expect(
            settings.transcriptPostProcessingConfiguration.textReplacementRules ==
                settings.textReplacementRules
        )

        settings.customTextCorrectionModel = "  "
        settings.textCorrectionPrompt = "  "

        #expect(settings.resolvedTextCorrectionModel == TextCorrectionConfiguration.defaultModel)
        #expect(
            settings.textCorrectionConfiguration.resolvedPrompt
                == AppSettings.defaultTextCorrectionPrompt
        )
    }

    @Test func projectsRawTextCorrectionConfigurationWithoutOwningPersistence() {
        var settings = AppSettings.defaults
        settings.textCorrectionEnabled = true
        settings.textCorrectionModelPreset = .custom
        settings.customTextCorrectionModel = "  custom-correction-model  "
        settings.textCorrectionPrompt = "  Correct names only.  "

        let configuration = settings.textCorrectionConfiguration

        #expect(configuration.isEnabled)
        #expect(configuration.modelPreset == .custom)
        #expect(configuration.customModel == "  custom-correction-model  ")
        #expect(configuration.prompt == "  Correct names only.  ")
        #expect(settings.resolvedTextCorrectionModel == configuration.resolvedModel)
        #expect(settings.isTextCorrectionPromptDefault == configuration.isPromptDefault)
    }

    @Test func resolvesEmojiCommandPromptFromActiveSet() {
        var settings = AppSettings.defaults

        #expect(settings.emojiCommandsConfiguration.enabledBuiltInSets.map(\.id) == ["en"])
        #expect(settings.emojiCommandsConfiguration.promptText?.contains("emoji smile") == true)
        #expect(
            settings.emojiCommandsConfiguration.promptText?
                .contains("эмодзи улыбка") == false
        )

        settings.enabledEmojiCommandSetIDs = ["ru", "missing", "en", "ru", "de"]
        settings.customEmojiCommands = [
            CustomEmojiCommand(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000321")!,
                emoji: "🚀",
                command: "emoji rocket",
                aliases: ["launch emoji"]
            )
        ]

        #expect(settings.emojiCommandsConfiguration.enabledBuiltInSets.map(\.id) == ["ru"])
        #expect(
            settings.emojiCommandsConfiguration.enabledCustomCommands
                .map(\.displayCommand) == ["emoji rocket"]
        )
        #expect(settings.emojiCommandsConfiguration.promptText?.contains("emoji smile") == false)
        #expect(
            settings.emojiCommandsConfiguration.promptText?
                .contains("эмодзи улыбка") == true
        )
        #expect(
            settings.emojiCommandsConfiguration.promptText?
                .contains("эмодзи смех") == true
        )
        #expect(settings.emojiCommandsConfiguration.promptText?.contains("эмоции") == false)
        #expect(settings.emojiCommandsConfiguration.promptText?.contains("эмоджи") == false)
        #expect(settings.emojiCommandsConfiguration.promptText?.contains("emoji lächeln") == false)
        #expect(settings.emojiCommandsConfiguration.promptText?.contains("emoji rocket") == true)
        #expect(settings.emojiCommandsConfiguration.promptText?.contains("launch emoji") == true)

        settings.emojiCommandsEnabled = false

        #expect(settings.emojiCommandsConfiguration.enabledBuiltInSets.isEmpty)
        #expect(settings.emojiCommandsConfiguration.enabledCustomCommands.isEmpty)
        #expect(settings.emojiCommandsConfiguration.promptText == nil)
    }

    @Test func projectsRawEmojiConfigurationAndDelegatesResolvedValues() {
        var settings = AppSettings.defaults
        settings.emojiCommandsEnabled = true
        settings.enabledEmojiCommandSetIDs = ["missing", " ru ", "en"]
        settings.customEmojiCommands = [
            CustomEmojiCommand(emoji: " 🚀 ", command: " Emoji   Rocket ")
        ]

        let configuration = settings.emojiCommandsConfiguration

        #expect(configuration.isEnabled)
        #expect(configuration.enabledBuiltInSetIDs == ["missing", " ru ", "en"])
        #expect(configuration.customCommands == settings.customEmojiCommands)
        #expect(
            AppSettings.normalizedEmojiCommandSetIDs(settings.enabledEmojiCommandSetIDs) ==
                configuration.normalizedEnabledBuiltInSetIDs
        )
        #expect(
            AppSettings.normalizedCustomEmojiCommands(settings.customEmojiCommands) ==
                configuration.normalizedCustomCommands
        )
    }


    @Test func textCorrectionPromptResetRestoresDefaultPrompt() {
        var settings = AppSettings.defaults

        settings.textCorrectionPrompt = "Correct obvious names only."

        #expect(settings.isTextCorrectionPromptDefault == false)
        #expect(
            settings.textCorrectionConfiguration.resolvedPrompt
                == "Correct obvious names only."
        )

        settings.resetTextCorrectionPrompt()

        #expect(settings.textCorrectionPrompt == AppSettings.defaultTextCorrectionPrompt)
        #expect(
            settings.textCorrectionConfiguration.resolvedPrompt
                == AppSettings.defaultTextCorrectionPrompt
        )
        #expect(settings.isTextCorrectionPromptDefault)
    }

    @Test func loadsDefaultsFromEmptyUserDefaults() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)

        #expect(store.load() == .defaults)
    }

    @Test func customDictionaryPersistenceNormalizesArraysWithoutReparsingEntries() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = AppSettingsStore.keyPrefix + "customDictionary"
        defaults.set(
            [" ACME, Inc. ", "Line\nBreak", "acme, inc.", "   "],
            forKey: key
        )
        let store = AppSettingsStore(userDefaults: defaults)

        let settings = store.load()

        #expect(settings.customDictionary == ["ACME, Inc.", "Line\nBreak"])
        #expect(settings.resolvedCustomDictionary.promptText == "ACME, Inc., Line\nBreak")

        store.save(settings)

        #expect(defaults.stringArray(forKey: key) == ["ACME, Inc.", "Line\nBreak"])
    }

    @Test func textReplacementRulesDecodeFrozenLegacyPayloadWithoutMigration() throws {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = AppSettingsStore.keyPrefix + "textReplacementRules"
        let fixture = Data(
            #"""
            [
              {
                "id": "01234567-89AB-CDEF-0123-456789ABCDEF",
                "search": "—",
                "replacement": "-",
                "isEnabled": true
              },
              {
                "id": "FEDCBA98-7654-3210-FEDC-BA9876543210",
                "search": "  ",
                "replacement": "",
                "isEnabled": false
              }
            ]
            """#.utf8
        )
        defaults.set(fixture, forKey: key)
        let store = AppSettingsStore(userDefaults: defaults)

        let settings = store.load()

        #expect(defaults.data(forKey: key) == fixture)
        #expect(settings.textReplacementRules.map(\.search) == ["—", "  "])
        #expect(settings.textReplacementRules.map(\.replacement) == ["-", ""])
        #expect(settings.textReplacementRules.map(\.isEnabled) == [true, false])

        store.save(settings)

        let savedData = try #require(defaults.data(forKey: key))
        #expect(
            try JSONDecoder().decode(
                Array<HoldTypeDomain.TextReplacementRule>.self,
                from: savedData
            ) ==
                settings.textReplacementRules
        )
    }

    @Test func customEmojiCommandsDecodeFrozenLegacyPayloadWithoutMigration() throws {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = AppSettingsStore.keyPrefix + "customEmojiCommands"
        let fixture = Data(
            #"""
            [
              {
                "id": "00000000-0000-0000-0000-000000000321",
                "emoji": "🚀",
                "command": "emoji rocket",
                "aliases": ["launch emoji"],
                "isEnabled": false
              }
            ]
            """#.utf8
        )
        defaults.set(fixture, forKey: key)
        let store = AppSettingsStore(userDefaults: defaults)

        let settings = store.load()

        #expect(defaults.data(forKey: key) == fixture)
        #expect(settings.customEmojiCommands.count == 1)
        #expect(settings.customEmojiCommands.first?.emoji == "🚀")
        #expect(settings.customEmojiCommands.first?.command == "emoji rocket")
        #expect(settings.customEmojiCommands.first?.aliases == ["launch emoji"])
        #expect(settings.customEmojiCommands.first?.isEnabled == false)

        store.save(settings)

        let savedData = try #require(defaults.data(forKey: key))
        #expect(
            try JSONDecoder().decode(
                Array<HoldTypeDomain.CustomEmojiCommand>.self,
                from: savedData
            ) == settings.customEmojiCommands
        )
    }

    @Test func savesAndLoadsOnlyNonSecretSettings() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        let settings = AppSettings(
            transcriptionModel: "custom-model",
            language: .custom,
            customLanguageCode: "de",
            prompt: "Product names",
            customDictionary: ["OpenWhispr", "Synty"],
            emojiCommandsEnabled: false,
            enabledEmojiCommandSetIDs: ["ru"],
            customEmojiCommands: [
                CustomEmojiCommand(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000322")!,
                    emoji: "🚀",
                    command: "emoji rocket",
                    aliases: ["launch emoji"],
                    isEnabled: false
                )
            ],
            useActiveTextContext: true,
            textCorrectionEnabled: true,
            textCorrectionModelPreset: .custom,
            customTextCorrectionModel: "custom-correction-model",
            textCorrectionPrompt: "Correct punctuation only.",
            localTextCleanupEnabled: false,
            textReplacementRules: [
                TextReplacementRule(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000167")!,
                    search: "—",
                    replacement: "-",
                    isEnabled: true
                )
            ],
            translationShortcutEnabled: true,
            translationSourceMode: .override,
            translationSourceLanguage: .custom,
            customTranslationSourceLanguageCode: "es",
            translationTargetLanguage: .japanese,
            customTranslationTargetLanguageCode: "",
            translationModel: "custom-translation-model",
            translationPrompt: "Translate for an engineering audience.",
            automaticallyInsertTranscripts: false,
            saveTranscriptsToAppClipboard: false,
            soundEnabled: false,
            showFloatingIndicator: true,
            recordingStopTailDuration: .seconds1_5,
            recordingDurationLimit: RecordingDurationLimit(minutes: 12),
            saveTranscriptHistory: false,
            recordingCachePolicy: .keepLast(25)
        )

        store.save(settings)

        #expect(store.load() == settings)

        let persistedKeys = Set(
            defaults.dictionaryRepresentation().keys.filter {
                $0.hasPrefix(AppSettingsStore.keyPrefix)
            }
        )
        #expect(persistedKeys == expectedAppSettingsPersistedKeys)
        #expect(persistedKeys.contains { $0.localizedCaseInsensitiveContains("api") } == false)
        #expect(persistedKeys.contains { $0.localizedCaseInsensitiveContains("key") } == false)
    }


    @Test func voiceSessionPreferenceOptionsHaveExpectedLabels() {
        #expect(RecordingStopTailDuration.allCases.map(\.displayName) == [
            "Off",
            "0.5 seconds",
            "1.0 second",
            "1.5 seconds",
            "2.0 seconds",
        ])
        #expect(RecordingDurationLimit.allValues.map(\.displayName).first == "1 minute")
        #expect(RecordingDurationLimit.allValues.map(\.displayName).last == "15 minutes")
    }

    @Test func projectsOutputDeliveryPreferencesWithoutClaimingRuntimeEligibility() {
        var settings = AppSettings.defaults
        settings.automaticallyInsertTranscripts = false
        settings.saveTranscriptsToAppClipboard = true

        #expect(settings.outputDeliveryPreferences == OutputDeliveryPreferences(
            automaticInsertionPreferenceEnabled: false,
            keepLatestResult: true
        ))
    }

    @Test func outputDeliveryPreferencePersistenceKeepsTheLegacyBoolKeys() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        let insertionKey = AppSettingsStore.keyPrefix + "automaticallyInsertTranscripts"
        let latestResultKey = AppSettingsStore.keyPrefix + "saveTranscriptsToAppClipboard"
        let combinations = [
            OutputDeliveryPreferences(
                automaticInsertionPreferenceEnabled: false,
                keepLatestResult: false
            ),
            OutputDeliveryPreferences(
                automaticInsertionPreferenceEnabled: false,
                keepLatestResult: true
            ),
            OutputDeliveryPreferences(
                automaticInsertionPreferenceEnabled: true,
                keepLatestResult: false
            ),
            .defaults,
        ]

        for preferences in combinations {
            var settings = AppSettings.defaults
            settings.automaticallyInsertTranscripts =
                preferences.automaticInsertionPreferenceEnabled
            settings.saveTranscriptsToAppClipboard = preferences.keepLatestResult
            store.save(settings)

            #expect(
                defaults.bool(forKey: insertionKey) ==
                    preferences.automaticInsertionPreferenceEnabled
            )
            #expect(defaults.bool(forKey: latestResultKey) == preferences.keepLatestResult)
            #expect(store.load().outputDeliveryPreferences == preferences)
        }

        defaults.set("not-a-bool", forKey: insertionKey)
        defaults.set(Data([0x01]), forKey: latestResultKey)
        #expect(store.load().outputDeliveryPreferences == .defaults)
        #expect(defaults.string(forKey: insertionKey) == "not-a-bool")
        #expect(defaults.data(forKey: latestResultKey) == Data([0x01]))

        defaults.removeObject(forKey: insertionKey)
        defaults.removeObject(forKey: latestResultKey)
        #expect(store.load().outputDeliveryPreferences == .defaults)
        #expect(defaults.object(forKey: insertionKey) == nil)
        #expect(defaults.object(forKey: latestResultKey) == nil)
    }

    @Test func voiceSessionPreferencePersistenceKeepsLegacyKeysAndRawValues() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        var settings = AppSettings.defaults
        let soundKey = AppSettingsStore.keyPrefix + "soundEnabled"
        let tailKey = AppSettingsStore.keyPrefix + "recordingStopTailDuration"
        let durationLimitKey = AppSettingsStore.keyPrefix
            + "recordingDurationLimitMinutes"

        settings.soundEnabled = false
        settings.recordingDurationLimit = RecordingDurationLimit(minutes: 12)
        for tail in RecordingStopTailDuration.allCases {
            settings.recordingStopTailDuration = tail
            store.save(settings)
            #expect(defaults.bool(forKey: soundKey) == false)
            #expect(defaults.string(forKey: tailKey) == tail.rawValue)
            let loaded = store.load()
            #expect(!loaded.soundEnabled)
            #expect(loaded.recordingStopTailDuration == tail)
            #expect(
                loaded.recordingDurationLimit
                    == RecordingDurationLimit(minutes: 12)
            )
        }
        #expect(defaults.integer(forKey: durationLimitKey) == 12)

        defaults.set("legacyUnknownTail", forKey: tailKey)
        #expect(store.load().recordingStopTailDuration == .off)
        #expect(defaults.string(forKey: tailKey) == "legacyUnknownTail")

        defaults.set("not-a-bool", forKey: soundKey)
        defaults.set(Data([0x01]), forKey: tailKey)
        defaults.set(Data([0x02]), forKey: durationLimitKey)
        let invalidLoaded = store.load()
        #expect(invalidLoaded.soundEnabled)
        #expect(invalidLoaded.recordingStopTailDuration == .off)
        #expect(invalidLoaded.recordingDurationLimit == .default)
        #expect(defaults.string(forKey: soundKey) == "not-a-bool")
        #expect(defaults.data(forKey: tailKey) == Data([0x01]))
        #expect(defaults.data(forKey: durationLimitKey) == Data([0x02]))

        defaults.removeObject(forKey: soundKey)
        defaults.removeObject(forKey: tailKey)
        defaults.removeObject(forKey: durationLimitKey)
        let missingLoaded = store.load()
        #expect(missingLoaded.soundEnabled)
        #expect(missingLoaded.recordingStopTailDuration == .off)
        #expect(missingLoaded.recordingDurationLimit == .default)
        #expect(defaults.object(forKey: soundKey) == nil)
        #expect(defaults.object(forKey: tailKey) == nil)
    }

    @Test func recordingDurationLimitPersistenceDefaultsClampsAndRejectsWrongTypes() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        let key = AppSettingsStore.keyPrefix + "recordingDurationLimitMinutes"

        #expect(store.load().recordingDurationLimit == .default)

        for minutes in [1, 5, 15] {
            var settings = AppSettings.defaults
            settings.recordingDurationLimit = RecordingDurationLimit(minutes: minutes)
            store.save(settings)

            #expect(defaults.integer(forKey: key) == minutes)
            #expect(store.load().recordingDurationLimit.minutes == minutes)
        }

        defaults.set(-100, forKey: key)
        #expect(
            store.load().recordingDurationLimit.minutes
                == RecordingDurationLimit.minimumMinutes
        )

        defaults.set(100, forKey: key)
        #expect(
            store.load().recordingDurationLimit.minutes
                == RecordingDurationLimit.maximumMinutes
        )

        defaults.set("not-an-integer", forKey: key)
        #expect(store.load().recordingDurationLimit == .default)
        #expect(defaults.string(forKey: key) == "not-an-integer")

        defaults.set(Data([0x01]), forKey: key)
        #expect(store.load().recordingDurationLimit == .default)
        #expect(defaults.data(forKey: key) == Data([0x01]))

        defaults.set(true, forKey: key)
        #expect(store.load().recordingDurationLimit == .default)
        #expect(defaults.bool(forKey: key))

        defaults.set(12.0, forKey: key)
        #expect(store.load().recordingDurationLimit == .default)
        #expect(defaults.double(forKey: key) == 12)
    }

    @Test func invalidPersistedLanguageFallsBackToAutomatic() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("unsupported-language", forKey: AppSettingsStore.keyPrefix + "language")

        let settings = AppSettingsStore(userDefaults: defaults).load()

        #expect(settings.language == .automatic)
    }

    @Test func languagePersistenceKeepsRawABIAndUnnormalizedCustomInput() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AppSettingsStore(userDefaults: defaults)
        var settings = AppSettings.defaults
        settings.language = .automatic
        settings.customLanguageCode = " RU "

        store.save(settings)

        #expect(defaults.string(forKey: AppSettingsStore.keyPrefix + "language") == "auto")
        #expect(
            defaults.string(forKey: AppSettingsStore.keyPrefix + "customLanguageCode") ==
                " RU "
        )
        #expect(store.load().customLanguageCode == " RU ")
    }

    @Test func textCorrectionPersistenceKeepsLegacyRawValuesAndLoadFallbacks() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let enabledKey = AppSettingsStore.keyPrefix + "textCorrectionEnabled"
        let presetKey = AppSettingsStore.keyPrefix + "textCorrectionModelPreset"
        let customModelKey = AppSettingsStore.keyPrefix + "customTextCorrectionModel"
        let promptKey = AppSettingsStore.keyPrefix + "textCorrectionPrompt"
        defaults.set("legacy-unknown-preset", forKey: presetKey)
        defaults.set("  raw-custom-model  ", forKey: customModelKey)
        defaults.set("   ", forKey: promptKey)
        let store = AppSettingsStore(userDefaults: defaults)

        var settings = store.load()

        #expect(settings.textCorrectionModelPreset == .quality)
        #expect(settings.customTextCorrectionModel == "  raw-custom-model  ")
        #expect(settings.textCorrectionPrompt == AppSettings.defaultTextCorrectionPrompt)
        #expect(defaults.string(forKey: presetKey) == "legacy-unknown-preset")
        #expect(defaults.string(forKey: promptKey) == "   ")

        settings.textCorrectionEnabled = true
        settings.textCorrectionModelPreset = .fast
        settings.customTextCorrectionModel = "  saved-custom-model  "
        settings.textCorrectionPrompt = "  Keep raw prompt spacing.  "
        store.save(settings)

        #expect(defaults.bool(forKey: enabledKey))
        #expect(defaults.string(forKey: presetKey) == "fast")
        #expect(defaults.string(forKey: customModelKey) == "  saved-custom-model  ")
        #expect(defaults.string(forKey: promptKey) == "  Keep raw prompt spacing.  ")
        #expect(store.load().textCorrectionConfiguration == settings.textCorrectionConfiguration)
    }

}
