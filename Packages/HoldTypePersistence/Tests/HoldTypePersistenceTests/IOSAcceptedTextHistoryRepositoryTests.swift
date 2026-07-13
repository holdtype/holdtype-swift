import Foundation
import Testing
@testable import HoldTypePersistence

struct IOSAcceptedTextHistoryRepositoryTests {
    @Test func valueAndStorageContractsAreBoundedPrivateAndRedacted() async throws {
        let applicationSupportURL = URL(
            fileURLWithPath: "/private/app/Library/Application Support",
            isDirectory: true
        )
        #expect(
            IOSAcceptedTextHistoryStorageLocation.fileURL(
                in: applicationSupportURL
            ).path ==
                "/private/app/Library/Application Support/HoldType/ios-accepted-text-history.json"
        )
        #expect(IOSAcceptedTextHistoryRecord.maximumEntryCount == 20)
        #expect(IOSAcceptedTextHistoryRepository.maximumByteCount == 4 * 1_024 * 1_024)

        let entry = try makeEntry(index: 1, text: "PRIVATE-CANARY")
        let record = IOSAcceptedTextHistoryRecord(
            isEnabled: true,
            entries: [entry]
        )
        #expect(String(describing: entry) == "IOSAcceptedTextHistoryEntry(redacted)")
        #expect(String(reflecting: entry) == "IOSAcceptedTextHistoryEntry(redacted)")
        #expect(entry.customMirror.children.isEmpty)
        #expect(String(describing: record) == "IOSAcceptedTextHistoryRecord(redacted)")
        #expect(String(reflecting: record) == "IOSAcceptedTextHistoryRecord(redacted)")
        #expect(record.customMirror.children.isEmpty)
        requireSendable(IOSAcceptedTextHistoryEntry.self)
        requireSendable(IOSAcceptedTextHistoryRecord.self)
    }

    @Test func missingFileDefaultsEnabledAndEmptyWithoutWriting() async throws {
        let fileSystem = HistoryFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem)

        #expect(try await repository.load() == .enabledEmpty)
        #expect(fileSystem.replacementCallCount == 0)
        #expect(fileSystem.readPolicies == [expectedPolicy])
    }

    @Test func appendWritesCanonicalV1AndRoundTrips() async throws {
        let fileSystem = HistoryFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem)
        let entry = try makeEntry(index: 1, text: "Accepted text")

        #expect(try await repository.append(entry) == .inserted)
        #expect(
            String(decoding: try #require(fileSystem.data), as: UTF8.self) ==
                #"{"enabled":true,"entries":[{"createdAtMilliseconds":1000,"resultID":"00000000-0000-0000-0000-000000000001","text":"Accepted text"}],"schemaVersion":1}"#
        )
        #expect(try await repository.load() == IOSAcceptedTextHistoryRecord(
            isEnabled: true,
            entries: [entry]
        ))
        #expect(fileSystem.replacementPolicies == [expectedPolicy])
    }

    @Test func appendIsNewestFirstCappedAndIdempotent() async throws {
        let fileSystem = HistoryFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem)

        for index in 1...21 {
            #expect(
                try await repository.append(makeEntry(index: index)) == .inserted
            )
        }

        let record = try await repository.load()
        #expect(record.entries.count == 20)
        #expect(record.entries.map(\.resultID) == (2...21).reversed().map(identifier))
        let replacementCount = fileSystem.replacementCallCount
        #expect(
            try await repository.append(makeEntry(index: 21)) == .duplicate
        )
        #expect(
            try await repository.append(makeEntry(index: 1)) ==
                .outsideRetentionWindow
        )
        #expect(fileSystem.replacementCallCount == replacementCount)
    }

    @Test func sameIdentifierWithDifferentPayloadFailsClosed() async throws {
        let fileSystem = HistoryFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem)
        _ = try await repository.append(makeEntry(index: 1))
        let replacementCount = fileSystem.replacementCallCount

        await expectError(.identifierCollision) {
            _ = try await repository.append(
                makeEntry(index: 1, text: "Different accepted text")
            )
        }
        #expect(fileSystem.replacementCallCount == replacementCount)
    }

    @Test func deleteClearDisableAndEnableMutateOnlyAfterAtomicReplace() async throws {
        let fileSystem = HistoryFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem)
        _ = try await repository.append(makeEntry(index: 1))
        _ = try await repository.append(makeEntry(index: 2))

        let afterDelete = IOSAcceptedTextHistoryRecord(
            isEnabled: true,
            entries: [try makeEntry(index: 2)]
        )
        #expect(
            try await repository.delete(resultID: identifier(1))
                == afterDelete
        )
        #expect(
            try await repository.delete(resultID: identifier(1))
                == afterDelete
        )
        #expect(
            try await repository.clearAll(
                ifCurrent: IOSAcceptedTextHistorySnapshotToken(
                    record: afterDelete
                )
            ) == .confirmed(.enabledEmpty)
        )
        #expect(
            try await repository.clearAll(
                ifCurrent: IOSAcceptedTextHistorySnapshotToken(
                    record: .enabledEmpty
                )
            ) == .confirmed(.enabledEmpty)
        )
        _ = try await repository.append(makeEntry(index: 3))
        let enabledWithEntry = try await repository.load()
        let disabled = IOSAcceptedTextHistoryRecord(
            isEnabled: false,
            entries: []
        )
        #expect(
            try await repository.setEnabled(
                false,
                ifCurrent: IOSAcceptedTextHistorySnapshotToken(
                    record: enabledWithEntry
                )
            ) == .confirmed(disabled)
        )
        #expect(try await repository.load() == disabled)

        let replacementCount = fileSystem.replacementCallCount
        #expect(
            try await repository.append(makeEntry(index: 4)) == .disabled
        )
        #expect(
            try await repository.setEnabled(
                false,
                ifCurrent: IOSAcceptedTextHistorySnapshotToken(
                    record: disabled
                )
            ) == .confirmed(disabled)
        )
        #expect(fileSystem.replacementCallCount == replacementCount)
        #expect(
            try await repository.setEnabled(
                true,
                ifCurrent: IOSAcceptedTextHistorySnapshotToken(
                    record: disabled
                )
            ) == .confirmed(.enabledEmpty)
        )
        #expect(try await repository.load() == .enabledEmpty)
    }

    @Test func destructiveMutationsRejectAStaleConfirmedSnapshot() async throws {
        let fileSystem = HistoryFileSystemFake()
        let repository = makeRepository(fileSystem: fileSystem)
        _ = try await repository.append(makeEntry(index: 1))
        let observed = try await repository.load()
        let staleToken = IOSAcceptedTextHistorySnapshotToken(record: observed)
        _ = try await repository.append(makeEntry(index: 2))
        let current = try await repository.load()
        let replacementCount = fileSystem.replacementCallCount

        #expect(
            try await repository.clearAll(ifCurrent: staleToken)
                == .stale(current)
        )
        #expect(
            try await repository.setEnabled(false, ifCurrent: staleToken)
                == .stale(current)
        )
        #expect(fileSystem.replacementCallCount == replacementCount)
        #expect(try await repository.load() == current)
    }

    @Test func strictDecoderRejectsUntrustedRecordsWithoutRewriting() async {
        let invalidRecords: [(Data, IOSAcceptedTextHistoryRepositoryError)] = [
            (Data(#"{"schemaVersion":1,"schemaVersion":1,"enabled":true,"entries":[]}"#.utf8), .malformedData),
            (Data(#"[]"#.utf8), .topLevelNotObject),
            (Data(#"{"schemaVersion":1,"enabled":true}"#.utf8), .missingRequiredValue(path: "entries")),
            (Data(#"{"schemaVersion":2,"enabled":true,"entries":[]}"#.utf8), .unsupportedSchemaVersion),
            (Data(#"{"schemaVersion":1,"enabled":true,"entries":[],"extra":1}"#.utf8), .unexpectedFields(path: "$")),
            (Data(#"{"schemaVersion":1,"enabled":1,"entries":[]}"#.utf8), .invalidValueType(path: "enabled")),
            (Data(#"{"schemaVersion":1,"enabled":false,"entries":[{"resultID":"00000000-0000-0000-0000-000000000001","text":"Text","createdAtMilliseconds":1000}]}"#.utf8), .invalidValue(path: "entries")),
            (Data(#"{"schemaVersion":1,"enabled":true,"entries":[{"resultID":"00000000-0000-0000-0000-000000000001","text":"","createdAtMilliseconds":1000}]}"#.utf8), .invalidValue(path: "entries[0].text")),
        ]

        for (data, expectedError) in invalidRecords {
            let fileSystem = HistoryFileSystemFake(data: data)
            let repository = makeRepository(fileSystem: fileSystem)
            await expectError(expectedError) {
                _ = try await repository.load()
            }
            #expect(fileSystem.data == data)
            #expect(fileSystem.replacementCallCount == 0)
        }
    }

    @Test func decoderRejectsDuplicateIdentifiersAndNoncanonicalOrdering() async {
        let duplicate = Data(
            #"{"schemaVersion":1,"enabled":true,"entries":[{"resultID":"00000000-0000-0000-0000-000000000001","text":"First","createdAtMilliseconds":2000},{"resultID":"00000000-0000-0000-0000-000000000001","text":"Second","createdAtMilliseconds":1000}]}"#.utf8
        )
        let unordered = Data(
            #"{"schemaVersion":1,"enabled":true,"entries":[{"resultID":"00000000-0000-0000-0000-000000000001","text":"Older","createdAtMilliseconds":1000},{"resultID":"00000000-0000-0000-0000-000000000002","text":"Newer","createdAtMilliseconds":2000}]}"#.utf8
        )

        let duplicateRepository = makeRepository(
            fileSystem: HistoryFileSystemFake(data: duplicate)
        )
        await expectError(.duplicateIdentifier) {
            _ = try await duplicateRepository.load()
        }
        let unorderedRepository = makeRepository(
            fileSystem: HistoryFileSystemFake(data: unordered)
        )
        await expectError(.invalidOrdering) {
            _ = try await unorderedRepository.load()
        }
    }

    @Test func sizeAndIOFailuresAreDistinctAndNeverRewrite() async {
        let sourceTooLarge = HistoryFileSystemFake(
            readError: ProtectedAtomicMetadataFileSystemError.sizeLimitExceeded
        )
        await expectError(.sourceTooLarge) {
            _ = try await makeRepository(fileSystem: sourceTooLarge).load()
        }

        let readFailed = HistoryFileSystemFake(
            readError: HistoryFileSystemFakeError.readFailed
        )
        await expectError(.readFailed) {
            _ = try await makeRepository(fileSystem: readFailed).load()
        }

        let initialData = Data(
            #"{"enabled":true,"entries":[],"schemaVersion":1}"#.utf8
        )
        let writeFailed = HistoryFileSystemFake(
            data: initialData,
            replacementError: HistoryFileSystemFakeError.replacementFailed
        )
        await expectError(.writeFailed) {
            _ = try await makeRepository(fileSystem: writeFailed)
                .append(makeEntry(index: 1))
        }
        #expect(writeFailed.data == initialData)
        #expect(writeFailed.replacementCallCount == 1)
    }

    @Test func actorSerializesConcurrentMutations() async throws {
        let fileSystem = HistoryFileSystemFake(operationDelay: 0.001)
        let repository = makeRepository(fileSystem: fileSystem)

        await withTaskGroup(of: Void.self) { group in
            for index in 1...24 {
                group.addTask {
                    _ = try? await repository.append(
                        makeEntry(index: index)
                    )
                }
            }
        }

        let record = try await repository.load()
        #expect(record.entries.count == 20)
        #expect(Set(record.entries.map(\.resultID)).count == 20)
        #expect(fileSystem.maximumConcurrentOperationCount == 1)
    }

    private var expectedPolicy: ProtectedAtomicMetadataFilePolicy {
        ProtectedAtomicMetadataFilePolicy(
            maximumByteCount: 4 * 1_024 * 1_024,
            fileProtection: .complete,
            excludesFromBackup: true
        )
    }

    private func makeRepository(
        fileSystem: HistoryFileSystemFake
    ) -> IOSAcceptedTextHistoryRepository {
        IOSAcceptedTextHistoryRepository(
            fileURL: URL(
                fileURLWithPath:
                    "/app-private/HoldType/ios-accepted-text-history.json"
            ),
            fileSystem: fileSystem
        )
    }

    private func makeEntry(
        index: Int,
        text: String? = nil
    ) throws -> IOSAcceptedTextHistoryEntry {
        try IOSAcceptedTextHistoryEntry(
            resultID: identifier(index),
            text: text ?? "Accepted text \(index)",
            createdAt: Date(timeIntervalSince1970: TimeInterval(index))
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
        _ expectedError: IOSAcceptedTextHistoryRepositoryError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            Issue.record("Expected \(expectedError)")
        } catch let error as IOSAcceptedTextHistoryRepositoryError {
            #expect(error == expectedError)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    private func requireSendable<Value: Sendable>(_: Value.Type) {}
}

private enum HistoryFileSystemFakeError: Error {
    case readFailed
    case replacementFailed
}

private final class HistoryFileSystemFake:
    ProtectedAtomicMetadataFileSystem,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedData: Data?
    private var storedReadPolicies: [ProtectedAtomicMetadataFilePolicy] = []
    private var storedReplacementPolicies: [ProtectedAtomicMetadataFilePolicy] = []
    private var storedReplacementCallCount = 0
    private var activeOperationCount = 0
    private var storedMaximumConcurrentOperationCount = 0
    private let readError: Error?
    private let replacementError: Error?
    private let operationDelay: TimeInterval

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
    var maximumConcurrentOperationCount: Int {
        lock.withLock { storedMaximumConcurrentOperationCount }
    }

    init(
        data: Data? = nil,
        readError: Error? = nil,
        replacementError: Error? = nil,
        operationDelay: TimeInterval = 0
    ) {
        storedData = data
        self.readError = readError
        self.replacementError = replacementError
        self.operationDelay = operationDelay
    }

    func readFileIfPresent(
        at fileURL: URL,
        policy: ProtectedAtomicMetadataFilePolicy
    ) throws -> Data? {
        beginOperation()
        defer { endOperation() }
        delayIfRequested()
        return try lock.withLock {
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
        beginOperation()
        defer { endOperation() }
        delayIfRequested()
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

    private func beginOperation() {
        lock.withLock {
            activeOperationCount += 1
            storedMaximumConcurrentOperationCount = max(
                storedMaximumConcurrentOperationCount,
                activeOperationCount
            )
        }
    }

    private func endOperation() {
        lock.withLock { activeOperationCount -= 1 }
    }

    private func delayIfRequested() {
        guard operationDelay > 0 else { return }
        Thread.sleep(forTimeInterval: operationDelay)
    }
}
