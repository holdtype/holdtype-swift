import Darwin
import Foundation
@_spi(HoldTypeIOSCore) import HoldTypePersistence

protocol IOSFailedHistoryRetryAudioReading: Sendable {
    var format: IOSPendingRecordingAudioFormat { get }
    var byteCount: Int64 { get }

    func read(
        atOffset offset: Int64,
        maximumByteCount: Int
    ) async throws -> Data
}

extension IOSPendingTranscriptionAudio: IOSFailedHistoryRetryAudioReading {}

enum IOSFailedHistoryRetryAudioMaterializationError: Error, Equatable,
    Sendable {
    case invalidAudio
    case scratchUnavailable
    case writeFailed
    case cleanupFailed
}

nonisolated enum IOSFailedHistoryRetryScratchNamespace {
    static let directoryName = "holdtype-ios-failed-history-retry-v1"
    static let audioPrefix = "htr-audio-v1-"
    static let namespaceMarkerName =
        "com.holdtype.ios.failed-history-retry-namespace"
    static let audioMarkerName =
        "com.holdtype.ios.failed-history-retry-audio"
    static let namespaceMarkerValue = Array("htrn-v1".utf8)
    static let audioMarkerValue = Array("htra-v1".utf8)

    static var defaultParentDirectoryURL: URL {
        FileManager.default.temporaryDirectory
    }

    static func namespaceURL(in parentDirectoryURL: URL) -> URL {
        parentDirectoryURL.appendingPathComponent(
            directoryName,
            isDirectory: true
        )
    }

    static func audioFileName(
        identifier: UUID,
        format: IOSPendingRecordingAudioFormat
    ) -> String {
        let fileExtension = switch format {
        case .m4a: "m4a"
        case .wav: "wav"
        }
        return audioPrefix
            + identifier.uuidString.lowercased()
            + "."
            + fileExtension
    }

    static func audioFormat(
        inExactFileName fileName: String
    ) -> IOSPendingRecordingAudioFormat? {
        let suffix: String
        let format: IOSPendingRecordingAudioFormat
        if fileName.hasSuffix(".m4a") {
            suffix = ".m4a"
            format = .m4a
        } else if fileName.hasSuffix(".wav") {
            suffix = ".wav"
            format = .wav
        } else {
            return nil
        }
        guard fileName.hasPrefix(audioPrefix) else { return nil }
        let start = fileName.index(
            fileName.startIndex,
            offsetBy: audioPrefix.count
        )
        let end = fileName.index(
            fileName.endIndex,
            offsetBy: -suffix.count
        )
        let rawIdentifier = String(fileName[start..<end])
        guard let identifier = UUID(uuidString: rawIdentifier),
              rawIdentifier == identifier.uuidString.lowercased(),
              fileName == audioFileName(
                  identifier: identifier,
                  format: format
              ) else {
            return nil
        }
        return format
    }
}

nonisolated enum IOSFailedHistoryRetryScratchPrivateConfiguration {
    // Darwin protection class 1 is FileProtectionType.complete.
    static let completeProtectionClass: Int32 = 1
    static let backupExclusionAttributeName =
        "com.apple.metadata:com_apple_backup_excludeItem"
    static let backupExclusionAttributeValue = Data([
        0x62, 0x70, 0x6C, 0x69, 0x73, 0x74, 0x30, 0x30,
        0x5F, 0x10, 0x11, 0x63, 0x6F, 0x6D, 0x2E, 0x61,
        0x70, 0x70, 0x6C, 0x65, 0x2E, 0x62, 0x61, 0x63,
        0x6B, 0x75, 0x70, 0x64, 0x08, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x01, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x00, 0x00, 0x00, 0x00, 0x1C,
    ])

    static func apply(to fileDescriptor: Int32) -> Bool {
        var protectionResult: Int32
        repeat {
            protectionResult = Darwin.fcntl(
                fileDescriptor,
                F_SETPROTECTIONCLASS,
                completeProtectionClass
            )
        } while protectionResult != 0 && errno == EINTR
        guard protectionResult == 0 else { return false }

        let backupResult = backupExclusionAttributeName.withCString { name in
            backupExclusionAttributeValue.withUnsafeBytes { bytes in
                retryingPOSIXResult {
                    Darwin.fsetxattr(
                        fileDescriptor,
                        name,
                        bytes.baseAddress,
                        bytes.count,
                        0,
                        0
                    )
                }
            }
        }
        return backupResult == 0
    }

    static func isExact(on fileDescriptor: Int32) -> Bool {
        var protectionClass: Int32
        repeat {
            protectionClass = Darwin.fcntl(
                fileDescriptor,
                F_GETPROTECTIONCLASS
            )
        } while protectionClass < 0 && errno == EINTR
        guard protectionClass == completeProtectionClass else { return false }

        let attributeSize = backupExclusionAttributeName.withCString { name in
            retryingPOSIXSizeResult {
                Darwin.fgetxattr(fileDescriptor, name, nil, 0, 0, 0)
            }
        }
        guard attributeSize == backupExclusionAttributeValue.count else {
            return false
        }
        var actualValue = Data(count: attributeSize)
        let readSize = backupExclusionAttributeName.withCString { name in
            actualValue.withUnsafeMutableBytes { bytes in
                retryingPOSIXSizeResult {
                    Darwin.fgetxattr(
                        fileDescriptor,
                        name,
                        bytes.baseAddress,
                        bytes.count,
                        0,
                        0
                    )
                }
            }
        }
        return readSize == attributeSize
            && actualValue == backupExclusionAttributeValue
    }
}

nonisolated protocol IOSFailedHistoryRetryScratchSecurityCalling: Sendable {
    func applyPrivateConfiguration(to fileDescriptor: Int32) -> Bool
    func hasExactPrivateConfiguration(on fileDescriptor: Int32) -> Bool
    func installMarker(
        named name: String,
        value: [UInt8],
        on fileDescriptor: Int32
    ) -> Bool
    func hasExactMarker(
        named name: String,
        value: [UInt8],
        on fileDescriptor: Int32
    ) -> Bool
    func lockExclusively(fileDescriptor: Int32) -> Bool
    func write(
        fileDescriptor: Int32,
        buffer: UnsafeRawPointer,
        byteCount: Int
    ) -> Int
    func synchronize(fileDescriptor: Int32) -> Bool
}

