//
//  AppSettings.swift
//  HoldType
//
//  Created by Codex on 6/20/26.
//

import CoreFoundation
import Foundation
import HoldTypeDomain

struct AppSettings: Equatable {
    static let defaultTranscriptionModel = TranscriptionConfiguration.defaultModel
    static let defaultTranslationModel = TranslationConfiguration.defaultModel
    static let defaultEnabledEmojiCommandSetIDs =
        EmojiCommandsConfiguration.defaultEnabledBuiltInSetIDs
    static let defaultTextCorrectionPrompt = TextCorrectionConfiguration.defaultPrompt
    static let defaultTranslationPrompt = TranslationConfiguration.defaultPrompt

    static let defaults = AppSettings(
        transcriptionModel: defaultTranscriptionModel,
        language: .automatic,
        customLanguageCode: "",
        prompt: "",
        customDictionary: [],
        emojiCommandsEnabled: true,
        enabledEmojiCommandSetIDs: defaultEnabledEmojiCommandSetIDs,
        customEmojiCommands: [],
        useActiveTextContext: false,
        textCorrectionEnabled: false,
        textCorrectionModelPreset: .quality,
        customTextCorrectionModel: "",
        textCorrectionPrompt: defaultTextCorrectionPrompt,
        localTextCleanupEnabled: true,
        textReplacementRules: [],
        translationShortcutEnabled: true,
        translationSourceMode: .sameAsTranscription,
        translationSourceLanguage: .automatic,
        customTranslationSourceLanguageCode: "",
        translationTargetLanguage: .automatic,
        customTranslationTargetLanguageCode: "",
        translationModel: defaultTranslationModel,
        translationPrompt: defaultTranslationPrompt,
        automaticallyInsertTranscripts:
            OutputDeliveryPreferences.defaults.automaticInsertionPreferenceEnabled,
        saveTranscriptsToAppClipboard:
            OutputDeliveryPreferences.defaults.keepLatestResult,
        soundEnabled: VoiceSessionPreferences.defaults.audioCuesEnabled,
        showFloatingIndicator: true,
        recordingStopTailDuration:
            VoiceSessionPreferences.defaults.recordingStopTailDuration,
        recordingDurationLimit:
            VoiceSessionPreferences.defaults.recordingDurationLimit,
        saveTranscriptHistory: RetentionConfiguration.defaults.historyEnabled,
        recordingCachePolicy: RetentionConfiguration.defaults.recordingCachePolicy
    )

    var transcriptionModel: String
    var language: TranscriptionLanguage
    var customLanguageCode: String
    var prompt: String
    var customDictionary: [String] = []
    var emojiCommandsEnabled: Bool = true
    var enabledEmojiCommandSetIDs: [String] = Self.defaultEnabledEmojiCommandSetIDs
    var customEmojiCommands: [CustomEmojiCommand] = []
    var useActiveTextContext: Bool = false
    var textCorrectionEnabled: Bool = false
    var textCorrectionModelPreset: TextCorrectionModelPreset = .quality
    var customTextCorrectionModel: String = ""
    var textCorrectionPrompt: String = ""
    var localTextCleanupEnabled: Bool = true
    var textReplacementRules: [TextReplacementRule] = []
    var translationShortcutEnabled: Bool = true
    var translationSourceMode: TranslationSourceMode = .sameAsTranscription
    var translationSourceLanguage: TranscriptionLanguage = .automatic
    var customTranslationSourceLanguageCode: String = ""
    var translationTargetLanguage: TranscriptionLanguage = .automatic
    var customTranslationTargetLanguageCode: String = ""
    var translationModel: String = Self.defaultTranslationModel
    var translationPrompt: String = Self.defaultTranslationPrompt
    var automaticallyInsertTranscripts: Bool
    var saveTranscriptsToAppClipboard: Bool
    var soundEnabled: Bool
    var showFloatingIndicator: Bool
    var recordingStopTailDuration: RecordingStopTailDuration = .off
    var recordingDurationLimit: RecordingDurationLimit = .default
    var saveTranscriptHistory: Bool
    var recordingCachePolicy: RecordingCachePolicy = .deleteImmediately

    var transcriptionConfiguration: TranscriptionConfiguration {
        TranscriptionConfiguration(
            model: transcriptionModel,
            language: language,
            customLanguageCode: customLanguageCode,
            freeformPrompt: prompt
        )
    }

    var resolvedTranscriptionModel: String {
        transcriptionConfiguration.resolvedModel
    }

    var textCorrectionConfiguration: TextCorrectionConfiguration {
        TextCorrectionConfiguration(
            isEnabled: textCorrectionEnabled,
            modelPreset: textCorrectionModelPreset,
            customModel: customTextCorrectionModel,
            prompt: textCorrectionPrompt
        )
    }

    var resolvedTextCorrectionModel: String {
        textCorrectionConfiguration.resolvedModel
    }

    var isTextCorrectionPromptDefault: Bool {
        textCorrectionConfiguration.isPromptDefault
    }

    mutating func resetTextCorrectionPrompt() {
        textCorrectionPrompt = Self.defaultTextCorrectionPrompt
    }

