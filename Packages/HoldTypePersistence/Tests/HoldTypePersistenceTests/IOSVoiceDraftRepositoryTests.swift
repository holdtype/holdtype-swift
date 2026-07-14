import Foundation
import Testing
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence

struct IOSVoiceDraftRepositoryTests {
    @Test func storageContractIsBoundedProtectedAndRedacted() throws {
        let root = URL(
            fileURLWithPath: "/private/app/Library/Application Support",
            isDirectory: true
        )
        #expect(
            IOSVoiceDraftStorageLocation.fileURL(in: root).path ==
                "/private/app/Library/Application Support/HoldType/ios-voice-draft.json"
        )
        #expect(IOSVoiceDraftRecord.maximumSegmentCount == 100)
        #expect(IOSVoiceDraftRepository.maximumByteCount == 4 * 1_024 * 1_024)

        let segment = try makeSegment(1, text: "PRIVATE-CANARY")
        let record = IOSVoiceDraftRecord(segments: [segment])
        let token = IOSVoiceDraftSnapshotToken(record: record)
        #expect(String(describing: segment) == "IOSVoiceDraftSegment(redacted)")
        #expect(String(reflecting: record) == "IOSVoiceDraftRecord(redacted)")
        #expect(String(reflecting: token) == "IOSVoiceDraftSnapshotToken(redacted)")
        #expect(segment.customMirror.children.isEmpty)
        #expect(record.customMirror.children.isEmpty)
        #expect(token.customMirror.children.isEmpty)
    }

    @Test func missingFileLoadsEmptyWithoutWriting() async throws {
        let fileSystem = DraftFileSystemFake()
        let repository = makeRepository(fileSystem)

        #expect(try await repository.load() == .empty)
        #expect(fileSystem.replacementCallCount == 0)
        #expect(fileSystem.readPolicies == [expectedPolicy])
    }

    @Test func appendWritesCanonicalV1AndJoinsSegmentsWithBlankLines()
        async throws {
        let fileSystem = DraftFileSystemFake()
        let repository = makeRepository(fileSystem)

        #expect(
            try await repository.append(makeSegment(1, text: "First")) ==
                .inserted(IOSVoiceDraftRecord(segments: [try makeSegment(1, text: "First")]))
        )
        _ = try await repository.append(makeSegment(2, text: "Second"))

        let record = try await repository.load()
        #expect(record.text == "First\n\nSecond")
        #expect(
            String(decoding: try #require(fileSystem.data), as: UTF8.self) ==
                #"{"schemaVersion":1,"segments":[{"resultID":"00000000-0000-0000-0000-000000000001","text":"First"},{"resultID":"00000000-0000-0000-0000-000000000002","text":"Second"}]}"#
        )
        #expect(fileSystem.replacementPolicies == [expectedPolicy, expectedPolicy])
    }

    @Test func appendIsExactOnceRejectsCollisionsAndStopsAtBound() async throws {
        let fileSystem = DraftFileSystemFake()
        let repository = makeRepository(fileSystem)
        let first = try makeSegment(1)

        _ = try await repository.append(first)
        let replacementCount = fileSystem.replacementCallCount
        guard case .duplicate(let duplicate) = try await repository.append(first) else {
            Issue.record("Expected exact duplicate")
            return
        }
        #expect(duplicate.segments == [first])
        #expect(fileSystem.replacementCallCount == replacementCount)

        await expectError(.identifierCollision) {
            _ = try await repository.append(
                makeSegment(1, text: "Different text")
            )
        }

        for index in 2...IOSVoiceDraftRecord.maximumSegmentCount {
            _ = try await repository.append(makeSegment(index))
        }
        let full = try await repository.load()
        #expect(full.isFull)
        #expect(
            try await repository.append(makeSegment(101)) == .full(full)
        )
        #expect(fileSystem.replacementCallCount == IOSVoiceDraftRecord.maximumSegmentCount)
    }

    @Test func replaceUsesConfirmedSnapshotAndNeverOverwritesAStaleDraft()
        async throws {
        let fileSystem = DraftFileSystemFake()
        let repository = makeRepository(fileSystem)
        _ = try await repository.append(makeSegment(1))
        let observed = try await repository.load()
        let token = IOSVoiceDraftSnapshotToken(record: observed)
        _ = try await repository.append(makeSegment(2))
        let current = try await repository.load()
        let replacementCount = fileSystem.replacementCallCount

        #expect(
            try await repository.replace(.empty, ifCurrent: token) ==
                .stale(current)
        )
        #expect(fileSystem.replacementCallCount == replacementCount)
        #expect(try await repository.load() == current)
        #expect(
            try await repository.replace(
                .empty,
                ifCurrent: IOSVoiceDraftSnapshotToken(record: current)
            ) == .confirmed(.empty)
        )
    }

    @Test func strictDecoderRejectsUntrustedRecordsWithoutRewriting() async {
        let invalid: [(Data, IOSVoiceDraftRepositoryError)] = [
            (Data(#"{"schemaVersion":1,"schemaVersion":1,"segments":[]}"#.utf8), .malformedData),
            (Data(#"[]"#.utf8), .topLevelNotObject),
            (Data(#"{"schemaVersion":1}"#.utf8), .missingRequiredValue(path: "segments")),
            (Data(#"{"schemaVersion":2,"segments":[]}"#.utf8), .unsupportedSchemaVersion),
            (Data(#"{"schemaVersion":1,"segments":[],"extra":1}"#.utf8), .unexpectedFields(path: "$")),
            (Data(#"{"schemaVersion":1,"segments":[{"resultID":"not-a-uuid","text":"Text"}]}"#.utf8), .invalidValue(path: "segments[0].resultID")),
            (Data(#"{"schemaVersion":1,"segments":[{"resultID":"00000000-0000-0000-0000-000000000001","text":""}]}"#.utf8), .invalidValue(path: "segments[0].text")),
            (Data(#"{"schemaVersion":1,"segments":[{"resultID":"00000000-0000-0000-0000-000000000001","text":"One"},{"resultID":"00000000-0000-0000-0000-000000000001","text":"Two"}]}"#.utf8), .duplicateIdentifier),
        ]

        for (data, expected) in invalid {
            let fileSystem = DraftFileSystemFake(data: data)
            await expectError(expected) {
                _ = try await makeRepository(fileSystem).load()
            }
            #expect(fileSystem.data == data)
            #expect(fileSystem.replacementCallCount == 0)
        }
    }

    private var expectedPolicy: ProtectedAtomicMetadataFilePolicy {
        ProtectedAtomicMetadataFilePolicy(
            maximumByteCount: 4 * 1_024 * 1_024,
            fileProtection: .complete,
            excludesFromBackup: true
        )
    }

    private func makeRepository(
        _ fileSystem: DraftFileSystemFake
    ) -> IOSVoiceDraftRepository {
        IOSVoiceDraftRepository(
            fileURL: URL(fileURLWithPath: "/app-private/HoldType/ios-voice-draft.json"),
            fileSystem: fileSystem
        )
    }

    private func makeSegment(
        _ index: Int,
        text: String? = nil
    ) throws -> IOSVoiceDraftSegment {
        try IOSVoiceDraftSegment(
            resultID: identifier(index),
            text: text ?? "Accepted text \(index)"
        )
    }

    private func identifier(_ index: Int) -> UUID {
        UUID(
            uuidString: String(
                format: "00000000-0000-0000-0000-%012d",
                index
            )
        )!
    }

    private func expectError(
        _ expected: IOSVoiceDraftRepositoryError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expected)")
        } catch let error as IOSVoiceDraftRepositoryError {
            #expect(error == expected)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private enum DraftFileSystemFakeError: Error {
    case read
    case replace
}

private final class DraftFileSystemFake:
    ProtectedAtomicMetadataFileSystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedData: Data?
    private var storedReadPolicies: [ProtectedAtomicMetadataFilePolicy] = []
    private var storedReplacementPolicies: [ProtectedAtomicMetadataFilePolicy] = []
    private var storedReplacementCallCount = 0
    private let readError: Error?
    private let replacementError: Error?

    var data: Data? { lock.withLock { storedData } }
    var readPolicies: [ProtectedAtomicMetadataFilePolicy] {
        lock.withLock { storedReadPolicies }
    }
    var replacementPolicies: [ProtectedAtomicMetadataFilePolicy] {
        lock.withLock { storedReplacementPolicies }
    }
    var replacementCallCount: Int {
        lock.withLock { storedReplacementCallCount }
    }

    init(
        data: Data? = nil,
        readError: Error? = nil,
        replacementError: Error? = nil
    ) {
        storedData = data
        self.readError = readError
        self.replacementError = replacementError
    }

    func readFileIfPresent(
        at fileURL: URL,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws -> Data? {
        try lock.withLock {
            storedReadPolicies.append(policy)
            if let readError { throw readError }
            return storedData
        }
    }

    func replaceFileAtomically(
        at fileURL: URL,
        with data: Data,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws {
        try lock.withLock {
            storedReplacementCallCount += 1
            storedReplacementPolicies.append(policy)
            if let replacementError { throw replacementError }
            storedData = data
        }
    }

    func removeFileIfPresent(at fileURL: URL) throws {
        lock.withLock { storedData = nil }
    }
}
