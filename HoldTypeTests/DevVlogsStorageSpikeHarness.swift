import Darwin
import DiskArbitration
import Foundation
import IOKit
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
struct DevVlogsOrdinaryBookmarkResolution { let url: URL; let isStale: Bool }
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
enum DevVlogsStorageDestinationClass: String, CaseIterable {
    case externalSSD = "external-ssd"; case externalHDD = "external-hdd"
}
enum DevVlogsStorageFilesystemClass: String, CaseIterable { case apfs, hfs, exfat }
struct DevVlogsExternalStorageAuthorization {
    let volumeRootURL: URL; let destinationClass: DevVlogsStorageDestinationClass; let filesystemClass: DevVlogsStorageFilesystemClass
}
struct DevVlogsExternalVolumeEvidence {
    let mountRootURL: URL; let destinationClass: DevVlogsStorageDestinationClass?
    let filesystemClass: DevVlogsStorageFilesystemClass?; let isPhysicalExternal: Bool, isLocal: Bool, isWritable: Bool, containsSymbolicLink: Bool
}
struct DevVlogsExternalStorageRuntimeConfiguration {
    static let enableKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_ENABLE",
               rootKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_VOLUME_ROOT",
               destinationKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_DESTINATION_CLASS",
               filesystemKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_FILESYSTEM_CLASS",
               caseKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_CASE_ID",
               runKey = "HOLDTYPE_DEV_VLOGS_STORAGE_EXTERNAL_RUN_ID"
    let authorization: DevVlogsExternalStorageAuthorization
    let caseID: String
    let runID: UUID
    static func load(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> Self? {
        let keys = [enableKey, rootKey, destinationKey, filesystemKey, caseKey, runKey]
        let supplied = keys.filter { environment[$0] != nil }
        guard !supplied.isEmpty else { return nil }
        guard supplied.count == keys.count,
              environment[enableKey] == "execute",
              let root = environment[rootKey], root.hasPrefix("/"), root != "/",
              URL(fileURLWithPath: root).standardizedFileURL.path == root,
              let destinationValue = environment[destinationKey],
              let destination = DevVlogsStorageDestinationClass(rawValue: destinationValue),
              let filesystemValue = environment[filesystemKey],
              let filesystem = DevVlogsStorageFilesystemClass(rawValue: filesystemValue),
              let caseID = environment[caseKey], (1...64).contains(caseID.count),
              caseID.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }),
              let runValue = environment[runKey], let runID = UUID(uuidString: runValue),
              runValue == runID.uuidString.lowercased() else {
            throw DevVlogsStorageHarnessError.invalidRuntimeConfiguration
        }
        return Self(authorization: .init(
            volumeRootURL: URL(fileURLWithPath: root, isDirectory: true),
            destinationClass: destination, filesystemClass: filesystem
        ), caseID: caseID, runID: runID)
    }
}
enum DevVlogsStorageBaseAuthority {
    case internalDefault, nestedAttackFixture(URL), simulatedExternalFixture(URL)
    case explicitlyAuthorizedExternal(DevVlogsExternalStorageAuthorization)
}
enum DevVlogsStorageHarnessError: Error, Equatable {
    case rootAlreadyExists, outOfScope, symbolicLink, notDirectory, identityMismatch
    case markerMissing, markerMismatch, itemExists, exclusiveRenameUnsupported, crossVolume
    case invalidExternalAuthorization, invalidRuntimeConfiguration, prefixAlreadyExists
    case writeLimitExceeded, unexpectedContent
    case ioFailure(Int32)
}
final class DevVlogsStorageRunRoot {
    static let prefixName = "HoldType-DevVlogs-Phase0B"
    static let externalPrefixName = ".HoldTypeDevVlogsPhase0B"
    static let markerName = ".holdtype-phase0b-owner"
    static let prefixMarkerName = ".holdtype-phase0b-prefix-owner"
    static let maximumWriteBytes = 64 * 1024
    let runID: UUID
    let rootURL: URL
    private let fileManager: FileManager, temporaryDirectoryURL: URL
    private let activePrefixName: String, ownsPrefix: Bool
    private let prefixURL: URL
    private let temporaryPathComponentIdentities: [DevVlogsStoragePathComponentIdentity]
    private let temporaryDirectoryIdentity: DevVlogsStorageFileIdentity
    private let prefixIdentity: DevVlogsStorageFileIdentity, rootIdentity: DevVlogsStorageFileIdentity
    private let prefixMarkerIdentity: DevVlogsStorageFileIdentity?
    private var rootMarkerIdentity: DevVlogsStorageFileIdentity
    init(runID: UUID, fileManager: FileManager = .default,
         authority: DevVlogsStorageBaseAuthority = .internalDefault) throws {
        self.runID = runID
        self.fileManager = fileManager
        let base = try Self.resolveBase(authority, fileManager: fileManager)
        temporaryDirectoryURL = base.url
        activePrefixName = base.prefixName
        ownsPrefix = base.ownsPrefix
        // macOS may expose its physical temporary directory through the system-owned /var symlink.
        // Pin every component's lstat identity; the temporary leaf, prefix, and run root must be directories.
        temporaryPathComponentIdentities = try Self.capturePathComponentIdentities(through: temporaryDirectoryURL)
        temporaryDirectoryIdentity = try Self.directoryIdentity(at: temporaryDirectoryURL)
        prefixURL = temporaryDirectoryURL.appendingPathComponent(activePrefixName, isDirectory: true)
        try Self.rejectSymbolicLink(at: prefixURL, ifPresent: true)
        if ownsPrefix {
            guard mkdir(prefixURL.path, 0o700) == 0 else {
                if errno == EEXIST { throw DevVlogsStorageHarnessError.prefixAlreadyExists }
                throw DevVlogsStorageHarnessError.ioFailure(errno)
            }
        } else {
            try fileManager.createDirectory(at: prefixURL, withIntermediateDirectories: true)
        }
        prefixIdentity = try Self.directoryIdentity(at: prefixURL)
        if ownsPrefix {
            let markerURL = prefixURL.appendingPathComponent(Self.prefixMarkerName)
            try Self.writeExclusively(Data(runID.uuidString.lowercased().utf8), to: markerURL)
            prefixMarkerIdentity = try Self.fileIdentity(at: markerURL)
        } else {
            prefixMarkerIdentity = nil
        }
        rootURL = prefixURL.appendingPathComponent(runID.uuidString.lowercased(), isDirectory: true)
        guard mkdir(rootURL.path, 0o700) == 0 else {
            if errno == EEXIST { throw DevVlogsStorageHarnessError.rootAlreadyExists }
            throw DevVlogsStorageHarnessError.ioFailure(errno)
        }
        rootIdentity = try Self.directoryIdentity(at: rootURL)
        let rootMarkerURL = rootURL.appendingPathComponent(Self.markerName)
        try Self.writeExclusively(Data(runID.uuidString.lowercased().utf8), to: rootMarkerURL)
        rootMarkerIdentity = try Self.fileIdentity(at: rootMarkerURL)
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
        guard data.count <= Self.maximumWriteBytes else {
            throw DevVlogsStorageHarnessError.writeLimitExceeded
        }
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
            .appendingPathComponent(activePrefixName, isDirectory: true)
            .standardizedFileURL
        let expectedRootURL = expectedPrefixURL.appendingPathComponent(
            runID.uuidString.lowercased(), isDirectory: true).standardizedFileURL
        guard prefixURL.standardizedFileURL.path == expectedPrefixURL.path,
              rootURL.standardizedFileURL.path == expectedRootURL.path else {
            throw DevVlogsStorageHarnessError.outOfScope
        }
        try validateContainerIdentity()
        if let prefixMarkerIdentity {
            let markerURL = prefixURL.appendingPathComponent(Self.prefixMarkerName)
            guard try Self.fileIdentity(at: markerURL) == prefixMarkerIdentity,
                  (try? String(contentsOf: markerURL, encoding: .utf8)) ==
                    runID.uuidString.lowercased() else {
                throw DevVlogsStorageHarnessError.markerMismatch
            }
        }
        let markerURL = rootURL.appendingPathComponent(Self.markerName)
        guard fileManager.fileExists(atPath: markerURL.path) else { throw DevVlogsStorageHarnessError.markerMissing }
        guard try Self.fileIdentity(at: markerURL) == rootMarkerIdentity,
              (try? String(contentsOf: markerURL, encoding: .utf8)) == runID.uuidString.lowercased() else {
            throw DevVlogsStorageHarnessError.markerMismatch
        }
    }
    @discardableResult
    func cleanup() throws -> DevVlogsStorageCleanupClassification {
        try validateOwnership()
        if ownsPrefix {
            let expected = Set([Self.prefixMarkerName, runID.uuidString.lowercased()])
            let actual = Set(try fileManager.contentsOfDirectory(atPath: prefixURL.path))
            guard actual == expected else { throw DevVlogsStorageHarnessError.unexpectedContent }
        }
        try fileManager.removeItem(at: rootURL)
        guard ownsPrefix else { return .complete }
        guard try Self.directoryIdentity(at: temporaryDirectoryURL) == temporaryDirectoryIdentity,
              try Self.directoryIdentity(at: prefixURL) == prefixIdentity,
              let prefixMarkerIdentity,
              try Self.fileIdentity(at: prefixURL.appendingPathComponent(Self.prefixMarkerName)) ==
                prefixMarkerIdentity else {
            throw DevVlogsStorageHarnessError.identityMismatch
        }
        let remaining = try fileManager.contentsOfDirectory(atPath: prefixURL.path)
        guard remaining == [Self.prefixMarkerName] else {
            throw DevVlogsStorageHarnessError.unexpectedContent
        }
        guard unlink(prefixURL.appendingPathComponent(Self.prefixMarkerName).path) == 0,
              rmdir(prefixURL.path) == 0 else {
            throw DevVlogsStorageHarnessError.ioFailure(errno)
        }
        return .complete
    }
    func cleanupClassification() -> DevVlogsStorageCleanupClassification {
        (try? cleanup()) ?? .pendingReconnect
    }
    func restoreMissingMarkerForInternalTestTeardown() throws {
        guard !ownsPrefix else { throw DevVlogsStorageHarnessError.outOfScope }
        try validateContainerIdentity()
        let markerURL = rootURL.appendingPathComponent(Self.markerName)
        guard !fileManager.fileExists(atPath: markerURL.path) else {
            throw DevVlogsStorageHarnessError.markerMismatch
        }
        try Self.writeExclusively(Data(runID.uuidString.lowercased().utf8), to: markerURL)
        rootMarkerIdentity = try Self.fileIdentity(at: markerURL)
    }
    private func validateContainerIdentity() throws {
        try Self.validatePathComponentIdentities(temporaryPathComponentIdentities)
        guard try Self.directoryIdentity(at: temporaryDirectoryURL) == temporaryDirectoryIdentity,
              try Self.directoryIdentity(at: prefixURL) == prefixIdentity,
              try Self.directoryIdentity(at: rootURL) == rootIdentity,
              prefixIdentity.device == temporaryDirectoryIdentity.device,
              rootIdentity.device == temporaryDirectoryIdentity.device else {
            throw DevVlogsStorageHarnessError.identityMismatch
        }
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
    private static func writeExclusively(_ data: Data, to url: URL) throws {
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW, 0o600)
        guard descriptor >= 0 else { throw DevVlogsStorageHarnessError.ioFailure(errno) }
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
    private static func resolveBase(
        _ authority: DevVlogsStorageBaseAuthority,
        fileManager: FileManager
    ) throws -> (url: URL, prefixName: String, ownsPrefix: Bool) {
        switch authority {
        case .internalDefault:
            return (fileManager.temporaryDirectory.standardizedFileURL, prefixName, false)
        case let .nestedAttackFixture(url):
            try validateFixtureTemporaryDirectory(url, fileManager: fileManager)
            return (url.standardizedFileURL, prefixName, false)
        case let .simulatedExternalFixture(url):
            try validateFixtureTemporaryDirectory(url, fileManager: fileManager)
            return (url.standardizedFileURL, externalPrefixName, true)
        case let .explicitlyAuthorizedExternal(authorization):
            try validateExternalVolumeRoot(authorization, fileManager: fileManager)
            return (authorization.volumeRootURL.standardizedFileURL, externalPrefixName, true)
        }
    }
    private static func validateExternalVolumeRoot(_ authorization: DevVlogsExternalStorageAuthorization,
        fileManager: FileManager) throws {
        let rootURL = authorization.volumeRootURL.standardizedFileURL
        let homePath = fileManager.homeDirectoryForCurrentUser.standardizedFileURL.path
        guard rootURL.path != "/", rootURL.path != homePath, !homePath.hasPrefix(rootURL.path + "/") else { throw DevVlogsStorageHarnessError.invalidExternalAuthorization }
        let identities = try capturePathComponentIdentities(through: rootURL)
        let rootIdentity = try directoryIdentity(at: rootURL); let internalIdentity = try directoryIdentity(at: fileManager.temporaryDirectory)
        var fileSystem = statfs()
        guard rootIdentity.device != internalIdentity.device, statfs(rootURL.path, &fileSystem) == 0 else {
            throw DevVlogsStorageHarnessError.invalidExternalAuthorization
        }
        let state = try DevVlogsURLStorageDestinationStateProvider().state(at: rootURL)
        guard let session = DASessionCreate(kCFAllocatorDefault),
              let disk = DADiskCreateFromVolumePath(kCFAllocatorDefault, session, rootURL as CFURL),
              let description = DADiskCopyDescription(disk) as? [CFString: Any],
              let mountRoot = description[kDADiskDescriptionVolumePathKey] as? URL,
              let isInternal = description[kDADiskDescriptionDeviceInternalKey] as? Bool,
              let mediaWritable = description[kDADiskDescriptionMediaWritableKey] as? Bool,
              let bsdNamePointer = DADiskGetBSDName(disk) else {
            throw DevVlogsStorageHarnessError.invalidExternalAuthorization
        }
        let bsdName = String(cString: bsdNamePointer)
        let service = IOServiceGetMatchingService(kIOMainPortDefault,
            IOBSDNameMatching(kIOMainPortDefault, 0, bsdName))
        guard service != IO_OBJECT_NULL else { throw DevVlogsStorageHarnessError.invalidExternalAuthorization }
        defer { IOObjectRelease(service) }
        let options = IOOptionBits(kIORegistryIterateRecursively | kIORegistryIterateParents)
        let characteristics = IORegistryEntrySearchCFProperty(
            service, kIOServicePlane, "Device Characteristics" as CFString, kCFAllocatorDefault, options
        ) as? [String: Any]
        let protocolCharacteristics = IORegistryEntrySearchCFProperty(service, kIOServicePlane,
            "Protocol Characteristics" as CFString, kCFAllocatorDefault, options) as? [String: Any]
        let evidence = DevVlogsExternalVolumeEvidence(
            mountRootURL: mountRoot,
            destinationClass: (characteristics?["Solid State"] as? Bool).map { $0 ? DevVlogsStorageDestinationClass.externalSSD : .externalHDD },
            filesystemClass: DevVlogsStorageFilesystemClass(rawValue:
                fileSystemString(fileSystem.f_fstypename).lowercased()),
            isPhysicalExternal: !isInternal && (protocolCharacteristics?["Physical Interconnect Location"] as? String) == "External",
            isLocal: state.isLocal,
            isWritable: state.isAvailable && !state.isReadOnly && mediaWritable,
            containsSymbolicLink: identities.contains { $0.identity.fileType == S_IFLNK }
        )
        try validateExternalAuthorization(authorization, evidence: evidence)
    }
    static func validateExternalAuthorization(_ authorization: DevVlogsExternalStorageAuthorization,
        evidence: DevVlogsExternalVolumeEvidence,
        homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser) throws {
        let root = authorization.volumeRootURL.standardizedFileURL
        let home = homeDirectoryURL.standardizedFileURL.path
        guard root.isFileURL, root.path.hasPrefix("/"), root.path != "/", root.path != home, !home.hasPrefix(root.path + "/"),
              evidence.mountRootURL.standardizedFileURL == root,
              evidence.isPhysicalExternal, evidence.isLocal, evidence.isWritable,
              !evidence.containsSymbolicLink,
              evidence.destinationClass == authorization.destinationClass,
              evidence.filesystemClass == authorization.filesystemClass else {
            throw DevVlogsStorageHarnessError.invalidExternalAuthorization
        }
    }
    private static func fileSystemString<T>(_ tuple: T) -> String { withUnsafeBytes(of: tuple) { String(cString: $0.baseAddress!.assumingMemoryBound(to: CChar.self)) } }
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
