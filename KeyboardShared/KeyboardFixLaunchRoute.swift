import Foundation

/// Opaque public route used only to wake the containing app for one already
/// published Keyboard Fix request. Source text and action metadata stay in the
/// bounded App Group record.
nonisolated struct KeyboardFixLaunchRoute: Equatable, Sendable {
    static let scheme = "holdtype"
    static let host = "keyboard-fix"

    let requestID: UUID

    init(requestID: UUID) {
        self.requestID = requestID
    }

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
        components.queryItems == nil,
        components.fragment == nil
        else {
            return nil
        }

        let path = components.path.split(separator: "/")
        guard path.count == 1 else {
            return nil
        }
        let rawRequestID = String(path[0])
        guard let requestID = UUID(uuidString: rawRequestID),
              rawRequestID == requestID.uuidString.lowercased()
        else {
            return nil
        }
        self.requestID = requestID
    }

    var url: URL? {
        var components = URLComponents()
        components.scheme = Self.scheme
        components.host = Self.host
        components.path = "/\(requestID.uuidString.lowercased())"
        return components.url
    }
}
