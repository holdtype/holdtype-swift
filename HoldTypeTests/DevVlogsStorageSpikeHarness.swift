import Darwin
import Foundation

protocol DevVlogsStorageCapacityProviding {
    func usefulCapacity(at destinationURL: URL) throws -> Int64?
}

protocol DevVlogsStorageDestinationStateProviding {
    func state(at destinationURL: URL) throws -> DevVlogsStorageDestinationState
}

struct DevVlogsStorageDestinationState: Equatable {
    let isAvailable: Bool
    let isLocal: Bool
    let isReadOnly: Bool
}

enum DevVlogsStorageSkipReason: String, Equatable {
    case unavailable
    case nonlocal
    case readOnly = "read_only"
    case capacityUnknown = "capacity_unknown"
    case insufficientCapacity = "insufficient_capacity"
}

enum DevVlogsStoragePreflightResult: Equatable {
    case proceed(usefulCapacity: Int64, suppliedReserve: Int64)
    case skip(DevVlogsStorageSkipReason)
}

struct DevVlogsStoragePreflight {
    let capacityProvider: any DevVlogsStorageCapacityProviding
    let destinationStateProvider: any DevVlogsStorageDestinationStateProviding

    func evaluate(destinationURL: URL, suppliedReserve: Int64) throws -> DevVlogsStoragePreflightResult {
        let state = try destinationStateProvider.state(at: destinationURL)
        guard state.isAvailable else { return .skip(.unavailable) }
        guard state.isLocal else { return .skip(.nonlocal) }
        guard !state.isReadOnly else { return .skip(.readOnly) }
        guard let capacity = try capacityProvider.usefulCapacity(at: destinationURL) else {
            return .skip(.capacityUnknown)
        }
        guard capacity >= suppliedReserve else { return .skip(.insufficientCapacity) }
        return .proceed(usefulCapacity: capacity, suppliedReserve: suppliedReserve)
    }
}

struct DevVlogsURLStorageCapacityProvider: DevVlogsStorageCapacityProviding {
    func usefulCapacity(at destinationURL: URL) throws -> Int64? {
        try destinationURL.resourceValues(
            forKeys: [.volumeAvailableCapacityForImportantUsageKey]
        ).volumeAvailableCapacityForImportantUsage
    }
}

struct DevVlogsURLStorageDestinationStateProvider: DevVlogsStorageDestinationStateProviding {
    func state(at destinationURL: URL) throws -> DevVlogsStorageDestinationState {
        let values = try destinationURL.resourceValues(forKeys: [
            .isWritableKey,
            .volumeIsLocalKey,
            .volumeIsReadOnlyKey,
        ])
        return DevVlogsStorageDestinationState(
            isAvailable: values.isWritable != nil,
            isLocal: values.volumeIsLocal == true,
            isReadOnly: values.volumeIsReadOnly == true || values.isWritable == false
        )
    }
}

struct DevVlogsOrdinaryBookmarkResolution {
    let url: URL
    let isStale: Bool
}

enum DevVlogsOrdinaryBookmark {
    static func create(for url: URL) throws -> Data {
        try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    static func resolve(_ data: Data) throws -> DevVlogsOrdinaryBookmarkResolution {
        var isStale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withoutUI, .withoutMounting],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return DevVlogsOrdinaryBookmarkResolution(url: url, isStale: isStale)
    }
}

enum DevVlogsStorageHarnessError: Error, Equatable {
    case rootAlreadyExists
    case outOfScope
    case symbolicLink
    case notDirectory
    case identityMismatch
    case markerMissing
    case markerMismatch
    case itemExists
    case exclusiveRenameUnsupported
    case crossVolume
    case ioFailure(Int32)
}

final class DevVlogsStorageRunRoot {
    static let prefixName = "HoldType-DevVlogs-Phase0B"
    static let markerName = ".holdtype-phase0b-owner"

    let runID: UUID
    let rootURL: URL

    private let fileManager: FileManager
    private let temporaryDirectoryURL: URL
    private let prefixURL: URL
    private let temporaryPathComponentIdentities: [DevVlogsStoragePathComponentIdentity]
    private let temporaryDirectoryIdentity: DevVlogsStorageFileIdentity
    private let prefixIdentity: DevVlogsStorageFileIdentity
    private let rootIdentity: DevVlogsStorageFileIdentity

