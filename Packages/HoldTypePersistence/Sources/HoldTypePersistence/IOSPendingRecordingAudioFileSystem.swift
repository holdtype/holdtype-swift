import AVFoundation
import Darwin
import Foundation
import HoldTypeDomain

enum IOSPendingRecordingAudioFileSystemError: Error, Equatable, Sendable {
    case namespaceUnavailable
    case namespaceNotEmpty
    case invalidSource
    case sourceUnavailable
    case sourceChanged
    case invalidDuration
    case destinationConflict
    case writeFailed
    case synchronizationFailed
    case mediaValidationFailed
    case mediaValidationTimedOut
    case operationTimedOut
    case operationCancelled
    case protectedAudioMissing
    case protectedAudioInvalid
    case dataProtectionUnavailable
    case removeFailed
}

protocol IOSPendingRecordingPublishedAudioLease: AnyObject, Sendable {
    var relativeIdentifier: String { get }
    var audioArtifact: AudioRecordingArtifact { get }
    var durationMilliseconds: Int64 { get }

    func revalidate() async throws -> AudioRecordingArtifact
    func release()
}

protocol IOSPendingRecordingAudioFileSystem: Sendable {
    func requireEmptyNamespace() async throws

    func publishProtectedCopy(
        from source: AudioRecordingArtifact,
        attemptID: UUID,
        format: IOSPendingRecordingAudioFormat,
        durationMilliseconds: Int64
    ) async throws -> any IOSPendingRecordingPublishedAudioLease

    func validatePublishedAudio(
        relativeIdentifier: String,
        attemptID: UUID,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) async throws -> AudioRecordingArtifact

    func removePublishedAudioIfPresent(
        relativeIdentifier: String,
        attemptID: UUID,
        expectedByteCount: Int64
    ) async throws -> Bool
}

enum IOSPendingRecordingPOSIXResult<Value> {
    case success(Value)
    case failure(Int32)
}

enum IOSPendingRecordingDirectoryEntry: Equatable, Sendable {
    case name(String)
    case invalidName
}

protocol IOSPendingRecordingPOSIXAdapter: Sendable {
    func effectiveUserID() -> IOSPendingRecordingPOSIXResult<uid_t>
    func openPath(_ path: String, flags: Int32, mode: mode_t?)
        -> IOSPendingRecordingPOSIXResult<Int32>
    func openAt(
        directoryDescriptor: Int32,
        name: String,
        flags: Int32,
        mode: mode_t?
    ) -> IOSPendingRecordingPOSIXResult<Int32>
    func makeDirectoryAt(
        directoryDescriptor: Int32,
        name: String,
        mode: mode_t
    ) -> IOSPendingRecordingPOSIXResult<Void>
    func status(of fileDescriptor: Int32) -> IOSPendingRecordingPOSIXResult<stat>
    func statusAtPath(_ path: String) -> IOSPendingRecordingPOSIXResult<stat>
    func statusAt(
        directoryDescriptor: Int32,
        name: String,
        flags: Int32
    ) -> IOSPendingRecordingPOSIXResult<stat>
    func read(
        fileDescriptor: Int32,
        buffer: UnsafeMutableRawPointer,
        byteCount: Int
    ) -> IOSPendingRecordingPOSIXResult<Int>
    func write(
        fileDescriptor: Int32,
        buffer: UnsafeRawPointer,
        byteCount: Int
    ) -> IOSPendingRecordingPOSIXResult<Int>
    func synchronize(fileDescriptor: Int32) -> IOSPendingRecordingPOSIXResult<Void>
    func changeMode(fileDescriptor: Int32, mode: mode_t)
        -> IOSPendingRecordingPOSIXResult<Void>
    func lock(fileDescriptor: Int32, operation: Int32)
        -> IOSPendingRecordingPOSIXResult<Void>
    func setExtendedAttribute(
        fileDescriptor: Int32,
        name: String,
        value: [UInt8],
        flags: Int32
    ) -> IOSPendingRecordingPOSIXResult<Void>
    func extendedAttribute(
        fileDescriptor: Int32,
        name: String,
        maximumByteCount: Int
    ) -> IOSPendingRecordingPOSIXResult<[UInt8]>
    func setProtectionClass(fileDescriptor: Int32, protectionClass: Int32)
        -> IOSPendingRecordingPOSIXResult<Void>
    func protectionClass(fileDescriptor: Int32)
        -> IOSPendingRecordingPOSIXResult<Int32>
    func publishExclusively(
        directoryDescriptor: Int32,
        temporaryName: String,
        finalName: String
    ) -> IOSPendingRecordingPOSIXResult<Void>
    func unlinkAt(directoryDescriptor: Int32, name: String)
        -> IOSPendingRecordingPOSIXResult<Void>
    func openDirectoryStream(fileDescriptor: Int32)
        -> IOSPendingRecordingPOSIXResult<UnsafeMutablePointer<DIR>>
    func nextDirectoryEntry(stream: UnsafeMutablePointer<DIR>)
        -> IOSPendingRecordingPOSIXResult<IOSPendingRecordingDirectoryEntry?>
    func closeFile(_ fileDescriptor: Int32)
    func closeDirectoryStream(_ stream: UnsafeMutablePointer<DIR>)
}

struct DarwinIOSPendingRecordingPOSIXAdapter: IOSPendingRecordingPOSIXAdapter {
    func effectiveUserID() -> IOSPendingRecordingPOSIXResult<uid_t> {
        .success(Darwin.geteuid())
    }

    func openPath(
        _ path: String,
        flags: Int32,
        mode: mode_t?
    ) -> IOSPendingRecordingPOSIXResult<Int32> {
        let result = path.withCString { path in
            if let mode {
                return Darwin.open(path, flags, mode)
            }
            return Darwin.open(path, flags)
        }
        return result >= 0 ? .success(result) : .failure(errno)
    }

    func openAt(
        directoryDescriptor: Int32,
        name: String,
        flags: Int32,
        mode: mode_t?
    ) -> IOSPendingRecordingPOSIXResult<Int32> {
        let result = name.withCString { name in
            if let mode {
                return Darwin.openat(directoryDescriptor, name, flags, mode)
            }
            return Darwin.openat(directoryDescriptor, name, flags)
        }
        return result >= 0 ? .success(result) : .failure(errno)
    }

    func makeDirectoryAt(
        directoryDescriptor: Int32,
        name: String,
        mode: mode_t
    ) -> IOSPendingRecordingPOSIXResult<Void> {
        let result = name.withCString { Darwin.mkdirat(directoryDescriptor, $0, mode) }
        return result == 0 ? .success(()) : .failure(errno)
    }

    func status(of fileDescriptor: Int32) -> IOSPendingRecordingPOSIXResult<stat> {
        var value = stat()
        return Darwin.fstat(fileDescriptor, &value) == 0
            ? .success(value)
            : .failure(errno)
    }

    func statusAtPath(_ path: String) -> IOSPendingRecordingPOSIXResult<stat> {
        var value = stat()
        let result = path.withCString { Darwin.lstat($0, &value) }
        return result == 0 ? .success(value) : .failure(errno)
    }

    func statusAt(
        directoryDescriptor: Int32,
        name: String,
        flags: Int32
    ) -> IOSPendingRecordingPOSIXResult<stat> {
        var value = stat()
        let result = name.withCString {
            Darwin.fstatat(directoryDescriptor, $0, &value, flags)
        }
        return result == 0 ? .success(value) : .failure(errno)
    }

    func read(
        fileDescriptor: Int32,
        buffer: UnsafeMutableRawPointer,
        byteCount: Int
    ) -> IOSPendingRecordingPOSIXResult<Int> {
        let result = Darwin.read(fileDescriptor, buffer, byteCount)
        return result >= 0 ? .success(result) : .failure(errno)
    }

    func write(
        fileDescriptor: Int32,
        buffer: UnsafeRawPointer,
        byteCount: Int
    ) -> IOSPendingRecordingPOSIXResult<Int> {
        let result = Darwin.write(fileDescriptor, buffer, byteCount)
        return result >= 0 ? .success(result) : .failure(errno)
    }

    func synchronize(fileDescriptor: Int32) -> IOSPendingRecordingPOSIXResult<Void> {
        Darwin.fsync(fileDescriptor) == 0 ? .success(()) : .failure(errno)
    }

    func changeMode(
        fileDescriptor: Int32,
        mode: mode_t
    ) -> IOSPendingRecordingPOSIXResult<Void> {
        Darwin.fchmod(fileDescriptor, mode) == 0 ? .success(()) : .failure(errno)
    }

    func lock(
        fileDescriptor: Int32,
        operation: Int32
    ) -> IOSPendingRecordingPOSIXResult<Void> {
        flock(fileDescriptor, operation) == 0 ? .success(()) : .failure(errno)
    }

