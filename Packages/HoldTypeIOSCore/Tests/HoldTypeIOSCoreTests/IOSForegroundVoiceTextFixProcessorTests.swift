import Foundation
import HoldTypeDomain
import HoldTypeOpenAI
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@_spi(HoldTypeIOSCore) @testable import HoldTypeIOSCore

@MainActor
@Suite(.serialized)
struct IOSForegroundVoiceTextFixProcessorTests {
    @Test func typedFixForcesSavedCorrectionWithoutMutatingVoiceState()
        async throws {
        let fixture = try await ProcessorFixture()
        defer { fixture.removeFiles() }
        let calls = TextFixProcessorCallLog()
        let processor = fixture.makeProcessor(
            provider: provider(
                transcribe: { _, _ in
                    calls.record("transcription")
                    return "unexpected"
                },
                correct: { transcript, configuration, _ in
                    calls.record("correction")
                    #expect(configuration.isEnabled)
                    #expect(transcript.text == "Original Draft")
                    return "Improved Draft"
                }
            )
        )

        let result = await processor.processDraftTextFix(
            fixture.fixRequest(action: fixture.fixAction, text: "Original Draft")
        )

        #expect(result == .success("Improved Draft"))
        #expect(calls.events == ["correction"])
        try await fixture.expectVoiceStateUnchanged()
    }

    @Test func typedTranslateUsesTheSavedRouteAndMapsTimeout() async throws {
        var settings = IOSAppSettings.defaults
        settings.translationConfiguration = TranslationConfiguration(
            actionPreferenceEnabled: true,
            targetLanguage: .french
        )
        let fixture = try await ProcessorFixture(settings: settings)
        defer { fixture.removeFiles() }
        let calls = TextFixProcessorCallLog()
        let processor = fixture.makeProcessor(
            provider: provider(
                translate: { request, _ in
                    calls.record("translation")
                    #expect(
                        request.translationConfiguration.targetLanguage
                            == .french
                    )
                    throw OpenAITextTranslationServiceError.timedOut
                }
            )
        )

        let result = await processor.processDraftTextFix(
            fixture.fixRequest(
                action: fixture.translateAction,
                text: "Translate this"
            )
        )

        #expect(result == .failure(.timedOut))
        #expect(calls.events == ["translation"])
        try await fixture.expectVoiceStateUnchanged()
    }

    @Test func customFixProjectsExactSourcePromptModelAndReturnsExactOutput()
        async throws {
        var settings = IOSAppSettings.defaults
        settings.textCorrectionConfiguration.modelPreset = .custom
        settings.textCorrectionConfiguration.customModel = "gpt-custom-fix"
        let fixture = try await ProcessorFixture(settings: settings)
        defer { fixture.removeFiles() }
        let action = try TextFixAction(
            id: "test.expand",
            kind: .customPrompt,
            title: "Expand",
            icon: .expand,
            prompt: "Expand without changing the language.",
            isEnabled: true
        )
        let calls = TextFixProcessorCallLog()
        let exactSource = "  Small source  "
        let exactOutput = "\n  A much longer transformed result.  \n"
        let processor = fixture.makeProcessor(
            provider: provider(
                transform: { request, _ in
                    calls.record("transform")
                    #expect(request.sourceText == exactSource)
                    #expect(request.prompt == action.prompt)
                    #expect(request.model == "gpt-custom-fix")
                    return exactOutput
                }
            )
        )

        let result = await processor.processDraftTextFix(
            fixture.fixRequest(action: action, text: exactSource)
        )

        #expect(result == .success(exactOutput))
        #expect(calls.events == ["transform"])
        try await fixture.expectVoiceStateUnchanged()
    }

    @Test func oversizedOrWhitespaceCustomResultsFailWithoutMutation()
        async throws {
        let fixture = try await ProcessorFixture()
        defer { fixture.removeFiles() }
        let action = try TextFixAction(
            id: "test.custom",
            kind: .customPrompt,
            title: "Custom",
            icon: .custom,
            prompt: "Rewrite.",
            isEnabled: true
        )
        let calls = TextFixProcessorCallLog()
        let oversizedProcessor = fixture.makeProcessor(
            provider: provider(
                transform: { _, _ in
                    calls.record("unexpected")
                    return "unexpected"
                }
            )
        )
        let oversized = String(
            repeating: "x",
            count: TextTransformationRequest.maximumSourceUTF8ByteCount + 1
        )

        #expect(
            await oversizedProcessor.processDraftTextFix(
                fixture.fixRequest(action: action, text: oversized)
            ) == .failure(.sourceTooLarge)
        )
        #expect(calls.events.isEmpty)

        let whitespaceProcessor = fixture.makeProcessor(
            provider: provider(transform: { _, _ in " \n\t " })
        )
        #expect(
            await whitespaceProcessor.processDraftTextFix(
                fixture.fixRequest(action: action, text: "Source")
            ) == .failure(.invalidResponse)
        )
        try await fixture.expectVoiceStateUnchanged()
    }
}

private extension ProcessorFixture {
    var translateAction: TextFixAction {
        TextFixCatalog.defaults.actions[0]
    }

    var fixAction: TextFixAction {
        TextFixCatalog.defaults.actions[1]
    }

    func fixRequest(
        action: TextFixAction,
        text: String
    ) -> IOSVoiceDraftTextFixRequest {
        IOSVoiceDraftTextFixRequest(
            action: action,
            text: text,
            settings: settings,
            credential: credential,
            consentObservation: acceptedConsent
        )
    }

    func expectVoiceStateUnchanged() async throws {
        #expect(try await persistenceOwner.load()?.recording == pending)
        #expect(try await persistenceOwner.loadLatestResult() == .absent)
    }
}

private final class TextFixProcessorCallLog: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [String] = []

    var events: [String] { lock.withLock { storedEvents } }

    func record(_ event: String) {
        lock.withLock { storedEvents.append(event) }
    }
}