nonisolated struct DarwinIOSFailedHistoryRetryScratchSecurityCalls:
    IOSFailedHistoryRetryScratchSecurityCalling {
    func applyPrivateConfiguration(to fileDescriptor: Int32) -> Bool {
        IOSFailedHistoryRetryScratchPrivateConfiguration.apply(
            to: fileDescriptor
        )
    }

    func hasExactPrivateConfiguration(on fileDescriptor: Int32) -> Bool {
        IOSFailedHistoryRetryScratchPrivateConfiguration.isExact(
            on: fileDescriptor
        )
    }

    func installMarker(
        named name: String,
        value: [UInt8],
        on fileDescriptor: Int32
    ) -> Bool {
        let result = name.withCString { name in
            value.withUnsafeBytes { bytes in
                retryingPOSIXResult {
                    Darwin.fsetxattr(
                        fileDescriptor,
                        name,
                        bytes.baseAddress,
                        bytes.count,
                        0,
                        XATTR_CREATE
                    )
                }
            }
        }
        return result == 0
    }

    func hasExactMarker(
        named name: String,
        value: [UInt8],
        on fileDescriptor: Int32
    ) -> Bool {
        var bytes = [UInt8](repeating: 0, count: value.count + 1)
        let readCount = name.withCString { name in
            bytes.withUnsafeMutableBytes { bytes in
                retryingPOSIXSizeResult {
                    Darwin.fgetxattr(
                        fileDescriptor,
                        name,
                        bytes.baseAddress,
                        bytes.count,
                        0,
                        0
                    )
                }
            }
        }
        return readCount == value.count
            && Array(bytes.prefix(readCount)) == value
    }

    func lockExclusively(fileDescriptor: Int32) -> Bool {
        retryingPOSIXResult {
            flock(fileDescriptor, LOCK_EX | LOCK_NB)
        } == 0
    }

    func write(
        fileDescriptor: Int32,
        buffer: UnsafeRawPointer,
        byteCount: Int
    ) -> Int {
        Darwin.write(fileDescriptor, buffer, byteCount)
    }

    func synchronize(fileDescriptor: Int32) -> Bool {
        retryingPOSIXResult { Darwin.fsync(fileDescriptor) } == 0
    }
}

/// Produces the one pathname required by the URL-based OpenAI upload service.
/// The durable source stays descriptor-bound. The transient copy lives in a
/// dedicated marked namespace, is protected before its first byte, remains
/// locked while in use, and is removed through its retained directory handle.
struct IOSFailedHistoryRetryAudioMaterializer: Sendable {
    static let maximumAudioByteCountExclusive: Int64 = 25_000_000
    private static let transferByteCount =
        IOSPendingTranscriptionAudio.maximumReadByteCount

    private let scratchParentDirectoryURL: URL
    private let securityCalls:
        any IOSFailedHistoryRetryScratchSecurityCalling

    init(
        scratchDirectoryURL: URL = IOSFailedHistoryRetryScratchNamespace
            .defaultParentDirectoryURL,
        securityCalls:
            any IOSFailedHistoryRetryScratchSecurityCalling =
                DarwinIOSFailedHistoryRetryScratchSecurityCalls()
    ) {
        scratchParentDirectoryURL = scratchDirectoryURL
        self.securityCalls = securityCalls
    }

    func withMaterializedAudio<Value: Sendable>(
        _ audio: any IOSFailedHistoryRetryAudioReading,
        operation: @escaping @Sendable (URL) async throws -> Value
    ) async throws -> Value {
        let materialized = try await materialize(audio)
        do {
            try materialized.validatePublishedPath()
            let value = try await operation(materialized.fileURL)
            try materialized.remove()
            return value
        } catch {
            let operationError = error
            do {
                try materialized.remove()
            } catch {
                throw IOSFailedHistoryRetryAudioMaterializationError
                    .cleanupFailed
            }
            throw operationError
        }
    }