    func setExtendedAttribute(
        fileDescriptor: Int32,
        name: String,
        value: [UInt8],
        flags: Int32
    ) -> IOSPendingRecordingPOSIXResult<Void> {
        let result = name.withCString { name in
            value.withUnsafeBytes {
                Darwin.fsetxattr(
                    fileDescriptor,
                    name,
                    $0.baseAddress,
                    $0.count,
                    0,
                    flags
                )
            }
        }
        return result == 0 ? .success(()) : .failure(errno)
    }

    func extendedAttribute(
        fileDescriptor: Int32,
        name: String,
        maximumByteCount: Int
    ) -> IOSPendingRecordingPOSIXResult<[UInt8]> {
        var bytes = [UInt8](repeating: 0, count: maximumByteCount)
        let result = name.withCString { name in
            bytes.withUnsafeMutableBytes {
                Darwin.fgetxattr(
                    fileDescriptor,
                    name,
                    $0.baseAddress,
                    $0.count,
                    0,
                    0
                )
            }
        }
        guard result >= 0 else { return .failure(errno) }
        return .success(Array(bytes.prefix(result)))
    }

    func setProtectionClass(
        fileDescriptor: Int32,
        protectionClass: Int32
    ) -> IOSPendingRecordingPOSIXResult<Void> {
        Darwin.fcntl(fileDescriptor, F_SETPROTECTIONCLASS, protectionClass) == 0
            ? .success(())
            : .failure(errno)
    }

    func protectionClass(
        fileDescriptor: Int32
    ) -> IOSPendingRecordingPOSIXResult<Int32> {
        let result = Darwin.fcntl(fileDescriptor, F_GETPROTECTIONCLASS)
        return result >= 0 ? .success(result) : .failure(errno)
    }

    func publishExclusively(
        directoryDescriptor: Int32,
        temporaryName: String,
        finalName: String
    ) -> IOSPendingRecordingPOSIXResult<Void> {
        let result = temporaryName.withCString { temporaryName in
            finalName.withCString { finalName in
                Darwin.renameatx_np(
                    directoryDescriptor,
                    temporaryName,
                    directoryDescriptor,
                    finalName,
                    UInt32(RENAME_EXCL)
                )
            }
        }
        return result == 0 ? .success(()) : .failure(errno)
    }

    func unlinkAt(
        directoryDescriptor: Int32,
        name: String
    ) -> IOSPendingRecordingPOSIXResult<Void> {
        let result = name.withCString { Darwin.unlinkat(directoryDescriptor, $0, 0) }
        return result == 0 ? .success(()) : .failure(errno)
    }

    func openDirectoryStream(
        fileDescriptor: Int32
    ) -> IOSPendingRecordingPOSIXResult<UnsafeMutablePointer<DIR>> {
        guard let stream = Darwin.fdopendir(fileDescriptor) else {
            return .failure(errno)
        }
        return .success(stream)
    }

    func nextDirectoryEntry(
        stream: UnsafeMutablePointer<DIR>
    ) -> IOSPendingRecordingPOSIXResult<IOSPendingRecordingDirectoryEntry?> {
        errno = 0
        guard let entry = Darwin.readdir(stream) else {
            return errno == 0 ? .success(nil) : .failure(errno)
        }
        let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: Int(entry.pointee.d_namlen) + 1
            ) { String(validatingCString: $0) }
        }
        return .success(name.map(IOSPendingRecordingDirectoryEntry.name) ?? .invalidName)
    }

    func closeFile(_ fileDescriptor: Int32) {
        Darwin.close(fileDescriptor)
    }

    func closeDirectoryStream(_ stream: UnsafeMutablePointer<DIR>) {
        Darwin.closedir(stream)
    }
}

protocol IOSPendingRecordingMediaValidating: Sendable {
    func durationMilliseconds(
        for fileURL: URL,
        timeoutNanoseconds: UInt64
    ) throws -> Int64
}

struct AVFoundationIOSPendingRecordingMediaValidator:
    IOSPendingRecordingMediaValidating {
    func durationMilliseconds(
        for fileURL: URL,
        timeoutNanoseconds: UInt64
    ) throws -> Int64 {
        let result = LockedMediaValidationResult()
        let task = Task {
            do {
                let asset = AVURLAsset(url: fileURL)
                let playable = try await asset.load(.isPlayable)
                let duration = try await asset.load(.duration)
                let tracks = try await asset.loadTracks(withMediaType: .audio)
                guard playable, !tracks.isEmpty else {
                    result.complete(.failure(.mediaValidationFailed))
                    return
                }
                let seconds = CMTimeGetSeconds(duration)
                guard seconds.isFinite, seconds > 0 else {
                    result.complete(.failure(.mediaValidationFailed))
                    return
                }
                let scaled = seconds * 1_000
                guard scaled.isFinite,
                      scaled >= Double(Int64.min),
                      scaled <= Double(Int64.max) else {
                    result.complete(.failure(.mediaValidationFailed))
                    return
                }
                result.complete(
                    .success(Int64(scaled.rounded(.toNearestOrAwayFromZero)))
                )
            } catch {
                result.complete(
                    .failure(
                        isIOSPendingRecordingProtectedDataError(error)
                            ? .dataProtectionUnavailable
                            : .mediaValidationFailed
                    )
                )
            }
        }

        let waitResult = result.wait(timeoutNanoseconds: timeoutNanoseconds)
        guard let waitResult else {
            task.cancel()
            throw IOSPendingRecordingAudioFileSystemError.mediaValidationTimedOut
        }
        task.cancel()
        return try waitResult.get()
    }
}

private final class LockedMediaValidationResult: @unchecked Sendable {
    private let lock = NSLock()
    private let semaphore = DispatchSemaphore(value: 0)
    private var result: Result<Int64, IOSPendingRecordingAudioFileSystemError>?

    func complete(
        _ result: Result<Int64, IOSPendingRecordingAudioFileSystemError>
    ) {
        lock.lock()
        guard self.result == nil else {
            lock.unlock()
            return
        }
        self.result = result
        lock.unlock()
        semaphore.signal()
    }

    func wait(
        timeoutNanoseconds: UInt64
    ) -> Result<Int64, IOSPendingRecordingAudioFileSystemError>? {
        let timeout = DispatchTime.now() + .nanoseconds(
            Int(min(timeoutNanoseconds, UInt64(Int.max)))
        )
        guard semaphore.wait(timeout: timeout) == .success else { return nil }
        return lock.withLock { result }
    }
}

