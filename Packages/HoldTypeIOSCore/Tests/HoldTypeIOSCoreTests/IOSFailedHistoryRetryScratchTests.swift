import Darwin
import Foundation
@_spi(HoldTypeIOSCore) import HoldTypePersistence
import Testing
@testable import HoldTypeIOSCore

struct IOSFailedHistoryRetryScratchTests {
    @Test func productionStyle0755ParentSupportsMaterializationAndScavenging()
        async throws {
        let root = try retryScratchTemporaryRoot("production-parent")
        defer { try? FileManager.default.removeItem(at: root) }
        #expect(Darwin.chmod(root.path, 0o755) == 0)
        let audio = RetryScratchTestAudio(
            data: Data(repeating: 0x41, count: 1_024),
            format: .wav
        )
        let materializer = IOSFailedHistoryRetryAudioMaterializer(
            scratchDirectoryURL: root
        )

        let copiedByteCount = try await materializer.withMaterializedAudio(
            audio
        ) { fileURL in
            try Data(contentsOf: fileURL).count
        }
        #expect(copiedByteCount == audio.data.count)
        try expectRetryScratchNamespaceEmpty(in: root)

        let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(
            in: root
        )
        let orphan = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .wav,
            byteCount: 64,
            marker: .exact
        )
        let now = try currentRetryScratchTimestamp()
        let summary = IOSFailedHistoryRetryScratchScavenger(
            parentDirectoryURL: root,
            wallClock: {
                .init(
                    seconds: now.seconds + 7_200,
                    nanoseconds: now.nanoseconds
                )
            },
            monotonicClock: { 0 }
        ).run()

