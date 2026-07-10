public struct OutputDeliveryRequest: Equatable, Sendable {
    public let acceptedTranscript: AcceptedTranscript
    public let preferences: OutputDeliveryPreferences

    public init(
        acceptedTranscript: AcceptedTranscript,
        preferences: OutputDeliveryPreferences
    ) {
        self.acceptedTranscript = acceptedTranscript
        self.preferences = preferences
    }
}
