import Darwin
import Foundation

nonisolated struct POSIXOpenAITranscriptionMultipartFileSystem: OpenAITranscriptionMultipartFileSystem {
    private let calls: any OpenAITranscriptionPOSIXCalling

    init(
        calls: any OpenAITranscriptionPOSIXCalling =
            DarwinOpenAITranscriptionPOSIXCalls()
    ) {
        self.calls = calls
    }

    func openAudioSource(at fileURL: URL) throws -> any OpenAITranscriptionAudioSource {
        try fileURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { throw OpenAITranscriptionMultipartFileSystemError.invalidSource }
            var pathStatus = stat()
            guard Darwin.lstat(path, &pathStatus) == 0 else {
                if errno == ENOENT { throw OpenAITranscriptionMultipartFileSystemError.missingSource }
                throw OpenAITranscriptionMultipartFileSystemError.invalidSource
            }
            guard isRegular(pathStatus), !isSymbolicLink(pathStatus) else {
                throw OpenAITranscriptionMultipartFileSystemError.invalidSource
            }
            let fd = Darwin.open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
            guard fd >= 0 else {
                if errno == ENOENT { throw OpenAITranscriptionMultipartFileSystemError.missingSource }
                throw OpenAITranscriptionMultipartFileSystemError.invalidSource
            }
            var descriptorStatus = stat()
            guard Darwin.fstat(fd, &descriptorStatus) == 0,
                  isRegular(descriptorStatus),
                  fileIdentity(pathStatus) == fileIdentity(descriptorStatus) else {
                Darwin.close(fd)
                throw OpenAITranscriptionMultipartFileSystemError.invalidSource
            }
            return POSIXOpenAITranscriptionAudioSource(
                fileURL: fileURL,
                fileDescriptor: fd,
                identity: fileIdentity(descriptorStatus),
                calls: calls
            )
        }
    }

    func createScratchFile(at fileURL: URL) throws -> any OpenAITranscriptionScratchFile {
        let directoryURL = fileURL.deletingLastPathComponent()
        guard let identifier = OpenAIMultipartScratchNamespace.identifier(
            inV1FileName: fileURL.lastPathComponent
        ) else {
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        let stagingName = OpenAIMultipartScratchNamespace.legacyFileName(
            for: identifier
        )
        let finalName = OpenAIMultipartScratchNamespace.v1FileName(
            for: identifier
        )
        guard fileURL.lastPathComponent == finalName else {
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        try ensurePrivateDirectory(directoryURL)
        let directoryDescriptor = try openPrivateDirectory(directoryURL)
        defer { Darwin.close(directoryDescriptor) }

        let fd = stagingName.withCString { name in
            Darwin.openat(
                directoryDescriptor,
                name,
                O_WRONLY | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                0o600
            )
        }
        guard fd >= 0 else {
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        var published = false
        var createdStatus = stat()
        guard Darwin.fstat(fd, &createdStatus) == 0,
              isRegular(createdStatus),
              createdStatus.st_uid == geteuid(),
              createdStatus.st_nlink == 1,
              createdStatus.st_size == 0 else {
            Darwin.close(fd)
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        let createdIdentity = fileIdentity(createdStatus)
        guard calls.lockMultipartScratch(on: fd) else {
            unlinkScratchIfMatching(
                stagingName,
                in: directoryDescriptor,
                identity: createdIdentity
            )
            Darwin.close(fd)
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        guard Darwin.fchmod(fd, 0o600) == 0 else {
            unlinkScratchIfMatching(
                stagingName,
                in: directoryDescriptor,
                identity: createdIdentity
            )
            Darwin.close(fd)
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        do {
            guard calls.applyPrivateMultipartScratchConfiguration(on: fd),
                  calls.hasExactPrivateMultipartScratchConfiguration(on: fd),
                  calls.installMultipartScratchMarker(on: fd) else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            var descriptorStatus = stat()
            guard let stagingStatus = try statusIfPresent(
                named: stagingName,
                in: directoryDescriptor
            ),
                  Darwin.fstat(fd, &descriptorStatus) == 0,
                  isPrivateScratch(descriptorStatus),
                  isPrivateScratch(stagingStatus),
                  fileIdentity(stagingStatus) == fileIdentity(descriptorStatus),
                  calls.hasExactPrivateMultipartScratchConfiguration(on: fd),
                  calls.hasExactMultipartScratchMarker(on: fd),
                  calls.publishMultipartScratch(
                      in: directoryDescriptor,
                      from: stagingName,
                      to: finalName
                  ) else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            published = true

            var publishedDescriptorStatus = stat()
            guard let publishedPathStatus = try statusIfPresent(
                named: finalName,
                in: directoryDescriptor
            ),
                  Darwin.fstat(fd, &publishedDescriptorStatus) == 0,
                  isPrivateScratch(publishedDescriptorStatus),
                  isPrivateScratch(publishedPathStatus),
                  fileIdentity(publishedPathStatus)
                    == fileIdentity(publishedDescriptorStatus),
                  calls.hasExactPrivateMultipartScratchConfiguration(on: fd),
                  calls.hasExactMultipartScratchMarker(on: fd),
                  try statusIfPresent(
                      named: stagingName,
                      in: directoryDescriptor
                  ) == nil else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            return POSIXOpenAITranscriptionScratchFile(
                fileURL: fileURL,
                fileDescriptor: fd,
                identity: fileIdentity(publishedDescriptorStatus),
                calls: calls
            )
        } catch {
            if published {
                unlinkScratchIfMatching(
                    finalName,
                    in: directoryDescriptor,
                    identity: createdIdentity
                )
            }
            unlinkScratchIfMatching(
                stagingName,
                in: directoryDescriptor,
                identity: createdIdentity
            )
            Darwin.close(fd)
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
    }

    private func ensurePrivateDirectory(_ directoryURL: URL) throws {
        try directoryURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable }
            if Darwin.mkdir(path, 0o700) != 0, errno != EEXIST {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            var status = stat()
            guard Darwin.lstat(path, &status) == 0,
                  status.st_mode & S_IFMT == S_IFDIR,
                  status.st_uid == geteuid() else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            guard Darwin.chmod(path, 0o700) == 0 else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            try Self.applyPrivateDirectoryResourceValues(directoryURL)
            var protectedStatus = stat()
            guard Darwin.lstat(path, &protectedStatus) == 0,
                  protectedStatus.st_mode & S_IFMT == S_IFDIR,
                  protectedStatus.st_uid == geteuid(),
                  protectedStatus.st_mode & mode_t(0o777) == mode_t(0o700) else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
        }
    }

    private static func applyPrivateDirectoryResourceValues(_ fileURL: URL) throws {
#if os(iOS)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: fileURL.path
        )
#endif
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = fileURL
        try mutableURL.setResourceValues(values)
    }

    private func openPrivateDirectory(_ directoryURL: URL) throws -> Int32 {
        try directoryURL.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            let descriptor = Darwin.open(
                path,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
            guard descriptor >= 0 else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            var status = stat()
            guard Darwin.fstat(descriptor, &status) == 0,
                  status.st_mode & S_IFMT == S_IFDIR,
                  status.st_uid == geteuid(),
                  status.st_mode & mode_t(0o777) == mode_t(0o700) else {
                Darwin.close(descriptor)
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            return descriptor
        }
    }

    private func statusIfPresent(
        named fileName: String,
        in directoryFileDescriptor: Int32
    ) throws -> stat? {
        var status = stat()
        let result = fileName.withCString { name in
            Darwin.fstatat(
                directoryFileDescriptor,
                name,
                &status,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard result == 0 else {
            if errno == ENOENT {
                return nil
            }
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        return status
    }

    private func unlinkScratchIfMatching(
        _ fileName: String,
        in directoryFileDescriptor: Int32,
        identity: OpenAITranscriptionFileIdentity
    ) {
        let candidateStatus: stat?
        do {
            candidateStatus = try statusIfPresent(
                named: fileName,
                in: directoryFileDescriptor
            )
        } catch {
            return
        }
        guard let status = candidateStatus,
              isRegular(status),
              status.st_uid == geteuid(),
              UInt64(status.st_dev) == identity.device,
              UInt64(status.st_ino) == identity.inode else {
            return
        }
        var result: Int32
        repeat {
            result = fileName.withCString { name in
                Darwin.unlinkat(directoryFileDescriptor, name, 0)
            }
        } while result != 0 && errno == EINTR
    }
}

nonisolated private final class POSIXOpenAITranscriptionAudioSource:
    OpenAITranscriptionAudioSource,
    @unchecked Sendable {
    private struct State {
        var fileDescriptor: Int32?
        var activeOperationCount = 0
        var closeRequested = false
    }

    let identity: OpenAITranscriptionFileIdentity
    private let fileURL: URL
    private let calls: any OpenAITranscriptionPOSIXCalling
    private let lock = NSLock()
    private var state: State

    init(
        fileURL: URL,
        fileDescriptor: Int32,
        identity: OpenAITranscriptionFileIdentity,
        calls: any OpenAITranscriptionPOSIXCalling
    ) {
        self.fileURL = fileURL
        self.identity = identity
        self.calls = calls
        state = State(fileDescriptor: fileDescriptor)
    }

    func read(upToCount count: Int) throws -> Data {
        guard count > 0 else { return Data() }
        let fd = try beginDescriptorUse(
            failure: OpenAITranscriptionMultipartFileSystemError.sourceReadFailed
        )
        defer { finishDescriptorUse() }

        var data = Data(count: count)
        let result = data.withUnsafeMutableBytes { bytes -> Int in
            guard let base = bytes.baseAddress else { return 0 }
            while true {
                let result = calls.read(fd, base, count)
                if result < 0, errno == EINTR { continue }
                return result
            }
        }
        guard result >= 0, result <= count else {
            throw OpenAITranscriptionMultipartFileSystemError.sourceReadFailed
        }
        data.count = result
        return data
    }

    func validateUnchanged() throws {
        let fd = try beginDescriptorUse(
            failure: OpenAITranscriptionMultipartFileSystemError.sourceChanged
        )
        defer { finishDescriptorUse() }

        var descriptorStatus = stat()
        guard Darwin.fstat(fd, &descriptorStatus) == 0,
              fileIdentity(descriptorStatus) == identity else {
            throw OpenAITranscriptionMultipartFileSystemError.sourceChanged
        }
        try fileURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { throw OpenAITranscriptionMultipartFileSystemError.sourceChanged }
            var pathStatus = stat()
            guard Darwin.lstat(path, &pathStatus) == 0,
                  fileIdentity(pathStatus) == identity else {
                throw OpenAITranscriptionMultipartFileSystemError.sourceChanged
            }
        }
    }

    func close() {
        let descriptor = lock.withLock { () -> Int32? in
            state.closeRequested = true
            guard state.activeOperationCount == 0 else { return nil }
            let descriptor = state.fileDescriptor
            state.fileDescriptor = nil
            return descriptor
        }
        if let descriptor { Darwin.close(descriptor) }
    }

    private func beginDescriptorUse(failure: Error) throws -> Int32 {
        try lock.withLock {
            guard !state.closeRequested, let descriptor = state.fileDescriptor else {
                throw failure
            }
            state.activeOperationCount += 1
            return descriptor
        }
    }

    private func finishDescriptorUse() {
        let descriptor = lock.withLock { () -> Int32? in
            state.activeOperationCount -= 1
            guard state.activeOperationCount == 0, state.closeRequested else { return nil }
            let descriptor = state.fileDescriptor
            state.fileDescriptor = nil
            return descriptor
        }
        if let descriptor { Darwin.close(descriptor) }
    }

    deinit { close() }
}

nonisolated private final class POSIXOpenAITranscriptionScratchFile:
    OpenAITranscriptionScratchFile,
    @unchecked Sendable {
    private struct State {
        var fileDescriptor: Int32?
        var activeOperationCount = 0
        var closeRequested = false
    }

    private enum UnlinkState: Equatable {
        case available
        case inProgress
        case complete
    }

    let fileURL: URL
    private let identity: OpenAITranscriptionFileIdentity
    private let calls: any OpenAITranscriptionPOSIXCalling
    private let lock = NSLock()
    private var state: State
    private var unlinkState = UnlinkState.available

    init(
        fileURL: URL,
        fileDescriptor: Int32,
        identity: OpenAITranscriptionFileIdentity,
        calls: any OpenAITranscriptionPOSIXCalling
    ) {
        self.fileURL = fileURL
        self.identity = identity
        self.calls = calls
        state = State(fileDescriptor: fileDescriptor)
    }

    func writeAll(_ data: Data) throws {
        let fd = try beginDescriptorUse()
        defer { finishDescriptorUse() }

        try data.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            var offset = 0
            while offset < bytes.count {
                let written = calls.write(fd, base.advanced(by: offset), bytes.count - offset)
                if written < 0, errno == EINTR { continue }
                guard written > 0, written <= bytes.count - offset else {
                    throw OpenAITranscriptionMultipartFileSystemError.scratchWriteFailed
                }
                offset += written
            }
        }
    }

    func synchronizeAndValidate(expectedByteCount: Int64) throws {
        let fd = try beginDescriptorUse()
        defer { finishDescriptorUse() }

        while calls.synchronize(fd) != 0 {
            if errno == EINTR { continue }
            throw OpenAITranscriptionMultipartFileSystemError.scratchWriteFailed
        }
        try Task.checkCancellation()
        try validateWriterAndPath(fd: fd, expectedByteCount: expectedByteCount)
        try Task.checkCancellation()
    }

    func pinFinalizedUploadArtifact(
        expectedByteCount: Int64
    ) throws -> any OpenAIFileUploadBody {
        guard claimUnlink() else {
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }

        var shouldRestoreUnlink = true
        var readDescriptor: Int32 = -1
        defer {
            if readDescriptor >= 0 { Darwin.close(readDescriptor) }
            if shouldRestoreUnlink { finishUnlink(completed: false) }
        }

        let writerDescriptor = try beginDescriptorUse()
        defer { finishDescriptorUse() }
        try Task.checkCancellation()
        try validateWriterAndPath(
            fd: writerDescriptor,
            expectedByteCount: expectedByteCount
        )
        try Task.checkCancellation()

        readDescriptor = try fileURL.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            let descriptor = Darwin.open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK)
            guard descriptor >= 0 else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            return descriptor
        }
        try Task.checkCancellation()

        var writerStatus = stat()
        var readerStatus = stat()
        guard Darwin.fstat(writerDescriptor, &writerStatus) == 0,
              Darwin.fstat(readDescriptor, &readerStatus) == 0,
              matchesOwnedScratch(writerStatus, expectedByteCount: expectedByteCount),
              matchesOwnedScratch(readerStatus, expectedByteCount: expectedByteCount),
              sameFile(writerStatus, readerStatus) else {
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        try Task.checkCancellation()

        try fileURL.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            var pathStatus = stat()
            guard Darwin.lstat(path, &pathStatus) == 0,
                  matchesOwnedScratch(pathStatus, expectedByteCount: expectedByteCount),
                  sameFile(writerStatus, pathStatus),
                  sameFile(readerStatus, pathStatus) else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
            try Task.checkCancellation()

            var unlinkResult: Int32
            repeat {
                unlinkResult = Darwin.unlink(path)
            } while unlinkResult != 0 && errno == EINTR
            guard unlinkResult == 0 else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
            }
        }

        finishUnlink(completed: true)
        shouldRestoreUnlink = false
        try Task.checkCancellation()

        var pinnedStatus = stat()
        guard Darwin.fstat(readDescriptor, &pinnedStatus) == 0,
              matchesOwnedScratch(
                  pinnedStatus,
                  expectedByteCount: expectedByteCount,
                  expectedLinkCount: 0
              ),
              sameFile(readerStatus, pinnedStatus) else {
            throw OpenAITranscriptionMultipartFileSystemError.scratchUnavailable
        }
        try Task.checkCancellation()

        let artifact = OpenAITranscriptionMultipartUploadArtifact(
            fileDescriptor: readDescriptor,
            identity: fileIdentity(pinnedStatus),
            calls: calls
        )
        readDescriptor = -1
        return artifact
    }

    func close() {
        let descriptor = lock.withLock { () -> Int32? in
            state.closeRequested = true
            guard state.activeOperationCount == 0 else { return nil }
            let descriptor = state.fileDescriptor
            state.fileDescriptor = nil
            return descriptor
        }
        if let descriptor { Darwin.close(descriptor) }
    }

    func unlinkIfOwned() {
        guard claimUnlink() else { return }
        var completed = false
        fileURL.withUnsafeFileSystemRepresentation { path in
            guard let path else { return }
            var status = stat()
            var statusResult: Int32
            repeat {
                statusResult = Darwin.lstat(path, &status)
            } while statusResult != 0 && errno == EINTR
            guard statusResult == 0 else {
                completed = errno == ENOENT
                return
            }
            guard isRegular(status),
                  UInt64(status.st_dev) == identity.device,
                  UInt64(status.st_ino) == identity.inode else {
                completed = true
                return
            }
            var unlinkResult: Int32
            repeat {
                unlinkResult = Darwin.unlink(path)
            } while unlinkResult != 0 && errno == EINTR
            completed = unlinkResult == 0 || errno == ENOENT
        }
        finishUnlink(completed: completed)
    }

    private func beginDescriptorUse() throws -> Int32 {
        try lock.withLock {
            guard !state.closeRequested, let descriptor = state.fileDescriptor else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchWriteFailed
            }
            state.activeOperationCount += 1
            return descriptor
        }
    }

    private func finishDescriptorUse() {
        let descriptor = lock.withLock { () -> Int32? in
            state.activeOperationCount -= 1
            guard state.activeOperationCount == 0, state.closeRequested else { return nil }
            let descriptor = state.fileDescriptor
            state.fileDescriptor = nil
            return descriptor
        }
        if let descriptor { Darwin.close(descriptor) }
    }

    private func validateWriterAndPath(
        fd: Int32,
        expectedByteCount: Int64
    ) throws {
        var descriptorStatus = stat()
        guard Darwin.fstat(fd, &descriptorStatus) == 0,
              matchesOwnedScratch(descriptorStatus, expectedByteCount: expectedByteCount) else {
            throw OpenAITranscriptionMultipartFileSystemError.scratchWriteFailed
        }
        try fileURL.withUnsafeFileSystemRepresentation { path in
            guard let path else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchWriteFailed
            }
            var pathStatus = stat()
            guard Darwin.lstat(path, &pathStatus) == 0,
                  matchesOwnedScratch(pathStatus, expectedByteCount: expectedByteCount),
                  sameFile(descriptorStatus, pathStatus) else {
                throw OpenAITranscriptionMultipartFileSystemError.scratchWriteFailed
            }
        }
    }

    private func claimUnlink() -> Bool {
        lock.withLock {
            guard unlinkState == .available else { return false }
            unlinkState = .inProgress
            return true
        }
    }

    private func finishUnlink(completed: Bool) {
        lock.withLock {
            unlinkState = completed ? .complete : .available
        }
    }

    private func matchesOwnedScratch(
        _ status: stat,
        expectedByteCount: Int64,
        expectedLinkCount: UInt16 = 1
    ) -> Bool {
        isRegular(status)
            && status.st_uid == geteuid()
            && status.st_mode & mode_t(0o777) == mode_t(0o600)
            && Int64(status.st_size) == expectedByteCount
            && status.st_nlink == expectedLinkCount
    }

    private func sameFile(_ left: stat, _ right: stat) -> Bool {
        left.st_dev == right.st_dev && left.st_ino == right.st_ino
    }

    deinit {
        unlinkIfOwned()
        close()
    }
}

nonisolated func isRegular(_ status: stat) -> Bool { status.st_mode & S_IFMT == S_IFREG }
nonisolated private func isSymbolicLink(_ status: stat) -> Bool { status.st_mode & S_IFMT == S_IFLNK }
nonisolated private func isPrivateScratch(_ status: stat) -> Bool {
    isRegular(status)
        && status.st_uid == geteuid()
        && status.st_mode & mode_t(0o777) == mode_t(0o600)
        && status.st_size == 0
        && status.st_nlink == 1
}
nonisolated func fileIdentity(_ status: stat) -> OpenAITranscriptionFileIdentity {
    OpenAITranscriptionFileIdentity(
        device: UInt64(status.st_dev),
        inode: UInt64(status.st_ino),
        byteCount: Int64(status.st_size),
        modificationSeconds: Int64(status.st_mtimespec.tv_sec),
        modificationNanoseconds: Int64(status.st_mtimespec.tv_nsec),
        changeSeconds: Int64(status.st_ctimespec.tv_sec),
        changeNanoseconds: Int64(status.st_ctimespec.tv_nsec)
    )
}
