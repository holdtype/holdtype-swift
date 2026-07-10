import Darwin
import Foundation
import Testing
@testable import HoldTypePersistence

struct ProtectedAtomicMetadataFileSystemTests {
    private let byteLimit = 32

    @Test func readAcceptsExactLimitAndRejectsOneByteMoreWithoutChangingSource() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem()
            let exactData = Data(repeating: 0x61, count: byteLimit)
            try exactData.write(to: fileURL)

            #expect(
                try fileSystem.readFileIfPresent(
                    at: fileURL,
                    policy: policy(maximumByteCount: byteLimit)
                ) == exactData
            )

            let oversizedData = Data(repeating: 0x62, count: byteLimit + 1)
            try oversizedData.write(to: fileURL)
            #expect(throws: ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded) {
                _ = try fileSystem.readFileIfPresent(
                    at: fileURL,
                    policy: policy(maximumByteCount: byteLimit)
                )
            }
            #expect(try Data(contentsOf: fileURL) == oversizedData)
        }
    }

    @Test func oversizedSaveStopsBeforeTempCreationAndPreservesDestination() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let originalData = Data("durable-record".utf8)
            try originalData.write(to: fileURL)
            let namesBeforeSave = try directoryNames(at: directoryURL)
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem()

            #expect(throws: ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded) {
                try fileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data(repeating: 0x63, count: byteLimit + 1),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }

            #expect(try Data(contentsOf: fileURL) == originalData)
            #expect(try directoryNames(at: directoryURL) == namesBeforeSave)
        }
    }

    @Test func oversizedSaveDoesNotCreateAMissingParentDirectory() throws {
        try withTemporaryDirectory { rootURL in
            let missingDirectoryURL = rootURL.appendingPathComponent(
                "missing",
                isDirectory: true
            )
            let fileURL = missingDirectoryURL.appendingPathComponent("record.json")
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem()

            #expect(throws: ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded) {
                try fileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data(repeating: 0x64, count: byteLimit + 1),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }

            #expect(!FileManager.default.fileExists(atPath: missingDirectoryURL.path))
        }
    }

    @Test func atomicSavePublishesOwnerOnlyProtectedBytesWithCallerBackupPolicy() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let expectedData = Data("new-record".utf8)
            let prewriteCheckCounter = LockedCounter()
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    prewriteCheckpoint: { _, temporaryName in
                        let temporaryURL = directoryURL.appendingPathComponent(
                            temporaryName
                        )
                        let attributes = try? FileManager.default.attributesOfItem(
                            atPath: temporaryURL.path
                        )
                        let protectionMatches: Bool
                        #if targetEnvironment(simulator)
                        if let protection = attributes?[.protectionKey] as? FileProtectionType {
                            protectionMatches = protection == .complete
                        } else {
                            // The simulator can omit the effective Data Protection
                            // class even after accepting the requested attribute.
                            protectionMatches = true
                        }
                        #else
                        protectionMatches =
                            attributes?[.protectionKey] as? FileProtectionType == .complete
                        #endif
                        guard let data = try? Data(contentsOf: temporaryURL),
                              data.isEmpty,
                              let attributes,
                              let permissions = attributes[.posixPermissions] as? NSNumber,
                              permissions.intValue & 0o077 == 0,
                              protectionMatches,
                              let backupExcluded = try? temporaryURL.resourceValues(
                                  forKeys: [.isExcludedFromBackupKey]
                              ).isExcludedFromBackup,
                              backupExcluded == true else {
                            return .failed
                        }
                        _ = prewriteCheckCounter.incrementAndGet()
                        return .success
                    }
                )
            )

            try fileSystem.replaceFileAtomically(
                at: fileURL,
                with: expectedData,
                policy: policy(maximumByteCount: byteLimit, excludesFromBackup: true)
            )

            #expect(try Data(contentsOf: fileURL) == expectedData)
            #expect(prewriteCheckCounter.value == 1)
            #expect(try directoryNames(at: directoryURL) == ["record.json"])
            let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            let permissions = try #require(attributes[.posixPermissions] as? NSNumber)
            #expect(permissions.intValue & 0o077 == 0)
            #expect(
                try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
                    .isExcludedFromBackup == true
            )

            #if targetEnvironment(simulator)
            if let protection = attributes[.protectionKey] as? FileProtectionType {
                #expect(protection == .complete)
            }
            #else
            #expect(attributes[.protectionKey] as? FileProtectionType == .complete)
            #endif
        }
    }

    @Test func failedPublishPreservesDestinationAndRemovesOwnedTemporaryFile() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let originalData = Data("durable-record".utf8)
            try originalData.write(to: fileURL)
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    publish: { _, _, _ in .failed }
                )
            )

            #expect(throws: ProtectedAtomicMetadataFileSystemError.writeFailed) {
                try fileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data("replacement".utf8),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }

            #expect(try Data(contentsOf: fileURL) == originalData)
            #expect(try directoryNames(at: directoryURL) == ["record.json"])
        }
    }

    @Test func failedPublishDoesNotRemoveARacedReplacementAtTheTemporaryName() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let originalData = Data("durable-record".utf8)
            try originalData.write(to: fileURL)
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    publish: { directoryFileDescriptor, temporaryName, _ in
                        _ = temporaryName.withCString { name in
                            Darwin.unlinkat(directoryFileDescriptor, name, 0)
                        }
                        _ = temporaryName.withCString { name in
                            "raced-sentinel".withCString { destination in
                                Darwin.symlinkat(destination, directoryFileDescriptor, name)
                            }
                        }
                        return .failed
                    }
                )
            )

            #expect(throws: ProtectedAtomicMetadataFileSystemError.writeFailed) {
                try fileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data("replacement".utf8),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }

            #expect(try Data(contentsOf: fileURL) == originalData)
            let temporaryNames = try directoryNames(at: directoryURL).filter {
                $0.hasPrefix(".record.json.") && $0.hasSuffix(".tmp")
            }
            let temporaryName = try #require(temporaryNames.first)
            let temporaryURL = directoryURL.appendingPathComponent(temporaryName)
            #expect(
                try FileManager.default.destinationOfSymbolicLink(
                    atPath: temporaryURL.path
                ) == "raced-sentinel"
            )
        }
    }

    @Test func symbolicLinksDirectoriesAndSpecialFilesAreRejectedWithoutMutation() throws {
        try withTemporaryDirectory { directoryURL in
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem()
            let sentinelURL = directoryURL.appendingPathComponent("sentinel")
            try Data("sentinel".utf8).write(to: sentinelURL)

            let symlinkURL = directoryURL.appendingPathComponent("symlink")
            try FileManager.default.createSymbolicLink(
                at: symlinkURL,
                withDestinationURL: sentinelURL
            )
            let nestedDirectoryURL = directoryURL.appendingPathComponent(
                "directory",
                isDirectory: true
            )
            try FileManager.default.createDirectory(
                at: nestedDirectoryURL,
                withIntermediateDirectories: false
            )
            let fifoURL = directoryURL.appendingPathComponent("fifo")
            let fifoResult = fifoURL.path.withCString { path in
                Darwin.mkfifo(path, S_IRUSR | S_IWUSR)
            }
            #expect(fifoResult == 0)

            for invalidURL in [symlinkURL, nestedDirectoryURL, fifoURL] {
                #expect(throws: ProtectedAtomicMetadataFileSystemError.invalidFileType) {
                    _ = try fileSystem.readFileIfPresent(
                        at: invalidURL,
                        policy: policy(maximumByteCount: byteLimit)
                    )
                }
                #expect(throws: ProtectedAtomicMetadataFileSystemError.invalidFileType) {
                    try fileSystem.replaceFileAtomically(
                        at: invalidURL,
                        with: Data("replacement".utf8),
                        policy: policy(maximumByteCount: byteLimit)
                    )
                }
                #expect(throws: ProtectedAtomicMetadataFileSystemError.removeFailed) {
                    try fileSystem.removeFileIfPresent(at: invalidURL)
                }
            }

            #expect(try Data(contentsOf: sentinelURL) == Data("sentinel".utf8))
            #expect(
                try FileManager.default.destinationOfSymbolicLink(
                    atPath: symlinkURL.path
                ) == sentinelURL.path
            )
            var isDirectory: ObjCBool = false
            #expect(
                FileManager.default.fileExists(
                    atPath: nestedDirectoryURL.path,
                    isDirectory: &isDirectory
                ) && isDirectory.boolValue
            )
        }
    }

    @Test func missingReadAndRemoveAreIdempotent() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("missing.json")
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem()

            #expect(
                try fileSystem.readFileIfPresent(
                    at: fileURL,
                    policy: policy(maximumByteCount: byteLimit)
                ) == nil
            )
            try fileSystem.removeFileIfPresent(at: fileURL)
            try fileSystem.removeFileIfPresent(at: fileURL)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func removalThatRacesAnotherSuccessfulRemovalRemainsSuccessful() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            try Data("record".utf8).write(to: fileURL)
            let live = ProtectedAtomicMetadataFileOperations.live
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    remove: { directoryFileDescriptor, fileName in
                        guard live.remove(directoryFileDescriptor, fileName) == .success else {
                            return .failed
                        }
                        return .missing
                    }
                )
            )

            try fileSystem.removeFileIfPresent(at: fileURL)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    @Test func sameSizeMutationDuringReadIsRejectedInsteadOfReturningStaleBytes() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let originalData = Data("aaaaaaaa".utf8)
            let mutatedData = Data("bbbbbbbb".utf8)
            try originalData.write(to: fileURL)
            let readCounter = LockedCounter()
            let live = ProtectedAtomicMetadataFileOperations.live
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    read: { fileDescriptor, buffer, byteCount in
                        let result = live.read(fileDescriptor, buffer, byteCount)
                        if case .byteCount(let transferredByteCount) = result,
                           transferredByteCount > 0,
                           readCounter.incrementAndGet() == 1 {
                            overwriteRegularFileInPlace(
                                at: fileURL,
                                with: mutatedData
                            )
                        }
                        return result
                    }
                )
            )

            #expect(throws: ProtectedAtomicMetadataFileSystemError.readFailed) {
                _ = try fileSystem.readFileIfPresent(
                    at: fileURL,
                    policy: policy(maximumByteCount: byteLimit)
                )
            }
            #expect(try Data(contentsOf: fileURL) == mutatedData)
        }
    }

    @Test func sameSizeDestinationMutationPreventsPublishAndPreservesRacedBytes() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let originalData = Data("old-record".utf8)
            let racedData = Data("new-raced!".utf8)
            #expect(originalData.count == racedData.count)
            try originalData.write(to: fileURL)
            let synchronizeCounter = LockedCounter()
            let live = ProtectedAtomicMetadataFileOperations.live
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    synchronize: { fileDescriptor in
                        let result = live.synchronize(fileDescriptor)
                        if result == .success,
                           synchronizeCounter.incrementAndGet() == 1 {
                            overwriteRegularFileInPlace(
                                at: fileURL,
                                with: racedData
                            )
                        }
                        return result
                    }
                )
            )

            #expect(throws: ProtectedAtomicMetadataFileSystemError.writeFailed) {
                try fileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data("replacement".utf8),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }

            #expect(try Data(contentsOf: fileURL) == racedData)
            #expect(try directoryNames(at: directoryURL) == ["record.json"])
        }
    }

    @Test func racedTemporaryReplacementIsNeverWrittenPublishedOrDeleted() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let sentinelURL = directoryURL.appendingPathComponent("sentinel")
            let originalData = Data("durable-record".utf8)
            let sentinelData = Data("sentinel-data".utf8)
            try originalData.write(to: fileURL)
            try sentinelData.write(to: sentinelURL)
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    prewriteCheckpoint: { directoryFileDescriptor, temporaryName in
                        _ = temporaryName.withCString { name in
                            Darwin.unlinkat(directoryFileDescriptor, name, 0)
                        }
                        _ = sentinelURL.path.withCString { destination in
                            temporaryName.withCString { name in
                                Darwin.symlinkat(
                                    destination,
                                    directoryFileDescriptor,
                                    name
                                )
                            }
                        }
                        return .success
                    }
                )
            )

            #expect(throws: ProtectedAtomicMetadataFileSystemError.writeFailed) {
                try fileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data("replacement".utf8),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }

            #expect(try Data(contentsOf: fileURL) == originalData)
            #expect(try Data(contentsOf: sentinelURL) == sentinelData)
            let temporaryNames = try directoryNames(at: directoryURL).filter {
                $0.hasPrefix(".record.json.") && $0.hasSuffix(".tmp")
            }
            let temporaryURL = directoryURL.appendingPathComponent(
                try #require(temporaryNames.first)
            )
            #expect(
                try FileManager.default.destinationOfSymbolicLink(
                    atPath: temporaryURL.path
                ) == sentinelURL.path
            )
        }
    }

    @Test func shortWritesAndInterruptionsAreRetriedWithoutChangingTheBytes() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let expectedData = Data("short-write-record".utf8)
            let writeCounter = LockedCounter()
            let live = ProtectedAtomicMetadataFileOperations.live
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    write: { fileDescriptor, buffer, byteCount in
                        if writeCounter.incrementAndGet() == 1 {
                            return .interrupted
                        }
                        return live.write(
                            fileDescriptor,
                            buffer,
                            min(byteCount, 2)
                        )
                    }
                )
            )

            try fileSystem.replaceFileAtomically(
                at: fileURL,
                with: expectedData,
                policy: policy(maximumByteCount: byteLimit)
            )

            #expect(try Data(contentsOf: fileURL) == expectedData)
            #expect(writeCounter.value > 2)
        }
    }

    @Test func readInterruptionIsRetriedWithinTheBound() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let expectedData = Data("read-record".utf8)
            try expectedData.write(to: fileURL)
            let readCounter = LockedCounter()
            let live = ProtectedAtomicMetadataFileOperations.live
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    read: { fileDescriptor, buffer, byteCount in
                        if readCounter.incrementAndGet() == 1 {
                            return .interrupted
                        }
                        return live.read(fileDescriptor, buffer, byteCount)
                    }
                )
            )

            #expect(
                try fileSystem.readFileIfPresent(
                    at: fileURL,
                    policy: policy(maximumByteCount: byteLimit)
                ) == expectedData
            )
        }
    }

    @Test func repeatedInterruptionsStopAtTheBoundAndPreserveDestination() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let originalData = Data("durable-record".utf8)
            try originalData.write(to: fileURL)
            let writeCounter = LockedCounter()
            let fileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    write: { _, _, _ in
                        _ = writeCounter.incrementAndGet()
                        return .interrupted
                    }
                )
            )

            #expect(throws: ProtectedAtomicMetadataFileSystemError.writeFailed) {
                try fileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data("replacement".utf8),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }

            #expect(writeCounter.value == 9)
            #expect(try Data(contentsOf: fileURL) == originalData)
            #expect(try directoryNames(at: directoryURL) == ["record.json"])
        }
    }

    @Test func zeroProgressAndPrecommitSyncFailurePreserveDestinationAndCleanTemp() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let originalData = Data("durable-record".utf8)
            try originalData.write(to: fileURL)

            let zeroProgressFileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    write: { _, _, _ in .byteCount(0) }
                )
            )
            #expect(throws: ProtectedAtomicMetadataFileSystemError.writeFailed) {
                try zeroProgressFileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data("replacement".utf8),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }
            #expect(try Data(contentsOf: fileURL) == originalData)
            #expect(try directoryNames(at: directoryURL) == ["record.json"])

            let syncFailureFileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    synchronize: { _ in .failed }
                )
            )
            #expect(throws: ProtectedAtomicMetadataFileSystemError.writeFailed) {
                try syncFailureFileSystem.replaceFileAtomically(
                    at: fileURL,
                    with: Data("replacement".utf8),
                    policy: policy(maximumByteCount: byteLimit)
                )
            }
            #expect(try Data(contentsOf: fileURL) == originalData)
            #expect(try directoryNames(at: directoryURL) == ["record.json"])
        }
    }

    @Test func postcommitDirectorySyncFailureCannotTurnCommittedMutationsIntoErrors() throws {
        try withTemporaryDirectory { directoryURL in
            let fileURL = directoryURL.appendingPathComponent("record.json")
            let originalData = Data("durable-record".utf8)
            let replacementData = Data("replacement".utf8)
            try originalData.write(to: fileURL)
            let synchronizeCounter = LockedCounter()
            let live = ProtectedAtomicMetadataFileOperations.live
            let saveFileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    synchronize: { fileDescriptor in
                        if synchronizeCounter.incrementAndGet() == 1 {
                            return live.synchronize(fileDescriptor)
                        }
                        return .failed
                    }
                )
            )

            try saveFileSystem.replaceFileAtomically(
                at: fileURL,
                with: replacementData,
                policy: policy(maximumByteCount: byteLimit)
            )
            #expect(try Data(contentsOf: fileURL) == replacementData)
            #expect(synchronizeCounter.value == 2)

            let removeFileSystem = FoundationProtectedAtomicMetadataFileSystem(
                operations: operations(
                    synchronize: { _ in .failed }
                )
            )
            try removeFileSystem.removeFileIfPresent(at: fileURL)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    private func policy(
        maximumByteCount: Int,
        excludesFromBackup: Bool = false
    ) -> ProtectedAtomicMetadataFilePolicy {
        ProtectedAtomicMetadataFilePolicy(
            maximumByteCount: maximumByteCount,
            fileProtection: .complete,
            excludesFromBackup: excludesFromBackup
        )
    }

    private func operations(
        read: ProtectedAtomicMetadataFileOperations.ReadOperation? = nil,
        write: ProtectedAtomicMetadataFileOperations.WriteOperation? = nil,
        synchronize: ProtectedAtomicMetadataFileOperations.SynchronizeOperation? = nil,
        publish: ProtectedAtomicMetadataFileOperations.PublishOperation? = nil,
        remove: ProtectedAtomicMetadataFileOperations.RemoveOperation? = nil,
        prewriteCheckpoint: ProtectedAtomicMetadataFileOperations.PrewriteCheckpoint? = nil
    ) -> ProtectedAtomicMetadataFileOperations {
        let live = ProtectedAtomicMetadataFileOperations.live
        return ProtectedAtomicMetadataFileOperations(
            read: read ?? live.read,
            write: write ?? live.write,
            synchronize: synchronize ?? live.synchronize,
            publish: publish ?? live.publish,
            remove: remove ?? live.remove,
            prewriteCheckpoint: prewriteCheckpoint ?? live.prewriteCheckpoint
        )
    }

    private func directoryNames(at directoryURL: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil
        ).map(\.lastPathComponent).sorted()
    }

    private func withTemporaryDirectory(
        _ operation: (URL) throws -> Void
    ) throws {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(
            "holdtype-protected-metadata-tests-\(UUID().uuidString)",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: false
        )
        defer { try? FileManager.default.removeItem(at: directoryURL) }
        try operation(directoryURL)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue = 0

    var value: Int {
        lock.withLock { storedValue }
    }

    func incrementAndGet() -> Int {
        lock.withLock {
            storedValue += 1
            return storedValue
        }
    }
}

private func overwriteRegularFileInPlace(at fileURL: URL, with data: Data) {
    let descriptor = fileURL.path.withCString { path in
        Darwin.open(path, O_WRONLY | O_CLOEXEC | O_NOFOLLOW)
    }
    guard descriptor >= 0 else {
        return
    }
    defer { Darwin.close(descriptor) }

    data.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else {
            return
        }
        _ = Darwin.pwrite(descriptor, baseAddress, bytes.count, 0)
    }
    var timestamps = [
        timespec(tv_sec: 2_000_000_000, tv_nsec: 123_456_789),
        timespec(tv_sec: 2_000_000_000, tv_nsec: 123_456_789),
    ]
    _ = timestamps.withUnsafeMutableBufferPointer { buffer in
        Darwin.futimens(descriptor, buffer.baseAddress)
    }
    _ = Darwin.fsync(descriptor)
}
