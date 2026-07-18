import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct AppSettingsTranslationTests {
    @Test func resolvesTranslationModelPromptLanguagesAndReset() {
        var settings = AppSettings.defaults

        settings.translationShortcutEnabled = true
        settings.language = .spanish
        settings.translationTargetLanguage = .japanese
        settings.translationModel = "  custom-translation-model  "
        settings.translationPrompt = "  Translate for product UI labels.  "

        #expect(settings.resolvedTranslationSourceLanguageCode == "es")
        #expect(settings.resolvedTranslationTargetLanguageCode == "ja")
        #expect(settings.translationConfiguration.resolvedModel == "custom-translation-model")
        #expect(
            settings.translationConfiguration.resolvedPrompt
                == "Translate for product UI labels."
        )
        #expect(settings.canRunTranslation)
        #expect(settings.isTranslationPromptDefault == false)

        settings.translationModel = "  "
        settings.translationPrompt = "  "

        #expect(
            settings.translationConfiguration.resolvedModel
                == AppSettings.defaultTranslationModel
        )
        #expect(
            settings.translationConfiguration.resolvedPrompt
                == AppSettings.defaultTranslationPrompt
        )

        settings.resetTranslationPrompt()

        #expect(settings.translationPrompt == AppSettings.defaultTranslationPrompt)
        #expect(settings.isTranslationPromptDefault)
    }

    @Test func projectsRawTranslationConfigurationAndDelegatesResolvedValues() {
        var settings = AppSettings.defaults
        settings.translationShortcutEnabled = false
        settings.translationSourceMode = .override
        settings.translationSourceLanguage = .custom
        settings.customTranslationSourceLanguageCode = "  ES  "
        settings.translationTargetLanguage = .custom
        settings.customTranslationTargetLanguageCode = "  ENG  "
        settings.translationModel = "  custom-translation-model  "
        settings.translationPrompt = "  Translate names only.  "

        let configuration = settings.translationConfiguration

        #expect(configuration.actionPreferenceEnabled == false)
        #expect(configuration.sourceMode == .override)
        #expect(configuration.sourceLanguage == .custom)
        #expect(configuration.customSourceLanguageCode == "  ES  ")
        #expect(configuration.targetLanguage == .custom)
        #expect(configuration.customTargetLanguageCode == "  ENG  ")
        #expect(configuration.model == "  custom-translation-model  ")
        #expect(configuration.prompt == "  Translate names only.  ")
        #expect(
            settings.resolvedTranslationSourceLanguageCode ==
                configuration.resolvedSourceLanguageCode(
                    transcriptionConfiguration: settings.transcriptionConfiguration
                )
        )
        #expect(
            settings.resolvedTranslationTargetLanguageCode ==
                configuration.resolvedTargetLanguageCode
        )
        #expect(settings.isTranslationPromptDefault == configuration.isPromptDefault)
        #expect(settings.translationConfigurationIssue == configuration.configurationIssue)
        #expect(settings.canRunTranslation == configuration.canRunAction)
    }

    @Test func explicitDisabledTranslationShortcutOverridesDefault() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(false, forKey: AppSettingsStore.keyPrefix + "translationShortcutEnabled")

        let settings = AppSettingsStore(userDefaults: defaults).load()

        #expect(settings.translationShortcutEnabled == false)
    }

    @Test func legacyRussianToEnglishShortcutSettingMigratesToTranslationShortcut() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AppSettingsStore.keyPrefix + "translateRussianToEnglishShortcutEnabled")
        let store = AppSettingsStore(userDefaults: defaults)

        var settings = store.load()

        #expect(settings.translationShortcutEnabled)
        #expect(settings.translationSourceMode == .override)
        #expect(settings.translationSourceLanguage == .russian)
        #expect(settings.resolvedTranslationSourceLanguageCode == "ru")
        #expect(settings.translationTargetLanguage == .english)
        #expect(settings.resolvedTranslationTargetLanguageCode == "en")
        #expect(settings.canRunTranslation)

        settings.translationShortcutEnabled = false
        store.save(settings)

        #expect(defaults.object(forKey: AppSettingsStore.keyPrefix + "translateRussianToEnglishShortcutEnabled") == nil)
        #expect(defaults.bool(forKey: AppSettingsStore.keyPrefix + "translationShortcutEnabled") == false)
        #expect(
            defaults.string(forKey: AppSettingsStore.keyPrefix + "translationSourceMode")
                == TranslationSourceMode.override.rawValue
        )
    }

    @Test func explicitDisabledTranslationPreferenceKeepsLegacyRouteUntilSave() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let enabledKey = AppSettingsStore.keyPrefix + "translationShortcutEnabled"
        let legacyKey = AppSettingsStore.keyPrefix + "translateRussianToEnglishShortcutEnabled"
        let modeKey = AppSettingsStore.keyPrefix + "translationSourceMode"
        let sourceKey = AppSettingsStore.keyPrefix + "translationSourceLanguage"
        let targetKey = AppSettingsStore.keyPrefix + "translationTargetLanguage"
        defaults.set(false, forKey: enabledKey)
        defaults.set(true, forKey: legacyKey)
        let store = AppSettingsStore(userDefaults: defaults)

        let settings = store.load()

        #expect(settings.translationShortcutEnabled == false)
        #expect(settings.translationSourceMode == .override)
        #expect(settings.translationSourceLanguage == .russian)
        #expect(settings.translationTargetLanguage == .english)
        #expect(settings.translationConfigurationIssue == nil)
        #expect(settings.canRunTranslation == false)
        #expect(defaults.object(forKey: modeKey) == nil)
        #expect(defaults.object(forKey: sourceKey) == nil)
        #expect(defaults.object(forKey: targetKey) == nil)

        store.save(settings)

        #expect(defaults.bool(forKey: enabledKey) == false)
        #expect(defaults.string(forKey: modeKey) == "override")
        #expect(defaults.string(forKey: sourceKey) == "russian")
        #expect(defaults.string(forKey: targetKey) == "english")
        #expect(defaults.object(forKey: legacyKey) == nil)
    }

    @Test func translationPersistenceKeepsRawValuesAndFallbacksWithoutLoadRewrite() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let enabledKey = AppSettingsStore.keyPrefix + "translationShortcutEnabled"
        let legacyKey = AppSettingsStore.keyPrefix + "translateRussianToEnglishShortcutEnabled"
        let modeKey = AppSettingsStore.keyPrefix + "translationSourceMode"
        let sourceKey = AppSettingsStore.keyPrefix + "translationSourceLanguage"
        let customSourceKey = AppSettingsStore.keyPrefix + "customTranslationSourceLanguageCode"
        let targetKey = AppSettingsStore.keyPrefix + "translationTargetLanguage"
        let customTargetKey = AppSettingsStore.keyPrefix + "customTranslationTargetLanguageCode"
        let modelKey = AppSettingsStore.keyPrefix + "translationModel"
        let promptKey = AppSettingsStore.keyPrefix + "translationPrompt"
        defaults.set(false, forKey: enabledKey)
        defaults.set(true, forKey: legacyKey)
        defaults.set("unknown-mode", forKey: modeKey)
        defaults.set("unknown-source", forKey: sourceKey)
        defaults.set("  ES  ", forKey: customSourceKey)
        defaults.set("unknown-target", forKey: targetKey)
        defaults.set("  ENG  ", forKey: customTargetKey)
        defaults.set("  custom-translation-model  ", forKey: modelKey)
        defaults.set("  Keep raw translation prompt.  ", forKey: promptKey)
        let store = AppSettingsStore(userDefaults: defaults)

        var settings = store.load()

        #expect(settings.translationShortcutEnabled == false)
        #expect(settings.translationSourceMode == .sameAsTranscription)
        #expect(settings.translationSourceLanguage == .automatic)
        #expect(settings.translationTargetLanguage == .automatic)
        #expect(settings.customTranslationSourceLanguageCode == "  ES  ")
        #expect(settings.customTranslationTargetLanguageCode == "  ENG  ")
        #expect(settings.translationModel == "  custom-translation-model  ")
        #expect(settings.translationPrompt == "  Keep raw translation prompt.  ")
        #expect(defaults.string(forKey: modeKey) == "unknown-mode")
        #expect(defaults.string(forKey: sourceKey) == "unknown-source")
        #expect(defaults.string(forKey: targetKey) == "unknown-target")

        settings.translationShortcutEnabled = true
        settings.translationSourceMode = .override
        settings.translationSourceLanguage = .custom
        settings.translationTargetLanguage = .custom
        store.save(settings)

        #expect(defaults.bool(forKey: enabledKey))
        #expect(defaults.string(forKey: modeKey) == "override")
        #expect(defaults.string(forKey: sourceKey) == "custom")
        #expect(defaults.string(forKey: customSourceKey) == "  ES  ")
        #expect(defaults.string(forKey: targetKey) == "custom")
        #expect(defaults.string(forKey: customTargetKey) == "  ENG  ")
        #expect(defaults.string(forKey: modelKey) == "  custom-translation-model  ")
        #expect(defaults.string(forKey: promptKey) == "  Keep raw translation prompt.  ")
        #expect(defaults.object(forKey: legacyKey) == nil)
        #expect(store.load().translationConfiguration == settings.translationConfiguration)
    }

    @Test func enabledTranslationSettingsWithoutSourceModePreserveSourceOverride() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set(true, forKey: AppSettingsStore.keyPrefix + "translationShortcutEnabled")
        defaults.set("spanish", forKey: AppSettingsStore.keyPrefix + "translationSourceLanguage")
        defaults.set("english", forKey: AppSettingsStore.keyPrefix + "translationTargetLanguage")

        let settings = AppSettingsStore(userDefaults: defaults).load()

        #expect(settings.translationSourceMode == .override)
        #expect(settings.translationSourceLanguage == .spanish)
        #expect(settings.resolvedTranslationSourceLanguageCode == "es")
        #expect(settings.translationTargetLanguage == .english)
        #expect(settings.canRunTranslation)
    }

    @Test func blankPersistedTranslationPromptLoadsDefaultPrompt() {
        let (defaults, suiteName) = makeIsolatedUserDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }

        defaults.set("   ", forKey: AppSettingsStore.keyPrefix + "translationPrompt")

        let settings = AppSettingsStore(userDefaults: defaults).load()

        #expect(settings.translationPrompt == AppSettings.defaultTranslationPrompt)
        #expect(settings.isTranslationPromptDefault)
    }
}
