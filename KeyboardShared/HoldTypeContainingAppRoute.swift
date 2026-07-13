import Foundation

/// Public routes that the keyboard may request without sharing app-owned data.
nonisolated enum HoldTypeContainingAppRoute: String, Equatable, Sendable {
    case history

    static let scheme = "holdtype"

    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = rawValue
        return components.url
    }

    init?(url: URL) {
        guard url.scheme?.lowercased() == Self.scheme,
              let host = url.host?.lowercased(),
              let route = Self(rawValue: host),
              url.user == nil,
              url.password == nil,
              url.port == nil,
              url.path.isEmpty,
              url.query == nil,
              url.fragment == nil else {
            return nil
        }
        self = route
    }
}