final class FoundationIOSPendingRecordingAudioFileSystem:
    IOSPendingRecordingAudioFileSystem,
    @unchecked Sendable {
    static let maximumAudioByteCount: Int64 = 25_000_000
    static let maximumTransferByteCount = 64 * 1_024
    static let maximumInterruptedRetryCount = 8
    static let copyDeadlineNanoseconds: UInt64 = 10_000_000_000
    static let mediaValidationDeadlineNanoseconds: UInt64 = 2_000_000_000
    static let maximumDurationDeltaMilliseconds: Int64 = 250

    private static let audioMarkerName =
        "com.holdtype.ios.pending-recording-audio"
    private static let audioMarkerValue = Array("v1".utf8)
    private static let completeProtectionClass: Int32 = 1
    private static let backupExclusionAttributeName =
        "com.apple.metadata:com_apple_backup_excludeItem"
    private static let backupExclusionAttributeValue: [UInt8] = [
        0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x30, 0x30,
        0x5F, 0x10, 0x11, 0x63, 0x6F, 0x6D, 0x2E, 0x61,
        0x70, 0x70, 0x6C, 0x65, 0x2E, 0x62, 0x61, 0x63,
        0x6B, 0x75, 0x70, 0x64, 0x08, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x1C,
    ]

    private let applicationSupportDirectoryURL: URL
    fileprivate let adapter: any IOSPendingRecordingPOSIXAdapter
    private let mediaValidator: any IOSPendingRecordingMediaValidating
    private let monotonicClock: @Sendable () -> UInt64?
    private let queue: DispatchQueue

    init(
        applicationSupportDirectoryURL: URL,
        adapter: any IOSPendingRecordingPOSIXAdapter =
            DarwinIOSPendingRecordingPOSIXAdapter(),
        mediaValidator: any IOSPendingRecordingMediaValidating =
            AVFoundationIOSPendingRecordingMediaValidator(),
        monotonicClock: @escaping @Sendable () -> UInt64? = {
            systemPendingRecordingMonotonicNanoseconds()
        },
        queue: DispatchQueue = DispatchQueue(
            label: "app.holdtype.pending-recording-audio",
            qos: .utility
        )
    ) {
        self.applicationSupportDirectoryURL = applicationSupportDirectoryURL
        self.adapter = adapter
        self.mediaValidator = mediaValidator
        self.monotonicClock = monotonicClock
        self.queue = queue
    }

    func requireEmptyNamespace() async throws {
        try await runQueued(deadlineNanoseconds: Self.copyDeadlineNanoseconds) { control in
            guard let directory = try self.openPendingDirectory(
                createIfMissing: false,
                control: control
            ) else {
                return
            }
            defer { self.adapter.closeFile(directory.descriptor) }
            try self.requireNoEntries(in: directory, control: control)
        }
    }

    func publishProtectedCopy(
        from source: AudioRecordingArtifact,
        attemptID: UUID,
        format: IOSPendingRecordingAudioFormat,
        durationMilliseconds: Int64
    ) async throws -> any IOSPendingRecordingPublishedAudioLease {
        try await runQueued(
            deadlineNanoseconds: Self.copyDeadlineNanoseconds,
            onLateValue: { $0.release() }
        ) { control in
            try self.publishProtectedCopySynchronously(
                from: source,
                attemptID: attemptID,
                format: format,
                durationMilliseconds: durationMilliseconds,
                control: control
            )
        }
    }

    func validatePublishedAudio(
        relativeIdentifier: String,
        attemptID: UUID,
        durationMilliseconds: Int64,
        byteCount: Int64
    ) async throws -> AudioRecordingArtifact {
        try await runQueued(deadlineNanoseconds: Self.copyDeadlineNanoseconds) { control in
            let opened = try self.openValidatedPublishedAudio(
                relativeIdentifier: relativeIdentifier,
                attemptID: attemptID,
                durationMilliseconds: durationMilliseconds,
                byteCount: byteCount,
                control: control
            )
            defer {
                self.adapter.closeFile(opened.fileDescriptor)
                self.adapter.closeFile(opened.directoryDescriptor)
            }
            return opened.artifact
        }
    }

    func removePublishedAudioIfPresent(
        relativeIdentifier: String,
        attemptID: UUID,
        expectedByteCount: Int64
    ) async throws -> Bool {
        try await runQueued(deadlineNanoseconds: Self.copyDeadlineNanoseconds) { control in
            try self.removePublishedAudioSynchronously(
                relativeIdentifier: relativeIdentifier,
                attemptID: attemptID,
                expectedByteCount: expectedByteCount,
                control: control
            )
        }
    }

    private func runQueued<Value: Sendable>(
        deadlineNanoseconds: UInt64,
        onLateValue: @escaping @Sendable (Value) -> Void = { _ in },
        onOperationFinished: @escaping @Sendable () -> Void = {},
        operation: @escaping @Sendable (PendingRecordingOperationControl) throws -> Value
    ) async throws -> Value {
        let control: PendingRecordingOperationControl
        do {
            control = try PendingRecordingOperationControl(
                timeoutNanoseconds: deadlineNanoseconds,
                monotonicClock: monotonicClock
            )
        } catch {
            onOperationFinished()
            throw error
        }
        let completion = PendingRecordingOperationCompletion<Value>()
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                completion.install(continuation)
                queue.async {
                    defer { onOperationFinished() }
                    do {
                        let value = try operation(control)
                        guard completion.resolve(.success(value)) else {
                            onLateValue(value)
                            return
                        }
                    } catch {
                        _ = completion.resolve(.failure(error))
                    }
                }
                DispatchQueue.global(qos: .utility).asyncAfter(
                    deadline: .now() + .nanoseconds(
                        Int(min(deadlineNanoseconds, UInt64(Int.max)))
                    )
                ) {
                    control.expire()
                    _ = completion.resolve(
                        .failure(
                            IOSPendingRecordingAudioFileSystemError.operationTimedOut
                        )
                    )
                }
            }
        } onCancel: {
            control.cancel()
            _ = completion.resolve(
                .failure(IOSPendingRecordingAudioFileSystemError.operationCancelled)
            )
        }
    }
}

