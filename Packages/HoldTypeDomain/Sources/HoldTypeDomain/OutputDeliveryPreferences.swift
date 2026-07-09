public struct OutputDeliveryPreferences: Equatable, Sendable {
    public static let defaults = OutputDeliveryPreferences()

    public var automaticInsertionPreferenceEnabled: Bool
    public var keepLatestResult: Bool

    public init(
        automaticInsertionPreferenceEnabled: Bool = true,
        keepLatestResult: Bool = true
    ) {
        self.automaticInsertionPreferenceEnabled = automaticInsertionPreferenceEnabled
        self.keepLatestResult = keepLatestResult
    }
}
