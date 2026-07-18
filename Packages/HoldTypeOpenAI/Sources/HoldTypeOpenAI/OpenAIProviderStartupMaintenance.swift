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
        let adapter = DarwinOpenAIMultipartScratchPOSIXAdapter()
        return markerIsInstalled(
            on: fileDescriptor,
            adapter: adapter,
            shouldStartOperation: { true }
        )
    }

    static func hasExactMarker(on fileDescriptor: Int32) -> Bool {
        let adapter = DarwinOpenAIMultipartScratchPOSIXAdapter()
        return markerIsExact(
            on: fileDescriptor,
            adapter: adapter,
            shouldStartOperation: { true }
        )
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

nonisolated struct POSIXOpenAIMultipartScratchFileSystem:
    OpenAIMultipartScratchFileSystem {
    private let adapter: any OpenAIMultipartScratchPOSIXAdapter

    init(
        adapter: any OpenAIMultipartScratchPOSIXAdapter =
            DarwinOpenAIMultipartScratchPOSIXAdapter()
    ) {
        self.adapter = adapter
    }

    func openNamespace(
        at directoryURL: URL,
        shouldStartOperation: () -> Bool
    ) throws -> (any OpenAIMultipartScratchDirectory)? {
        let openResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.openFile(
                atPath: directoryURL.path,
                flags: O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
        }
        guard case .some(.success(let descriptor)) = openResult else {
            return nil
        }

        let statusResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.fileStatus(for: descriptor)
        }
        let userResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.effectiveUserID()
        }
        guard case .some(.success(let status)) = statusResult,
              case .some(.success(let effectiveUserID)) = userResult,
              status.st_mode & S_IFMT == S_IFDIR,
              status.st_uid == effectiveUserID,
              status.st_mode & mode_t(0o777) == mode_t(0o700) else {
            adapter.closeFile(descriptor)
            return nil
        }

        let streamResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.openDirectoryStream(for: descriptor)
        }
        guard case .some(.success(let stream)) = streamResult else {
            adapter.closeFile(descriptor)
            return nil
        }
        return POSIXOpenAIMultipartScratchDirectory(
            stream: stream,
            effectiveUserID: effectiveUserID,
            adapter: adapter
        )
    }
}

nonisolated final class POSIXOpenAIMultipartScratchDirectory:
    OpenAIMultipartScratchDirectory {
    private var stream: UnsafeMutablePointer<DIR>?
    private let effectiveUserID: uid_t
    private let adapter: any OpenAIMultipartScratchPOSIXAdapter

    init(
        stream: UnsafeMutablePointer<DIR>,
        effectiveUserID: uid_t,
        adapter: any OpenAIMultipartScratchPOSIXAdapter
    ) {
        self.stream = stream
        self.effectiveUserID = effectiveUserID
        self.adapter = adapter
    }

    func nextEntry(
        shouldStartOperation: () -> Bool
    ) throws -> OpenAIMultipartScratchDirectoryEntry? {
        guard let stream else {
            return nil
        }
        let result = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.nextDirectoryEntry(in: stream)
        }
        guard let result else {
            return nil
        }
        switch result {
        case .success(let entry):
            return entry
        case .failure:
            throw POSIXOpenAIMultipartScratchError.directoryReadFailed
        }
    }

    func openCandidate(
        named fileName: String,
        kind: OpenAIMultipartScratchKind,
        shouldStartOperation: () -> Bool
    ) throws -> (any OpenAIMultipartScratchCandidate)? {
        guard let stream else {
            return nil
        }
        let directoryResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.directoryDescriptor(for: stream)
        }
        guard case .some(.success(let directoryDescriptor)) = directoryResult else {
            return nil
        }

        let openResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.openFile(
                relativeTo: directoryDescriptor,
                named: fileName,
                flags: O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
        }
        guard case .some(.success(let descriptor)) = openResult else {
            return nil
        }

        let statusResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.fileStatus(for: descriptor)
        }
        guard case .some(.success(let status)) = statusResult,
              isEligibleScratchStatus(status, effectiveUserID: effectiveUserID),
              (kind != .markedV1
                || markerIsExact(
                    on: descriptor,
                    adapter: adapter,
                    shouldStartOperation: shouldStartOperation
                )),
              case .some(.success) = retryingScratchPOSIXCall(
                shouldStartOperation: shouldStartOperation,
                operation: {
                    adapter.lock(
                        fileDescriptor: descriptor,
                        operation: LOCK_EX | LOCK_NB
                    )
                }
              ) else {
            adapter.closeFile(descriptor)
            return nil
        }
        return POSIXOpenAIMultipartScratchCandidate(
            directoryDescriptor: directoryDescriptor,
            fileDescriptor: descriptor,
            fileName: fileName,
            kind: kind,
            identity: fileIdentity(status),
            effectiveUserID: effectiveUserID,
            adapter: adapter
        )
    }

    func close() {
        guard let stream else {
            return
        }
        self.stream = nil
        adapter.closeDirectoryStream(stream)
    }

    deinit {
        close()
    }
}