        #expect(summary.removedFileCount == 1)
        #expect(!FileManager.default.fileExists(atPath: orphan.path))
        let permissions = try #require(
            FileManager.default.attributesOfItem(atPath: root.path)[
                .posixPermissions
            ] as? NSNumber
        )
        #expect(permissions.intValue & 0o777 == 0o755)
    }

    @Test func firstWriteUsesTheSameSecuredLockedDescriptor() async throws {
        let root = try retryScratchTemporaryRoot("prewrite")
        defer { try? FileManager.default.removeItem(at: root) }
        let calls = RecordingRetryScratchSecurityCalls()
        let materializer = IOSFailedHistoryRetryAudioMaterializer(
            scratchDirectoryURL: root,
            securityCalls: calls
        )
        let audio = RetryScratchTestAudio(
            data: Data(repeating: 0x5A, count: 4_097),
            format: .wav
        )

        let lockWasHeld = try await materializer.withMaterializedAudio(audio) {
            fileURL in
            #expect(
                IOSFailedHistoryRetryScratchNamespace.audioFormat(
                    inExactFileName: fileURL.lastPathComponent
                ) == .wav
            )
            let competingDescriptor = Darwin.open(
                fileURL.path,
                O_RDONLY | O_CLOEXEC | O_NOFOLLOW
            )
            guard competingDescriptor >= 0 else { return false }
            defer { _ = Darwin.close(competingDescriptor) }
            return flock(competingDescriptor, LOCK_EX | LOCK_NB) != 0
        }

        #expect(lockWasHeld)
        #expect(calls.writeCount > 0)
        #expect(calls.everyWriteStartedWithExactSecurity)
        try expectRetryScratchNamespaceEmpty(in: root)
    }

    @Test func cleanupPreservesAReplacementPathAndReportsFailure()
        async throws {
        let root = try retryScratchTemporaryRoot("replacement")
        defer { try? FileManager.default.removeItem(at: root) }
        let materializer = IOSFailedHistoryRetryAudioMaterializer(
            scratchDirectoryURL: root
        )
        let audio = RetryScratchTestAudio(
            data: Data(repeating: 0x31, count: 1_024),
            format: .m4a
        )
        let capture = RetryScratchURLCapture()

        do {
            _ = try await materializer.withMaterializedAudio(audio) {
                fileURL -> Int in
                await capture.store(fileURL)
                let movedURL = fileURL.deletingLastPathComponent()
                    .appendingPathComponent("preserved-original")
                try FileManager.default.moveItem(at: fileURL, to: movedURL)
                try Data("foreign replacement".utf8).write(to: fileURL)
                return 1
            }
            Issue.record("Expected identity-pinned cleanup to fail closed.")
        } catch IOSFailedHistoryRetryAudioMaterializationError.cleanupFailed {
            // Expected.
        }

        let fileURL = try #require(await capture.value())
        let replacement = try Data(contentsOf: fileURL)
        #expect(replacement == Data("foreign replacement".utf8))
        #expect(
            FileManager.default.fileExists(
                atPath: fileURL.deletingLastPathComponent()
                    .appendingPathComponent("preserved-original").path
            )
        )
    }

    @Test func cleanupPreservesASymlinkReplacementAndItsTarget()
        async throws {
        let root = try retryScratchTemporaryRoot("symlink-replacement")
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceURL = root.appendingPathComponent("source-recording.wav")
        let source = Data("source recording".utf8)
        try source.write(to: sourceURL)
        let materializer = IOSFailedHistoryRetryAudioMaterializer(
            scratchDirectoryURL: root
        )
        let audio = RetryScratchTestAudio(
            data: Data(repeating: 0x22, count: 1_024),
            format: .wav
        )
        let capture = RetryScratchURLCapture()

        do {
            _ = try await materializer.withMaterializedAudio(audio) {
                fileURL -> Int in
                await capture.store(fileURL)
                try FileManager.default.removeItem(at: fileURL)
                try FileManager.default.createSymbolicLink(
                    at: fileURL,
                    withDestinationURL: sourceURL
                )
                return 1
            }
            Issue.record("Expected symlink replacement to fail closed.")
        } catch IOSFailedHistoryRetryAudioMaterializationError.cleanupFailed {
            // Expected.
        }

        let fileURL = try #require(await capture.value())
        var status = stat()
        #expect(Darwin.lstat(fileURL.path, &status) == 0)
        #expect(status.st_mode & S_IFMT == S_IFLNK)
        #expect(try Data(contentsOf: sourceURL) == source)
    }

    @Test func scavengerRemovesOnlyAnOldExactMarkedUnlockedOrphan()
        async throws {
        let root = try retryScratchTemporaryRoot("scavenge-selection")
        defer { try? FileManager.default.removeItem(at: root) }
        try await createRetryScratchNamespace(in: root)
        let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(
            in: root
        )
        let now = try currentRetryScratchTimestamp()
        let oldReference = IOSFailedHistoryRetryScratchTimestamp(
            seconds: now.seconds + 7_200,
            nanoseconds: now.nanoseconds
        )

        let removable = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .wav,
            byteCount: 64,
            marker: .exact
        )
        let young = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .m4a,
            byteCount: 32,
            marker: .exact
        )
        try FileManager.default.setAttributes(
            [
                .modificationDate:
                    Date(timeIntervalSince1970:
                        TimeInterval(oldReference.seconds + 1))
            ],
            ofItemAtPath: young.path
        )
        let unmarked = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .wav,
            byteCount: 16,
            marker: .none
        )
        let wrongMarker = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .m4a,
            byteCount: 16,
            marker: .wrong
        )
        let hardLinked = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .wav,
            byteCount: 16,
            marker: .exact
        )
        let hardLinkPeer = namespace.appendingPathComponent("hard-link-peer")
        try FileManager.default.linkItem(at: hardLinked, to: hardLinkPeer)
        let wrongMode = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .wav,
            byteCount: 16,
            marker: .exact
        )
        #expect(Darwin.chmod(wrongMode.path, 0o640) == 0)
        let active = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .m4a,
            byteCount: 16,
            marker: .exact
        )
        let activeDescriptor = Darwin.open(
            active.path,
            O_RDONLY | O_CLOEXEC | O_NOFOLLOW
        )
        #expect(activeDescriptor >= 0)
        #expect(flock(activeDescriptor, LOCK_EX | LOCK_NB) == 0)

        let source = namespace.appendingPathComponent("recording.wav")
        try Data("source".utf8).write(to: source)
        let symlink = namespace.appendingPathComponent(
            IOSFailedHistoryRetryScratchNamespace.audioFileName(
                identifier: UUID(),
                format: .wav
            )
        )
        try FileManager.default.createSymbolicLink(
            at: symlink,
            withDestinationURL: source
        )
        let malformed = namespace.appendingPathComponent(
            "htr-audio-v1-01234567-89AB-CDEF-8123-456789ABCDEF.wav"
        )
        try Data("malformed".utf8).write(to: malformed)

        let summary = IOSFailedHistoryRetryScratchScavenger(
            parentDirectoryURL: root,
            wallClock: { oldReference },
            monotonicClock: { 0 }
        ).run()

        #expect(summary.stopReason == .complete)
        #expect(summary.removedFileCount == 1)
        #expect(!FileManager.default.fileExists(atPath: removable.path))
        for retained in [
            young, unmarked, wrongMarker, hardLinked, hardLinkPeer, wrongMode,
            active, source, symlink, malformed,
        ] {
            #expect(FileManager.default.fileExists(atPath: retained.path))
        }
        #expect(String(describing: summary).contains("redacted"))

        if activeDescriptor >= 0 {
            #expect(flock(activeDescriptor, LOCK_UN) == 0)
            _ = Darwin.close(activeDescriptor)
        }
    }

    @Test func scavengerFinalIdentityChangePreservesBothPaths()
        async throws {
        let root = try retryScratchTemporaryRoot("scavenge-race")
        defer { try? FileManager.default.removeItem(at: root) }
        try await createRetryScratchNamespace(in: root)
        let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(
            in: root
        )
        let candidate = try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .wav,
            byteCount: 8,
            marker: .exact
        )
        let mutation = RetryScratchReplacementMutation(
            candidateURL: candidate
        )
        let now = try currentRetryScratchTimestamp()
        let summary = IOSFailedHistoryRetryScratchScavenger(
            parentDirectoryURL: root,
            wallClock: {
                .init(
                    seconds: now.seconds + 7_200,
                    nanoseconds: now.nanoseconds
                )
            },
            monotonicClock: { 0 },
            beforeFinalValidation: { _ in mutation.runOnce() }
        ).run()

        #expect(summary.removedFileCount == 0)
        #expect(try Data(contentsOf: candidate) == Data("replacement".utf8))
        #expect(
            FileManager.default.fileExists(
                atPath: namespace.appendingPathComponent(
                    "preserved-scavenger-original"
                ).path
            )
        )
    }

    @Test func scavengerHonorsEntryRemovalByteAndTimeCaps() async throws {
        try await verifyRetryScratchEntryCap()
        try await verifyRetryScratchRemovalCap()
        try await verifyRetryScratchByteCap()

        let clock = RetryScratchScriptedClock(
            values: [
                0,
                IOSFailedHistoryRetryScratchScavenger
                    .maximumElapsedNanoseconds,
            ]
        )
        let timeSummary = IOSFailedHistoryRetryScratchScavenger(
            parentDirectoryURL: URL(fileURLWithPath: "/unused"),
            wallClock: { .init(seconds: 1, nanoseconds: 0) },
            monotonicClock: { clock.next() }
        ).run()
        #expect(timeSummary.stopReason == .timeLimit)
    }

    @Test func missingSymlinkOrUnmarkedNamespaceIsNeverClaimed()
        async throws {
        let root = try retryScratchTemporaryRoot("namespace-preservation")
        defer { try? FileManager.default.removeItem(at: root) }
        let missingSummary = IOSFailedHistoryRetryScratchScavenger(
            parentDirectoryURL: root,
            monotonicClock: { 0 }
        ).run()
        #expect(missingSummary.stopReason == .complete)
        #expect(
            !FileManager.default.fileExists(
                atPath: IOSFailedHistoryRetryScratchNamespace
                    .namespaceURL(in: root).path
            )
        )

        let target = root.appendingPathComponent("foreign-target")
        try FileManager.default.createDirectory(
            at: target,
            withIntermediateDirectories: false
        )
        #expect(Darwin.chmod(target.path, 0o700) == 0)
        let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(
            in: root
        )
        try FileManager.default.createSymbolicLink(
            at: namespace,
            withDestinationURL: target
        )
        let symlinkSummary = IOSFailedHistoryRetryScratchScavenger(
            parentDirectoryURL: root,
            monotonicClock: { 0 }
        ).run()
        #expect(symlinkSummary.stopReason == .namespaceUnavailable)
        #expect(FileManager.default.fileExists(atPath: target.path))

        try FileManager.default.removeItem(at: namespace)
        try FileManager.default.createDirectory(
            at: namespace,
            withIntermediateDirectories: false
        )
        #expect(Darwin.chmod(namespace.path, 0o700) == 0)
        let foreign = namespace.appendingPathComponent("foreign")
        try Data("keep".utf8).write(to: foreign)
        let unmarkedSummary = IOSFailedHistoryRetryScratchScavenger(
            parentDirectoryURL: root,
            monotonicClock: { 0 }
        ).run()
        #expect(unmarkedSummary.stopReason == .namespaceUnavailable)
        #expect(try Data(contentsOf: foreign) == Data("keep".utf8))
    }
}