    private func materialize(
        _ audio: any IOSFailedHistoryRetryAudioReading
    ) async throws -> IOSFailedHistoryRetryMaterializedAudio {
        try Task.checkCancellation()
        guard audio.byteCount > 0,
              audio.byteCount < Self.maximumAudioByteCountExclusive else {
            throw IOSFailedHistoryRetryAudioMaterializationError.invalidAudio
        }
        let namespace = try openRetryScratchNamespace(
            parentDirectoryURL: scratchParentDirectoryURL,
            createIfMissing: true,
            securityCalls: securityCalls
        )
        guard let namespace else {
            throw IOSFailedHistoryRetryAudioMaterializationError
                .scratchUnavailable
        }

        let fileName = IOSFailedHistoryRetryScratchNamespace.audioFileName(
            identifier: UUID(),
            format: audio.format
        )
        let fileURL = namespace.namespaceURL.appendingPathComponent(
            fileName,
            isDirectory: false
        )
        var fileDescriptor: Int32 = -1
        var createdIdentity: IOSFailedHistoryRetryScratchNodeIdentity?

        do {
            fileDescriptor = try openRetryScratchAudio(
                named: fileName,
                namespaceDescriptor: namespace.namespaceDescriptor
            )
            var initialStatus = stat()
            guard Darwin.fstat(fileDescriptor, &initialStatus) == 0,
                  isExactRetryScratchFileStatus(
                      initialStatus,
                      effectiveUserID: namespace.effectiveUserID,
                      allowsEmpty: true
                  ) else {
                throw IOSFailedHistoryRetryAudioMaterializationError
                    .scratchUnavailable
            }
            createdIdentity = retryScratchNodeIdentity(initialStatus)

            guard securityCalls.applyPrivateConfiguration(
                      to: fileDescriptor
                  ),
                  securityCalls.hasExactPrivateConfiguration(
                      on: fileDescriptor
                  ),
                  securityCalls.installMarker(
                      named: IOSFailedHistoryRetryScratchNamespace
                          .audioMarkerName,
                      value: IOSFailedHistoryRetryScratchNamespace
                          .audioMarkerValue,
                      on: fileDescriptor
                  ),
                  securityCalls.hasExactMarker(
                      named: IOSFailedHistoryRetryScratchNamespace
                          .audioMarkerName,
                      value: IOSFailedHistoryRetryScratchNamespace
                          .audioMarkerValue,
                      on: fileDescriptor
                  ),
                  securityCalls.lockExclusively(
                      fileDescriptor: fileDescriptor
                  ),
                  retryScratchPathMatchesDescriptor(
                      directoryDescriptor: namespace.namespaceDescriptor,
                      fileName: fileName,
                      fileDescriptor: fileDescriptor,
                      effectiveUserID: namespace.effectiveUserID,
                      allowsEmpty: true
                  ),
                  namespace.hasExactPublishedIdentity() else {
                throw IOSFailedHistoryRetryAudioMaterializationError
                    .scratchUnavailable
            }

            var offset: Int64 = 0
            while offset < audio.byteCount {
                try Task.checkCancellation()
                let requested = min(
                    Self.transferByteCount,
                    Int(audio.byteCount - offset)
                )
                let chunk = try await audio.read(
                    atOffset: offset,
                    maximumByteCount: requested
                )
                guard !chunk.isEmpty,
                      chunk.count <= requested,
                      Int64(chunk.count) <= audio.byteCount - offset else {
                    throw IOSFailedHistoryRetryAudioMaterializationError
                        .invalidAudio
                }
                try writeAll(chunk, to: fileDescriptor)
                offset += Int64(chunk.count)
            }

            var finalStatus = stat()
            guard offset == audio.byteCount,
                  securityCalls.synchronize(
                      fileDescriptor: fileDescriptor
                  ),
                  Darwin.fstat(fileDescriptor, &finalStatus) == 0,
                  isExactRetryScratchFileStatus(
                      finalStatus,
                      effectiveUserID: namespace.effectiveUserID,
                      allowsEmpty: false
                  ),
                  finalStatus.st_size == off_t(audio.byteCount),
                  securityCalls.hasExactPrivateConfiguration(
                      on: fileDescriptor
                  ),
                  securityCalls.hasExactMarker(
                      named: IOSFailedHistoryRetryScratchNamespace
                          .audioMarkerName,
                      value: IOSFailedHistoryRetryScratchNamespace
                          .audioMarkerValue,
                      on: fileDescriptor
                  ),
                  retryScratchPathMatchesDescriptor(
                      directoryDescriptor: namespace.namespaceDescriptor,
                      fileName: fileName,
                      fileDescriptor: fileDescriptor,
                      effectiveUserID: namespace.effectiveUserID,
                      allowsEmpty: false
                  ),
                  namespace.hasExactPublishedIdentity() else {
                throw IOSFailedHistoryRetryAudioMaterializationError.writeFailed
            }
            try Task.checkCancellation()
            return IOSFailedHistoryRetryMaterializedAudio(
                namespace: namespace,
                fileDescriptor: fileDescriptor,
                fileName: fileName,
                fileURL: fileURL,
                identity: retryScratchFileIdentity(finalStatus),
                securityCalls: securityCalls
            )
        } catch {
            let originalError = error
            if fileDescriptor >= 0 {
                let didRemove = createdIdentity.map {
                    removeCreatedRetryScratchAudio(
                        namespace: namespace,
                        fileDescriptor: fileDescriptor,
                        fileName: fileName,
                        createdIdentity: $0
                    )
                } ?? false
                _ = Darwin.close(fileDescriptor)
                namespace.close()
                guard didRemove else {
                    throw IOSFailedHistoryRetryAudioMaterializationError
                        .cleanupFailed
                }
            } else {
                namespace.close()
            }
            throw originalError
        }
    }

    private func writeAll(
        _ data: Data,
        to fileDescriptor: Int32
    ) throws {
        try data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                throw IOSFailedHistoryRetryAudioMaterializationError.writeFailed
            }
            var writtenByteCount = 0
            while writtenByteCount < bytes.count {
                let result = securityCalls.write(
                    fileDescriptor: fileDescriptor,
                    buffer: baseAddress.advanced(by: writtenByteCount),
                    byteCount: bytes.count - writtenByteCount
                )
                if result < 0, errno == EINTR { continue }
                guard result > 0 else {
                    throw IOSFailedHistoryRetryAudioMaterializationError
                        .writeFailed
                }
                writtenByteCount += result
            }
        }
    }
}

private final class IOSFailedHistoryRetryMaterializedAudio:
    @unchecked Sendable {
    private let lock = NSLock()
    private let namespace: IOSFailedHistoryRetryOpenNamespace
    private var fileDescriptor: Int32?
    private let fileName: String
    let fileURL: URL
    private let identity: IOSFailedHistoryRetryScratchFileIdentity
    private let securityCalls:
        any IOSFailedHistoryRetryScratchSecurityCalling

    init(
        namespace: IOSFailedHistoryRetryOpenNamespace,
        fileDescriptor: Int32,
        fileName: String,
        fileURL: URL,
        identity: IOSFailedHistoryRetryScratchFileIdentity,
        securityCalls: any IOSFailedHistoryRetryScratchSecurityCalling
    ) {
        self.namespace = namespace
        self.fileDescriptor = fileDescriptor
        self.fileName = fileName
        self.fileURL = fileURL
        self.identity = identity
        self.securityCalls = securityCalls
    }

    func validatePublishedPath() throws {
        lock.lock()
        defer { lock.unlock() }
        guard let fileDescriptor,
              hasExactIdentity(fileDescriptor: fileDescriptor) else {
            throw IOSFailedHistoryRetryAudioMaterializationError
                .scratchUnavailable
        }
    }

    func remove() throws {
        lock.lock()
        defer { lock.unlock() }
        guard let fileDescriptor else { return }
        self.fileDescriptor = nil
        defer {
            _ = Darwin.close(fileDescriptor)
            namespace.close()
        }
        guard hasExactIdentity(fileDescriptor: fileDescriptor),
              retryingPOSIXResult({
                  fileName.withCString {
                      Darwin.unlinkat(
                          namespace.namespaceDescriptor,
                          $0,
                          0
                      )
                  }
              }) == 0 else {
            throw IOSFailedHistoryRetryAudioMaterializationError.cleanupFailed
        }
    }

    private func hasExactIdentity(fileDescriptor: Int32) -> Bool {
        var descriptorStatus = stat()
        var pathStatus = stat()
        guard namespace.hasExactPublishedIdentity(),
              Darwin.fstat(fileDescriptor, &descriptorStatus) == 0,
              isExactRetryScratchFileStatus(
                  descriptorStatus,
                  effectiveUserID: namespace.effectiveUserID,
                  allowsEmpty: false
              ),
              retryScratchFileIdentity(descriptorStatus) == identity,
              securityCalls.hasExactPrivateConfiguration(
                  on: fileDescriptor
              ),
              securityCalls.hasExactMarker(
                  named: IOSFailedHistoryRetryScratchNamespace.audioMarkerName,
                  value: IOSFailedHistoryRetryScratchNamespace.audioMarkerValue,
                  on: fileDescriptor
              ),
              fileName.withCString({
                  Darwin.fstatat(
                      namespace.namespaceDescriptor,
                      $0,
                      &pathStatus,
                      AT_SYMLINK_NOFOLLOW
                  )
              }) == 0,
              isExactRetryScratchFileStatus(
                  pathStatus,
                  effectiveUserID: namespace.effectiveUserID,
                  allowsEmpty: false
              ),
              retryScratchFileIdentity(pathStatus) == identity else {
            return false
        }
        return true
    }

    deinit {
        if let fileDescriptor {
            _ = Darwin.close(fileDescriptor)
        }
        namespace.close()
    }
}

