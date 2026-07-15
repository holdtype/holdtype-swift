import Foundation
import HoldTypeDomain
import Testing
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence
@testable import HoldTypeIOS

@MainActor
struct IOSKeyboardSnapshotPublisherTests {
    @Test func productionContainerQualificationSeedsHistoryLatest() async throws {
        let environment = ProcessInfo.processInfo.environment
        let usesProductionContainers = environment["HOLDTYPE_AUTOMATION"] == "1"
            && environment[
                "HOLDTYPE_AUTOMATION_SEED_KEYBOARD_LATEST"
            ] == "1"
        let temporaryRoot = usesProductionContainers ? nil : FileManager
            .default.temporaryDirectory.appendingPathComponent(
                UUID().uuidString,
                isDirectory: true
            )
        defer {
            if let temporaryRoot {
                try? FileManager.default.removeItem(at: temporaryRoot)
            }
        }

        let applicationSupportDirectoryURL: URL
        let publisherStore: HoldTypeIOS.KeyboardBridgeStore
        let readerStore: KeyboardBridgeStore
        if usesProductionContainers {
            applicationSupportDirectoryURL = try FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            publisherStore = try HoldTypeIOS.KeyboardBridgeStore.appGroup()
            readerStore = try KeyboardBridgeStore.appGroup()
        } else {
            let temporaryRoot = try #require(temporaryRoot)
            applicationSupportDirectoryURL = temporaryRoot
                .appendingPathComponent("app-support", isDirectory: true)
            let bridgeDirectoryURL = temporaryRoot.appendingPathComponent(
                "app-group",
                isDirectory: true
            )
            publisherStore = HoldTypeIOS.KeyboardBridgeStore(
                directoryURL: bridgeDirectoryURL,
                writingOptions: .atomic
            )
            readerStore = KeyboardBridgeStore(
                directoryURL: bridgeDirectoryURL,
                writingOptions: .atomic
            )
        }

        let historyRepository = IOSAcceptedTextHistoryRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL
        )
        if usesProductionContainers {
            let existingHistory = try await historyRepository.load()
            guard existingHistory == .enabledEmpty else {
                Issue.record(
                    "Qualification seeding requires an empty compact History."
                )
                return
            }
        }
        let persistenceOwner = IOSV1ForegroundVoicePersistenceOwner(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL,
            acceptedTextHistoryRepository: historyRepository
        )
        let existingLatest = try await persistenceOwner.loadLatestResult()
        let existingPending = try await persistenceOwner.load()
        guard existingLatest == .absent, existingPending == nil else {
            Issue.record(
                "Qualification seeding requires an empty canonical Voice state."
            )
            return
        }

