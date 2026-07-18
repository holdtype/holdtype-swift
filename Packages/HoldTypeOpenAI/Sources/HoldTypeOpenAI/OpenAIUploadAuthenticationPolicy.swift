import Foundation

nonisolated enum OpenAIUploadAuthenticationPolicy {
    enum Decision: Equatable, Sendable {
        case ignoreSupersededTask
        case performDefaultHandling
        case rejectActiveChallenge
    }

    static func decision(
        isActiveTask: Bool,
        authenticationMethod: String
    ) -> Decision {
        guard isActiveTask else {
            return .ignoreSupersededTask
        }
        return authenticationMethod == NSURLAuthenticationMethodServerTrust
            ? .performDefaultHandling
            : .rejectActiveChallenge
    }
}