nonisolated struct IOSFailedHistoryRetryScratchTimestamp:
    Comparable,
    Equatable,
    Sendable {
    let seconds: Int64
    let nanoseconds: Int64

    static func < (
        lhs: IOSFailedHistoryRetryScratchTimestamp,
        rhs: IOSFailedHistoryRetryScratchTimestamp
    ) -> Bool {
        lhs.seconds < rhs.seconds
            || (lhs.seconds == rhs.seconds
                && lhs.nanoseconds < rhs.nanoseconds)
    }

    func isAtLeast(
        _ ageInSeconds: Int64,
        before reference: IOSFailedHistoryRetryScratchTimestamp
    ) -> Bool {
        guard self <= reference else { return false }
        let cutoff = reference.seconds.subtractingReportingOverflow(
            ageInSeconds
        )
        guard !cutoff.overflow else { return false }
        return self <= IOSFailedHistoryRetryScratchTimestamp(
            seconds: cutoff.partialValue,
            nanoseconds: reference.nanoseconds
        )
    }
}

nonisolated struct IOSFailedHistoryRetryScratchScavengeSummary:
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
        "IOSFailedHistoryRetryScratchScavengeSummary(<redacted>)"
    }

    var debugDescription: String { description }
    var customMirror: Mirror { Mirror(self, children: [:]) }
}

/// One bounded, provider-free startup pass over the dedicated retry namespace.
/// It never follows links or scans outside that namespace and removes only an
/// exact old marked file whose descriptor and directory entry still agree.
nonisolated struct IOSFailedHistoryRetryScratchScavenger: Sendable {
    static let minimumAgeInSeconds: Int64 = 60 * 60
    static let maximumInspectedEntryCount = 128
    static let maximumRemovedFileCount = 16
    static let maximumAccountedByteCount: Int64 = 200_000_000
    static let maximumElapsedNanoseconds: UInt64 = 500_000_000

    private let parentDirectoryURL: URL
    private let securityCalls:
        any IOSFailedHistoryRetryScratchSecurityCalling
    private let wallClock:
        @Sendable () -> IOSFailedHistoryRetryScratchTimestamp?
    private let monotonicClock: @Sendable () -> UInt64?
    private let beforeFinalValidation: @Sendable (String) -> Void

    init(
        parentDirectoryURL: URL = IOSFailedHistoryRetryScratchNamespace
            .defaultParentDirectoryURL,
        securityCalls:
            any IOSFailedHistoryRetryScratchSecurityCalling =
                DarwinIOSFailedHistoryRetryScratchSecurityCalls(),
        wallClock: @escaping @Sendable () ->
            IOSFailedHistoryRetryScratchTimestamp? = {
                systemRetryScratchTimestamp(clock: CLOCK_REALTIME)
            },
        monotonicClock: @escaping @Sendable () -> UInt64? = {
            systemRetryScratchNanoseconds(clock: CLOCK_MONOTONIC)
        },
        beforeFinalValidation: @escaping @Sendable (String) -> Void = { _ in }
    ) {
        self.parentDirectoryURL = parentDirectoryURL
        self.securityCalls = securityCalls
        self.wallClock = wallClock
        self.monotonicClock = monotonicClock
        self.beforeFinalValidation = beforeFinalValidation
    }

    func run() -> IOSFailedHistoryRetryScratchScavengeSummary {
        guard let referenceTime = wallClock(),
              let startTime = monotonicClock() else {
            return summary(stopReason: .clockFailure)
        }
        guard withinTimeBudget(startTime: startTime) else {
            return summary(stopReason: .timeLimit)
        }

        let namespace: IOSFailedHistoryRetryOpenNamespace?
        do {
            namespace = try openRetryScratchNamespace(
                parentDirectoryURL: parentDirectoryURL,
                createIfMissing: false,
                securityCalls: securityCalls
            )
        } catch {
            return summary(stopReason: .namespaceUnavailable)
        }
        guard let namespace else {
            return summary(stopReason: .complete)
        }
        defer { namespace.close() }
        guard withinTimeBudget(startTime: startTime) else {
            return summary(stopReason: .timeLimit)
        }

        let enumerationDescriptor = Darwin.dup(
            namespace.namespaceDescriptor
        )
        guard enumerationDescriptor >= 0,
              let stream = Darwin.fdopendir(enumerationDescriptor) else {
            if enumerationDescriptor >= 0 {
                _ = Darwin.close(enumerationDescriptor)
            }
            return summary(stopReason: .directoryFailure)
        }
        defer { Darwin.closedir(stream) }

        var inspected = 0
        var removed = 0
        var bytes: Int64 = 0
        while true {
            guard withinTimeBudget(startTime: startTime) else {
                return summary(
                    inspected: inspected,
                    removed: removed,
                    bytes: bytes,
                    stopReason: .timeLimit
                )
            }
            guard inspected < Self.maximumInspectedEntryCount else {
                return summary(
                    inspected: inspected,
                    removed: removed,
                    bytes: bytes,
                    stopReason: .entryLimit
                )
            }

            errno = 0
            guard let entry = Darwin.readdir(stream) else {
                return summary(
                    inspected: inspected,
                    removed: removed,
                    bytes: bytes,
                    stopReason: errno == 0 ? .complete : .directoryFailure
                )
            }
            guard let fileName = retryScratchEntryName(entry),
                  fileName != ".",
                  fileName != ".." else {
                continue
            }
            inspected += 1
            guard IOSFailedHistoryRetryScratchNamespace.audioFormat(
                      inExactFileName: fileName
                  ) != nil else {
                continue
            }

            guard let candidate = openRetryScratchScavengeCandidate(
                namespace: namespace,
                fileName: fileName,
                securityCalls: securityCalls,
                referenceTime: referenceTime
            ) else {
                continue
            }
            let addition = bytes.addingReportingOverflow(
                candidate.identity.byteCount
            )
            guard !addition.overflow,
                  addition.partialValue
                    <= Self.maximumAccountedByteCount else {
                _ = Darwin.close(candidate.fileDescriptor)
                return summary(
                    inspected: inspected,
                    removed: removed,
                    bytes: bytes,
                    stopReason: .byteLimit
                )
            }
            bytes = addition.partialValue
            guard withinTimeBudget(startTime: startTime) else {
                _ = Darwin.close(candidate.fileDescriptor)
                return summary(
                    inspected: inspected,
                    removed: removed,
                    bytes: bytes,
                    stopReason: .timeLimit
                )
            }

            beforeFinalValidation(fileName)
            if withinTimeBudget(startTime: startTime),
               removeRetryScratchCandidateIfUnchanged(
                   candidate,
                   namespace: namespace,
                   securityCalls: securityCalls,
                   referenceTime: referenceTime,
                   shouldUnlink: {
                       withinTimeBudget(startTime: startTime)
                   }
               ) {
                removed += 1
            }
            _ = Darwin.close(candidate.fileDescriptor)
            if removed >= Self.maximumRemovedFileCount {
                return summary(
                    inspected: inspected,
                    removed: removed,
                    bytes: bytes,
                    stopReason: .removalLimit
                )
            }
        }
    }

    private func withinTimeBudget(startTime: UInt64) -> Bool {
        guard let current = monotonicClock(), current >= startTime else {
            return false
        }
        return current - startTime < Self.maximumElapsedNanoseconds
    }

    private func summary(
        inspected: Int = 0,
        removed: Int = 0,
        bytes: Int64 = 0,
        stopReason: IOSFailedHistoryRetryScratchScavengeSummary.StopReason
    ) -> IOSFailedHistoryRetryScratchScavengeSummary {
        IOSFailedHistoryRetryScratchScavengeSummary(
            inspectedEntryCount: inspected,
            removedFileCount: removed,
            accountedByteCount: bytes,
            stopReason: stopReason
        )
    }
}

