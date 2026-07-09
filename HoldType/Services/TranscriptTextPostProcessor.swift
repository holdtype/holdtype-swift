import HoldTypeDomain

typealias TranscriptTextPostProcessor = HoldTypeDomain.TranscriptTextPostProcessor

extension HoldTypeDomain.TranscriptTextPostProcessor {
    func process(_ text: String, settings: AppSettings, fallback: String? = nil) -> String {
        process(
            text,
            configuration: settings.transcriptPostProcessingConfiguration,
            fallback: fallback
        )
    }
}