    init(
        runID: UUID,
        fileManager: FileManager = .default,
        temporaryDirectoryURL suppliedTemporaryDirectoryURL: URL? = nil
    ) throws {
        self.runID = runID
        self.fileManager = fileManager
        if let suppliedTemporaryDirectoryURL {
            try Self.validateFixtureTemporaryDirectory(
                suppliedTemporaryDirectoryURL,
                fileManager: fileManager
            )
        }
        temporaryDirectoryURL = (suppliedTemporaryDirectoryURL ?? fileManager.temporaryDirectory)
            .standardizedFileURL
        // macOS may expose its physical temporary directory through the system-owned /var symlink.
        // Pin every component's lstat identity; the temporary leaf, prefix, and run root must be directories.
        temporaryPathComponentIdentities = try Self.capturePathComponentIdentities(
            through: temporaryDirectoryURL
        )
        temporaryDirectoryIdentity = try Self.directoryIdentity(at: temporaryDirectoryURL)
        prefixURL = temporaryDirectoryURL
            .appendingPathComponent(Self.prefixName, isDirectory: true)
        try Self.rejectSymbolicLink(at: prefixURL, ifPresent: true)
        try fileManager.createDirectory(at: prefixURL, withIntermediateDirectories: true)
        prefixIdentity = try Self.directoryIdentity(at: prefixURL)

        rootURL = prefixURL.appendingPathComponent(runID.uuidString.lowercased(), isDirectory: true)
        guard !fileManager.fileExists(atPath: rootURL.path) else {
            throw DevVlogsStorageHarnessError.rootAlreadyExists
        }
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: false)
        rootIdentity = try Self.directoryIdentity(at: rootURL)
        try Data(runID.uuidString.lowercased().utf8).write(
            to: rootURL.appendingPathComponent(Self.markerName),
            options: .atomic
        )
        try validateOwnership()
    }

    func ownedURL(relativePath: String) throws -> URL {
        try validateOwnership()
        guard Self.isSafeRelativePath(relativePath) else {
            throw DevVlogsStorageHarnessError.outOfScope
        }
        let candidate = rootURL.appendingPathComponent(relativePath).standardizedFileURL
        guard candidate.path.hasPrefix(rootURL.standardizedFileURL.path + "/") else {
            throw DevVlogsStorageHarnessError.outOfScope
        }
        try rejectExistingSymbolicLinkComponents(to: candidate)
        return candidate
    }

    func writeSynchronously(_ data: Data, relativePath: String) throws -> URL {
        let fileURL = try ownedURL(relativePath: relativePath)
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try rejectExistingSymbolicLinkComponents(to: fileURL)
        let descriptor = open(fileURL.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else {
            if errno == EEXIST { throw DevVlogsStorageHarnessError.itemExists }
            throw DevVlogsStorageHarnessError.ioFailure(errno)
        }
        defer { close(descriptor) }
        try data.withUnsafeBytes { bytes in
            var offset = 0
            while offset < bytes.count {
                let count = write(descriptor, bytes.baseAddress?.advanced(by: offset), bytes.count - offset)
                guard count > 0 else { throw DevVlogsStorageHarnessError.ioFailure(errno) }
                offset += count
            }
        }
        guard fsync(descriptor) == 0 else { throw DevVlogsStorageHarnessError.ioFailure(errno) }
        return fileURL
    }

    func promoteExclusively(fragmentRelativePath: String, finalRelativePath: String) throws -> URL {
        let fragmentURL = try ownedURL(relativePath: fragmentRelativePath)
        let finalURL = try ownedURL(relativePath: finalRelativePath)
        try fileManager.createDirectory(
            at: finalURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try rejectExistingSymbolicLinkComponents(to: finalURL)

        let sourceVolume = try fragmentURL.resourceValues(forKeys: [.volumeIdentifierKey])
        let targetVolume = try finalURL.deletingLastPathComponent().resourceValues(
            forKeys: [.volumeIdentifierKey, .volumeSupportsExclusiveRenamingKey]
        )
        guard Self.equalVolumeIDs(sourceVolume.volumeIdentifier, targetVolume.volumeIdentifier) else {
            throw DevVlogsStorageHarnessError.crossVolume
        }
        guard targetVolume.volumeSupportsExclusiveRenaming == true else {
            throw DevVlogsStorageHarnessError.exclusiveRenameUnsupported
        }
        guard renamex_np(fragmentURL.path, finalURL.path, UInt32(RENAME_EXCL)) == 0 else {
            if errno == EEXIST { throw DevVlogsStorageHarnessError.itemExists }
            throw DevVlogsStorageHarnessError.ioFailure(errno)
        }
        return finalURL
    }

    func validateOwnership() throws {
        let expectedPrefixURL = temporaryDirectoryURL
            .appendingPathComponent(Self.prefixName, isDirectory: true)
            .standardizedFileURL
        let expectedRootURL = expectedPrefixURL
            .appendingPathComponent(runID.uuidString.lowercased(), isDirectory: true)
            .standardizedFileURL
        guard prefixURL.standardizedFileURL.path == expectedPrefixURL.path,
              rootURL.standardizedFileURL.path == expectedRootURL.path else {
            throw DevVlogsStorageHarnessError.outOfScope
        }
        try Self.validatePathComponentIdentities(temporaryPathComponentIdentities)
        guard try Self.directoryIdentity(at: temporaryDirectoryURL) == temporaryDirectoryIdentity,
              try Self.directoryIdentity(at: prefixURL) == prefixIdentity,
              try Self.directoryIdentity(at: rootURL) == rootIdentity else {
            throw DevVlogsStorageHarnessError.identityMismatch
        }
        let markerURL = rootURL.appendingPathComponent(Self.markerName)
        guard fileManager.fileExists(atPath: markerURL.path) else {
            throw DevVlogsStorageHarnessError.markerMissing
        }
        try Self.rejectSymbolicLink(at: markerURL, ifPresent: false)
        guard (try? String(contentsOf: markerURL, encoding: .utf8)) == runID.uuidString.lowercased() else {
            throw DevVlogsStorageHarnessError.markerMismatch
        }
    }

    func cleanup() throws {
        try validateOwnership()
        try fileManager.removeItem(at: rootURL)
    }

    private func rejectExistingSymbolicLinkComponents(to candidate: URL) throws {
        var current = rootURL
        let relative = candidate.path.dropFirst(rootURL.path.count + 1)
        for component in relative.split(separator: "/") {
            current.appendPathComponent(String(component))
            try Self.rejectSymbolicLink(at: current, ifPresent: true)
        }
    }

    private static func rejectSymbolicLink(at url: URL, ifPresent: Bool) throws {
        var metadata = stat()
        if lstat(url.path, &metadata) != 0 {
            if ifPresent && errno == ENOENT { return }
            throw DevVlogsStorageHarnessError.ioFailure(errno)
        }
        if (metadata.st_mode & S_IFMT) == S_IFLNK {
            throw DevVlogsStorageHarnessError.symbolicLink
        }
    }

    private static func directoryIdentity(at url: URL) throws -> DevVlogsStorageFileIdentity {
        let identity = try fileIdentity(at: url)
        guard identity.fileType != S_IFLNK else {
            throw DevVlogsStorageHarnessError.symbolicLink
        }
        guard identity.fileType == S_IFDIR else {
            throw DevVlogsStorageHarnessError.notDirectory
        }
        return identity
    }

    private static func fileIdentity(at url: URL) throws -> DevVlogsStorageFileIdentity {
        var metadata = stat()
        guard lstat(url.path, &metadata) == 0 else {
            throw DevVlogsStorageHarnessError.ioFailure(errno)
        }
        let fileType = metadata.st_mode & S_IFMT
        return DevVlogsStorageFileIdentity(
            device: metadata.st_dev,
            inode: metadata.st_ino,
            fileType: fileType
        )
    }

    private static func capturePathComponentIdentities(
        through directoryURL: URL
    ) throws -> [DevVlogsStoragePathComponentIdentity] {
        guard directoryURL.path.hasPrefix("/") else {
            throw DevVlogsStorageHarnessError.outOfScope
        }
        var currentURL = URL(fileURLWithPath: "/", isDirectory: true)
        var identities = [DevVlogsStoragePathComponentIdentity(
            url: currentURL,
            identity: try fileIdentity(at: currentURL)
        )]
        for component in directoryURL.pathComponents.dropFirst() {
            currentURL.appendPathComponent(component, isDirectory: true)
            identities.append(DevVlogsStoragePathComponentIdentity(
                url: currentURL,
                identity: try fileIdentity(at: currentURL)
            ))
        }
        return identities
    }

    private static func validatePathComponentIdentities(
        _ identities: [DevVlogsStoragePathComponentIdentity]
    ) throws {
        for captured in identities {
            guard try fileIdentity(at: captured.url) == captured.identity else {
                throw DevVlogsStorageHarnessError.identityMismatch
            }
        }
    }

    private static func validateFixtureTemporaryDirectory(
        _ fixtureURL: URL,
        fileManager: FileManager
    ) throws {
        let defaultPrefixURL = fileManager.temporaryDirectory
            .appendingPathComponent(prefixName, isDirectory: true)
            .standardizedFileURL
        let candidateURL = fixtureURL.standardizedFileURL
        guard candidateURL.path.hasPrefix(defaultPrefixURL.path + "/") else {
            throw DevVlogsStorageHarnessError.outOfScope
        }
        let relativePath = candidateURL.path.dropFirst(defaultPrefixURL.path.count + 1)
        let components = relativePath.split(separator: "/")
        guard components.count >= 2,
              let outerRunID = UUID(uuidString: String(components[0])),
              String(components[0]) == outerRunID.uuidString.lowercased() else {
            throw DevVlogsStorageHarnessError.outOfScope
        }

        _ = try directoryIdentity(at: defaultPrefixURL)
        var currentURL = defaultPrefixURL.appendingPathComponent(
            outerRunID.uuidString.lowercased(),
            isDirectory: true
        )
        _ = try directoryIdentity(at: currentURL)
        let markerURL = currentURL.appendingPathComponent(markerName)
        try rejectSymbolicLink(at: markerURL, ifPresent: false)
        guard (try? String(contentsOf: markerURL, encoding: .utf8)) ==
            outerRunID.uuidString.lowercased() else {
            throw DevVlogsStorageHarnessError.markerMismatch
        }
        for component in components.dropFirst() {
            currentURL.appendPathComponent(String(component), isDirectory: true)
            _ = try directoryIdentity(at: currentURL)
        }
    }

    private static func isSafeRelativePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && path.split(separator: "/").allSatisfy {
            $0 != "." && $0 != ".."
        }
    }

    private static func equalVolumeIDs(_ lhs: Any?, _ rhs: Any?) -> Bool {
        guard let lhs = lhs as? NSObject, let rhs = rhs as? NSObject else { return false }
        return lhs.isEqual(rhs)
    }
}

