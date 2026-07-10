import Darwin
import Foundation

nonisolated enum OpenAIMultipartScratchNamespace {
    static let directoryName = "holdtype-openai-multipart"
    static let v1Prefix = "htmp-v1-"
    static let fileExtension = ".multipart"
    static let markerName = "com.holdtype.openai.multipart-scratch"
    static let markerValue: [UInt8] = [0x76, 0x31]

    static var defaultDirectoryURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
    }

    static func v1FileName(for identifier: UUID) -> String {
        v1Prefix + identifier.uuidString.lowercased() + fileExtension
    }

    static func legacyFileName(for identifier: UUID) -> String {
        identifier.uuidString.uppercased() + fileExtension
    }

    static func identifier(inV1FileName fileName: String) -> UUID? {
        guard fileName.hasPrefix(v1Prefix),
              fileName.hasSuffix(fileExtension) else {
            return nil
        }
        let start = fileName.index(fileName.startIndex, offsetBy: v1Prefix.count)
        let end = fileName.index(fileName.endIndex, offsetBy: -fileExtension.count)
        let value = String(fileName[start..<end])
        guard let identifier = UUID(uuidString: value),
              value == identifier.uuidString.lowercased(),
              fileName == v1FileName(for: identifier) else {
            return nil
        }
        return identifier
    }

    static func identifier(inLegacyFileName fileName: String) -> UUID? {
        guard fileName.hasSuffix(fileExtension) else {
            return nil
        }
        let end = fileName.index(fileName.endIndex, offsetBy: -fileExtension.count)
        let value = String(fileName[..<end])
        guard let identifier = UUID(uuidString: value),
              value == identifier.uuidString.uppercased(),
              fileName == legacyFileName(for: identifier) else {
            return nil
        }
        return identifier
    }

    static func installMarker(on fileDescriptor: Int32) -> Bool {
        markerName.withCString { name in
            markerValue.withUnsafeBytes { value in
                Darwin.fsetxattr(
                    fileDescriptor,
                    name,
                    value.baseAddress,
                    value.count,
                    0,
                    XATTR_CREATE
                ) == 0
            }
        }
    }

    static func hasExactMarker(on fileDescriptor: Int32) -> Bool {
        var bytes = [UInt8](repeating: 0, count: markerValue.count + 1)
        let count = markerName.withCString { name in
            bytes.withUnsafeMutableBytes { buffer in
                Darwin.fgetxattr(
                    fileDescriptor,
                    name,
                    buffer.baseAddress,
                    buffer.count,
                    0,
                    0
                )
            }
        }
        return count == markerValue.count
            && Array(bytes.prefix(markerValue.count)) == markerValue
    }
}

public nonisolated enum OpenAIProviderStartupMaintenance {
    private static let scheduler = OpenAIProviderStartupMaintenanceScheduler()

    public static func schedule() {
        scheduler.schedule {
            _ = OpenAIMultipartScratchScavenger().run()
        }
    }
}

nonisolated final class OpenAIProviderStartupMaintenanceScheduler:
    @unchecked Sendable {
    typealias Dispatch = @Sendable (@escaping @Sendable () -> Void) -> Void

    private let lock = NSLock()
    private let dispatch: Dispatch
    private var didSchedule = false

    init(
        dispatch: @escaping Dispatch = { operation in
            DispatchQueue.global(qos: .utility).async(execute: operation)
        }
    ) {
        self.dispatch = dispatch
    }

    @discardableResult
    func schedule(_ operation: @escaping @Sendable () -> Void) -> Bool {
        let shouldSchedule = lock.withLock { () -> Bool in
            guard !didSchedule else {
                return false
            }
            didSchedule = true
            return true
        }
        guard shouldSchedule else {
            return false
        }
        dispatch(operation)
        return true
    }
}

nonisolated struct OpenAIMultipartScratchTimestamp:
    Comparable,
    Equatable,
    Sendable {
    let seconds: Int64
    let nanoseconds: Int64

    static func < (
        lhs: OpenAIMultipartScratchTimestamp,
        rhs: OpenAIMultipartScratchTimestamp
    ) -> Bool {
        lhs.seconds < rhs.seconds
            || (lhs.seconds == rhs.seconds && lhs.nanoseconds < rhs.nanoseconds)
    }

    func isAtLeast(
        _ ageInSeconds: Int64,
        before reference: OpenAIMultipartScratchTimestamp
    ) -> Bool {
        guard self <= reference else {
            return false
        }
        let cutoff = reference.seconds.subtractingReportingOverflow(ageInSeconds)
        guard !cutoff.overflow else {
            return false
        }
        return self <= OpenAIMultipartScratchTimestamp(
            seconds: cutoff.partialValue,
            nanoseconds: reference.nanoseconds
        )
    }
}