private final class IOSFailedHistoryRetryOpenNamespace:
    @unchecked Sendable {
    private let lock = NSLock()
    let parentDirectoryURL: URL
    let namespaceURL: URL
    private(set) var parentDescriptor: Int32
    private(set) var namespaceDescriptor: Int32
    let effectiveUserID: uid_t
    let parentIdentity: IOSFailedHistoryRetryScratchNodeIdentity
    let namespaceIdentity: IOSFailedHistoryRetryScratchNodeIdentity
    private let securityCalls:
        any IOSFailedHistoryRetryScratchSecurityCalling

    init(
        parentDirectoryURL: URL,
        namespaceURL: URL,
        parentDescriptor: Int32,
        namespaceDescriptor: Int32,
        effectiveUserID: uid_t,
        parentIdentity: IOSFailedHistoryRetryScratchNodeIdentity,
        namespaceIdentity: IOSFailedHistoryRetryScratchNodeIdentity,
        securityCalls: any IOSFailedHistoryRetryScratchSecurityCalling
    ) {
        self.parentDirectoryURL = parentDirectoryURL
        self.namespaceURL = namespaceURL
        self.parentDescriptor = parentDescriptor
        self.namespaceDescriptor = namespaceDescriptor
        self.effectiveUserID = effectiveUserID
        self.parentIdentity = parentIdentity
        self.namespaceIdentity = namespaceIdentity
        self.securityCalls = securityCalls
    }

    func hasExactPublishedIdentity() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard parentDescriptor >= 0, namespaceDescriptor >= 0 else {
            return false
        }
        var parentStatus = stat()
        var parentPathStatus = stat()
        var namespaceStatus = stat()
        var namespacePathStatus = stat()
        guard Darwin.fstat(parentDescriptor, &parentStatus) == 0,
              Darwin.lstat(parentDirectoryURL.path, &parentPathStatus) == 0,
              isTrustedRetryScratchParentStatus(
                  parentStatus,
                  effectiveUserID: effectiveUserID
              ),
              isTrustedRetryScratchParentStatus(
                  parentPathStatus,
                  effectiveUserID: effectiveUserID
              ),
              retryScratchNodeIdentity(parentStatus) == parentIdentity,
              retryScratchNodeIdentity(parentPathStatus) == parentIdentity,
              Darwin.fstat(namespaceDescriptor, &namespaceStatus) == 0,
              isExactRetryScratchDirectoryStatus(
                  namespaceStatus,
                  effectiveUserID: effectiveUserID
              ),
              retryScratchNodeIdentity(namespaceStatus) == namespaceIdentity,
              IOSFailedHistoryRetryScratchNamespace.directoryName.withCString({
                  Darwin.fstatat(
                      parentDescriptor,
                      $0,
                      &namespacePathStatus,
                      AT_SYMLINK_NOFOLLOW
                  )
              }) == 0,
              isExactRetryScratchDirectoryStatus(
                  namespacePathStatus,
                  effectiveUserID: effectiveUserID
              ),
              retryScratchNodeIdentity(namespacePathStatus)
                == namespaceIdentity,
              securityCalls.hasExactPrivateConfiguration(
                  on: namespaceDescriptor
              ),
              securityCalls.hasExactMarker(
                  named: IOSFailedHistoryRetryScratchNamespace
                      .namespaceMarkerName,
                  value: IOSFailedHistoryRetryScratchNamespace
                      .namespaceMarkerValue,
                  on: namespaceDescriptor
              ) else {
            return false
        }
        return true
    }

    func close() {
        lock.lock()
        defer { lock.unlock() }
        if namespaceDescriptor >= 0 {
            _ = Darwin.close(namespaceDescriptor)
            namespaceDescriptor = -1
        }
        if parentDescriptor >= 0 {
            _ = Darwin.close(parentDescriptor)
            parentDescriptor = -1
        }
    }

    deinit { close() }
}

private struct IOSFailedHistoryRetryScratchNodeIdentity:
    Equatable,
    Sendable {
    let device: dev_t
    let inode: ino_t
    let generation: UInt32
}

private struct IOSFailedHistoryRetryScratchFileIdentity:
    Equatable,
    Sendable {
    let node: IOSFailedHistoryRetryScratchNodeIdentity
    let byteCount: Int64
    let modificationSeconds: Int64
    let modificationNanoseconds: Int64
    let changeSeconds: Int64
    let changeNanoseconds: Int64
}

private struct IOSFailedHistoryRetryScratchScavengeCandidate: Sendable {
    let fileDescriptor: Int32
    let fileName: String
    let identity: IOSFailedHistoryRetryScratchFileIdentity
}