        let attemptID = try #require(
            UUID(uuidString: "8D6148F8-7D2C-446A-A407-E7DC092B23F4")
        )
        let transcriptID = try #require(
            UUID(uuidString: "58AD706F-0C9F-41DF-A2A8-AF80A97B7467")
        )
        let createdAt = Date(
            timeIntervalSince1970: floor(Date().timeIntervalSince1970)
        )
        let pending = try IOSV1PendingRecording.qualificationFixture(
            attemptID: attemptID,
            outputIntent: .standard,
            phase: .outputDelivery,
            transcriptionID: transcriptID,
            createdAt: createdAt,
            durationMilliseconds: 1_000,
            byteCount: 1_024
        )
        let repository = IOSVoiceStateRepository(
            applicationSupportDirectoryURL: applicationSupportDirectoryURL
        )
        _ = try await repository.installPending(pending.state)
        let preparation = try IOSV1ForegroundVoiceAcceptedOutputPreparation(
            deliveryID: UUID(),
            sessionID: UUID(),
            attemptID: attemptID,
            transcriptID: transcriptID,
            rawAcceptedText: "HoldType canonical History qualification",
            outputIntent: .standard
        )
        let acceptance = try await persistenceOwner.accept(
            preparation,
            expectedPending: IOSV1PendingRecordingExpectation(recording: pending)
        )
        guard case .resultReady(let accepted, _) = acceptance else {
            Issue.record("Expected a canonical accepted result.")
            return
        }

        let publisher = IOSKeyboardSnapshotPublisher(
            store: publisherStore,
            loadHistory: { try await historyRepository.load() }
        )
        #expect(await publisher.publishCurrent())

        let snapshot = try #require(try readerStore.load())
        #expect(snapshot.schemaVersion == 4)
        #expect(snapshot.latest?.resultID == accepted.resultID)
        #expect(snapshot.latest?.text == accepted.acceptedText)
        #expect(snapshot.latestForInsertion() != nil)
    }

    @Test func publishesFirstHistoryEntryWithoutAgeExpiry() async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let oldDate = now.addingTimeInterval(-365 * 24 * 60 * 60)
        let history = try publisherHistory([
            ("Exact line one\n\tExact line two 😀", oldDate),
            ("Older", oldDate.addingTimeInterval(-1)),
        ])
        let source = PublisherSource(history: history)
        let publisher = makePublisher(fixture: fixture, source: source)

        #expect(await publisher.publishCurrent(at: now))
        let snapshot = try #require(try fixture.readerStore.load())

        #expect(snapshot.revision == 1)
        #expect(snapshot.publishedAt == now)
        #expect(snapshot.latest?.resultID == history.entries.first?.resultID)
        #expect(snapshot.latest?.text == history.entries.first?.text)
        #expect(snapshot.latest?.createdAt == oldDate)
        #expect(snapshot.latestForInsertion() != nil)
    }

    @Test func historyChangesReplaceFallbackThenClearIt() async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let initial = try publisherHistory([
            ("Newest", now),
            ("Previous", now.addingTimeInterval(-1)),
        ])
        let source = PublisherSource(history: initial)
        let publisher = makePublisher(fixture: fixture, source: source)

        #expect(await publisher.publishCurrent(at: now))
        #expect(try fixture.readerStore.load()?.latest?.text == "Newest")

        await source.setHistory(
            IOSAcceptedTextHistoryRecord(
                isEnabled: true,
                entries: Array(initial.entries.dropFirst())
            )
        )
        #expect(await publisher.publishCurrent(at: now.addingTimeInterval(1)))
        #expect(try fixture.readerStore.load()?.latest?.text == "Previous")

        await source.setHistory(.enabledEmpty)
        #expect(await publisher.publishCurrent(at: now.addingTimeInterval(2)))
        #expect(try fixture.readerStore.load()?.latest == nil)
    }

    @Test func maximumHistoryTextRemainsInsertable() async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let text = String(
            repeating: "x",
            count: KeyboardBridgeConfiguration.maximumTextUTF8Bytes
        )
        let source = PublisherSource(
            history: try publisherHistory([(text, Date())])
        )
        let publisher = makePublisher(fixture: fixture, source: source)

        #expect(await publisher.publishCurrent())
        #expect(try fixture.readerStore.load()?.latest?.text == text)
    }

    @Test func historyLoadFailureClearsLastKnownSnapshot() async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let source = PublisherSource(
            history: try publisherHistory([("Valid", now)])
        )
        let publisher = makePublisher(fixture: fixture, source: source)

        #expect(await publisher.publishCurrent(at: now))
        #expect(try fixture.readerStore.load()?.latest?.text == "Valid")

        await source.failNextHistoryLoad()
        #expect(!(await publisher.publishCurrent(at: now.addingTimeInterval(1))))
        let cleared = try #require(try fixture.readerStore.load())
        #expect(cleared.revision == 2)
        #expect(cleared.latest == nil)
    }

    @Test func unavailableReadAndWriteBoundariesReturnFalse() async throws {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let source = PublisherSource(history: .enabledEmpty)
        let unavailable = IOSKeyboardSnapshotPublisher(
            store: nil,
            loadHistory: { try await source.loadHistory() }
        )

        #expect(!(await unavailable.publishCurrent(at: now)))
        #expect(await source.historyLoadCount == 0)

        let corrupt = try PublisherStoreFixture()
        defer { corrupt.remove() }
        try corrupt.write(Data("not-json".utf8))
        let corruptPublisher = makePublisher(fixture: corrupt, source: source)
        #expect(await corruptPublisher.publishCurrent(at: now))
        #expect(try corrupt.readerStore.load()?.latest == nil)

        let blockedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: blockedRoot,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: blockedRoot) }
        let blockedDirectory = blockedRoot.appendingPathComponent("not-a-directory")
        try Data("occupied".utf8).write(to: blockedDirectory)
        let blockedPublisher = IOSKeyboardSnapshotPublisher(
            store: HoldTypeIOS.KeyboardBridgeStore(
                directoryURL: blockedDirectory,
                writingOptions: .atomic
            ),
            loadHistory: { try await source.loadHistory() }
        )
        #expect(!(await blockedPublisher.publishCurrent(at: now)))
    }

    @Test func concurrentRequestsSerializeWholePublicationsAndIncreaseRevision()
        async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let source = BlockingPublisherSource(
            history: try publisherHistory([("Latest", now)])
        )
        let publisher = IOSKeyboardSnapshotPublisher(
            store: fixture.publisherStore,
            loadHistory: { await source.loadHistory() }
        )

        let first = Task { await publisher.publishCurrent(at: now) }
        await source.waitUntilFirstHistoryLoadStarts()
        let second = Task {
            await publisher.publishCurrent(at: now.addingTimeInterval(1))
        }
        for _ in 0..<20 { await Task.yield() }

        #expect(await source.historyLoadCount == 1)
        await source.releaseFirstHistoryLoad()
        #expect(await first.value)
        #expect(await second.value)
        #expect(
            await source.events == [
                "history-1-start",
                "history-1-finish",
                "history-2-start",
                "history-2-finish",
            ]
        )
        #expect(try fixture.readerStore.load()?.revision == 2)
    }
}

