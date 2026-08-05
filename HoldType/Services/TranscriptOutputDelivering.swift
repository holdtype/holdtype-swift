protocol TranscriptOutputDelivering {
    func deliver(_ request: OutputDeliveryRequest) async throws -> TextInsertionResult
}

extension TextInsertionService: TranscriptOutputDelivering {}