private struct DevVlogsStorageFileIdentity: Equatable {
    let device: dev_t
    let inode: ino_t
    let fileType: mode_t
}

private struct DevVlogsStoragePathComponentIdentity {
    let url: URL
    let identity: DevVlogsStorageFileIdentity
}

enum DevVlogsStorageMediaValidation: String, Equatable {
    case playable
    case unvalidated
    case unusable
}

enum DevVlogsStorageClipClassification: String, Equatable {
    case ready
    case incomplete
    case failed
}

enum DevVlogsStorageCleanupClassification: String, Equatable {
    case complete
    case pendingReconnect = "pending_reconnect"
}

struct DevVlogsStorageTerminalState: Equatable {
    let clip: DevVlogsStorageClipClassification
    let cleanup: DevVlogsStorageCleanupClassification

    static func classify(
        byteCount: Int64?,
        validation: DevVlogsStorageMediaValidation,
        destinationAvailable: Bool
    ) -> Self {
        let clip: DevVlogsStorageClipClassification
        if (byteCount ?? 0) <= 0 || validation == .unusable {
            clip = .failed
        } else if validation == .playable {
            clip = .ready
        } else {
            clip = .incomplete
        }
        return Self(
            clip: clip,
            cleanup: destinationAvailable ? .complete : .pendingReconnect
        )
    }
}

struct DevVlogsStorageEvidenceRecord: Codable, Equatable {
    let runID: String
    let caseID: String
    let attemptID: String
    let destinationClass: String
    let filesystemClass: String
    let relativePathClass: String
    let byteCount: Int64
    let bookmarkWasStale: Bool
    let result: String

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}
