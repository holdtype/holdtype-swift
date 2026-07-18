import Foundation

nonisolated struct KeyboardHistoryLaunchRoute: Equatable, Sendable {
    static let scheme = "holdtype"
    static let host = "history"

    init() {}

    init?(url: URL) {
        guard let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ),
        components.scheme == Self.scheme,
        components.host == Self.host,
        components.user == nil,
        components.password == nil,
        components.port == nil,
        components.path.isEmpty,
        components.queryItems == nil,
        components.fragment == nil else {
            return nil
        }
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        return components.url
    }
}