nonisolated enum OpenAIMultipartScratchKind: Equatable, Sendable {
    case markedV1
    case legacy

    var minimumAgeInSeconds: Int64 {
        switch self {
        case .markedV1:
            60 * 60
        case .legacy:
            24 * 60 * 60
        }
    }
}

nonisolated enum OpenAIMultipartScratchDirectoryEntry: Equatable, Sendable {
    case name(String)
    case invalidName
}

nonisolated struct OpenAIMultipartScratchDeletionSnapshot: Equatable, Sendable {
    let identity: OpenAITranscriptionFileIdentity
    let referenceTime: OpenAIMultipartScratchTimestamp
    let minimumAgeInSeconds: Int64
}

nonisolated protocol OpenAIMultipartScratchCandidate: AnyObject {
    func makeDeletionSnapshot(
        referenceTime: OpenAIMultipartScratchTimestamp,
        minimumAgeInSeconds: Int64,
        shouldStartOperation: () -> Bool
    ) -> OpenAIMultipartScratchDeletionSnapshot?
    func removeIfUnchanged(
        _ snapshot: OpenAIMultipartScratchDeletionSnapshot,
        shouldStartOperation: () -> Bool
    ) -> Bool
    func close()
}

nonisolated protocol OpenAIMultipartScratchDirectory: AnyObject {
    func nextEntry(
        shouldStartOperation: () -> Bool
    ) throws -> OpenAIMultipartScratchDirectoryEntry?
    func openCandidate(
        named fileName: String,
        kind: OpenAIMultipartScratchKind,
        shouldStartOperation: () -> Bool
    ) throws -> (any OpenAIMultipartScratchCandidate)?
    func close()
}

nonisolated protocol OpenAIMultipartScratchFileSystem {
    func openNamespace(
        at directoryURL: URL,
        shouldStartOperation: () -> Bool
    ) throws -> (any OpenAIMultipartScratchDirectory)?
}

nonisolated struct OpenAIMultipartScratchScavengeSummary:
    Equatable,
    Sendable,
    CustomStringConvertible,
    CustomDebugStringConvertible,
    CustomReflectable {
    enum StopReason: Equatable, Sendable {
        case complete
        case namespaceUnavailable
        case directoryFailure
        case entryLimit
        case removalLimit
        case byteLimit
        case timeLimit
        case clockFailure
    }

    let inspectedEntryCount: Int
    let removedFileCount: Int
    let accountedByteCount: Int64
    let stopReason: StopReason

    var description: String {
        "OpenAIMultipartScratchScavengeSummary(<redacted>)"
    }

    var debugDescription: String { description }

    var customMirror: Mirror {
        Mirror(
            self,
            children: [(label: String?, value: Any)](),
            displayStyle: .struct
        )
    }
}