    var translationConfiguration: TranslationConfiguration {
        TranslationConfiguration(
            actionPreferenceEnabled: translationShortcutEnabled,
            sourceMode: translationSourceMode,
            sourceLanguage: translationSourceLanguage,
            customSourceLanguageCode: customTranslationSourceLanguageCode,
            targetLanguage: translationTargetLanguage,
            customTargetLanguageCode: customTranslationTargetLanguageCode,
            model: translationModel,
            prompt: translationPrompt
        )
    }

    var isTranslationPromptDefault: Bool {
        translationConfiguration.isPromptDefault
    }

    mutating func resetTranslationPrompt() {
        translationPrompt = Self.defaultTranslationPrompt
    }

    var resolvedTranslationSourceLanguageCode: String? {
        translationConfiguration.resolvedSourceLanguageCode(
            transcriptionConfiguration: transcriptionConfiguration
        )
    }

    var resolvedTranslationTargetLanguageCode: String? {
        translationConfiguration.resolvedTargetLanguageCode
    }

    var canRunTranslation: Bool {
        translationConfiguration.canRunAction
    }

    var translationConfigurationIssue: TranslationConfigurationIssue? {
        translationConfiguration.configurationIssue
    }

    var isTranslationSourceConfigurationValid: Bool {
        translationConfiguration.isSourceConfigurationValid
    }

    var retentionConfiguration: RetentionConfiguration {
        RetentionConfiguration(
            historyEnabled: saveTranscriptHistory,
            recordingCachePolicy: recordingCachePolicy
        )
    }

    var outputDeliveryPreferences: OutputDeliveryPreferences {
        OutputDeliveryPreferences(
            automaticInsertionPreferenceEnabled: automaticallyInsertTranscripts,
            keepLatestResult: saveTranscriptsToAppClipboard
        )
    }

    var transcriptPostProcessingConfiguration: TranscriptPostProcessingConfiguration {
        TranscriptPostProcessingConfiguration(
            localTextCleanupEnabled: localTextCleanupEnabled,
            emojiCommands: emojiCommandsConfiguration,
            textReplacementRules: textReplacementRules
        )
    }

    var resolvedPrompt: String? {
        resolvedPrompt(context: nil)
    }

    func resolvedPrompt(context: TranscriptionPromptContext?) -> String? {
        transcriptionPromptComposition(context: context).providerPrompt
    }

    func transcriptionPromptComposition(
        context: TranscriptionPromptContext?
    ) -> TranscriptionPromptComposition {
        TranscriptionPromptComposition(
            resolvedFreeformPrompt: transcriptionConfiguration.resolvedFreeformPrompt,
            context: useActiveTextContext ? context : nil,
            emojiCommandsConfiguration: emojiCommandsConfiguration,
            customDictionary: resolvedCustomDictionary
        )
    }

    func audioTranscriptionRequest(
        audioFileURL: URL,
        context: TranscriptionPromptContext?
    ) throws -> AudioTranscriptionRequest {
        try AudioTranscriptionRequest(
            audioFileURL: audioFileURL,
            transcriptionConfiguration: transcriptionConfiguration,
            promptComposition: transcriptionPromptComposition(context: context)
        )
    }

    func acceptedTranscriptHistoryRequest(
        acceptedTranscript: AcceptedTranscript,
        audioDuration: TimeInterval?,
        cachedAudioFileURL: URL?
    ) -> AcceptedTranscriptHistoryRequest {
        AcceptedTranscriptHistoryRequest(
            acceptedTranscript: acceptedTranscript,
            transcriptionConfiguration: transcriptionConfiguration,
            retentionConfiguration: retentionConfiguration,
            audioDuration: audioDuration,
            cachedAudioFileURL: cachedAudioFileURL
        )
    }

    var resolvedCustomDictionaryEntries: [String] {
        resolvedCustomDictionary.entries
    }

    var resolvedCustomDictionary: CustomDictionary {
        CustomDictionary(entries: customDictionary)
    }

    var emojiCommandsConfiguration: EmojiCommandsConfiguration {
        EmojiCommandsConfiguration(
            isEnabled: emojiCommandsEnabled,
            enabledBuiltInSetIDs: enabledEmojiCommandSetIDs,
            customCommands: customEmojiCommands
        )
    }

    var resolvedLanguageCode: String? {
        transcriptionConfiguration.resolvedLanguageCode
    }

    var customLanguageCodeValidation: CustomLanguageCodeValidation {
        transcriptionConfiguration.customLanguageCodeValidation
    }

    static func isSupportedCustomLanguageCode(_ code: String) -> Bool {
        TranscriptionLanguage.isWellFormedCustomLanguageCode(code)
    }

    static func parseCustomDictionaryEntries(from text: String) -> [String] {
        CustomDictionary.parseEntries(from: text)
    }

    static func normalizedCustomDictionary(_ entries: [String]) -> [String] {
        CustomDictionary(entries: entries).entries
    }

    static func normalizedEmojiCommandSetIDs(_ ids: [String]) -> [String] {
        EmojiCommandsConfiguration(enabledBuiltInSetIDs: ids)
            .normalizedEnabledBuiltInSetIDs
    }

    static func normalizedCustomEmojiCommands(_ commands: [CustomEmojiCommand]) -> [CustomEmojiCommand] {
        EmojiCommandsConfiguration.normalizedCustomCommands(commands)
    }

    static func appendingCustomDictionaryEntries(from text: String, to entries: [String]) -> [String] {
        CustomDictionary(entries: entries).appendingEntries(from: text).entries
    }
}
