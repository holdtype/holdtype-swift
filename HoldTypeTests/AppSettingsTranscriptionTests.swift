import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

struct AppSettingsTranscriptionTests {
    @Test func resolvesBlankModelAndPromptWithoutMutatingStoredValues() {
        var settings = AppSettings.defaults
        settings.transcriptionModel = "  "
        settings.prompt = "  release names, Swift symbols  "
        settings.customDictionary = [" OpenWhispr ", "openwhispr", "", "Synty"]
        settings.emojiCommandsEnabled = false

        #expect(settings.transcriptionModel == "  ")
        #expect(settings.resolvedTranscriptionModel == AppSettings.defaultTranscriptionModel)
        #expect(settings.resolvedCustomDictionaryEntries == ["OpenWhispr", "Synty"])
        #expect(settings.resolvedCustomDictionary.promptText == "OpenWhispr, Synty")
        #expect(
            settings.resolvedPrompt ==
                """
                release names, Swift symbols

                Custom Dictionary (use these exact spellings when they appear in the text): OpenWhispr, Synty
                """
        )
    }

    @Test func projectsRawTranscriptionConfigurationWithoutOwningPersistence() {
        var settings = AppSettings.defaults
        settings.transcriptionModel = "  custom-transcribe  "
        settings.language = .custom
        settings.customLanguageCode = " RU "
        settings.prompt = "  Prefer HoldType.  "

        let configuration = settings.transcriptionConfiguration

        #expect(configuration.model == "  custom-transcribe  ")
        #expect(configuration.language == .custom)
        #expect(configuration.customLanguageCode == " RU ")
        #expect(configuration.freeformPrompt == "  Prefer HoldType.  ")
        #expect(settings.resolvedTranscriptionModel == configuration.resolvedModel)
        #expect(settings.resolvedLanguageCode == configuration.resolvedLanguageCode)
        #expect(
            settings.customLanguageCodeValidation ==
                configuration.customLanguageCodeValidation
        )
        #expect(settings.resolvedPrompt == configuration.resolvedFreeformPrompt.map { prompt in
            """
            \(prompt)

            \(TranscriptionPromptComposition.emojiCommandsPromptPrefix)\(
                settings.emojiCommandsConfiguration.promptText ?? ""
            )
            """
        })
    }

    @Test func includesActiveTextContextOnlyWhenEnabled() throws {
        var disabledSettings = AppSettings.defaults
        disabledSettings.prompt = "Prefer project vocabulary."
        disabledSettings.emojiCommandsEnabled = false
        disabledSettings.useActiveTextContext = false
        let context = try #require(
            TranscriptionPromptContext("The user is already writing about macOS Accessibility.")
        )

        #expect(disabledSettings.resolvedPrompt(context: context) == "Prefer project vocabulary.")
        #expect(
            disabledSettings.transcriptionPromptComposition(context: context)
                .contextEchoGuardText == nil
        )

        var enabledSettings = disabledSettings
        enabledSettings.useActiveTextContext = true
        enabledSettings.customDictionary = ["HoldType"]

        #expect(
            enabledSettings.resolvedPrompt(context: context) ==
                """
                Prefer project vocabulary.

                Current writing context near the cursor. Use this only for continuity; transcribe only the new speech:
                The user is already writing about macOS Accessibility.

                Custom Dictionary (use these exact spellings when they appear in the text): HoldType
                """
        )
        let composition = enabledSettings.transcriptionPromptComposition(context: context)
        #expect(composition.providerPrompt == enabledSettings.resolvedPrompt(context: context))
        #expect(
            composition.contextEchoGuardText ==
                "The user is already writing about macOS Accessibility."
        )
        #expect(composition.dictionaryEchoGuardText == "HoldType")
    }

    @Test func projectsOneFrozenAudioTranscriptionRequest() throws {
        var settings = AppSettings.defaults
        settings.transcriptionModel = "  custom-transcribe  "
        settings.language = .custom
        settings.customLanguageCode = " PT "
        settings.prompt = "Prefer product vocabulary."
        settings.useActiveTextContext = true
        settings.customDictionary = ["HoldType"]
        let audioFileURL = URL(fileURLWithPath: "/tmp/frozen-request.m4a")
        let context = try #require(TranscriptionPromptContext("Existing sentence."))

        let request = try settings.audioTranscriptionRequest(
            audioFileURL: audioFileURL,
            context: context
        )

        #expect(request.audioFileURL == audioFileURL)
        #expect(request.model == "custom-transcribe")
        #expect(request.languageCode == "pt")
        #expect(
            request.promptComposition ==
                settings.transcriptionPromptComposition(context: context)
        )
    }

    @Test func rejectsInvalidCustomLanguageBeforeProducingAnAudioRequest() {
        var settings = AppSettings.defaults
        settings.language = .custom
        settings.customLanguageCode = "en-US"

        #expect(
            throws: AudioTranscriptionRequest.ValidationError.invalidCustomLanguageCode("en-US")
        ) {
            _ = try settings.audioTranscriptionRequest(
                audioFileURL: URL(fileURLWithPath: "/tmp/invalid-request.m4a"),
                context: nil
            )
        }
    }

    @Test func keepsExactFourPartTranscriptionPromptOrder() throws {
        var settings = AppSettings.defaults
        settings.prompt = "Prefer product vocabulary."
        settings.useActiveTextContext = true
        settings.enabledEmojiCommandSetIDs = []
        settings.customEmojiCommands = [
            CustomEmojiCommand(emoji: "🚀", command: "emoji rocket")
        ]
        settings.customDictionary = ["HoldType"]
        let context = try #require(TranscriptionPromptContext("Existing sentence."))

        #expect(
            settings.resolvedPrompt(context: context) ==
                """
                Prefer product vocabulary.

                Current writing context near the cursor. Use this only for continuity; transcribe only the new speech:
                Existing sentence.

                Emoji command vocabulary (transcribe these spoken phrases exactly when spoken): emoji rocket

                Custom Dictionary (use these exact spellings when they appear in the text): HoldType
                """
        )
        let composition = settings.transcriptionPromptComposition(context: context)
        #expect(composition.providerPrompt == settings.resolvedPrompt(context: context))
        #expect(composition.contextEchoGuardText == "Existing sentence.")
        #expect(composition.dictionaryEchoGuardText == "HoldType")
    }

    @Test func parsesAndAppendsCustomDictionaryEntries() {
        let parsedEntries = AppSettings.parseCustomDictionaryEntries(
            from: " OpenWhispr, Synty\nThe word is HoldType,, "
        )

        #expect(parsedEntries == ["OpenWhispr", "Synty", "The word is HoldType"])
        #expect(
            AppSettings.normalizedCustomDictionary([" OpenWhispr ", "openwhispr", "Synty"]) ==
                CustomDictionary(entries: [" OpenWhispr ", "openwhispr", "Synty"]).entries
        )
        #expect(
            AppSettings.appendingCustomDictionaryEntries(
                from: "openwhispr, Sinead",
                to: ["OpenWhispr"]
            ) == ["OpenWhispr", "Sinead"]
        )
    }

    @Test func validatesCustomLanguageCodeForSettingsAndRequests() {
        var settings = AppSettings.defaults

        #expect(settings.customLanguageCodeValidation == .notRequired)
        settings.language = .custom
        settings.customLanguageCode = "   "

        #expect(settings.customLanguageCodeValidation == .emptyFallsBackToAutomatic)
        #expect(settings.resolvedLanguageCode == nil)

        settings.customLanguageCode = " RU "

        #expect(settings.customLanguageCodeValidation == .valid(normalizedCode: "ru"))
        #expect(settings.resolvedLanguageCode == "ru")

        settings.customLanguageCode = "russian"

        #expect(settings.customLanguageCodeValidation == .invalid)
        #expect(settings.resolvedLanguageCode == nil)

        settings.language = .russian

        #expect(settings.resolvedLanguageCode == "ru")
    }
}