nonisolated struct OpenAIMultipartScratchScavenger {
    static let maximumInspectedEntryCount = 256
    static let maximumRemovedFileCount = 32
    static let maximumAccountedByteCount: Int64 = 512 * 1_024 * 1_024
    static let maximumElapsedNanoseconds: UInt64 = 1_000_000_000

    private let namespaceURL: URL
    private let fileSystem: any OpenAIMultipartScratchFileSystem
    private let wallClock: @Sendable () -> OpenAIMultipartScratchTimestamp?
    private let monotonicClock: @Sendable () -> UInt64?

    init(
        namespaceURL: URL = OpenAIMultipartScratchNamespace.defaultDirectoryURL,
        fileSystem: any OpenAIMultipartScratchFileSystem =
            POSIXOpenAIMultipartScratchFileSystem(),
        wallClock: @escaping @Sendable () -> OpenAIMultipartScratchTimestamp? = {
            systemScratchTimestamp(clock: CLOCK_REALTIME)
        },
        monotonicClock: @escaping @Sendable () -> UInt64? = {
            systemScratchNanoseconds(clock: CLOCK_MONOTONIC)
        }
    ) {
        self.namespaceURL = namespaceURL
        self.fileSystem = fileSystem
        self.wallClock = wallClock
        self.monotonicClock = monotonicClock
    }

    func run() -> OpenAIMultipartScratchScavengeSummary {
        guard let referenceTime = wallClock(),
              let startTime = monotonicClock() else {
            return summary(stopReason: .clockFailure)
        }

        let directory: (any OpenAIMultipartScratchDirectory)?
        do {
            directory = try fileSystem.openNamespace(
                at: namespaceURL,
                shouldStartOperation: {
                    withinTimeBudget(startTime: startTime)
                }
            )
        } catch {
            return summary(stopReason: .namespaceUnavailable)
        }
        guard withinTimeBudget(startTime: startTime) else {
            directory?.close()
            return summary(stopReason: .timeLimit)
        }
        guard let directory else {
            return summary(stopReason: .complete)
        }
        defer { directory.close() }

        var inspectedEntryCount = 0
        var removedFileCount = 0
        var accountedByteCount: Int64 = 0

        while true {
            guard withinTimeBudget(startTime: startTime) else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }
            guard inspectedEntryCount < Self.maximumInspectedEntryCount else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .entryLimit
                )
            }

            let entry: OpenAIMultipartScratchDirectoryEntry?
            do {
                entry = try directory.nextEntry(
                    shouldStartOperation: {
                        withinTimeBudget(startTime: startTime)
                    }
                )
            } catch {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .directoryFailure
                )
            }
            guard withinTimeBudget(startTime: startTime) else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }
            guard let entry else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .complete
                )
            }

            if case .name(let name) = entry, name == "." || name == ".." {
                continue
            }
            inspectedEntryCount += 1

            guard case .name(let fileName) = entry,
                  let kind = kind(for: fileName) else {
                continue
            }
            guard withinTimeBudget(startTime: startTime) else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }

            let candidate: (any OpenAIMultipartScratchCandidate)?
            do {
                candidate = try directory.openCandidate(
                    named: fileName,
                    kind: kind,
                    shouldStartOperation: {
                        withinTimeBudget(startTime: startTime)
                    }
                )
            } catch {
                continue
            }
            guard let candidate else {
                continue
            }

            guard withinTimeBudget(startTime: startTime) else {
                candidate.close()
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }
            guard let deletionSnapshot = candidate.makeDeletionSnapshot(
                referenceTime: referenceTime,
                minimumAgeInSeconds: kind.minimumAgeInSeconds,
                shouldStartOperation: {
                    withinTimeBudget(startTime: startTime)
                }
            ) else {
                candidate.close()
                continue
            }

            let byteCount = deletionSnapshot.identity.byteCount
            let addition = accountedByteCount.addingReportingOverflow(byteCount)
            guard !addition.overflow,
                  addition.partialValue <= Self.maximumAccountedByteCount else {
                candidate.close()
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .byteLimit
                )
            }
            accountedByteCount = addition.partialValue
            guard withinTimeBudget(startTime: startTime) else {
                candidate.close()
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .timeLimit
                )
            }

            if candidate.removeIfUnchanged(
                deletionSnapshot,
                shouldStartOperation: {
                    withinTimeBudget(startTime: startTime)
                }
            ) {
                removedFileCount += 1
            }
            candidate.close()
            guard removedFileCount < Self.maximumRemovedFileCount else {
                return summary(
                    inspected: inspectedEntryCount,
                    removed: removedFileCount,
                    bytes: accountedByteCount,
                    stopReason: .removalLimit
                )
            }
        }
    }

    private func kind(for fileName: String) -> OpenAIMultipartScratchKind? {
        if OpenAIMultipartScratchNamespace.identifier(inV1FileName: fileName) != nil {
            return .markedV1
        }
        if OpenAIMultipartScratchNamespace.identifier(inLegacyFileName: fileName) != nil {
            return .legacy
        }
        return nil
    }

    private func withinTimeBudget(startTime: UInt64) -> Bool {
        guard let currentTime = monotonicClock(), currentTime >= startTime else {
            return false
        }
        return currentTime - startTime < Self.maximumElapsedNanoseconds
    }

    private func summary(
        inspected: Int = 0,
        removed: Int = 0,
        bytes: Int64 = 0,
        stopReason: OpenAIMultipartScratchScavengeSummary.StopReason
    ) -> OpenAIMultipartScratchScavengeSummary {
        OpenAIMultipartScratchScavengeSummary(
            inspectedEntryCount: inspected,
            removedFileCount: removed,
            accountedByteCount: bytes,
            stopReason: stopReason
        )
    }
}