private enum RetryScratchArtifactMarker {
    case exact
    case wrong
    case none
}

private struct RetryScratchTestAudio: IOSFailedHistoryRetryAudioReading {
    let data: Data
    let format: IOSPendingRecordingAudioFormat
    var byteCount: Int64 { Int64(data.count) }

    func read(
        atOffset offset: Int64,
        maximumByteCount: Int
    ) async throws -> Data {
        guard offset >= 0,
              maximumByteCount > 0,
              offset < Int64(data.count) else {
            return Data()
        }
        let lower = Int(offset)
        let upper = min(data.count, lower + maximumByteCount)
        return data.subdata(in: lower..<upper)
    }
}

private final class RecordingRetryScratchSecurityCalls:
    @unchecked Sendable,
    IOSFailedHistoryRetryScratchSecurityCalling {
    private let lock = NSLock()
    private let base = DarwinIOSFailedHistoryRetryScratchSecurityCalls()
    private var storedWriteCount = 0
    private var storedEveryWriteStartedWithExactSecurity = true

    var writeCount: Int {
        lock.withLock { storedWriteCount }
    }

    var everyWriteStartedWithExactSecurity: Bool {
        lock.withLock { storedEveryWriteStartedWithExactSecurity }
    }

    func applyPrivateConfiguration(to fileDescriptor: Int32) -> Bool {
        base.applyPrivateConfiguration(to: fileDescriptor)
    }

    func hasExactPrivateConfiguration(on fileDescriptor: Int32) -> Bool {
        base.hasExactPrivateConfiguration(on: fileDescriptor)
    }

    func installMarker(
        named name: String,
        value: [UInt8],
        on fileDescriptor: Int32
    ) -> Bool {
        base.installMarker(
            named: name,
            value: value,
            on: fileDescriptor
        )
    }

    func hasExactMarker(
        named name: String,
        value: [UInt8],
        on fileDescriptor: Int32
    ) -> Bool {
        base.hasExactMarker(
            named: name,
            value: value,
            on: fileDescriptor
        )
    }

    func lockExclusively(fileDescriptor: Int32) -> Bool {
        base.lockExclusively(fileDescriptor: fileDescriptor)
    }

    func write(
        fileDescriptor: Int32,
        buffer: UnsafeRawPointer,
        byteCount: Int
    ) -> Int {
        var status = stat()
        let isExact = Darwin.fstat(fileDescriptor, &status) == 0
            && status.st_mode & S_IFMT == S_IFREG
            && status.st_mode & mode_t(0o777) == mode_t(0o600)
            && status.st_nlink == 1
            && base.hasExactPrivateConfiguration(on: fileDescriptor)
            && base.hasExactMarker(
                named: IOSFailedHistoryRetryScratchNamespace.audioMarkerName,
                value: IOSFailedHistoryRetryScratchNamespace.audioMarkerValue,
                on: fileDescriptor
            )
        lock.withLock {
            storedWriteCount += 1
            storedEveryWriteStartedWithExactSecurity =
                storedEveryWriteStartedWithExactSecurity && isExact
        }
        return base.write(
            fileDescriptor: fileDescriptor,
            buffer: buffer,
            byteCount: byteCount
        )
    }

    func synchronize(fileDescriptor: Int32) -> Bool {
        base.synchronize(fileDescriptor: fileDescriptor)
    }
}

