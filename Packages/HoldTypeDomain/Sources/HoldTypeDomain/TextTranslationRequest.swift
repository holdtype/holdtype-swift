public struct TextTranslationRequest: Equatable, Sendable {
    public let acceptedTranscript: AcceptedTranscript
    public let translationConfiguration: TranslationConfiguration
    public let resolvedSourceLanguageCode: String?

    public init(
        acceptedTranscript: AcceptedTranscript,
        translationConfiguration: TranslationConfiguration,
        transcriptionConfiguration: TranscriptionConfiguration
    ) {
        self.acceptedTranscript = acceptedTranscript
        self.translationConfiguration = translationConfiguration
        resolvedSourceLanguageCode = translationConfiguration.resolvedSourceLanguageCode(
            transcriptionConfiguration: transcriptionConfiguration
        )
    }
}