nonisolated struct POSIXOpenAIMultipartScratchFileSystem:
    OpenAIMultipartScratchFileSystem {
    func openNamespace(
        at directoryURL: URL,
        shouldStartOperation: () -> Bool
    ) throws -> (any OpenAIMultipartScratchDirectory)? {
        directoryURL.withUnsafeFileSystemRepresentation { path in
            guard let path, shouldStartOperation() else {
                return nil
            }
            let descriptor = Darwin.open(
                path,
                O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
            guard descriptor >= 0 else {
                return nil
            }

            var status = stat()
            guard shouldStartOperation(),
                  Darwin.fstat(descriptor, &status) == 0,
                  status.st_mode & S_IFMT == S_IFDIR,
                  status.st_uid == geteuid(),
                  status.st_mode & mode_t(0o777) == mode_t(0o700) else {
                Darwin.close(descriptor)
                return nil
            }
            guard shouldStartOperation(),
                  let stream = Darwin.fdopendir(descriptor) else {
                Darwin.close(descriptor)
                return nil
            }
            return POSIXOpenAIMultipartScratchDirectory(stream: stream)
        }
    }
}

nonisolated private final class POSIXOpenAIMultipartScratchDirectory:
    OpenAIMultipartScratchDirectory {
    private var stream: UnsafeMutablePointer<DIR>?

    init(stream: UnsafeMutablePointer<DIR>) {
        self.stream = stream
    }

    func nextEntry(
        shouldStartOperation: () -> Bool
    ) throws -> OpenAIMultipartScratchDirectoryEntry? {
        guard let stream, shouldStartOperation() else {
            return nil
        }
        errno = 0
        guard let entry = Darwin.readdir(stream) else {
            if errno != 0 {
                throw POSIXOpenAIMultipartScratchError.directoryReadFailed
            }
            return nil
        }
        let name = withUnsafePointer(to: &entry.pointee.d_name) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: Int(entry.pointee.d_namlen) + 1
            ) { String(validatingCString: $0) }
        }
        guard let name else {
            return .invalidName
        }
        return .name(name)
    }

    func openCandidate(
        named fileName: String,
        kind: OpenAIMultipartScratchKind,
        shouldStartOperation: () -> Bool
    ) throws -> (any OpenAIMultipartScratchCandidate)? {
        guard let stream, shouldStartOperation() else {
            return nil
        }
        let directoryDescriptor = Darwin.dirfd(stream)
        let descriptor = fileName.withCString { name in
            Darwin.openat(
                directoryDescriptor,
                name,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
        }
        guard descriptor >= 0 else {
            return nil
        }

        var status = stat()
        guard shouldStartOperation(),
              Darwin.fstat(descriptor, &status) == 0,
              isEligibleScratchStatus(status),
              (kind != .markedV1
                || (shouldStartOperation()
                    && OpenAIMultipartScratchNamespace.hasExactMarker(
                        on: descriptor
                    ))),
              shouldStartOperation(),
              flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            Darwin.close(descriptor)
            return nil
        }
        return POSIXOpenAIMultipartScratchCandidate(
            directoryDescriptor: directoryDescriptor,
            fileDescriptor: descriptor,
            fileName: fileName,
            kind: kind,
            identity: fileIdentity(status)
        )
    }

    func close() {
        guard let stream else {
            return
        }
        self.stream = nil
        Darwin.closedir(stream)
    }

    deinit {
        close()
    }
}