private actor RetryScratchURLCapture {
    private var storedURL: URL?
    func store(_ url: URL) { storedURL = url }
    func value() -> URL? { storedURL }
}

private final class RetryScratchReplacementMutation: @unchecked Sendable {
    private let lock = NSLock()
    private let candidateURL: URL
    private var didRun = false

    init(candidateURL: URL) {
        self.candidateURL = candidateURL
    }

    func runOnce() {
        lock.withLock {
            guard !didRun else { return }
            didRun = true
            let moved = candidateURL.deletingLastPathComponent()
                .appendingPathComponent("preserved-scavenger-original")
            try? FileManager.default.moveItem(at: candidateURL, to: moved)
            try? Data("replacement".utf8).write(to: candidateURL)
        }
    }
}

private final class RetryScratchScriptedClock: @unchecked Sendable {
    private let lock = NSLock()
    private let values: [UInt64]
    private var index = 0

    init(values: [UInt64]) { self.values = values }

    func next() -> UInt64 {
        lock.withLock {
            let value = values[min(index, values.count - 1)]
            index += 1
            return value
        }
    }
}

private func retryScratchTemporaryRoot(_ suffix: String) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
        "ios-failed-retry-scratch-\(suffix)-\(UUID().uuidString)",
        isDirectory: true
    )
    try FileManager.default.createDirectory(
        at: root,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
    )
    guard Darwin.chmod(root.path, 0o700) == 0 else {
        throw CocoaError(.fileWriteNoPermission)
    }
    return root
}