private func openRetryScratchNamespace(
    parentDirectoryURL: URL,
    createIfMissing: Bool,
    securityCalls: any IOSFailedHistoryRetryScratchSecurityCalling
) throws -> IOSFailedHistoryRetryOpenNamespace? {
    guard parentDirectoryURL.isFileURL else {
        throw IOSFailedHistoryRetryAudioMaterializationError.scratchUnavailable
    }
    let parentDescriptor = retryingOpen {
        Darwin.open(
            parentDirectoryURL.path,
            O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
        )
    }
    guard parentDescriptor >= 0 else {
        throw IOSFailedHistoryRetryAudioMaterializationError.scratchUnavailable
    }
    var shouldCloseParent = true
    defer {
        if shouldCloseParent { _ = Darwin.close(parentDescriptor) }
    }

    let effectiveUserID = Darwin.geteuid()
    var parentStatus = stat()
    var parentPathStatus = stat()
    guard Darwin.fstat(parentDescriptor, &parentStatus) == 0,
          Darwin.lstat(parentDirectoryURL.path, &parentPathStatus) == 0,
          isTrustedRetryScratchParentStatus(
              parentStatus,
              effectiveUserID: effectiveUserID
          ),
          isTrustedRetryScratchParentStatus(
              parentPathStatus,
              effectiveUserID: effectiveUserID
          ),
          retryScratchNodeIdentity(parentStatus)
            == retryScratchNodeIdentity(parentPathStatus) else {
        throw IOSFailedHistoryRetryAudioMaterializationError.scratchUnavailable
    }

    var createdNamespace = false
    if createIfMissing {
        let mkdirResult = IOSFailedHistoryRetryScratchNamespace.directoryName
            .withCString { directoryName in
                retryingPOSIXResult {
                    Darwin.mkdirat(parentDescriptor, directoryName, 0o700)
                }
            }
        if mkdirResult == 0 {
            createdNamespace = true
        } else if errno != EEXIST {
            throw IOSFailedHistoryRetryAudioMaterializationError
                .scratchUnavailable
        }
    }

    let namespaceDescriptor = retryingOpen {
        IOSFailedHistoryRetryScratchNamespace.directoryName.withCString {
            Darwin.openat(
                parentDescriptor,
                $0,
                O_RDONLY
                    | O_DIRECTORY
                    | O_CLOEXEC
                    | O_NOFOLLOW
                    | O_NONBLOCK
            )
        }
    }
    guard namespaceDescriptor >= 0 else {
        if createdNamespace {
            removeNewRetryScratchNamespaceIfEmpty(
                parentDescriptor: parentDescriptor,
                expectedIdentity: nil
            )
        }
        if !createIfMissing, errno == ENOENT { return nil }
        throw IOSFailedHistoryRetryAudioMaterializationError.scratchUnavailable
    }
    var shouldCloseNamespace = true
    defer {
        if shouldCloseNamespace { _ = Darwin.close(namespaceDescriptor) }
    }

    var namespaceStatus = stat()
    var namespacePathStatus = stat()
    guard Darwin.fstat(namespaceDescriptor, &namespaceStatus) == 0,
          IOSFailedHistoryRetryScratchNamespace.directoryName.withCString({
              Darwin.fstatat(
                  parentDescriptor,
                  $0,
                  &namespacePathStatus,
                  AT_SYMLINK_NOFOLLOW
              )
          }) == 0,
          isExactRetryScratchDirectoryStatus(
              namespaceStatus,
              effectiveUserID: effectiveUserID
          ),
          isExactRetryScratchDirectoryStatus(
              namespacePathStatus,
              effectiveUserID: effectiveUserID
          ),
          retryScratchNodeIdentity(namespaceStatus)
            == retryScratchNodeIdentity(namespacePathStatus) else {
        if createdNamespace {
            removeNewRetryScratchNamespaceIfEmpty(
                parentDescriptor: parentDescriptor,
                expectedIdentity: retryScratchNodeIdentity(namespaceStatus)
            )
        }
        throw IOSFailedHistoryRetryAudioMaterializationError.scratchUnavailable
    }

    let configurationIsExact: Bool
    let markerIsExact: Bool
    if createdNamespace {
        configurationIsExact = securityCalls.applyPrivateConfiguration(
            to: namespaceDescriptor
        ) && securityCalls.hasExactPrivateConfiguration(
            on: namespaceDescriptor
        )
        markerIsExact = securityCalls.installMarker(
            named: IOSFailedHistoryRetryScratchNamespace.namespaceMarkerName,
            value: IOSFailedHistoryRetryScratchNamespace.namespaceMarkerValue,
            on: namespaceDescriptor
        ) && securityCalls.hasExactMarker(
            named: IOSFailedHistoryRetryScratchNamespace.namespaceMarkerName,
            value: IOSFailedHistoryRetryScratchNamespace.namespaceMarkerValue,
            on: namespaceDescriptor
        )
    } else {
        configurationIsExact = securityCalls.hasExactPrivateConfiguration(
            on: namespaceDescriptor
        )
        markerIsExact = securityCalls.hasExactMarker(
            named: IOSFailedHistoryRetryScratchNamespace.namespaceMarkerName,
            value: IOSFailedHistoryRetryScratchNamespace.namespaceMarkerValue,
            on: namespaceDescriptor
        )
    }
    guard configurationIsExact, markerIsExact else {
        if createdNamespace {
            removeNewRetryScratchNamespaceIfEmpty(
                parentDescriptor: parentDescriptor,
                expectedIdentity: retryScratchNodeIdentity(namespaceStatus)
            )
        }
        throw IOSFailedHistoryRetryAudioMaterializationError.scratchUnavailable
    }

    shouldCloseParent = false
    shouldCloseNamespace = false
    let namespace = IOSFailedHistoryRetryOpenNamespace(
        parentDirectoryURL: parentDirectoryURL,
        namespaceURL: IOSFailedHistoryRetryScratchNamespace.namespaceURL(
            in: parentDirectoryURL
        ),
        parentDescriptor: parentDescriptor,
        namespaceDescriptor: namespaceDescriptor,
        effectiveUserID: effectiveUserID,
        parentIdentity: retryScratchNodeIdentity(parentStatus),
        namespaceIdentity: retryScratchNodeIdentity(namespaceStatus),
        securityCalls: securityCalls
    )
    guard namespace.hasExactPublishedIdentity() else {
        throw IOSFailedHistoryRetryAudioMaterializationError.scratchUnavailable
    }
    return namespace
}

