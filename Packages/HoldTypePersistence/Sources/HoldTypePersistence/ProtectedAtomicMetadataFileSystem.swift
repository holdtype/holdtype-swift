import Darwin
import Foundation

enum ProtectedAtomicMetadataFileSystemError: Error, Equatable, Sendable {
    case invalidLocation
    case invalidFileType
    case sizeLimitExceeded
    case readFailed
    case writeFailed
    case removeFailed
}

struct ProtectedAtomicMetadataFilePolicy: Equatable, Sendable {
    enum FileProtection: Equatable, Sendable {
        case complete
    }

    let maximumByteCount: Int
    let fileProtection: FileProtection
    let excludesFromBackup: Bool
}

protocol ProtectedAtomicMetadataFileSystem: Sendable {
    func readFileIfPresent(
        at fileURL: URL,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws -> Data?

    func replaceFileAtomically(
        at fileURL: URL,
        with data: Data,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws

    func removeFileIfPresent(at fileURL: URL) throws
}

enum ProtectedAtomicMetadataTransferResult: Equatable, Sendable {
    case byteCount(Int)
    case interrupted
    case failed
}

enum ProtectedAtomicMetadataCallResult: Equatable, Sendable {
    case success
    case interrupted
    case missing
    case failed
}

struct ProtectedAtomicMetadataFileOperations: Sendable {
    // This narrow seam exercises partial/interrupted Darwin calls and the last
    // empty-file identity check without exposing filesystem details publicly.
    typealias ReadOperation = @Sendable (
        _ fileDescriptor: Int32,
        _ buffer: UnsafeMutableRawPointer?,
        _ byteCount: Int
    ) -> ProtectedAtomicMetadataTransferResult
    typealias WriteOperation = @Sendable (
        _ fileDescriptor: Int32,
        _ buffer: UnsafeRawPointer?,
        _ byteCount: Int
    ) -> ProtectedAtomicMetadataTransferResult
    typealias SynchronizeOperation = @Sendable (
        _ fileDescriptor: Int32
    ) -> ProtectedAtomicMetadataCallResult
    typealias PublishOperation = @Sendable (
        _ directoryFileDescriptor: Int32,
        _ temporaryName: String,
        _ destinationName: String
    ) -> ProtectedAtomicMetadataCallResult
    typealias RemoveOperation = @Sendable (
        _ directoryFileDescriptor: Int32,
        _ fileName: String
    ) -> ProtectedAtomicMetadataCallResult
    typealias PrewriteCheckpoint = @Sendable (
        _ directoryFileDescriptor: Int32,
        _ temporaryName: String
    ) -> ProtectedAtomicMetadataCallResult

    static let live = ProtectedAtomicMetadataFileOperations(
        read: { fileDescriptor, buffer, byteCount in
            let result = Darwin.read(fileDescriptor, buffer, byteCount)
            if result >= 0 {
                return .byteCount(result)
            }
            return errno == EINTR ? .interrupted : .failed
        },
        write: { fileDescriptor, buffer, byteCount in
            let result = Darwin.write(fileDescriptor, buffer, byteCount)
            if result >= 0 {
                return .byteCount(result)
            }
            return errno == EINTR ? .interrupted : .failed
        },
        synchronize: { fileDescriptor in
            guard Darwin.fsync(fileDescriptor) != 0 else {
                return .success
            }
            return errno == EINTR ? .interrupted : .failed
        },
        publish: { directoryFileDescriptor, temporaryName, destinationName in
            let result = temporaryName.withCString { temporaryPath in
                destinationName.withCString { destinationPath in
                    Darwin.renameat(
                        directoryFileDescriptor,
                        temporaryPath,
                        directoryFileDescriptor,
                        destinationPath
                    )
                }
            }
            guard result != 0 else {
                return .success
            }
            return errno == EINTR ? .interrupted : .failed
        },
        remove: { directoryFileDescriptor, fileName in
            let result = fileName.withCString { name in
                Darwin.unlinkat(directoryFileDescriptor, name, 0)
            }
            guard result != 0 else {
                return .success
            }
            if errno == ENOENT {
                return .missing
            }
            return errno == EINTR ? .interrupted : .failed
        },
        prewriteCheckpoint: { _, _ in .success }
    )

    let read: ReadOperation
    let write: WriteOperation
    let synchronize: SynchronizeOperation
    let publish: PublishOperation
    let remove: RemoveOperation
    let prewriteCheckpoint: PrewriteCheckpoint
}

/// A bounded app-private file boundary for small metadata records.
///
/// Darwin descriptor-relative operations pin the directory and file identities.
/// Foundation is used only to apply Apple Data Protection and backup metadata to
/// an exclusive temporary file before its first content write.
struct FoundationProtectedAtomicMetadataFileSystem: ProtectedAtomicMetadataFileSystem {
    private static let transferChunkByteCount = 64 * 1_024
    private static let maximumInterruptedRetryCount = 8

    private let operations: ProtectedAtomicMetadataFileOperations

    init(operations: ProtectedAtomicMetadataFileOperations = .live) {
        self.operations = operations
    }

    func readFileIfPresent(
        at fileURL: URL,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws -> Data? {
        guard policy.maximumByteCount >= 0,
              policy.maximumByteCount < Int.max else {
            throw ProtectedAtomicMetadataFileSystemError.invalidLocation
        }

        let path = try MetadataPath(fileURL: fileURL)
        guard let directory = try openDirectoryIfPresent(at: path.directoryURL) else {
            return nil
        }
        guard let pathStatus = try statusIfPresent(
            named: path.fileName,
            in: directory.rawValue,
            failure: .readFailed
        ) else {
            return nil
        }
        try validateRegularFile(pathStatus)

        let fileDescriptor = try openRegularFileForReading(
            named: path.fileName,
            in: directory.rawValue
        )
        let openedStatus = try status(
            of: fileDescriptor.rawValue,
            failure: .readFailed
        )
        try validateRegularFile(openedStatus)
        guard FileSnapshot(pathStatus) == FileSnapshot(openedStatus) else {
            throw ProtectedAtomicMetadataFileSystemError.readFailed
        }

        guard openedStatus.st_size >= 0,
              openedStatus.st_size <= off_t(policy.maximumByteCount) else {
            throw ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded
        }

        var data = Data()
        data.reserveCapacity(Int(openedStatus.st_size))
        var buffer = [UInt8](
            repeating: 0,
            count: min(Self.transferChunkByteCount, policy.maximumByteCount + 1)
        )
        if buffer.isEmpty {
            buffer = [0]
        }

        while true {
            let remainingByteCount = policy.maximumByteCount - data.count
            let requestedByteCount = min(buffer.count, remainingByteCount + 1)
            let readByteCount = try read(
                from: fileDescriptor.rawValue,
                into: &buffer,
                byteCount: requestedByteCount
            )

            guard readByteCount > 0 else {
                break
            }
            guard readByteCount <= remainingByteCount else {
                throw ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded
            }
            data.append(contentsOf: buffer.prefix(readByteCount))
        }

        let finalStatus = try status(
            of: fileDescriptor.rawValue,
            failure: .readFailed
        )
        try validateRegularFile(finalStatus)
        guard FileSnapshot(finalStatus) == FileSnapshot(openedStatus),
              finalStatus.st_size == off_t(data.count) else {
            throw ProtectedAtomicMetadataFileSystemError.readFailed
        }

        return data
    }

    func replaceFileAtomically(
        at fileURL: URL,
        with data: Data,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws {
        guard policy.maximumByteCount >= 0,
              policy.maximumByteCount < Int.max else {
            throw ProtectedAtomicMetadataFileSystemError.invalidLocation
        }
        guard data.count <= policy.maximumByteCount else {
            throw ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded
        }

        let path = try MetadataPath(fileURL: fileURL)
        try createDirectoryIfNeeded(at: path.directoryURL, protection: policy.fileProtection)
        guard let directory = try openDirectoryIfPresent(at: path.directoryURL) else {
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }
        let originalDestinationStatus = try statusIfPresent(
            named: path.fileName,
            in: directory.rawValue,
            failure: .writeFailed
        )
        if let originalDestinationStatus {
            try validateRegularFile(originalDestinationStatus)
        }

        let temporaryName = ".\(path.fileName).\(UUID().uuidString).tmp"
        let temporaryFile = try createTemporaryFile(
            named: temporaryName,
            in: directory.rawValue
        )
        let temporaryIdentity = FileIdentity(
            try status(of: temporaryFile.rawValue, failure: .writeFailed)
        )
        var shouldRemoveTemporaryFile = true
        defer {
            if shouldRemoveTemporaryFile {
                removeOwnedTemporaryFileIfPresent(
                    named: temporaryName,
                    identity: temporaryIdentity,
                    from: directory.rawValue
                )
            }
        }

        try validateDirectoryIdentity(
            at: path.directoryURL,
            expected: directory.identity
        )
        try validateOwnedTemporaryFile(
            descriptor: temporaryFile.rawValue,
            named: temporaryName,
            identity: temporaryIdentity,
            in: directory.rawValue,
            expectedByteCount: 0
        )
        try applyMetadata(
            to: path.directoryURL.appendingPathComponent(temporaryName),
            descriptor: temporaryFile.rawValue,
            policy: policy
        )
        try validateDirectoryIdentity(
            at: path.directoryURL,
            expected: directory.identity
        )
        try validateOwnedTemporaryFile(
            descriptor: temporaryFile.rawValue,
            named: temporaryName,
            identity: temporaryIdentity,
            in: directory.rawValue,
            expectedByteCount: 0
        )
        try runPrewriteCheckpoint(
            temporaryName: temporaryName,
            in: directory.rawValue
        )
        try validateDirectoryIdentity(
            at: path.directoryURL,
            expected: directory.identity
        )
        try validateOwnedTemporaryFile(
            descriptor: temporaryFile.rawValue,
            named: temporaryName,
            identity: temporaryIdentity,
            in: directory.rawValue,
            expectedByteCount: 0
        )

        try write(data, to: temporaryFile.rawValue)
        try synchronize(temporaryFile.rawValue, failure: .writeFailed)
        try validateOwnedTemporaryFile(
            descriptor: temporaryFile.rawValue,
            named: temporaryName,
            identity: temporaryIdentity,
            in: directory.rawValue,
            expectedByteCount: data.count
        )
        try validateDestinationIsUnchanged(
            originalStatus: originalDestinationStatus,
            named: path.fileName,
            in: directory.rawValue
        )

        try publish(
            temporaryName: temporaryName,
            destinationName: path.fileName,
            in: directory.rawValue
        )
        // The rename is the mutation commit point. Nothing below may throw and
        // turn an already-published destination into a reported failure.
        shouldRemoveTemporaryFile = false
        synchronizeBestEffort(directory.rawValue)
    }

    func removeFileIfPresent(at fileURL: URL) throws {
        let path: MetadataPath
        do {
            path = try MetadataPath(fileURL: fileURL)
        } catch {
            throw ProtectedAtomicMetadataFileSystemError.removeFailed
        }

        guard let directory = try openDirectoryIfPresentForRemoval(at: path.directoryURL) else {
            return
        }
        guard let pathStatus = try statusIfPresent(
            named: path.fileName,
            in: directory.rawValue,
            failure: .removeFailed
        ) else {
            return
        }
        do {
            try validateRegularFile(pathStatus)
        } catch {
            throw ProtectedAtomicMetadataFileSystemError.removeFailed
        }

        let fileDescriptor: FileDescriptor
        do {
            guard let openedFileDescriptor = try openRegularFileForRemoval(
                named: path.fileName,
                in: directory.rawValue
            ) else {
                return
            }
            fileDescriptor = openedFileDescriptor
            let openedStatus = try status(
                of: fileDescriptor.rawValue,
                failure: .removeFailed
            )
            try validateRegularFile(openedStatus)
            guard FileIdentity(openedStatus) == FileIdentity(pathStatus) else {
                throw ProtectedAtomicMetadataFileSystemError.removeFailed
            }
            guard let currentStatus = try statusIfPresent(
                named: path.fileName,
                in: directory.rawValue,
                failure: .removeFailed
            ) else {
                return
            }
            try validateRegularFile(currentStatus)
            guard FileSnapshot(currentStatus) == FileSnapshot(pathStatus) else {
                throw ProtectedAtomicMetadataFileSystemError.removeFailed
            }
        } catch {
            throw ProtectedAtomicMetadataFileSystemError.removeFailed
        }

        let removed = try remove(
            fileName: path.fileName,
            from: directory.rawValue
        )
        guard removed else {
            return
        }
        // The unlink is the mutation commit point; directory sync is best effort.
        synchronizeBestEffort(directory.rawValue)
    }

    private func createDirectoryIfNeeded(
        at directoryURL: URL,
        protection: ProtectedAtomicMetadataFilePolicy.FileProtection
    ) throws {
        let attributes: [FileAttributeKey: Any]
        switch protection {
        case .complete:
            attributes = [.protectionKey: FileProtectionType.complete]
        }

        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: attributes
            )
        } catch {
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }
    }

    private func openDirectoryIfPresent(at directoryURL: URL) throws -> DirectoryDescriptor? {
        let descriptor = directoryURL.path.withCString { path in
            Darwin.open(path, O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            if errno == ENOENT {
                return nil
            }
            throw ProtectedAtomicMetadataFileSystemError.invalidLocation
        }

        let fileDescriptor = FileDescriptor(rawValue: descriptor)
        let openedStatus = try status(of: descriptor, failure: .invalidLocation)
        guard (openedStatus.st_mode & S_IFMT) == S_IFDIR else {
            throw ProtectedAtomicMetadataFileSystemError.invalidLocation
        }
        try validateDirectoryIdentity(
            at: directoryURL,
            expected: FileIdentity(openedStatus)
        )
        return DirectoryDescriptor(
            fileDescriptor: fileDescriptor,
            identity: FileIdentity(openedStatus)
        )
    }

    private func openDirectoryIfPresentForRemoval(
        at directoryURL: URL
    ) throws -> DirectoryDescriptor? {
        do {
            return try openDirectoryIfPresent(at: directoryURL)
        } catch {
            throw ProtectedAtomicMetadataFileSystemError.removeFailed
        }
    }

    private func validateDirectoryIdentity(
        at directoryURL: URL,
        expected: FileIdentity
    ) throws {
        var pathStatus = stat()
        let result = directoryURL.path.withCString { path in
            Darwin.lstat(path, &pathStatus)
        }
        guard result == 0,
              (pathStatus.st_mode & S_IFMT) == S_IFDIR,
              FileIdentity(pathStatus) == expected else {
            throw ProtectedAtomicMetadataFileSystemError.invalidLocation
        }
    }

    private func statusIfPresent(
        named fileName: String,
        in directoryFileDescriptor: Int32,
        failure: ProtectedAtomicMetadataFileSystemError
    ) throws -> stat? {
        var fileStatus = stat()
        let result = fileName.withCString { name in
            Darwin.fstatat(
                directoryFileDescriptor,
                name,
                &fileStatus,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard result == 0 else {
            if errno == ENOENT {
                return nil
            }
            throw failure
        }
        return fileStatus
    }

    private func status(
        of fileDescriptor: Int32,
        failure: ProtectedAtomicMetadataFileSystemError
    ) throws -> stat {
        var fileStatus = stat()
        guard Darwin.fstat(fileDescriptor, &fileStatus) == 0 else {
            throw failure
        }
        return fileStatus
    }

    private func validateRegularFile(_ fileStatus: stat) throws {
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG,
              fileStatus.st_nlink == 1 else {
            throw ProtectedAtomicMetadataFileSystemError.invalidFileType
        }
    }

    private func openRegularFileForReading(
        named fileName: String,
        in directoryFileDescriptor: Int32
    ) throws -> FileDescriptor {
        let descriptor = fileName.withCString { name in
            Darwin.openat(
                directoryFileDescriptor,
                name,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
        }
        guard descriptor >= 0 else {
            throw ProtectedAtomicMetadataFileSystemError.readFailed
        }
        return FileDescriptor(rawValue: descriptor)
    }

    private func createTemporaryFile(
        named fileName: String,
        in directoryFileDescriptor: Int32
    ) throws -> FileDescriptor {
        let descriptor = fileName.withCString { name in
            Darwin.openat(
                directoryFileDescriptor,
                name,
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                S_IRUSR | S_IWUSR
            )
        }
        guard descriptor >= 0 else {
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }
        return FileDescriptor(rawValue: descriptor)
    }

    private func openRegularFileForRemoval(
        named fileName: String,
        in directoryFileDescriptor: Int32
    ) throws -> FileDescriptor? {
        let descriptor = fileName.withCString { name in
            Darwin.openat(
                directoryFileDescriptor,
                name,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
        }
        guard descriptor >= 0 else {
            if errno == ENOENT {
                return nil
            }
            throw ProtectedAtomicMetadataFileSystemError.removeFailed
        }
        return FileDescriptor(rawValue: descriptor)
    }

    private func applyMetadata(
        to temporaryURL: URL,
        descriptor: Int32,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws {
        guard Darwin.fchmod(descriptor, S_IRUSR | S_IWUSR) == 0 else {
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }

        let attributes: [FileAttributeKey: Any]
        switch policy.fileProtection {
        case .complete:
            attributes = [.protectionKey: FileProtectionType.complete]
        }

        do {
            try FileManager.default.setAttributes(
                attributes,
                ofItemAtPath: temporaryURL.path
            )
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = policy.excludesFromBackup
            var mutableTemporaryURL = temporaryURL
            try mutableTemporaryURL.setResourceValues(resourceValues)
        } catch {
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }
    }

    private func validateOwnedTemporaryFile(
        descriptor: Int32,
        named fileName: String,
        identity: FileIdentity,
        in directoryFileDescriptor: Int32,
        expectedByteCount: Int
    ) throws {
        let descriptorStatus = try status(of: descriptor, failure: .writeFailed)
        guard let pathStatus = try statusIfPresent(
            named: fileName,
            in: directoryFileDescriptor,
            failure: .writeFailed
        ) else {
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }

        guard (descriptorStatus.st_mode & S_IFMT) == S_IFREG,
              descriptorStatus.st_nlink == 1,
              (pathStatus.st_mode & S_IFMT) == S_IFREG,
              pathStatus.st_nlink == 1,
              FileIdentity(descriptorStatus) == identity,
              FileIdentity(pathStatus) == identity,
              descriptorStatus.st_uid == geteuid(),
              descriptorStatus.st_size == off_t(expectedByteCount),
              descriptorStatus.st_mode & (S_IRWXG | S_IRWXO) == 0 else {
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }
    }

    private func validateDestinationIsUnchanged(
        originalStatus: stat?,
        named fileName: String,
        in directoryFileDescriptor: Int32
    ) throws {
        let currentStatus = try statusIfPresent(
            named: fileName,
            in: directoryFileDescriptor,
            failure: .writeFailed
        )
        if let currentStatus {
            try validateRegularFile(currentStatus)
        }

        let originalSnapshot = originalStatus.map(FileSnapshot.init)
        let currentSnapshot = currentStatus.map(FileSnapshot.init)
        guard originalSnapshot == currentSnapshot else {
            throw ProtectedAtomicMetadataFileSystemError.writeFailed
        }
    }

    private func read(
        from fileDescriptor: Int32,
        into buffer: inout [UInt8],
        byteCount: Int
    ) throws -> Int {
        var interruptedRetryCount = 0
        while true {
            let result = buffer.withUnsafeMutableBytes { bytes in
                operations.read(fileDescriptor, bytes.baseAddress, byteCount)
            }
            switch result {
            case .byteCount(let transferredByteCount):
                guard transferredByteCount >= 0,
                      transferredByteCount <= byteCount else {
                    throw ProtectedAtomicMetadataFileSystemError.readFailed
                }
                return transferredByteCount
            case .interrupted where interruptedRetryCount < Self.maximumInterruptedRetryCount:
                interruptedRetryCount += 1
            case .interrupted, .failed:
                throw ProtectedAtomicMetadataFileSystemError.readFailed
            }
        }
    }

    private func write(_ data: Data, to fileDescriptor: Int32) throws {
        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return
            }

            var writtenByteCount = 0
            var interruptedRetryCount = 0
            while writtenByteCount < bytes.count {
                let result = operations.write(
                    fileDescriptor,
                    baseAddress.advanced(by: writtenByteCount),
                    bytes.count - writtenByteCount
                )
                switch result {
                case .byteCount(let transferredByteCount)
                    where transferredByteCount > 0 &&
                        transferredByteCount <= bytes.count - writtenByteCount:
                    writtenByteCount += transferredByteCount
                    interruptedRetryCount = 0
                case .interrupted
                    where interruptedRetryCount < Self.maximumInterruptedRetryCount:
                    interruptedRetryCount += 1
                case .byteCount, .interrupted, .failed:
                    throw ProtectedAtomicMetadataFileSystemError.writeFailed
                }
            }
        }
    }

    private func synchronize(
        _ fileDescriptor: Int32,
        failure: ProtectedAtomicMetadataFileSystemError
    ) throws {
        var interruptedRetryCount = 0
        while true {
            switch operations.synchronize(fileDescriptor) {
            case .success:
                return
            case .interrupted where interruptedRetryCount < Self.maximumInterruptedRetryCount:
                interruptedRetryCount += 1
            case .interrupted, .missing, .failed:
                throw failure
            }
        }
    }

    private func runPrewriteCheckpoint(
        temporaryName: String,
        in directoryFileDescriptor: Int32
    ) throws {
        var interruptedRetryCount = 0
        while true {
            switch operations.prewriteCheckpoint(
                directoryFileDescriptor,
                temporaryName
            ) {
            case .success:
                return
            case .interrupted where interruptedRetryCount < Self.maximumInterruptedRetryCount:
                interruptedRetryCount += 1
            case .interrupted, .missing, .failed:
                throw ProtectedAtomicMetadataFileSystemError.writeFailed
            }
        }
    }

    private func publish(
        temporaryName: String,
        destinationName: String,
        in directoryFileDescriptor: Int32
    ) throws {
        var interruptedRetryCount = 0
        while true {
            switch operations.publish(
                directoryFileDescriptor,
                temporaryName,
                destinationName
            ) {
            case .success:
                return
            case .interrupted where interruptedRetryCount < Self.maximumInterruptedRetryCount:
                interruptedRetryCount += 1
            case .interrupted, .missing, .failed:
                throw ProtectedAtomicMetadataFileSystemError.writeFailed
            }
        }
    }

    private func remove(
        fileName: String,
        from directoryFileDescriptor: Int32
    ) throws -> Bool {
        var interruptedRetryCount = 0
        while true {
            switch operations.remove(directoryFileDescriptor, fileName) {
            case .success:
                return true
            case .missing:
                return false
            case .interrupted where interruptedRetryCount < Self.maximumInterruptedRetryCount:
                interruptedRetryCount += 1
            case .interrupted, .failed:
                throw ProtectedAtomicMetadataFileSystemError.removeFailed
            }
        }
    }

    private func synchronizeBestEffort(_ fileDescriptor: Int32) {
        var interruptedRetryCount = 0
        while interruptedRetryCount <= Self.maximumInterruptedRetryCount {
            switch operations.synchronize(fileDescriptor) {
            case .success, .missing, .failed:
                return
            case .interrupted:
                interruptedRetryCount += 1
            }
        }
    }

    private func removeOwnedTemporaryFileIfPresent(
        named fileName: String,
        identity: FileIdentity,
        from directoryFileDescriptor: Int32
    ) {
        guard let fileStatus = try? statusIfPresent(
            named: fileName,
            in: directoryFileDescriptor,
            failure: .writeFailed
        ), FileIdentity(fileStatus) == identity else {
            return
        }

        var interruptedRetryCount = 0
        while interruptedRetryCount <= Self.maximumInterruptedRetryCount {
            switch operations.remove(directoryFileDescriptor, fileName) {
            case .success, .missing, .failed:
                return
            case .interrupted:
                interruptedRetryCount += 1
            }
        }
    }
}

private struct MetadataPath {
    let directoryURL: URL
    let fileName: String

    init(fileURL: URL) throws {
        let fileName = fileURL.lastPathComponent
        guard fileURL.isFileURL,
              !fileName.isEmpty,
              fileName != ".",
              fileName != "..",
              !fileName.contains("/") else {
            throw ProtectedAtomicMetadataFileSystemError.invalidLocation
        }

        self.directoryURL = fileURL.deletingLastPathComponent()
        self.fileName = fileName
    }
}

private struct FileIdentity: Equatable {
    let device: dev_t
    let inode: ino_t

    init(_ fileStatus: stat) {
        device = fileStatus.st_dev
        inode = fileStatus.st_ino
    }
}

private struct FileSnapshot: Equatable {
    let identity: FileIdentity
    let byteCount: off_t
    let modificationSeconds: time_t
    let modificationNanoseconds: Int
    let statusChangeSeconds: time_t
    let statusChangeNanoseconds: Int

    init(_ fileStatus: stat) {
        identity = FileIdentity(fileStatus)
        byteCount = fileStatus.st_size
        modificationSeconds = fileStatus.st_mtimespec.tv_sec
        modificationNanoseconds = fileStatus.st_mtimespec.tv_nsec
        statusChangeSeconds = fileStatus.st_ctimespec.tv_sec
        statusChangeNanoseconds = fileStatus.st_ctimespec.tv_nsec
    }
}

private final class FileDescriptor {
    let rawValue: Int32

    init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    deinit {
        Darwin.close(rawValue)
    }
}

private struct DirectoryDescriptor {
    private let fileDescriptor: FileDescriptor
    let identity: FileIdentity

    var rawValue: Int32 {
        fileDescriptor.rawValue
    }

    init(fileDescriptor: FileDescriptor, identity: FileIdentity) {
        self.fileDescriptor = fileDescriptor
        self.identity = identity
    }
}