fileprivate extension FoundationIOSPendingRecordingAudioFileSystem {
    struct DirectoryHandle: @unchecked Sendable {
        let descriptor: Int32
        let effectiveUserID: uid_t
        let identity: FileIdentity
    }

    struct OpenedPublishedAudio {
        let directoryDescriptor: Int32
        let fileDescriptor: Int32
        let artifact: AudioRecordingArtifact
    }

    func publishProtectedCopySynchronously(
        from source: AudioRecordingArtifact,
        attemptID: UUID,
        format: IOSPendingRecordingAudioFormat,
        durationMilliseconds: Int64,
        control: PendingRecordingOperationControl
    ) throws -> any IOSPendingRecordingPublishedAudioLease {
        guard durationMilliseconds > 0, durationMilliseconds < 300_000,
              canonicalDurationMilliseconds(source.duration) == durationMilliseconds,
              source.byteCount > 0,
              source.byteCount < Self.maximumAudioByteCount,
              source.fileURL.pathExtension == fileExtension(for: format) else {
            throw IOSPendingRecordingAudioFileSystemError.invalidSource
        }

        let sourceDescriptor = try openValidatedSource(
            source,
            control: control
        )
        defer { adapter.closeFile(sourceDescriptor.descriptor) }

        guard let directory = try openPendingDirectory(
            createIfMissing: true,
            control: control
        ) else {
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
        var directoryIsOwnedByLease = false
        defer {
            if !directoryIsOwnedByLease {
                adapter.closeFile(directory.descriptor)
            }
        }

        let relativeIdentifier =
            IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
                for: attemptID,
                format: format
            )
        guard let finalURL =
                IOSPendingRecordingStorageLocation.audioFileURL(
                    forRelativeIdentifier: relativeIdentifier,
                    in: applicationSupportDirectoryURL
                ) else {
            throw IOSPendingRecordingAudioFileSystemError.invalidSource
        }
        let finalName = finalURL.lastPathComponent
        let temporaryName = [
            ".recording-staging-v1-",
            UUID().uuidString.lowercased(),
            ".",
            fileExtension(for: format),
        ].joined()
        let temporaryURL = finalURL.deletingLastPathComponent()
            .appendingPathComponent(temporaryName, isDirectory: false)

        let temporaryDescriptor = try createExclusiveTemporaryFile(
            named: temporaryName,
            in: directory,
            control: control
        )
        var descriptorIsOwnedByLease = false
        var didPublish = false
        var capturedTemporaryIdentity: FileIdentity?
        defer {
            if !descriptorIsOwnedByLease {
                adapter.closeFile(temporaryDescriptor)
            }
            if !didPublish, let capturedTemporaryIdentity {
                unlinkOwnedTemporaryIfPresent(
                    name: temporaryName,
                    identity: capturedTemporaryIdentity,
                    directoryDescriptor: directory.descriptor,
                    control: control
                )
            }
        }
        let temporaryIdentity = try statusSnapshot(
            descriptor: temporaryDescriptor,
            control: control,
            failure: .writeFailed
        ).identity
        capturedTemporaryIdentity = temporaryIdentity

        try configureTemporaryFile(
            descriptor: temporaryDescriptor,
            name: temporaryName,
            directory: directory,
            expectedIdentity: temporaryIdentity,
            control: control
        )
        try copySource(
            sourceDescriptor: sourceDescriptor.descriptor,
            destinationDescriptor: temporaryDescriptor,
            expectedByteCount: source.byteCount,
            control: control
        )
        try validateSourceUnchanged(
            sourceDescriptor,
            control: control
        )
        try validateOwnedAudio(
            descriptor: temporaryDescriptor,
            name: temporaryName,
            directory: directory,
            expectedIdentity: temporaryIdentity,
            expectedByteCount: source.byteCount,
            control: control
        )
        try synchronize(
            temporaryDescriptor,
            control: control,
            failure: .synchronizationFailed
        )
        try validateOwnedAudio(
            descriptor: temporaryDescriptor,
            name: temporaryName,
            directory: directory,
            expectedIdentity: temporaryIdentity,
            expectedByteCount: source.byteCount,
            control: control
        )

        try control.checkpoint()
        let mediaDuration = try validatedMediaDuration(for: temporaryURL)
        try validateMediaDuration(
            mediaDuration,
            expectedDuration: durationMilliseconds
        )
        try control.checkpoint()
        try validateOwnedAudio(
            descriptor: temporaryDescriptor,
            name: temporaryName,
            directory: directory,
            expectedIdentity: temporaryIdentity,
            expectedByteCount: source.byteCount,
            control: control
        )
        try requireMissingFinal(
            name: finalName,
            directoryDescriptor: directory.descriptor,
            control: control
        )
        try validateOwnedAudio(
            descriptor: temporaryDescriptor,
            name: temporaryName,
            directory: directory,
            expectedIdentity: temporaryIdentity,
            expectedByteCount: source.byteCount,
            control: control
        )
        try publish(
            temporaryName: temporaryName,
            finalName: finalName,
            directory: directory,
            control: control
        )
        didPublish = true
        try validateOwnedAudio(
            descriptor: temporaryDescriptor,
            name: finalName,
            directory: directory,
            expectedIdentity: temporaryIdentity,
            expectedByteCount: source.byteCount,
            control: control
        )
        try synchronize(
            directory.descriptor,
            control: control,
            failure: .synchronizationFailed
        )
        try validateOwnedAudio(
            descriptor: temporaryDescriptor,
            name: finalName,
            directory: directory,
            expectedIdentity: temporaryIdentity,
            expectedByteCount: source.byteCount,
            control: control
        )

        descriptorIsOwnedByLease = true
        directoryIsOwnedByLease = true
        return POSIXIOSPendingRecordingPublishedAudioLease(
            fileSystem: self,
            relativeIdentifier: relativeIdentifier,
            fileURL: finalURL,
            directoryDescriptor: directory.descriptor,
            fileDescriptor: temporaryDescriptor,
            identity: temporaryIdentity,
            byteCount: source.byteCount,
            durationMilliseconds: durationMilliseconds
        )
    }

    func openValidatedSource(
        _ source: AudioRecordingArtifact,
        control: PendingRecordingOperationControl
    ) throws -> SourceHandle {
        guard source.fileURL.isFileURL,
              !source.fileURL.path.isEmpty,
              !source.fileURL.path.utf8.contains(0) else {
            throw IOSPendingRecordingAudioFileSystemError.invalidSource
        }
        let pathResult = try call(control: control) {
            adapter.statusAtPath(source.fileURL.path)
        }
        if case .failure(let errorCode) = pathResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let pathStatus) = pathResult else {
            throw IOSPendingRecordingAudioFileSystemError.sourceUnavailable
        }
        let effectiveUserID = try readEffectiveUserID(control: control)
        try validateSourceStatus(
            pathStatus,
            effectiveUserID: effectiveUserID,
            expectedByteCount: source.byteCount
        )

        let openResult = try call(control: control) {
            adapter.openPath(
                source.fileURL.path,
                flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK,
                mode: nil
            )
        }
        if case .failure(let errorCode) = openResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let descriptor) = openResult else {
            throw IOSPendingRecordingAudioFileSystemError.sourceUnavailable
        }
        do {
            let descriptorStatus = try status(
                descriptor: descriptor,
                control: control,
                failure: .sourceUnavailable
            )
            try validateSourceStatus(
                descriptorStatus,
                effectiveUserID: effectiveUserID,
                expectedByteCount: source.byteCount
            )
            let snapshot = FileSnapshot(descriptorStatus)
            guard snapshot == FileSnapshot(pathStatus) else {
                throw IOSPendingRecordingAudioFileSystemError.invalidSource
            }
            return SourceHandle(
                descriptor: descriptor,
                fileURL: source.fileURL,
                snapshot: snapshot
            )
        } catch {
            adapter.closeFile(descriptor)
            throw error
        }
    }

    func openPendingDirectory(
        createIfMissing: Bool,
        control: PendingRecordingOperationControl
    ) throws -> DirectoryHandle? {
        guard applicationSupportDirectoryURL.isFileURL,
              !applicationSupportDirectoryURL.path.isEmpty,
              !applicationSupportDirectoryURL.path.utf8.contains(0) else {
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
        let openRoot = try call(control: control) {
            adapter.openPath(
                applicationSupportDirectoryURL.path,
                flags: O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
                mode: nil
            )
        }
        if case .failure(let errorCode) = openRoot,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let applicationSupportDescriptor) = openRoot else {
            if case .failure(ENOENT) = openRoot, !createIfMissing { return nil }
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
        var currentDescriptor = applicationSupportDescriptor
        var ownsCurrent = true
        defer {
            if ownsCurrent { adapter.closeFile(currentDescriptor) }
        }
        let effectiveUserID = try readEffectiveUserID(control: control)

        for component in [
            IOSPendingRecordingStorageLocation.rootDirectoryName,
            IOSPendingRecordingStorageLocation.recordingsDirectoryName,
            IOSPendingRecordingStorageLocation.pendingDirectoryName,
        ] {
            let next = try openChildDirectory(
                named: component,
                in: currentDescriptor,
                createIfMissing: createIfMissing,
                effectiveUserID: effectiveUserID,
                control: control
            )
            guard let next else { return nil }
            adapter.closeFile(currentDescriptor)
            currentDescriptor = next
        }

        let pendingStatus = try status(
            descriptor: currentDescriptor,
            control: control,
            failure: .namespaceUnavailable
        )
        guard pendingStatus.st_mode & S_IFMT == S_IFDIR,
              pendingStatus.st_uid == effectiveUserID,
              pendingStatus.st_mode & mode_t(0o7777) == mode_t(0o700) else {
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
        ownsCurrent = false
        return DirectoryHandle(
            descriptor: currentDescriptor,
            effectiveUserID: effectiveUserID,
            identity: FileIdentity(pendingStatus)
        )
    }

    func openChildDirectory(
        named name: String,
        in directoryDescriptor: Int32,
        createIfMissing: Bool,
        effectiveUserID: uid_t,
        control: PendingRecordingOperationControl
    ) throws -> Int32? {
        func open() throws -> IOSPendingRecordingPOSIXResult<Int32> {
            try call(control: control) {
                adapter.openAt(
                    directoryDescriptor: directoryDescriptor,
                    name: name,
                    flags: O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
                    mode: nil
                )
            }
        }

        var result = try open()
        var createdDirectory = false
        if case .failure(ENOENT) = result, createIfMissing {
            let makeResult = try call(control: control) {
                adapter.makeDirectoryAt(
                    directoryDescriptor: directoryDescriptor,
                    name: name,
                    mode: mode_t(0o700)
                )
            }
            switch makeResult {
            case .success:
                createdDirectory = true
                result = try open()
            case .failure(EEXIST):
                result = try open()
            case .failure(let errorCode)
                where isDataProtectionFailure(errorCode):
                throw IOSPendingRecordingAudioFileSystemError
                    .dataProtectionUnavailable
            case .failure:
                throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
            }
        }
        switch result {
        case .success(let descriptor):
            do {
                let value = try status(
                    descriptor: descriptor,
                    control: control,
                    failure: .namespaceUnavailable
                )
                guard value.st_mode & S_IFMT == S_IFDIR,
                      value.st_uid == effectiveUserID else {
                    throw IOSPendingRecordingAudioFileSystemError
                        .namespaceUnavailable
                }
                if createdDirectory {
                    try requireSuccess(
                        control: control,
                        failure: .namespaceUnavailable
                    ) {
                        adapter.changeMode(
                            fileDescriptor: descriptor,
                            mode: mode_t(0o700)
                        )
                    }
                    let configured = try status(
                        descriptor: descriptor,
                        control: control,
                        failure: .namespaceUnavailable
                    )
                    let pathResult = try call(control: control) {
                        adapter.statusAt(
                            directoryDescriptor: directoryDescriptor,
                            name: name,
                            flags: AT_SYMLINK_NOFOLLOW
                        )
                    }
                    guard case .success(let pathStatus) = pathResult,
                          configured.st_mode & S_IFMT == S_IFDIR,
                          configured.st_uid == effectiveUserID,
                          configured.st_mode & mode_t(0o7777) == mode_t(0o700),
                          FileIdentity(configured) == FileIdentity(pathStatus) else {
                        throw IOSPendingRecordingAudioFileSystemError
                            .namespaceUnavailable
                    }
                    try synchronize(
                        descriptor,
                        control: control,
                        failure: .synchronizationFailed
                    )
                    try synchronize(
                        directoryDescriptor,
                        control: control,
                        failure: .synchronizationFailed
                    )
                }
                return descriptor
            } catch {
                adapter.closeFile(descriptor)
                throw error
            }
        case .failure(ENOENT) where !createIfMissing:
            return nil
        case .failure(let errorCode) where isDataProtectionFailure(errorCode):
            throw IOSPendingRecordingAudioFileSystemError
                .dataProtectionUnavailable
        case .failure:
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
    }

    func requireNoEntries(
        in directory: DirectoryHandle,
        control: PendingRecordingOperationControl
    ) throws {
        try validatePendingDirectoryPath(directory, control: control)
        let duplicateResult = try call(control: control) {
            adapter.openAt(
                directoryDescriptor: directory.descriptor,
                name: ".",
                flags: O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW,
                mode: nil
            )
        }
        if case .failure(let errorCode) = duplicateResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let duplicateDescriptor) = duplicateResult else {
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
        var duplicateDescriptorIsOwned = true
        defer {
            if duplicateDescriptorIsOwned {
                adapter.closeFile(duplicateDescriptor)
            }
        }
        let streamResult = try call(control: control) {
            adapter.openDirectoryStream(fileDescriptor: duplicateDescriptor)
        }
        if case .failure(let errorCode) = streamResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let stream) = streamResult else {
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
        duplicateDescriptorIsOwned = false
        defer { adapter.closeDirectoryStream(stream) }

        while true {
            let entryResult = try call(control: control) {
                adapter.nextDirectoryEntry(stream: stream)
            }
            if case .failure(let errorCode) = entryResult,
               isDataProtectionFailure(errorCode) {
                throw IOSPendingRecordingAudioFileSystemError
                    .dataProtectionUnavailable
            }
            guard case .success(let entry) = entryResult else {
                throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
            }
            guard let entry else {
                try validatePendingDirectoryPath(directory, control: control)
                return
            }
            switch entry {
            case .name("."), .name(".."):
                continue
            case .name, .invalidName:
                throw IOSPendingRecordingAudioFileSystemError.namespaceNotEmpty
            }
        }
    }

    func createExclusiveTemporaryFile(
        named name: String,
        in directory: DirectoryHandle,
        control: PendingRecordingOperationControl
    ) throws -> Int32 {
        let result = try call(control: control) {
            adapter.openAt(
                directoryDescriptor: directory.descriptor,
                name: name,
                flags: O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                mode: mode_t(0o600)
            )
        }
        if case .failure(let errorCode) = result,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let descriptor) = result else {
            throw IOSPendingRecordingAudioFileSystemError.writeFailed
        }
        return descriptor
    }

    func configureTemporaryFile(
        descriptor: Int32,
        name: String,
        directory: DirectoryHandle,
        expectedIdentity: FileIdentity,
        control: PendingRecordingOperationControl
    ) throws {
        try requireSuccess(control: control, failure: .writeFailed) {
            adapter.changeMode(fileDescriptor: descriptor, mode: mode_t(0o600))
        }
        try requireSuccess(control: control, failure: .writeFailed) {
            adapter.lock(fileDescriptor: descriptor, operation: LOCK_EX | LOCK_NB)
        }
        try requireSuccess(control: control, failure: .writeFailed) {
            adapter.setExtendedAttribute(
                fileDescriptor: descriptor,
                name: Self.audioMarkerName,
                value: Self.audioMarkerValue,
                flags: XATTR_CREATE
            )
        }
        try requireSuccess(control: control, failure: .dataProtectionUnavailable) {
            adapter.setProtectionClass(
                fileDescriptor: descriptor,
                protectionClass: Self.completeProtectionClass
            )
        }
        try requireSuccess(control: control, failure: .dataProtectionUnavailable) {
            adapter.setExtendedAttribute(
                fileDescriptor: descriptor,
                name: Self.backupExclusionAttributeName,
                value: Self.backupExclusionAttributeValue,
                flags: XATTR_CREATE
            )
        }
        try validateOwnedAudio(
            descriptor: descriptor,
            name: name,
            directory: directory,
            expectedIdentity: expectedIdentity,
            expectedByteCount: 0,
            control: control
        )
    }

    func copySource(
        sourceDescriptor: Int32,
        destinationDescriptor: Int32,
        expectedByteCount: Int64,
        control: PendingRecordingOperationControl
    ) throws {
        var buffer = [UInt8](repeating: 0, count: Self.maximumTransferByteCount)
        var copiedByteCount: Int64 = 0
        while copiedByteCount < expectedByteCount {
            let remaining = expectedByteCount - copiedByteCount
            let requested = min(buffer.count, Int(remaining))
            let readCount = try buffer.withUnsafeMutableBytes { bytes in
                try transferCount(
                    control: control,
                    failure: .sourceUnavailable
                ) {
                    adapter.read(
                        fileDescriptor: sourceDescriptor,
                        buffer: bytes.baseAddress!,
                        byteCount: requested
                    )
                }
            }
            guard readCount > 0 else {
                throw IOSPendingRecordingAudioFileSystemError.sourceChanged
            }
            guard readCount <= requested else {
                throw IOSPendingRecordingAudioFileSystemError.sourceChanged
            }

            var written = 0
            while written < readCount {
                let writeCount = try buffer.withUnsafeBytes { bytes in
                    try transferCount(
                        control: control,
                        failure: .writeFailed
                    ) {
                        adapter.write(
                            fileDescriptor: destinationDescriptor,
                            buffer: bytes.baseAddress!.advanced(by: written),
                            byteCount: readCount - written
                        )
                    }
                }
                guard writeCount > 0 else {
                    throw IOSPendingRecordingAudioFileSystemError.writeFailed
                }
                guard writeCount <= readCount - written else {
                    throw IOSPendingRecordingAudioFileSystemError.writeFailed
                }
                written += writeCount
            }
            copiedByteCount += Int64(readCount)
        }

        var extraByte: UInt8 = 0
        let extraCount = try withUnsafeMutableBytes(of: &extraByte) { bytes in
            try transferCount(control: control, failure: .sourceChanged) {
                adapter.read(
                    fileDescriptor: sourceDescriptor,
                    buffer: bytes.baseAddress!,
                    byteCount: 1
                )
            }
        }
        guard extraCount == 0 else {
            throw IOSPendingRecordingAudioFileSystemError.sourceChanged
        }
    }

    func validateSourceUnchanged(
        _ source: SourceHandle,
        control: PendingRecordingOperationControl
    ) throws {
        let descriptorStatus = try status(
            descriptor: source.descriptor,
            control: control,
            failure: .sourceChanged
        )
        let pathResult = try call(control: control) {
            adapter.statusAtPath(source.fileURL.path)
        }
        if case .failure(let errorCode) = pathResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let pathStatus) = pathResult,
              FileSnapshot(descriptorStatus) == source.snapshot,
              FileSnapshot(pathStatus) == source.snapshot else {
            throw IOSPendingRecordingAudioFileSystemError.sourceChanged
        }
    }

    func validateOwnedAudio(
        descriptor: Int32,
        name: String,
        directory: DirectoryHandle,
        expectedIdentity: FileIdentity,
        expectedByteCount: Int64,
        control: PendingRecordingOperationControl
    ) throws {
        try validatePendingDirectoryPath(directory, control: control)
        let descriptorStatus = try status(
            descriptor: descriptor,
            control: control,
            failure: .protectedAudioInvalid
        )
        let pathResult = try call(control: control) {
            adapter.statusAt(
                directoryDescriptor: directory.descriptor,
                name: name,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }
        if case .failure(let errorCode) = pathResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let pathStatus) = pathResult,
              isExactOwnedAudioStatus(
                descriptorStatus,
                effectiveUserID: directory.effectiveUserID,
                expectedByteCount: expectedByteCount
              ),
              isExactOwnedAudioStatus(
                pathStatus,
                effectiveUserID: directory.effectiveUserID,
                expectedByteCount: expectedByteCount
              ),
              FileIdentity(descriptorStatus) == expectedIdentity,
              FileIdentity(pathStatus) == expectedIdentity else {
            throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
        }
        try validateExactConfiguration(descriptor: descriptor, control: control)
    }

    func validateExactConfiguration(
        descriptor: Int32,
        control: PendingRecordingOperationControl
    ) throws {
        let markerResult = try call(control: control) {
            adapter.extendedAttribute(
                fileDescriptor: descriptor,
                name: Self.audioMarkerName,
                maximumByteCount: Self.audioMarkerValue.count + 1
            )
        }
        if case .failure(let errorCode) = markerResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(Self.audioMarkerValue) = markerResult else {
            throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
        }
        let protectionResult = try call(control: control) {
            adapter.protectionClass(fileDescriptor: descriptor)
        }
        if case .failure(let errorCode) = protectionResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(Self.completeProtectionClass) = protectionResult else {
            throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
        }
        let backupResult = try call(control: control) {
            adapter.extendedAttribute(
                fileDescriptor: descriptor,
                name: Self.backupExclusionAttributeName,
                maximumByteCount: Self.backupExclusionAttributeValue.count + 1
            )
        }
        if case .failure(let errorCode) = backupResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(Self.backupExclusionAttributeValue) = backupResult else {
            throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
        }
    }

    func requireMissingFinal(
        name: String,
        directoryDescriptor: Int32,
        control: PendingRecordingOperationControl
    ) throws {
        let result = try call(control: control) {
            adapter.statusAt(
                directoryDescriptor: directoryDescriptor,
                name: name,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }
        if case .failure(let errorCode) = result,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .failure(ENOENT) = result else {
            throw IOSPendingRecordingAudioFileSystemError.destinationConflict
        }
    }

    func publish(
        temporaryName: String,
        finalName: String,
        directory: DirectoryHandle,
        control: PendingRecordingOperationControl
    ) throws {
        try validatePendingDirectoryPath(directory, control: control)
        try requireSuccess(control: control, failure: .destinationConflict) {
            adapter.publishExclusively(
                directoryDescriptor: directory.descriptor,
                temporaryName: temporaryName,
                finalName: finalName
            )
        }
        try validatePendingDirectoryPath(directory, control: control)
    }

    func openValidatedPublishedAudio(
        relativeIdentifier: String,
        attemptID: UUID,
        durationMilliseconds: Int64,
        byteCount: Int64,
        control: PendingRecordingOperationControl
    ) throws -> OpenedPublishedAudio {
        guard durationMilliseconds > 0, durationMilliseconds < 300_000,
              byteCount > 0, byteCount < Self.maximumAudioByteCount,
              let parsedURL = IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier: relativeIdentifier,
                in: applicationSupportDirectoryURL
              ),
              relativeIdentifier == expectedRelativeIdentifier(
                attemptID: attemptID,
                fileExtension: parsedURL.pathExtension
              ) else {
            throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
        }
        guard let directory = try openPendingDirectory(
            createIfMissing: false,
            control: control
        ) else {
            throw IOSPendingRecordingAudioFileSystemError.protectedAudioMissing
        }
        var closeDirectory = true
        defer { if closeDirectory { adapter.closeFile(directory.descriptor) } }
        try validatePendingDirectoryPath(directory, control: control)

        let name = parsedURL.lastPathComponent
        let pathResult = try call(control: control) {
            adapter.statusAt(
                directoryDescriptor: directory.descriptor,
                name: name,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }
        if case .failure(let errorCode) = pathResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let pathStatus) = pathResult else {
            if case .failure(ENOENT) = pathResult {
                throw IOSPendingRecordingAudioFileSystemError.protectedAudioMissing
            }
            throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
        }
        let openResult = try call(control: control) {
            adapter.openAt(
                directoryDescriptor: directory.descriptor,
                name: name,
                flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK,
                mode: nil
            )
        }
        if case .failure(let errorCode) = openResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let fileDescriptor) = openResult else {
            throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
        }
        do {
            let descriptorStatus = try status(
                descriptor: fileDescriptor,
                control: control,
                failure: .protectedAudioInvalid
            )
            guard isExactOwnedAudioStatus(
                descriptorStatus,
                effectiveUserID: directory.effectiveUserID,
                expectedByteCount: byteCount
            ),
            isExactOwnedAudioStatus(
                pathStatus,
                effectiveUserID: directory.effectiveUserID,
                expectedByteCount: byteCount
            ),
            FileSnapshot(descriptorStatus) == FileSnapshot(pathStatus) else {
                throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
            }
            try validateExactConfiguration(descriptor: fileDescriptor, control: control)
            try requireSuccess(control: control, failure: .protectedAudioInvalid) {
                adapter.lock(fileDescriptor: fileDescriptor, operation: LOCK_EX | LOCK_NB)
            }
            try control.checkpoint()
            let mediaDuration = try validatedMediaDuration(for: parsedURL)
            try validateMediaDuration(
                mediaDuration,
                expectedDuration: durationMilliseconds
            )
            try control.checkpoint()
            let finalDescriptorStatus = try status(
                descriptor: fileDescriptor,
                control: control,
                failure: .protectedAudioInvalid
            )
            let finalPathResult = try call(control: control) {
                adapter.statusAt(
                    directoryDescriptor: directory.descriptor,
                    name: name,
                    flags: AT_SYMLINK_NOFOLLOW
                )
            }
            if case .failure(let errorCode) = finalPathResult,
               isDataProtectionFailure(errorCode) {
                throw IOSPendingRecordingAudioFileSystemError
                    .dataProtectionUnavailable
            }
            guard case .success(let finalPathStatus) = finalPathResult,
                  FileSnapshot(finalDescriptorStatus) == FileSnapshot(descriptorStatus),
                  FileSnapshot(finalPathStatus) == FileSnapshot(descriptorStatus) else {
                throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
            }
            try validateExactConfiguration(
                descriptor: fileDescriptor,
                control: control
            )

            closeDirectory = false
            return OpenedPublishedAudio(
                directoryDescriptor: directory.descriptor,
                fileDescriptor: fileDescriptor,
                artifact: AudioRecordingArtifact(
                    fileURL: parsedURL,
                    duration: TimeInterval(durationMilliseconds) / 1_000,
                    byteCount: byteCount
                )
            )
        } catch {
            adapter.closeFile(fileDescriptor)
            throw error
        }
    }

    func removePublishedAudioSynchronously(
        relativeIdentifier: String,
        attemptID: UUID,
        expectedByteCount: Int64,
        control: PendingRecordingOperationControl
    ) throws -> Bool {
        guard expectedByteCount > 0,
              expectedByteCount < Self.maximumAudioByteCount,
              let fileURL = IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier: relativeIdentifier,
                in: applicationSupportDirectoryURL
              ),
              relativeIdentifier == expectedRelativeIdentifier(
                attemptID: attemptID,
                fileExtension: fileURL.pathExtension
              ) else {
            throw IOSPendingRecordingAudioFileSystemError.removeFailed
        }
        guard let directory = try openPendingDirectory(
            createIfMissing: false,
            control: control
        ) else {
            return false
        }
        defer { adapter.closeFile(directory.descriptor) }
        try validatePendingDirectoryPath(directory, control: control)
        let name = fileURL.lastPathComponent
        let pathResult = try call(control: control) {
            adapter.statusAt(
                directoryDescriptor: directory.descriptor,
                name: name,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }
        if case .failure(let errorCode) = pathResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let pathStatus) = pathResult else {
            if case .failure(ENOENT) = pathResult { return false }
            throw IOSPendingRecordingAudioFileSystemError.removeFailed
        }
        let openResult = try call(control: control) {
            adapter.openAt(
                directoryDescriptor: directory.descriptor,
                name: name,
                flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK,
                mode: nil
            )
        }
        if case .failure(let errorCode) = openResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let descriptor) = openResult else {
            if case .failure(ENOENT) = openResult { return false }
            throw IOSPendingRecordingAudioFileSystemError.removeFailed
        }
        defer { adapter.closeFile(descriptor) }
        let descriptorStatus = try status(
            descriptor: descriptor,
            control: control,
            failure: .removeFailed
        )
        guard isExactOwnedAudioStatus(
            descriptorStatus,
            effectiveUserID: directory.effectiveUserID,
            expectedByteCount: expectedByteCount
        ),
        isExactOwnedAudioStatus(
            pathStatus,
            effectiveUserID: directory.effectiveUserID,
            expectedByteCount: expectedByteCount
        ),
        FileSnapshot(descriptorStatus) == FileSnapshot(pathStatus) else {
            throw IOSPendingRecordingAudioFileSystemError.removeFailed
        }
        try validateExactConfiguration(descriptor: descriptor, control: control)
        try requireSuccess(control: control, failure: .removeFailed) {
            adapter.lock(fileDescriptor: descriptor, operation: LOCK_EX | LOCK_NB)
        }
        let finalDescriptorStatus = try status(
            descriptor: descriptor,
            control: control,
            failure: .removeFailed
        )
        let finalPathResult = try call(control: control) {
            adapter.statusAt(
                directoryDescriptor: directory.descriptor,
                name: name,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }
        if case .failure(let errorCode) = finalPathResult,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let finalPathStatus) = finalPathResult,
              FileSnapshot(finalDescriptorStatus) == FileSnapshot(descriptorStatus),
              FileSnapshot(finalPathStatus) == FileSnapshot(descriptorStatus) else {
            throw IOSPendingRecordingAudioFileSystemError.removeFailed
        }
        do {
            try validateExactConfiguration(descriptor: descriptor, control: control)
        } catch IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        } catch {
            throw IOSPendingRecordingAudioFileSystemError.removeFailed
        }
        try validatePendingDirectoryPath(directory, control: control)
        try requireSuccess(control: control, failure: .removeFailed) {
            adapter.unlinkAt(directoryDescriptor: directory.descriptor, name: name)
        }
        try validatePendingDirectoryPath(directory, control: control)
        try requireMissingAfterRemoval(
            name: name,
            directoryDescriptor: directory.descriptor,
            control: control
        )
        try synchronize(
            directory.descriptor,
            control: control,
            failure: .removeFailed
        )
        try validatePendingDirectoryPath(directory, control: control)
        try requireMissingAfterRemoval(
            name: name,
            directoryDescriptor: directory.descriptor,
            control: control
        )
        return true
    }

    func revalidateLease(
        relativeIdentifier: String,
        fileURL: URL,
        directoryDescriptor: Int32,
        fileDescriptor: Int32,
        identity: FileIdentity,
        byteCount: Int64,
        durationMilliseconds: Int64,
        onOperationFinished: @escaping @Sendable () -> Void
    ) async throws -> AudioRecordingArtifact {
        try await runQueued(
            deadlineNanoseconds: Self.copyDeadlineNanoseconds,
            onOperationFinished: onOperationFinished
        ) { control in
            guard IOSPendingRecordingStorageLocation.audioFileURL(
                forRelativeIdentifier: relativeIdentifier,
                in: self.applicationSupportDirectoryURL
            ) == fileURL else {
                throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
            }
            let directory = DirectoryHandle(
                descriptor: directoryDescriptor,
                effectiveUserID: try self.readEffectiveUserID(control: control),
                identity: FileIdentity(
                    try self.status(
                        descriptor: directoryDescriptor,
                        control: control,
                        failure: .protectedAudioInvalid
                    )
                )
            )
            try self.validateOwnedAudio(
                descriptor: fileDescriptor,
                name: fileURL.lastPathComponent,
                directory: directory,
                expectedIdentity: identity,
                expectedByteCount: byteCount,
                control: control
            )
            try control.checkpoint()
            let mediaDuration = try self.validatedMediaDuration(for: fileURL)
            try self.validateMediaDuration(
                mediaDuration,
                expectedDuration: durationMilliseconds
            )
            try self.validateOwnedAudio(
                descriptor: fileDescriptor,
                name: fileURL.lastPathComponent,
                directory: directory,
                expectedIdentity: identity,
                expectedByteCount: byteCount,
                control: control
            )
            return AudioRecordingArtifact(
                fileURL: fileURL,
                duration: TimeInterval(durationMilliseconds) / 1_000,
                byteCount: byteCount
            )
        }
    }

    func validateMediaDuration(
        _ actualDuration: Int64,
        expectedDuration: Int64
    ) throws {
        let delta = actualDuration.subtractingReportingOverflow(expectedDuration)
        guard actualDuration > 0,
              actualDuration < 300_000,
              !delta.overflow,
              delta.partialValue != Int64.min,
              abs(delta.partialValue) <= Self.maximumDurationDeltaMilliseconds else {
            throw IOSPendingRecordingAudioFileSystemError.mediaValidationFailed
        }
    }

    func validatedMediaDuration(for fileURL: URL) throws -> Int64 {
        do {
            return try mediaValidator.durationMilliseconds(
                for: fileURL,
                timeoutNanoseconds: Self.mediaValidationDeadlineNanoseconds
            )
        } catch IOSPendingRecordingAudioFileSystemError.mediaValidationTimedOut {
            throw IOSPendingRecordingAudioFileSystemError.mediaValidationTimedOut
        } catch IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        } catch {
            throw IOSPendingRecordingAudioFileSystemError.mediaValidationFailed
        }
    }

    func canonicalDurationMilliseconds(_ duration: TimeInterval) -> Int64? {
        guard duration.isFinite, duration > 0 else { return nil }
        let milliseconds = duration * 1_000
        guard milliseconds.isFinite,
              milliseconds >= Double(Int64.min),
              milliseconds <= Double(Int64.max) else {
            return nil
        }
        return Int64(milliseconds.rounded(.toNearestOrAwayFromZero))
    }

    func expectedRelativeIdentifier(
        attemptID: UUID,
        fileExtension: String
    ) -> String? {
        let format: IOSPendingRecordingAudioFormat
        switch fileExtension {
        case "m4a":
            format = .m4a
        case "wav":
            format = .wav
        default:
            return nil
        }
        return IOSPendingRecordingStorageLocation.relativeAudioIdentifier(
            for: attemptID,
            format: format
        )
    }

    func fileExtension(for format: IOSPendingRecordingAudioFormat) -> String {
        switch format {
        case .m4a: "m4a"
        case .wav: "wav"
        }
    }
}

