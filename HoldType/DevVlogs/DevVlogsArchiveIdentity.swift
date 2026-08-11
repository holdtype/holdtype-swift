import Darwin
import Foundation

nonisolated enum DevVlogsFileKind: Equatable, Hashable {
    case directory
    case regularFile
}

nonisolated struct DevVlogsFileIdentity: Equatable, Hashable {
    let device: UInt64
    let inode: UInt64
    let linkCount: UInt64
    let size: Int64
    let mode: UInt16
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let statusChangeSeconds: Int64
    let statusChangeNanoseconds: Int64
    let kind: DevVlogsFileKind

    static func capture(
        at url: URL,
        kind: DevVlogsFileKind,
        requireSingleLink: Bool = false
    ) -> DevVlogsFileIdentity? {
        var value = stat()
        guard lstat(url.path, &value) == 0 else { return nil }
        let fileType = value.st_mode & S_IFMT
        let expectedType: mode_t = kind == .directory ? S_IFDIR : S_IFREG
        guard fileType == expectedType,
              !requireSingleLink || value.st_nlink == 1 else {
            return nil
        }
        return DevVlogsFileIdentity(
            device: UInt64(value.st_dev),
            inode: UInt64(value.st_ino),
            linkCount: kind == .directory ? 0 : UInt64(value.st_nlink),
            size: kind == .directory ? 0 : Int64(value.st_size),
            mode: UInt16(value.st_mode),
            modificationSeconds: kind == .directory ? 0 : Int64(value.st_mtimespec.tv_sec),
            modificationNanoseconds: kind == .directory ? 0 : Int64(value.st_mtimespec.tv_nsec),
            statusChangeSeconds: kind == .directory ? 0 : Int64(value.st_ctimespec.tv_sec),
            statusChangeNanoseconds: kind == .directory ? 0 : Int64(value.st_ctimespec.tv_nsec),
            kind: kind
        )
    }

    func matches(
        _ url: URL,
        requireSingleLink: Bool = false
    ) -> Bool {
        Self.capture(at: url, kind: kind, requireSingleLink: requireSingleLink) == self
    }
}

nonisolated struct DevVlogsClipResourceIdentity: Equatable, Hashable {
    let rootURL: URL
    let relativeDirectory: String
    let hierarchy: [DevVlogsFileIdentity]
    let metadataIdentity: DevVlogsFileIdentity
    let mediaIdentity: DevVlogsFileIdentity
    let reviewIdentity: DevVlogsFileIdentity?

    var directoryURL: URL {
        relativeDirectory.split(separator: "/").reduce(rootURL) {
            $0.appendingPathComponent(String($1), isDirectory: true)
        }
    }

    var metadataURL: URL { directoryURL.appendingPathComponent("metadata.json") }
    var mediaURL: URL { directoryURL.appendingPathComponent("clip.mov") }
    var reviewURL: URL { directoryURL.appendingPathComponent("review.json") }

    static func capture(
        rootURL: URL,
        relativeDirectory: String,
        reviewExists: Bool
    ) -> DevVlogsClipResourceIdentity? {
        let root = rootURL.standardizedFileURL
        let components = relativeDirectory.split(separator: "/").map(String.init)
        guard components.count == 6,
              components[2] == "apps",
              components[4] == "clips",
              !components.contains(where: { $0 == "." || $0 == ".." }),
              let rootIdentity = DevVlogsFileIdentity.capture(at: root, kind: .directory) else {
            return nil
        }
        var hierarchy = [rootIdentity]
        var cursor = root
        for component in components {
            cursor.appendPathComponent(component, isDirectory: true)
            guard let identity = DevVlogsFileIdentity.capture(at: cursor, kind: .directory) else {
                return nil
            }
            hierarchy.append(identity)
        }
        let metadataURL = cursor.appendingPathComponent("metadata.json")
        let mediaURL = cursor.appendingPathComponent("clip.mov")
        guard let metadataIdentity = DevVlogsFileIdentity.capture(
            at: metadataURL,
            kind: .regularFile,
            requireSingleLink: true
        ),
            let mediaIdentity = DevVlogsFileIdentity.capture(
                at: mediaURL,
                kind: .regularFile,
                requireSingleLink: true
            ) else {
            return nil
        }
        let reviewURL = cursor.appendingPathComponent("review.json")
        let reviewIdentity: DevVlogsFileIdentity?
        if reviewExists {
            guard let captured = DevVlogsFileIdentity.capture(
                at: reviewURL,
                kind: .regularFile,
                requireSingleLink: true
            ) else {
                return nil
            }
            reviewIdentity = captured
        } else {
            reviewIdentity = nil
        }
        return DevVlogsClipResourceIdentity(
            rootURL: root,
            relativeDirectory: relativeDirectory,
            hierarchy: hierarchy,
            metadataIdentity: metadataIdentity,
            mediaIdentity: mediaIdentity,
            reviewIdentity: reviewIdentity
        )
    }

    func validateHierarchy() -> Bool {
        let components = relativeDirectory.split(separator: "/").map(String.init)
        guard components.count + 1 == hierarchy.count else { return false }
        var cursor = rootURL
        guard hierarchy[0].matches(cursor) else { return false }
        for (index, component) in components.enumerated() {
            cursor.appendPathComponent(component, isDirectory: true)
            guard hierarchy[index + 1].matches(cursor) else { return false }
        }
        return cursor == directoryURL
    }

    func validateSourceAndMetadata() -> Bool {
        validateHierarchy()
            && metadataIdentity.matches(metadataURL, requireSingleLink: true)
            && mediaIdentity.matches(mediaURL, requireSingleLink: true)
    }

    func validateAllExpectedChildren(fileManager: FileManager) -> Bool {
        guard validateSourceAndMetadata() else { return false }
        let expected = reviewIdentity == nil
            ? Set(["clip.mov", "metadata.json"])
            : Set(["clip.mov", "metadata.json", "review.json"])
        guard let children = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: []
        ),
            Set(children.map(\.lastPathComponent)) == expected else {
            return false
        }
        if let reviewIdentity {
            return reviewIdentity.matches(reviewURL, requireSingleLink: true)
        }
        return !fileManager.fileExists(atPath: reviewURL.path)
    }
}

nonisolated struct DevVlogsWorkspaceIdentity: Equatable {
    let rootURL: URL
    let buildID: UUID
    let hierarchyURLs: [URL]
    let hierarchy: [DevVlogsFileIdentity]
    let recipeIdentity: DevVlogsFileIdentity
    let temporaryOutputIdentity: DevVlogsFileIdentity?
    let finalOutputIdentity: DevVlogsFileIdentity?
}