private func createRetryScratchNamespace(in root: URL) async throws {
    let materializer = IOSFailedHistoryRetryAudioMaterializer(
        scratchDirectoryURL: root
    )
    _ = try await materializer.withMaterializedAudio(
        RetryScratchTestAudio(data: Data([0x01]), format: .wav)
    ) { _ in true }
}

private func expectRetryScratchNamespaceEmpty(in root: URL) throws {
    let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(
        in: root
    )
    #expect(FileManager.default.fileExists(atPath: namespace.path))
    #expect(
        try FileManager.default.contentsOfDirectory(atPath: namespace.path)
            .isEmpty
    )
}

@discardableResult
private func makeRetryScratchArtifact(
    in namespace: URL,
    identifier: UUID,
    format: IOSPendingRecordingAudioFormat,
    byteCount: Int64,
    marker: RetryScratchArtifactMarker
) throws -> URL {
    let fileName = IOSFailedHistoryRetryScratchNamespace.audioFileName(
        identifier: identifier,
        format: format
    )
    let fileURL = namespace.appendingPathComponent(fileName)
    let descriptor = Darwin.open(
        fileURL.path,
        O_RDWR | O_CREAT | O_EXCL | O_CLOEXEC | O_NOFOLLOW,
        S_IRUSR | S_IWUSR
    )
    guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
    defer { _ = Darwin.close(descriptor) }
    let calls = DarwinIOSFailedHistoryRetryScratchSecurityCalls()
    guard Darwin.fchmod(descriptor, S_IRUSR | S_IWUSR) == 0,
          calls.applyPrivateConfiguration(to: descriptor) else {
        throw CocoaError(.fileWriteNoPermission)
    }
    switch marker {
    case .exact:
        guard calls.installMarker(
            named: IOSFailedHistoryRetryScratchNamespace.audioMarkerName,
            value: IOSFailedHistoryRetryScratchNamespace.audioMarkerValue,
            on: descriptor
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
    case .wrong:
        guard calls.installMarker(
            named: IOSFailedHistoryRetryScratchNamespace.audioMarkerName,
            value: Array("wrong".utf8),
            on: descriptor
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }
    case .none:
        break
    }
    guard Darwin.ftruncate(descriptor, off_t(byteCount)) == 0,
          Darwin.fsync(descriptor) == 0 else {
        throw CocoaError(.fileWriteUnknown)
    }
    return fileURL
}

private func currentRetryScratchTimestamp() throws
    -> IOSFailedHistoryRetryScratchTimestamp {
    var value = timespec()
    guard Darwin.clock_gettime(CLOCK_REALTIME, &value) == 0 else {
        throw CocoaError(.fileReadUnknown)
    }
    return .init(
        seconds: Int64(value.tv_sec),
        nanoseconds: Int64(value.tv_nsec)
    )
}

private func verifyRetryScratchEntryCap() async throws {
    let root = try retryScratchTemporaryRoot("entry-cap")
    defer { try? FileManager.default.removeItem(at: root) }
    try await createRetryScratchNamespace(in: root)
    let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(in: root)
    for index in 0..<IOSFailedHistoryRetryScratchScavenger
        .maximumInspectedEntryCount {
        try Data().write(
            to: namespace.appendingPathComponent("foreign-\(index)")
        )
    }
    let summary = IOSFailedHistoryRetryScratchScavenger(
        parentDirectoryURL: root,
        monotonicClock: { 0 }
    ).run()
    #expect(summary.stopReason == .entryLimit)
    #expect(
        summary.inspectedEntryCount
            == IOSFailedHistoryRetryScratchScavenger
                .maximumInspectedEntryCount
    )
}