nonisolated private final class POSIXOpenAIMultipartScratchCandidate:
    OpenAIMultipartScratchCandidate {
    private let directoryDescriptor: Int32
    private var fileDescriptor: Int32?
    private let fileName: String
    private let kind: OpenAIMultipartScratchKind
    private let identity: OpenAITranscriptionFileIdentity

    init(
        directoryDescriptor: Int32,
        fileDescriptor: Int32,
        fileName: String,
        kind: OpenAIMultipartScratchKind,
        identity: OpenAITranscriptionFileIdentity
    ) {
        self.directoryDescriptor = directoryDescriptor
        self.fileDescriptor = fileDescriptor
        self.fileName = fileName
        self.kind = kind
        self.identity = identity
    }

    func makeDeletionSnapshot(
        referenceTime: OpenAIMultipartScratchTimestamp,
        minimumAgeInSeconds: Int64,
        shouldStartOperation: () -> Bool
    ) -> OpenAIMultipartScratchDeletionSnapshot? {
        guard let fileDescriptor else {
            return nil
        }
        var descriptorStatus = stat()
        guard shouldStartOperation(),
              Darwin.fstat(fileDescriptor, &descriptorStatus) == 0,
              isEligibleScratchStatus(descriptorStatus),
              fileIdentity(descriptorStatus) == identity,
              (kind != .markedV1
                || (shouldStartOperation()
                    && OpenAIMultipartScratchNamespace.hasExactMarker(
                        on: fileDescriptor
                    ))) else {
            return nil
        }

        var pathStatus = stat()
        guard shouldStartOperation() else {
            return nil
        }
        let statusResult = fileName.withCString { name in
            Darwin.fstatat(
                directoryDescriptor,
                name,
                &pathStatus,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard statusResult == 0,
              isEligibleScratchStatus(pathStatus),
              fileIdentity(pathStatus) == identity,
              newestTimestamp(for: descriptorStatus).isAtLeast(
                  minimumAgeInSeconds,
                  before: referenceTime
              ) else {
            return nil
        }
        return OpenAIMultipartScratchDeletionSnapshot(
            identity: identity,
            referenceTime: referenceTime,
            minimumAgeInSeconds: minimumAgeInSeconds
        )
    }

    func removeIfUnchanged(
        _ snapshot: OpenAIMultipartScratchDeletionSnapshot,
        shouldStartOperation: () -> Bool
    ) -> Bool {
        guard let fileDescriptor else {
            return false
        }
        var descriptorStatus = stat()
        guard shouldStartOperation(),
              Darwin.fstat(fileDescriptor, &descriptorStatus) == 0,
              isEligibleScratchStatus(descriptorStatus),
              fileIdentity(descriptorStatus) == snapshot.identity,
              newestTimestamp(for: descriptorStatus).isAtLeast(
                  snapshot.minimumAgeInSeconds,
                  before: snapshot.referenceTime
              ),
              (kind != .markedV1
                || (shouldStartOperation()
                    && OpenAIMultipartScratchNamespace.hasExactMarker(
                        on: fileDescriptor
                    ))),
              shouldStartOperation(),
              flock(fileDescriptor, LOCK_EX | LOCK_NB) == 0 else {
            return false
        }

        var pathStatus = stat()
        guard shouldStartOperation() else {
            return false
        }
        let statusResult = fileName.withCString { name in
            Darwin.fstatat(
                directoryDescriptor,
                name,
                &pathStatus,
                AT_SYMLINK_NOFOLLOW
            )
        }
        guard statusResult == 0,
              isEligibleScratchStatus(pathStatus),
              fileIdentity(pathStatus) == snapshot.identity,
              newestTimestamp(for: pathStatus).isAtLeast(
                  snapshot.minimumAgeInSeconds,
                  before: snapshot.referenceTime
              ),
              shouldStartOperation() else {
            return false
        }

        var result: Int32
        repeat {
            result = fileName.withCString { name in
                Darwin.unlinkat(directoryDescriptor, name, 0)
            }
        } while result != 0 && errno == EINTR
        return result == 0
    }

    func close() {
        guard let fileDescriptor else {
            return
        }
        self.fileDescriptor = nil
        Darwin.close(fileDescriptor)
    }

    deinit {
        close()
    }
}

nonisolated private enum POSIXOpenAIMultipartScratchError: Error {
    case directoryReadFailed
}

nonisolated private func isEligibleScratchStatus(_ status: stat) -> Bool {
    status.st_mode & S_IFMT == S_IFREG
        && status.st_uid == geteuid()
        && status.st_mode & mode_t(0o777) == mode_t(0o600)
        && status.st_nlink == 1
        && status.st_size >= 0
}

nonisolated private func newestTimestamp(
    for identity: OpenAITranscriptionFileIdentity
) -> OpenAIMultipartScratchTimestamp {
    max(
        OpenAIMultipartScratchTimestamp(
            seconds: identity.modificationSeconds,
            nanoseconds: identity.modificationNanoseconds
        ),
        OpenAIMultipartScratchTimestamp(
            seconds: identity.changeSeconds,
            nanoseconds: identity.changeNanoseconds
        )
    )
}

nonisolated private func newestTimestamp(
    for status: stat
) -> OpenAIMultipartScratchTimestamp {
    newestTimestamp(for: fileIdentity(status))
}

nonisolated private func systemScratchTimestamp(
    clock: clockid_t
) -> OpenAIMultipartScratchTimestamp? {
    var value = timespec()
    guard Darwin.clock_gettime(clock, &value) == 0 else {
        return nil
    }
    return OpenAIMultipartScratchTimestamp(
        seconds: Int64(value.tv_sec),
        nanoseconds: Int64(value.tv_nsec)
    )
}

nonisolated private func systemScratchNanoseconds(clock: clockid_t) -> UInt64? {
    guard let value = systemScratchTimestamp(clock: clock),
          value.seconds >= 0,
          value.nanoseconds >= 0 else {
        return nil
    }
    let seconds = UInt64(value.seconds).multipliedReportingOverflow(
        by: 1_000_000_000
    )
    guard !seconds.overflow else {
        return nil
    }
    let total = seconds.partialValue.addingReportingOverflow(
        UInt64(value.nanoseconds)
    )
    return total.overflow ? nil : total.partialValue
}