private enum PublisherTestError: Error {
    case injected
}

private actor PublisherSource {
    private var history: IOSAcceptedTextHistoryRecord
    private var shouldFailNextHistoryLoad = false
    private(set) var historyLoadCount = 0

    init(history: IOSAcceptedTextHistoryRecord) {
        self.history = history
    }

    func loadHistory() throws -> IOSAcceptedTextHistoryRecord {
        historyLoadCount += 1
        if shouldFailNextHistoryLoad {
            shouldFailNextHistoryLoad = false
            throw PublisherTestError.injected
        }
        return history
    }

    func setHistory(_ history: IOSAcceptedTextHistoryRecord) {
        self.history = history
    }

    func failNextHistoryLoad() {
        shouldFailNextHistoryLoad = true
    }
}

private actor BlockingPublisherSource {
    private let history: IOSAcceptedTextHistoryRecord
    private var firstHistoryLoadStarted = false
    private var firstHistoryLoadRelease: CheckedContinuation<Void, Never>?
    private var firstHistoryLoadStartWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var historyLoadCount = 0
    private(set) var events: [String] = []

    init(history: IOSAcceptedTextHistoryRecord) {
        self.history = history
    }

    func loadHistory() async -> IOSAcceptedTextHistoryRecord {
        historyLoadCount += 1
        let call = historyLoadCount
        events.append("history-\(call)-start")

        if call == 1 {
            firstHistoryLoadStarted = true
            firstHistoryLoadStartWaiters.forEach { $0.resume() }
            firstHistoryLoadStartWaiters.removeAll()
            await withCheckedContinuation { continuation in
                firstHistoryLoadRelease = continuation
            }
        }

        events.append("history-\(call)-finish")
        return history
    }

    func waitUntilFirstHistoryLoadStarts() async {
        guard !firstHistoryLoadStarted else { return }
        await withCheckedContinuation { continuation in
            firstHistoryLoadStartWaiters.append(continuation)
        }
    }

    func releaseFirstHistoryLoad() {
        firstHistoryLoadRelease?.resume()
        firstHistoryLoadRelease = nil
    }
}

@MainActor
private struct PublisherStoreFixture {
    let directoryURL: URL
    let publisherStore: HoldTypeIOS.KeyboardBridgeStore
    let readerStore: KeyboardBridgeStore

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        publisherStore = HoldTypeIOS.KeyboardBridgeStore(
            directoryURL: directoryURL,
            writingOptions: .atomic
        )
        readerStore = KeyboardBridgeStore(
            directoryURL: directoryURL,
            writingOptions: .atomic
        )
    }

    func write(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try data.write(to: snapshotURL, options: .atomic)
    }

    func remove() {
        try? FileManager.default.removeItem(at: directoryURL)
    }

    private var snapshotURL: URL {
        directoryURL.appendingPathComponent(
            KeyboardBridgeConfiguration.snapshotFilename,
            isDirectory: false
        )
    }
}

@MainActor
private func makePublisher(
    fixture: PublisherStoreFixture,
    source: PublisherSource
) -> IOSKeyboardSnapshotPublisher {
    IOSKeyboardSnapshotPublisher(
        store: fixture.publisherStore,
        loadHistory: { try await source.loadHistory() }
    )
}

private func publisherHistory(
    _ values: [(String, Date)]
) throws -> IOSAcceptedTextHistoryRecord {
    IOSAcceptedTextHistoryRecord(
        isEnabled: true,
        entries: try values.map { text, createdAt in
            try IOSAcceptedTextHistoryEntry(
                resultID: UUID(),
                text: text,
                createdAt: createdAt
            )
        }
    )
}