private func openRetryScratchAudio(
    named fileName: String,
    namespaceDescriptor: Int32
) throws -> Int32 {
    let descriptor = retryingOpen {
        fileName.withCString {
            Darwin.openat(
                namespaceDescriptor,
                $0,
                O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
                S_IRUSR | S_IWUSR
            )
        }
    }
    guard descriptor >= 0,
          retryingPOSIXResult({
              Darwin.fchmod(descriptor, S_IRUSR | S_IWUSR)
          }) == 0 else {
        if descriptor >= 0 { _ = Darwin.close(descriptor) }
        throw IOSFailedHistoryRetryAudioMaterializationError.scratchUnavailable
    }
    return descriptor
}

private func removeCreatedRetryScratchAudio(
    namespace: IOSFailedHistoryRetryOpenNamespace,
    fileDescriptor: Int32,
    fileName: String,
    createdIdentity: IOSFailedHistoryRetryScratchNodeIdentity
) -> Bool {
    var descriptorStatus = stat()
    var pathStatus = stat()
    guard namespace.hasExactPublishedIdentity(),
          Darwin.fstat(fileDescriptor, &descriptorStatus) == 0,
          isExactRetryScratchFileStatus(
              descriptorStatus,
              effectiveUserID: namespace.effectiveUserID,
              allowsEmpty: true
          ),
          retryScratchNodeIdentity(descriptorStatus) == createdIdentity,
          fileName.withCString({
              Darwin.fstatat(
                  namespace.namespaceDescriptor,
                  $0,
                  &pathStatus,
                  AT_SYMLINK_NOFOLLOW
              )
          }) == 0,
          isExactRetryScratchFileStatus(
              pathStatus,
              effectiveUserID: namespace.effectiveUserID,
              allowsEmpty: true
          ),
          retryScratchNodeIdentity(pathStatus) == createdIdentity else {
        return false
    }
    return retryingPOSIXResult {
        fileName.withCString {
            Darwin.unlinkat(namespace.namespaceDescriptor, $0, 0)
        }
    } == 0
}

private func removeNewRetryScratchNamespaceIfEmpty(
    parentDescriptor: Int32,
    expectedIdentity: IOSFailedHistoryRetryScratchNodeIdentity?
) {
    guard let expectedIdentity else { return }
    var pathStatus = stat()
    guard IOSFailedHistoryRetryScratchNamespace.directoryName.withCString({
        Darwin.fstatat(
            parentDescriptor,
            $0,
            &pathStatus,
            AT_SYMLINK_NOFOLLOW
        )
    }) == 0,
          retryScratchNodeIdentity(pathStatus) == expectedIdentity else {
        return
    }
    _ = retryingPOSIXResult {
        IOSFailedHistoryRetryScratchNamespace.directoryName.withCString {
            Darwin.unlinkat(parentDescriptor, $0, AT_REMOVEDIR)
        }
    }
}

private func retryScratchPathMatchesDescriptor(
    directoryDescriptor: Int32,
    fileName: String,
    fileDescriptor: Int32,
    effectiveUserID: uid_t,
    allowsEmpty: Bool
) -> Bool {
    var descriptorStatus = stat()
    var pathStatus = stat()
    guard Darwin.fstat(fileDescriptor, &descriptorStatus) == 0,
          fileName.withCString({
              Darwin.fstatat(
                  directoryDescriptor,
                  $0,
                  &pathStatus,
                  AT_SYMLINK_NOFOLLOW
              )
          }) == 0,
          isExactRetryScratchFileStatus(
              descriptorStatus,
              effectiveUserID: effectiveUserID,
              allowsEmpty: allowsEmpty
          ),
          isExactRetryScratchFileStatus(
              pathStatus,
              effectiveUserID: effectiveUserID,
              allowsEmpty: allowsEmpty
          ) else {
        return false
    }
    return retryScratchNodeIdentity(descriptorStatus)
        == retryScratchNodeIdentity(pathStatus)
}

private func openRetryScratchScavengeCandidate(
    namespace: IOSFailedHistoryRetryOpenNamespace,
    fileName: String,
    securityCalls: any IOSFailedHistoryRetryScratchSecurityCalling,
    referenceTime: IOSFailedHistoryRetryScratchTimestamp
) -> IOSFailedHistoryRetryScratchScavengeCandidate? {
    guard namespace.hasExactPublishedIdentity() else { return nil }
    let descriptor = retryingOpen {
        fileName.withCString {
            Darwin.openat(
                namespace.namespaceDescriptor,
                $0,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW | O_NONBLOCK
            )
        }
    }
    guard descriptor >= 0 else { return nil }
    var shouldClose = true
    defer { if shouldClose { _ = Darwin.close(descriptor) } }

    var status = stat()
    guard Darwin.fstat(descriptor, &status) == 0,
          isExactRetryScratchFileStatus(
              status,
              effectiveUserID: namespace.effectiveUserID,
              allowsEmpty: true
          ),
          status.st_size
            < IOSFailedHistoryRetryAudioMaterializer
                .maximumAudioByteCountExclusive,
          securityCalls.hasExactPrivateConfiguration(on: descriptor),
          securityCalls.hasExactMarker(
              named: IOSFailedHistoryRetryScratchNamespace.audioMarkerName,
              value: IOSFailedHistoryRetryScratchNamespace.audioMarkerValue,
              on: descriptor
          ),
          securityCalls.lockExclusively(fileDescriptor: descriptor),
          retryScratchNewestTimestamp(status).isAtLeast(
              IOSFailedHistoryRetryScratchScavenger.minimumAgeInSeconds,
              before: referenceTime
          ),
          retryScratchPathMatchesDescriptor(
              directoryDescriptor: namespace.namespaceDescriptor,
              fileName: fileName,
              fileDescriptor: descriptor,
              effectiveUserID: namespace.effectiveUserID,
              allowsEmpty: true
          ) else {
        return nil
    }
    shouldClose = false
    return IOSFailedHistoryRetryScratchScavengeCandidate(
        fileDescriptor: descriptor,
        fileName: fileName,
        identity: retryScratchFileIdentity(status)
    )
}