fileprivate extension FoundationIOSPendingRecordingAudioFileSystem {
    struct SourceHandle {
        let descriptor: Int32
        let fileURL: URL
        let snapshot: FileSnapshot
    }

    struct FileIdentity: Equatable, Sendable {
        let device: dev_t
        let inode: ino_t

        init(_ value: stat) {
            device = value.st_dev
            inode = value.st_ino
        }
    }

    struct FileSnapshot: Equatable, Sendable {
        let identity: FileIdentity
        let byteCount: off_t
        let modificationSeconds: time_t
        let modificationNanoseconds: Int
        let statusChangeSeconds: time_t
        let statusChangeNanoseconds: Int

        init(_ value: stat) {
            identity = FileIdentity(value)
            byteCount = value.st_size
            modificationSeconds = value.st_mtimespec.tv_sec
            modificationNanoseconds = value.st_mtimespec.tv_nsec
            statusChangeSeconds = value.st_ctimespec.tv_sec
            statusChangeNanoseconds = value.st_ctimespec.tv_nsec
        }
    }

    func readEffectiveUserID(
        control: PendingRecordingOperationControl
    ) throws -> uid_t {
        let result = try call(control: control) { adapter.effectiveUserID() }
        guard case .success(let value) = result else {
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
        return value
    }

    func status(
        descriptor: Int32,
        control: PendingRecordingOperationControl,
        failure: IOSPendingRecordingAudioFileSystemError
    ) throws -> stat {
        let result = try call(control: control) {
            adapter.status(of: descriptor)
        }
        switch result {
        case .success(let value):
            return value
        case .failure(let errorCode) where isDataProtectionFailure(errorCode):
            throw IOSPendingRecordingAudioFileSystemError
                .dataProtectionUnavailable
        case .failure:
            throw failure
        }
    }

    func statusSnapshot(
        descriptor: Int32,
        control: PendingRecordingOperationControl,
        failure: IOSPendingRecordingAudioFileSystemError
    ) throws -> FileSnapshot {
        FileSnapshot(
            try status(
                descriptor: descriptor,
                control: control,
                failure: failure
            )
        )
    }

    func validateSourceStatus(
        _ value: stat,
        effectiveUserID: uid_t,
        expectedByteCount: Int64
    ) throws {
        guard value.st_mode & S_IFMT == S_IFREG,
              value.st_uid == effectiveUserID,
              value.st_nlink == 1,
              value.st_size == off_t(expectedByteCount) else {
            throw IOSPendingRecordingAudioFileSystemError.invalidSource
        }
    }

    func isExactOwnedAudioStatus(
        _ value: stat,
        effectiveUserID: uid_t,
        expectedByteCount: Int64
    ) -> Bool {
        value.st_mode & S_IFMT == S_IFREG
            && value.st_uid == effectiveUserID
            && value.st_nlink == 1
            && value.st_mode & mode_t(0o7777) == mode_t(0o600)
            && value.st_size == off_t(expectedByteCount)
    }

    func isDataProtectionFailure(_ errorCode: Int32) -> Bool {
        errorCode == EACCES || errorCode == EPERM
    }

    func validatePendingDirectoryPath(
        _ directory: DirectoryHandle,
        control: PendingRecordingOperationControl
    ) throws {
        let result = try call(control: control) {
            adapter.statusAtPath(
                IOSPendingRecordingStorageLocation.audioDirectoryURL(
                    in: applicationSupportDirectoryURL
                ).path
            )
        }
        if case .failure(let errorCode) = result,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .success(let value) = result,
              value.st_mode & S_IFMT == S_IFDIR,
              value.st_uid == directory.effectiveUserID,
              value.st_mode & mode_t(0o7777) == mode_t(0o700),
              FileIdentity(value) == directory.identity else {
            throw IOSPendingRecordingAudioFileSystemError.namespaceUnavailable
        }
    }

    func call<Value>(
        control: PendingRecordingOperationControl,
        operation: () -> IOSPendingRecordingPOSIXResult<Value>
    ) throws -> IOSPendingRecordingPOSIXResult<Value> {
        var interruptedRetryCount = 0
        while true {
            try control.checkpoint()
            let result = operation()
            if case .failure(EINTR) = result,
               interruptedRetryCount < Self.maximumInterruptedRetryCount {
                interruptedRetryCount += 1
                continue
            }
            return result
        }
    }

    func transferCount(
        control: PendingRecordingOperationControl,
        failure: IOSPendingRecordingAudioFileSystemError,
        operation: () -> IOSPendingRecordingPOSIXResult<Int>
    ) throws -> Int {
        let result = try call(control: control, operation: operation)
        switch result {
        case .success(let count):
            return count
        case .failure(let errorCode) where isDataProtectionFailure(errorCode):
            throw IOSPendingRecordingAudioFileSystemError
                .dataProtectionUnavailable
        case .failure:
            throw failure
        }
    }

    func requireSuccess(
        control: PendingRecordingOperationControl,
        failure: IOSPendingRecordingAudioFileSystemError,
        operation: () -> IOSPendingRecordingPOSIXResult<Void>
    ) throws {
        let result = try call(control: control, operation: operation)
        switch result {
        case .success:
            return
        case .failure(let errorCode) where isDataProtectionFailure(errorCode):
            throw IOSPendingRecordingAudioFileSystemError
                .dataProtectionUnavailable
        case .failure:
            throw failure
        }
    }

    func synchronize(
        _ descriptor: Int32,
        control: PendingRecordingOperationControl,
        failure: IOSPendingRecordingAudioFileSystemError
    ) throws {
        try requireSuccess(control: control, failure: failure) {
            adapter.synchronize(fileDescriptor: descriptor)
        }
    }

    func unlinkOwnedTemporaryIfPresent(
        name: String,
        identity: FileIdentity,
        directoryDescriptor: Int32,
        control: PendingRecordingOperationControl
    ) {
        guard let statusResult = try? call(control: control, operation: {
            adapter.statusAt(
                directoryDescriptor: directoryDescriptor,
                name: name,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }), case .success(let status) = statusResult,
              FileIdentity(status) == identity else {
            return
        }
        _ = try? call(control: control) {
            adapter.unlinkAt(directoryDescriptor: directoryDescriptor, name: name)
        }
    }

    func requireMissingAfterRemoval(
        name: String,
        directoryDescriptor: Int32,
        control: PendingRecordingOperationControl
    ) throws {
        let result = try call(control: control) {
            adapter.statusAt(
                directoryDescriptor: directoryDescriptor,
                name: name,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }
        if case .failure(let errorCode) = result,
           isDataProtectionFailure(errorCode) {
            throw IOSPendingRecordingAudioFileSystemError.dataProtectionUnavailable
        }
        guard case .failure(ENOENT) = result else {
            throw IOSPendingRecordingAudioFileSystemError.removeFailed
        }
    }
}

private final class POSIXIOSPendingRecordingPublishedAudioLease:
    IOSPendingRecordingPublishedAudioLease,
    @unchecked Sendable {
    private struct State {
        var directoryDescriptor: Int32?
        var fileDescriptor: Int32?
        var activeRevalidationCount = 0
        var releaseRequested = false
    }

    let relativeIdentifier: String
    let audioArtifact: AudioRecordingArtifact
    let durationMilliseconds: Int64

    private let fileSystem: FoundationIOSPendingRecordingAudioFileSystem
    private let fileURL: URL
    private let identity: FoundationIOSPendingRecordingAudioFileSystem.FileIdentity
    private let byteCount: Int64
    private let lock = NSLock()
    private var state: State

    init(
        fileSystem: FoundationIOSPendingRecordingAudioFileSystem,
        relativeIdentifier: String,
        fileURL: URL,
        directoryDescriptor: Int32,
        fileDescriptor: Int32,
        identity: FoundationIOSPendingRecordingAudioFileSystem.FileIdentity,
        byteCount: Int64,
        durationMilliseconds: Int64
    ) {
        self.fileSystem = fileSystem
        self.relativeIdentifier = relativeIdentifier
        self.fileURL = fileURL
        self.identity = identity
        self.byteCount = byteCount
        self.durationMilliseconds = durationMilliseconds
        audioArtifact = AudioRecordingArtifact(
            fileURL: fileURL,
            duration: TimeInterval(durationMilliseconds) / 1_000,
            byteCount: byteCount
        )
        state = State(
            directoryDescriptor: directoryDescriptor,
            fileDescriptor: fileDescriptor
        )
    }

    func revalidate() async throws -> AudioRecordingArtifact {
        let descriptors = try lock.withLock { () throws -> (Int32, Int32) in
            guard !state.releaseRequested,
                  let directoryDescriptor = state.directoryDescriptor,
                  let fileDescriptor = state.fileDescriptor else {
                throw IOSPendingRecordingAudioFileSystemError.protectedAudioInvalid
            }
            state.activeRevalidationCount += 1
            return (directoryDescriptor, fileDescriptor)
        }
        return try await fileSystem.revalidateLease(
            relativeIdentifier: relativeIdentifier,
            fileURL: fileURL,
            directoryDescriptor: descriptors.0,
            fileDescriptor: descriptors.1,
            identity: identity,
            byteCount: byteCount,
            durationMilliseconds: durationMilliseconds,
            onOperationFinished: { [self] in finishRevalidation() }
        )
    }

    func release() {
        let descriptors = lock.withLock { () -> (Int32?, Int32?) in
            guard !state.releaseRequested else { return (nil, nil) }
            state.releaseRequested = true
            guard state.activeRevalidationCount == 0 else {
                return (nil, nil)
            }
            return takeDescriptorsForClose()
        }
        close(descriptors)
    }

    private func finishRevalidation() {
        let descriptors = lock.withLock { () -> (Int32?, Int32?) in
            guard state.activeRevalidationCount > 0 else {
                assertionFailure("A pending-recording revalidation must be active.")
                return (nil, nil)
            }
            state.activeRevalidationCount -= 1
            guard state.activeRevalidationCount == 0,
                  state.releaseRequested else {
                return (nil, nil)
            }
            return takeDescriptorsForClose()
        }
        close(descriptors)
    }

    private func takeDescriptorsForClose() -> (Int32?, Int32?) {
        let descriptors = (state.directoryDescriptor, state.fileDescriptor)
        state.directoryDescriptor = nil
        state.fileDescriptor = nil
        return descriptors
    }

    private func close(_ descriptors: (Int32?, Int32?)) {
        if let fileDescriptor = descriptors.1 {
            fileSystem.adapter.closeFile(fileDescriptor)
        }
        if let directoryDescriptor = descriptors.0 {
            fileSystem.adapter.closeFile(directoryDescriptor)
        }
    }

    deinit {
        release()
    }
}

private final class PendingRecordingOperationControl: @unchecked Sendable {
    private enum TerminalState {
        case active
        case cancelled
        case expired
    }

    private let lock = NSLock()
    private let timeoutNanoseconds: UInt64
    private let startNanoseconds: UInt64
    private let monotonicClock: @Sendable () -> UInt64?
    private var terminalState = TerminalState.active

    init(
        timeoutNanoseconds: UInt64,
        monotonicClock: @escaping @Sendable () -> UInt64?
    ) throws {
        guard let startNanoseconds = monotonicClock() else {
            throw IOSPendingRecordingAudioFileSystemError.operationTimedOut
        }
        self.timeoutNanoseconds = timeoutNanoseconds
        self.startNanoseconds = startNanoseconds
        self.monotonicClock = monotonicClock
    }

    func cancel() {
        lock.withLock {
            if case .active = terminalState {
                terminalState = .cancelled
            }
        }
    }

    func expire() {
        lock.withLock {
            if case .active = terminalState {
                terminalState = .expired
            }
        }
    }

    func checkpoint() throws {
        switch lock.withLock({ terminalState }) {
        case .cancelled:
            throw IOSPendingRecordingAudioFileSystemError.operationCancelled
        case .expired:
            throw IOSPendingRecordingAudioFileSystemError.operationTimedOut
        case .active:
            break
        }
        guard let current = monotonicClock(),
              current >= startNanoseconds,
              current - startNanoseconds < timeoutNanoseconds else {
            throw IOSPendingRecordingAudioFileSystemError.operationTimedOut
        }
    }
}

private final class PendingRecordingOperationCompletion<Value: Sendable>:
    @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, any Error>?
    private var pendingResult: Result<Value, any Error>?
    private var isResolved = false

    func install(_ continuation: CheckedContinuation<Value, any Error>) {
        let result = lock.withLock { () -> Result<Value, any Error>? in
            if let pendingResult {
                self.pendingResult = nil
                return pendingResult
            }
            self.continuation = continuation
            return nil
        }
        if let result {
            continuation.resume(with: result)
        }
    }

    @discardableResult
    func resolve(_ result: Result<Value, any Error>) -> Bool {
        let resolution = lock.withLock {
            () -> (Bool, CheckedContinuation<Value, any Error>?) in
            guard !isResolved else { return (false, nil) }
            isResolved = true
            guard let continuation else {
                pendingResult = result
                return (true, nil)
            }
            self.continuation = nil
            return (true, continuation)
        }
        if let continuation = resolution.1 {
            continuation.resume(with: result)
        }
        return resolution.0
    }
}

private func systemPendingRecordingMonotonicNanoseconds() -> UInt64? {
    var value = timespec()
    guard Darwin.clock_gettime(CLOCK_MONOTONIC, &value) == 0,
          value.tv_sec >= 0,
          value.tv_nsec >= 0 else {
        return nil
    }
    let seconds = UInt64(value.tv_sec).multipliedReportingOverflow(
        by: 1_000_000_000
    )
    guard !seconds.overflow else { return nil }
    let total = seconds.partialValue.addingReportingOverflow(UInt64(value.tv_nsec))
    return total.overflow ? nil : total.partialValue
}

private func isIOSPendingRecordingProtectedDataError(_ error: Error) -> Bool {
    var currentError: NSError? = error as NSError
    var inspectedErrorCount = 0
    while let error = currentError, inspectedErrorCount < 8 {
        if error.domain == NSPOSIXErrorDomain,
           error.code == Int(EACCES) || error.code == Int(EPERM) {
            return true
        }
        if error.domain == NSCocoaErrorDomain,
           error.code == CocoaError.Code.fileReadNoPermission.rawValue
            || error.code == CocoaError.Code.fileWriteNoPermission.rawValue {
            return true
        }
        if error.domain == AVFoundationErrorDomain,
           error.code == AVError.Code.contentIsProtected.rawValue {
            return true
        }
        currentError = error.userInfo[NSUnderlyingErrorKey] as? NSError
        inspectedErrorCount += 1
    }
    return false
}