nonisolated final class POSIXOpenAIMultipartScratchCandidate:
    OpenAIMultipartScratchCandidate {
    private let directoryDescriptor: Int32
    private var fileDescriptor: Int32?
    private let fileName: String
    private let kind: OpenAIMultipartScratchKind
    private let identity: OpenAITranscriptionFileIdentity
    private let effectiveUserID: uid_t
    private let adapter: any OpenAIMultipartScratchPOSIXAdapter

    init(
        directoryDescriptor: Int32,
        fileDescriptor: Int32,
        fileName: String,
        kind: OpenAIMultipartScratchKind,
        identity: OpenAITranscriptionFileIdentity,
        effectiveUserID: uid_t,
        adapter: any OpenAIMultipartScratchPOSIXAdapter
    ) {
        self.directoryDescriptor = directoryDescriptor
        self.fileDescriptor = fileDescriptor
        self.fileName = fileName
        self.kind = kind
        self.identity = identity
        self.effectiveUserID = effectiveUserID
        self.adapter = adapter
    }

    func makeDeletionSnapshot(
        referenceTime: OpenAIMultipartScratchTimestamp,
        minimumAgeInSeconds: Int64,
        shouldStartOperation: () -> Bool
    ) -> OpenAIMultipartScratchDeletionSnapshot? {
        guard let fileDescriptor else {
            return nil
        }
        let descriptorResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.fileStatus(for: fileDescriptor)
        }
        guard case .some(.success(let descriptorStatus)) = descriptorResult,
              isEligibleScratchStatus(
                descriptorStatus,
                effectiveUserID: effectiveUserID
              ),
              fileIdentity(descriptorStatus) == identity,
              (kind != .markedV1
                || markerIsExact(
                    on: fileDescriptor,
                    adapter: adapter,
                    shouldStartOperation: shouldStartOperation
                )) else {
            return nil
        }

        let pathResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.pathStatus(
                relativeTo: directoryDescriptor,
                named: fileName,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }
        guard case .some(.success(let pathStatus)) = pathResult,
              isEligibleScratchStatus(
                pathStatus,
                effectiveUserID: effectiveUserID
              ),
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
        let descriptorResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.fileStatus(for: fileDescriptor)
        }
        guard case .some(.success(let descriptorStatus)) = descriptorResult,
              isEligibleScratchStatus(
                descriptorStatus,
                effectiveUserID: effectiveUserID
              ),
              fileIdentity(descriptorStatus) == snapshot.identity,
              newestTimestamp(for: descriptorStatus).isAtLeast(
                  snapshot.minimumAgeInSeconds,
                  before: snapshot.referenceTime
              ),
              (kind != .markedV1
                || markerIsExact(
                    on: fileDescriptor,
                    adapter: adapter,
                    shouldStartOperation: shouldStartOperation
                )),
              case .some(.success) = retryingScratchPOSIXCall(
                shouldStartOperation: shouldStartOperation,
                operation: {
                    adapter.lock(
                        fileDescriptor: fileDescriptor,
                        operation: LOCK_EX | LOCK_NB
                    )
                }
              ) else {
            return false
        }

        let pathResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.pathStatus(
                relativeTo: directoryDescriptor,
                named: fileName,
                flags: AT_SYMLINK_NOFOLLOW
            )
        }
        guard case .some(.success(let pathStatus)) = pathResult,
              isEligibleScratchStatus(
                pathStatus,
                effectiveUserID: effectiveUserID
              ),
              fileIdentity(pathStatus) == snapshot.identity,
              newestTimestamp(for: pathStatus).isAtLeast(
                  snapshot.minimumAgeInSeconds,
                  before: snapshot.referenceTime
              ) else {
            return false
        }

        let unlinkResult = retryingScratchPOSIXCall(
            shouldStartOperation: shouldStartOperation
        ) {
            adapter.unlink(
                relativeTo: directoryDescriptor,
                named: fileName,
                flags: 0
            )
        }
        guard case .some(.success) = unlinkResult else {
            return false
        }
        return true
    }

    func close() {
        guard let fileDescriptor else {
            return
        }
        self.fileDescriptor = nil
        adapter.closeFile(fileDescriptor)
    }

    deinit {
        close()
    }
}

nonisolated private enum POSIXOpenAIMultipartScratchError: Error {
    case directoryReadFailed
}

nonisolated private func retryingScratchPOSIXCall<Value>(
    shouldStartOperation: () -> Bool,
    operation: () -> OpenAIMultipartScratchPOSIXCallResult<Value>
) -> OpenAIMultipartScratchPOSIXCallResult<Value>? {
    while shouldStartOperation() {
        let result = operation()
        if case .failure(EINTR) = result {
            continue
        }
        return result
    }
    return nil
}

nonisolated private func markerIsInstalled(
    on fileDescriptor: Int32,
    adapter: any OpenAIMultipartScratchPOSIXAdapter,
    shouldStartOperation: () -> Bool
) -> Bool {
    let result = retryingScratchPOSIXCall(
        shouldStartOperation: shouldStartOperation
    ) {
        adapter.setExtendedAttribute(
            named: OpenAIMultipartScratchNamespace.markerName,
            value: OpenAIMultipartScratchNamespace.markerValue,
            on: fileDescriptor,
            flags: XATTR_CREATE
        )
    }
    guard case .some(.success) = result else {
        return false
    }
    return true
}

nonisolated private func markerIsExact(
    on fileDescriptor: Int32,
    adapter: any OpenAIMultipartScratchPOSIXAdapter,
    shouldStartOperation: () -> Bool
) -> Bool {
    let result = retryingScratchPOSIXCall(
        shouldStartOperation: shouldStartOperation
    ) {
        adapter.extendedAttribute(
            named: OpenAIMultipartScratchNamespace.markerName,
            on: fileDescriptor,
            maximumByteCount: OpenAIMultipartScratchNamespace.markerValue.count + 1
        )
    }
    guard case .some(.success(let bytes)) = result else {
        return false
    }
    return bytes == OpenAIMultipartScratchNamespace.markerValue
}

nonisolated private func isEligibleScratchStatus(
    _ status: stat,
    effectiveUserID: uid_t
) -> Bool {
    status.st_mode & S_IFMT == S_IFREG
        && status.st_uid == effectiveUserID
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