private func verifyRetryScratchRemovalCap() async throws {
    let root = try retryScratchTemporaryRoot("removal-cap")
    defer { try? FileManager.default.removeItem(at: root) }
    try await createRetryScratchNamespace(in: root)
    let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(in: root)
    for _ in 0...IOSFailedHistoryRetryScratchScavenger
        .maximumRemovedFileCount {
        try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .wav,
            byteCount: 0,
            marker: .exact
        )
    }
    let now = try currentRetryScratchTimestamp()
    let summary = IOSFailedHistoryRetryScratchScavenger(
        parentDirectoryURL: root,
        wallClock: {
            .init(
                seconds: now.seconds + 7_200,
                nanoseconds: now.nanoseconds
            )
        },
        monotonicClock: { 0 }
    ).run()
    #expect(summary.stopReason == .removalLimit)
    #expect(
        summary.removedFileCount
            == IOSFailedHistoryRetryScratchScavenger.maximumRemovedFileCount
    )
}

private func verifyRetryScratchByteCap() async throws {
    let root = try retryScratchTemporaryRoot("byte-cap")
    defer { try? FileManager.default.removeItem(at: root) }
    try await createRetryScratchNamespace(in: root)
    let namespace = IOSFailedHistoryRetryScratchNamespace.namespaceURL(in: root)
    for _ in 0..<9 {
        try makeRetryScratchArtifact(
            in: namespace,
            identifier: UUID(),
            format: .m4a,
            byteCount: 24_000_000,
            marker: .exact
        )
    }
    let now = try currentRetryScratchTimestamp()
    let summary = IOSFailedHistoryRetryScratchScavenger(
        parentDirectoryURL: root,
        wallClock: {
            .init(
                seconds: now.seconds + 7_200,
                nanoseconds: now.nanoseconds
            )
        },
        monotonicClock: { 0 }
    ).run()
    #expect(summary.stopReason == .byteLimit)
    #expect(summary.removedFileCount == 8)
    #expect(summary.accountedByteCount == 192_000_000)
}
