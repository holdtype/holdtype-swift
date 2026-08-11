import Foundation

nonisolated enum DevVlogsLibraryHealth: String, Equatable {
    case ready
    case missing
    case invalid

    var title: String {
        switch self {
        case .ready: return "Ready"
        case .missing: return "Missing"
        case .invalid: return "Unavailable"
        }
    }
}

nonisolated struct DevVlogsLibraryClip: Identifiable, Equatable {
    let id: String
    let clipID: UUID?
    let createdAt: Date?
    let triggerBundleIdentifier: String?
    let triggerApplicationName: String
    let duration: TimeInterval
    let byteCount: Int64
    let health: DevVlogsLibraryHealth
    let isExcluded: Bool
    let mediaURL: URL?
    let relativeDirectory: String
    let resourceIdentity: DevVlogsClipResourceIdentity?

    var isBuildEligible: Bool {
        health == .ready && clipID != nil && mediaURL != nil && resourceIdentity != nil
    }
}

nonisolated struct DevVlogsLibraryAppGroup: Identifiable, Equatable {
    let id: String
    let displayName: String
    let bundleIdentifier: String?
    let clips: [DevVlogsLibraryClip]

    var duration: TimeInterval {
        clips.reduce(0) { $0 + $1.duration }
    }

    var byteCount: Int64 {
        clips.reduce(0) { $0 + $1.byteCount }
    }
}

nonisolated struct DevVlogsLibraryDay: Identifiable, Equatable {
    let id: String
    let date: Date
    let appGroups: [DevVlogsLibraryAppGroup]

    var clips: [DevVlogsLibraryClip] {
        appGroups.flatMap(\.clips).sorted(by: Self.clipComesBefore)
    }

    var clipCount: Int { clips.count }

    var duration: TimeInterval {
        clips.reduce(0) { $0 + $1.duration }
    }

    var byteCount: Int64 {
        clips.reduce(0) { $0 + $1.byteCount }
    }

    private static func clipComesBefore(
        _ lhs: DevVlogsLibraryClip,
        _ rhs: DevVlogsLibraryClip
    ) -> Bool {
        switch (lhs.createdAt, rhs.createdAt) {
        case let (left?, right?) where left != right:
            return left < right
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        default:
            return lhs.id < rhs.id
        }
    }
}

nonisolated struct DevVlogsLibrarySnapshot: Equatable {
    let days: [DevVlogsLibraryDay]

    static let empty = DevVlogsLibrarySnapshot(days: [])
}

nonisolated enum DevVlogsLibraryError: Error, Equatable, LocalizedError {
    case destinationUnavailable
    case archiveUnreadable
    case clipNotOwned
    case clipBusy
    case sourceMissing
    case sourceInvalid
    case identityChanged
    case exclusionUpdateFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .destinationUnavailable:
            return "The Dev Vlogs destination is unavailable."
        case .archiveUnreadable:
            return "The local Dev Vlogs archive could not be read."
        case .clipNotOwned:
            return "HoldType cannot verify ownership of this clip."
        case .clipBusy:
            return "This clip is currently in use and cannot be deleted."
        case .sourceMissing:
            return "The clip is missing. HoldType did not delete it."
        case .sourceInvalid:
            return "The clip cannot be validated, so HoldType left it unchanged."
        case .identityChanged:
            return "The clip changed after it was loaded, so HoldType left it unchanged."
        case .exclusionUpdateFailed:
            return "The clip preference could not be saved."
        case .deleteFailed:
            return "The clip could not be deleted."
        }
    }
}

nonisolated enum DevVlogsFormatting {
    static func duration(_ value: TimeInterval) -> String {
        let seconds = max(0, Int(value.rounded()))
        let minutes = seconds / 60
        let remainder = seconds % 60
        return minutes > 0 ? "\(minutes)m \(remainder)s" : "\(remainder)s"
    }

    static func byteCount(_ value: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, value), countStyle: .file)
    }
}
