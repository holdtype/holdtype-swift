public struct TextCorrectionRequest: Equatable, Sendable {
    public let acceptedTranscript: AcceptedTranscript
    public let correctionConfiguration: TextCorrectionConfiguration
    public let postProcessingConfiguration: TranscriptPostProcessingConfiguration

    public init(
        acceptedTranscript: AcceptedTranscript,
        correctionConfiguration: TextCorrectionConfiguration,
        postProcessingConfiguration: TranscriptPostProcessingConfiguration
    ) {
        self.acceptedTranscript = acceptedTranscript
        self.correctionConfiguration = correctionConfiguration
        self.postProcessingConfiguration = postProcessingConfiguration
    }
}
