import HoldTypeDomain

enum WritingContextMode: String, CaseIterable {
    case off
    case automatic
    case aiTasks

    /// Only a resolved or explicitly selected mode supplies a request hint.
    var profile: TranscriptionWritingContext? {
        self == .aiTasks ? .aiTasks : nil
    }

    func resolved(applicationBundleIdentifier: String?) -> WritingContextMode {
        guard self == .automatic else { return self }
        return applicationBundleIdentifier == "com.openai.codex" ? .aiTasks : .off
    }
}
