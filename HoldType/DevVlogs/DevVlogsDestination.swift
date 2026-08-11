import Foundation

enum DevVlogsDestinationAvailability: Equatable {
    case needsSetup
    case available
    case unavailable(DevVlogsDestinationUnavailableReason)
}

enum DevVlogsDestinationUnavailableReason: Equatable {
    case missing
    case readOnly
    case notDirectory
    case symbolicLink
    case bookmarkUnavailable
    case securityScopeDenied
    case persistedRecordUnreadable
    case inaccessible

    var message: String {
        switch self {
        case .missing:
            return "The selected folder is missing. Reconnect it or choose another folder."
        case .readOnly:
            return "The selected folder is read-only. Choose a writable folder."
        case .notDirectory:
            return "The selected location is no longer a folder. Choose another folder."
        case .symbolicLink:
            return "The selected folder cannot be used because it is a symbolic link."
        case .bookmarkUnavailable:
            return "HoldType could not reopen the saved folder. Reselect it to restore access."
        case .securityScopeDenied:
            return "HoldType no longer has access to the saved folder. Reselect it to restore access."
        case .persistedRecordUnreadable:
            return "The saved destination record could not be read. Choose a folder to replace it."
        case .inaccessible:
            return "The selected folder is unavailable right now. Reconnect it or choose another folder."
        }
    }
}

enum DevVlogsDestinationSelection: Equatable {
    case proposedDefault(path: String)
    case defaultFolder(path: String)
    case custom(displayName: String, pathSnapshot: String)
    case persistedRecordUnavailable
}

struct DevVlogsDestinationStatus: Equatable {
    let selection: DevVlogsDestinationSelection
    let availability: DevVlogsDestinationAvailability

    var isConfigured: Bool {
        if case .proposedDefault = selection {
            return false
        }
        return true
    }

    var isAvailable: Bool {
        availability == .available
    }

    var displayPath: String {
        switch selection {
        case .proposedDefault(let path), .defaultFolder(let path):
            return path
        case .custom(_, let pathSnapshot):
            return pathSnapshot
        case .persistedRecordUnavailable:
            return "Path unavailable"
        }
    }

    var displayName: String {
        switch selection {
        case .proposedDefault:
            return "Default folder"
        case .defaultFolder:
            return "Default folder"
        case .custom(let displayName, _):
            return displayName
        case .persistedRecordUnavailable:
            return "Saved destination"
        }
    }
}

struct DevVlogsBookmarkResolution: Equatable {
    let url: URL
    let isStale: Bool
}

protocol DevVlogsDestinationBookmarkResolving {
    func bookmarkData(for url: URL) throws -> Data
    func resolveBookmarkData(_ data: Data) throws -> DevVlogsBookmarkResolution
    func startAccessingSecurityScopedResource(at url: URL) -> Bool
    func stopAccessingSecurityScopedResource(at url: URL)
}

struct URLDevVlogsDestinationBookmarkResolver: DevVlogsDestinationBookmarkResolving {
    nonisolated init() {}

    func bookmarkData(for url: URL) throws -> Data {
        try url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    func resolveBookmarkData(_ data: Data) throws -> DevVlogsBookmarkResolution {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return DevVlogsBookmarkResolution(url: url, isStale: isStale)
    }

    func startAccessingSecurityScopedResource(at url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessingSecurityScopedResource(at url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

enum DevVlogsDestinationDirectoryState: Equatable {
    case missing
    case directory(isWritable: Bool)
    case symbolicLink
    case notDirectory
    case inaccessible
}

protocol DevVlogsDestinationFileAccessing {
    func directoryState(at url: URL) -> DevVlogsDestinationDirectoryState
    func createDirectory(at url: URL) throws
}

struct FileManagerDevVlogsDestinationFileAccess: DevVlogsDestinationFileAccessing {
    nonisolated init() {}

    func directoryState(at url: URL) -> DevVlogsDestinationDirectoryState {
        guard FileManager.default.fileExists(atPath: url.path) else {
            return .missing
        }

        do {
            let values = try url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey, .isWritableKey])
            if values.isSymbolicLink == true {
                return .symbolicLink
            }
            guard values.isDirectory == true else {
                return .notDirectory
            }
            return .directory(isWritable: values.isWritable == true)
        } catch {
            return .inaccessible
        }
    }

    func createDirectory(at url: URL) throws {
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
    }
}