private func removeRetryScratchCandidateIfUnchanged(
    _ candidate: IOSFailedHistoryRetryScratchScavengeCandidate,
    namespace: IOSFailedHistoryRetryOpenNamespace,
    securityCalls: any IOSFailedHistoryRetryScratchSecurityCalling,
    referenceTime: IOSFailedHistoryRetryScratchTimestamp,
    shouldUnlink: () -> Bool
) -> Bool {
    var descriptorStatus = stat()
    var pathStatus = stat()
    guard namespace.hasExactPublishedIdentity(),
          Darwin.fstat(candidate.fileDescriptor, &descriptorStatus) == 0,
          isExactRetryScratchFileStatus(
              descriptorStatus,
              effectiveUserID: namespace.effectiveUserID,
              allowsEmpty: true
          ),
          retryScratchFileIdentity(descriptorStatus) == candidate.identity,
          retryScratchNewestTimestamp(descriptorStatus).isAtLeast(
              IOSFailedHistoryRetryScratchScavenger.minimumAgeInSeconds,
              before: referenceTime
          ),
          securityCalls.hasExactPrivateConfiguration(
              on: candidate.fileDescriptor
          ),
          securityCalls.hasExactMarker(
              named: IOSFailedHistoryRetryScratchNamespace.audioMarkerName,
              value: IOSFailedHistoryRetryScratchNamespace.audioMarkerValue,
              on: candidate.fileDescriptor
          ),
          candidate.fileName.withCString({
              Darwin.fstatat(
                  namespace.namespaceDescriptor,
                  $0,
                  &pathStatus,
                  AT_SYMLINK_NOFOLLOW
              )
          }) == 0,
          isExactRetryScratchFileStatus(
              pathStatus,
              effectiveUserID: namespace.effectiveUserID,
              allowsEmpty: true
          ),
          retryScratchFileIdentity(pathStatus) == candidate.identity,
          retryScratchNewestTimestamp(pathStatus).isAtLeast(
              IOSFailedHistoryRetryScratchScavenger.minimumAgeInSeconds,
              before: referenceTime
          ),
          shouldUnlink() else {
        return false
    }
    // Darwin has no compare-and-unlink primitive. The descriptor and path are
    // rechecked immediately before this descriptor-relative unlink; any visible
    // replacement, link, mode, marker, protection, size, or age change fails
    // closed and is preserved.
    return retryingPOSIXResult {
        candidate.fileName.withCString {
            Darwin.unlinkat(namespace.namespaceDescriptor, $0, 0)
        }
    } == 0
}

private func isExactRetryScratchDirectoryStatus(
    _ status: stat,
    effectiveUserID: uid_t
) -> Bool {
    status.st_mode & S_IFMT == S_IFDIR
        && status.st_uid == effectiveUserID
        && status.st_mode & mode_t(0o777) == mode_t(0o700)
}

private func isTrustedRetryScratchParentStatus(
    _ status: stat,
    effectiveUserID: uid_t
) -> Bool {
    status.st_mode & S_IFMT == S_IFDIR
        && status.st_uid == effectiveUserID
        && status.st_mode & mode_t(0o022) == 0
}

private func isExactRetryScratchFileStatus(
    _ status: stat,
    effectiveUserID: uid_t,
    allowsEmpty: Bool
) -> Bool {
    status.st_mode & S_IFMT == S_IFREG
        && status.st_uid == effectiveUserID
        && status.st_mode & mode_t(0o777) == mode_t(0o600)
        && status.st_nlink == 1
        && (allowsEmpty ? status.st_size >= 0 : status.st_size > 0)
}

private func retryScratchNodeIdentity(
    _ status: stat
) -> IOSFailedHistoryRetryScratchNodeIdentity {
    IOSFailedHistoryRetryScratchNodeIdentity(
        device: status.st_dev,
        inode: status.st_ino,
        generation: status.st_gen
    )
}

private func retryScratchFileIdentity(
    _ status: stat
) -> IOSFailedHistoryRetryScratchFileIdentity {
    IOSFailedHistoryRetryScratchFileIdentity(
        node: retryScratchNodeIdentity(status),
        byteCount: Int64(status.st_size),
        modificationSeconds: Int64(status.st_mtimespec.tv_sec),
        modificationNanoseconds: Int64(status.st_mtimespec.tv_nsec),
        changeSeconds: Int64(status.st_ctimespec.tv_sec),
        changeNanoseconds: Int64(status.st_ctimespec.tv_nsec)
    )
}

private func retryScratchNewestTimestamp(
    _ status: stat
) -> IOSFailedHistoryRetryScratchTimestamp {
    max(
        IOSFailedHistoryRetryScratchTimestamp(
            seconds: Int64(status.st_mtimespec.tv_sec),
            nanoseconds: Int64(status.st_mtimespec.tv_nsec)
        ),
        IOSFailedHistoryRetryScratchTimestamp(
            seconds: Int64(status.st_ctimespec.tv_sec),
            nanoseconds: Int64(status.st_ctimespec.tv_nsec)
        )
    )
}

private func retryScratchEntryName(
    _ entry: UnsafeMutablePointer<dirent>
) -> String? {
    withUnsafePointer(to: &entry.pointee.d_name) { pointer in
        pointer.withMemoryRebound(
            to: CChar.self,
            capacity: Int(entry.pointee.d_namlen) + 1
        ) {
            String(validatingCString: $0)
        }
    }
}

private func systemRetryScratchTimestamp(
    clock: clockid_t
) -> IOSFailedHistoryRetryScratchTimestamp? {
    var value = timespec()
    guard Darwin.clock_gettime(clock, &value) == 0 else { return nil }
    return IOSFailedHistoryRetryScratchTimestamp(
        seconds: Int64(value.tv_sec),
        nanoseconds: Int64(value.tv_nsec)
    )
}

private func systemRetryScratchNanoseconds(
    clock: clockid_t
) -> UInt64? {
    guard let value = systemRetryScratchTimestamp(clock: clock),
          value.seconds >= 0,
          value.nanoseconds >= 0 else {
        return nil
    }
    let seconds = UInt64(value.seconds).multipliedReportingOverflow(
        by: 1_000_000_000
    )
    guard !seconds.overflow else { return nil }
    let total = seconds.partialValue.addingReportingOverflow(
        UInt64(value.nanoseconds)
    )
    return total.overflow ? nil : total.partialValue
}

private func retryingOpen(_ operation: () -> Int32) -> Int32 {
    var result: Int32
    repeat { result = operation() } while result < 0 && errno == EINTR
    return result
}

private func retryingPOSIXResult(_ operation: () -> Int32) -> Int32 {
    var result: Int32
    repeat { result = operation() } while result != 0 && errno == EINTR
    return result
}

private func retryingPOSIXSizeResult(_ operation: () -> Int) -> Int {
    var result: Int
    repeat { result = operation() } while result < 0 && errno == EINTR
    return result
}
