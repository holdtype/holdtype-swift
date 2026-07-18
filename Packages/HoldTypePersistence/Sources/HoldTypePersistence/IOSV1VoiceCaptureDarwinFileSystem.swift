import Darwin
import Foundation

struct IOSV1VoiceCaptureDarwinFileSystem: IOSV1VoiceCaptureFileSystem {
    func create(
        attemptID: UUID,
        directoryURL: URL,
        fileName: String
    ) throws -> IOSV1VoiceCaptureFileHandle {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [
                .posixPermissions: NSNumber(value: Int16(0o700)),
                .protectionKey: FileProtectionType.complete,
            ]
        )
        var directoryResourceValues = URLResourceValues()
        directoryResourceValues.isExcludedFromBackup = true
        var protectedDirectoryURL = directoryURL
        try protectedDirectoryURL.setResourceValues(directoryResourceValues)
        let directory = Darwin.open(
            directoryURL.path,
            O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC
        )
        guard directory >= 0 else {
            throw IOSV1VoiceCaptureError.namespaceUnavailable
        }
        let file = fileName.withCString {
            Darwin.openat(
                directory,
                $0,
                O_RDWR | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
                mode_t(0o600)
            )
        }
        guard file >= 0 else {
            Darwin.close(directory)
            throw IOSV1VoiceCaptureError.sourceConflict
        }
        do {
            guard flock(file, LOCK_EX | LOCK_NB) == 0,
                  Darwin.fchmod(file, mode_t(0o600)) == 0 else {
                throw IOSV1VoiceCaptureError.sourceConflict
            }
            var fileURL = directoryURL.appendingPathComponent(fileName)
            try FileManager.default.setAttributes(
                [
                    .posixPermissions: NSNumber(value: Int16(0o600)),
                    .protectionKey: FileProtectionType.complete,
                ],
                ofItemAtPath: fileURL.path
            )
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try fileURL.setResourceValues(values)
            guard Darwin.fsync(file) == 0, Darwin.fsync(directory) == 0 else {
                throw IOSV1VoiceCaptureError.dataProtectionUnavailable
            }
            let directoryIdentity = try identity(directory, type: S_IFDIR)
            let identity = try identity(file, type: S_IFREG)
            let handle = IOSV1VoiceCaptureFileHandle(
                attemptID: attemptID,
                directoryDescriptor: directory,
                fileDescriptor: file,
                directoryURL: directoryURL,
                fileName: fileName,
                directoryIdentity: directoryIdentity,
                identity: identity
            )
            _ = try validate(handle)
            return handle
        } catch {
            Darwin.close(file)
            Darwin.close(directory)
            throw error
        }
    }

    func validate(
        _ handle: IOSV1VoiceCaptureFileHandle
    ) throws -> IOSV1VoiceCaptureFileFacts {
        var directoryStatus = stat()
        var directoryPathStatus = stat()
        var descriptorStatus = stat()
        var pathStatus = stat()
        guard Darwin.fstat(handle.directoryDescriptor, &directoryStatus) == 0,
              Darwin.lstat(handle.directoryURL.path, &directoryPathStatus) == 0,
              directoryStatus.st_mode & S_IFMT == S_IFDIR,
              directoryStatus.st_dev == directoryPathStatus.st_dev,
              directoryStatus.st_ino == directoryPathStatus.st_ino,
              IOSV1VoiceCaptureFileIdentity(
                  device: UInt64(directoryStatus.st_dev),
                  inode: UInt64(directoryStatus.st_ino)
              ) == handle.directoryIdentity,
              Darwin.fstat(handle.fileDescriptor, &descriptorStatus) == 0,
              handle.fileName.withCString({
                  Darwin.fstatat(
                      handle.directoryDescriptor,
                      $0,
                      &pathStatus,
                      AT_SYMLINK_NOFOLLOW
                  )
              }) == 0,
              descriptorStatus.st_mode & S_IFMT == S_IFREG,
              descriptorStatus.st_mode & mode_t(0o777) == mode_t(0o600),
              descriptorStatus.st_nlink == 1,
              descriptorStatus.st_dev == pathStatus.st_dev,
              descriptorStatus.st_ino == pathStatus.st_ino,
              IOSV1VoiceCaptureFileIdentity(
                  device: UInt64(descriptorStatus.st_dev),
                  inode: UInt64(descriptorStatus.st_ino)
              ) == handle.identity else {
            throw IOSV1VoiceCaptureError.sourceChanged
        }
        return IOSV1VoiceCaptureFileFacts(
            identity: handle.identity,
            byteCount: Int64(descriptorStatus.st_size),
            modificationSeconds: Int64(descriptorStatus.st_mtimespec.tv_sec),
            modificationNanoseconds: Int64(descriptorStatus.st_mtimespec.tv_nsec)
        )
    }

    func synchronize(_ handle: IOSV1VoiceCaptureFileHandle) throws {
        guard Darwin.fsync(handle.fileDescriptor) == 0 else {
            throw IOSV1VoiceCaptureError.sourceChanged
        }
    }

    func remove(_ handle: IOSV1VoiceCaptureFileHandle) throws {
        var before = stat()
        guard Darwin.fstat(handle.fileDescriptor, &before) == 0 else {
            throw IOSV1VoiceCaptureError.cleanupUncertain
        }
        if before.st_nlink == 0 {
            guard Darwin.fsync(handle.directoryDescriptor) == 0 else {
                throw IOSV1VoiceCaptureError.cleanupUncertain
            }
            return
        }
        _ = try validate(handle)
        let result = handle.fileName.withCString {
            Darwin.unlinkat(handle.directoryDescriptor, $0, 0)
        }
        guard result == 0 else {
            throw IOSV1VoiceCaptureError.cleanupUncertain
        }
        var status = stat()
        guard Darwin.fstat(handle.fileDescriptor, &status) == 0,
              status.st_nlink == 0,
              Darwin.fsync(handle.directoryDescriptor) == 0 else {
            throw IOSV1VoiceCaptureError.cleanupUncertain
        }
    }

    func close(_ handle: IOSV1VoiceCaptureFileHandle) {
        Darwin.close(handle.fileDescriptor)
        Darwin.close(handle.directoryDescriptor)
    }

    private func identity(_ descriptor: Int32, type: mode_t) throws
        -> IOSV1VoiceCaptureFileIdentity {
        var status = stat()
        guard Darwin.fstat(descriptor, &status) == 0,
              status.st_mode & S_IFMT == type else {
            throw IOSV1VoiceCaptureError.sourceChanged
        }
        return IOSV1VoiceCaptureFileIdentity(
            device: UInt64(status.st_dev),
            inode: UInt64(status.st_ino)
        )
    }
}
