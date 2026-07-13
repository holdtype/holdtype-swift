import Foundation
import Testing
@_spi(HoldTypeIOSCore) @testable import HoldTypePersistence
@testable import HoldTypeIOS

@MainActor
struct IOSKeyboardSnapshotPublisherTests {
    @Test func unqualifiedProductionGateIsClosedWithoutDebugOptIn() {
        #expect(!KeyboardBridgeConfiguration.productionProjectionIsQualified)
        #expect(
            !IOSKeyboardSnapshotProductionGate.isEnabled(environment: [:])
        )
        #if DEBUG
        #expect(
            IOSKeyboardSnapshotProductionGate.isEnabled(
                environment: [
                    IOSKeyboardSnapshotProductionGate.debugEnvironmentKey: "1"
                ]
            )
        )
        #else
        #expect(
            !IOSKeyboardSnapshotProductionGate.isEnabled(
                environment: [
                    IOSKeyboardSnapshotProductionGate.debugEnvironmentKey: "1"
                ]
            )
        )
        #endif
    }

    @Test func publishesExactLatestAndBoundedOrderedRecentProjection()
        async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let latest = try publisherLatestRecord(
            text: "Exact line one\n\tExact line two 😀",
            createdAt: now.addingTimeInterval(-30)
        )
        let offsets: [TimeInterval] = [
            -60,
            -300,
            -120,
            -180,
            -240,
            -360,
            -KeyboardBridgeConfiguration.recentResultLifetime,
            -(KeyboardBridgeConfiguration.recentResultLifetime + 1),
        ]
        let entries = try offsets.enumerated().map { index, offset in
            try publisherHistoryEntry(
                text: "Exact recent \(index)\nsecond line",
                createdAt: now.addingTimeInterval(offset)
            )
        }
        let history = IOSAcceptedTextHistoryRecord(
            isEnabled: true,
            entries: entries
        )
        let source = PublisherSource(
            latest: .resultReady(latest),
            history: history
        )
        let publisher = makePublisher(fixture: fixture, source: source)

        #expect(await publisher.publishCurrent(at: now))
        let snapshot = try #require(try fixture.readerStore.load())
        let expectedRecent = entries
            .filter {
                $0.createdAt.addingTimeInterval(
                    KeyboardBridgeConfiguration.recentResultLifetime
                ) > now
            }
            .sorted(by: publisherHistoryOrder)
            .prefix(KeyboardBridgeConfiguration.maximumRecentResults)

        #expect(snapshot.revision == 1)
        #expect(snapshot.publishedAt == now)
        #expect(snapshot.historyEnabled)
        #expect(snapshot.latest?.resultID == latest.resultID)
        #expect(snapshot.latest?.text == latest.acceptedText)
        #expect(snapshot.latest?.createdAt == latest.createdAt)
        #expect(
            snapshot.latest?.expiresAt == latest.createdAt.addingTimeInterval(
                KeyboardBridgeConfiguration.latestLifetime
            )
        )
        #expect(
            snapshot.recentResults.map(\.resultID)
                == expectedRecent.map(\.resultID)
        )
        #expect(
            snapshot.recentResults.map(\.text)
                == expectedRecent.map(\.text)
        )
    }

    @Test func disabledHistoryStaysEmptyAndRepublishingDoesNotExtendLatest()
        async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let latest = try publisherLatestRecord(
            text: "Already expired",
            createdAt: now.addingTimeInterval(
                -(KeyboardBridgeConfiguration.latestLifetime + 1)
            )
        )
        let hiddenEntry = try publisherHistoryEntry(
            text: "Must not be projected",
            createdAt: now.addingTimeInterval(-60)
        )
        let source = PublisherSource(
            latest: .resultReady(latest),
            history: IOSAcceptedTextHistoryRecord(
                isEnabled: false,
                entries: [hiddenEntry]
            )
        )
        let publisher = makePublisher(fixture: fixture, source: source)

        #expect(await publisher.publishCurrent(at: now))
        let snapshot = try #require(try fixture.readerStore.load())

        #expect(!snapshot.historyEnabled)
        #expect(snapshot.recentResults.isEmpty)
        #expect(
            snapshot.latest?.expiresAt == latest.createdAt.addingTimeInterval(
                KeyboardBridgeConfiguration.latestLifetime
            )
        )
        #expect(snapshot.latestForInsertion(at: now) == nil)
    }

    @Test func loadOrValidationFailurePreservesLastValidSnapshot()
        async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let source = PublisherSource(
            latest: .resultReady(
                try publisherLatestRecord(text: "Valid", createdAt: now)
            ),
            history: .enabledEmpty
        )
        let publisher = makePublisher(fixture: fixture, source: source)

        #expect(await publisher.publishCurrent(at: now))
        let lastValid = try #require(try fixture.readerStore.load())

        let oversized = try publisherLatestRecord(
            text: String(
                repeating: "x",
                count: KeyboardBridgeConfiguration.maximumTextUTF8Bytes + 1
            ),
            createdAt: now
        )
        await source.setLatest(.resultReady(oversized))
        #expect(!(await publisher.publishCurrent(at: now.addingTimeInterval(1))))
        #expect(try fixture.readerStore.load() == lastValid)

        await source.failNextLatestLoad()
        #expect(!(await publisher.publishCurrent(at: now.addingTimeInterval(2))))
        #expect(try fixture.readerStore.load() == lastValid)
    }

    @Test func unavailableReadAndWriteBoundariesReturnFalse() async throws {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let source = PublisherSource(
            latest: .absent,
            history: .enabledEmpty
        )
        let unavailable = IOSKeyboardSnapshotPublisher(
            store: nil,
            loadLatest: { try await source.loadLatest() },
            loadHistory: { await source.loadHistory() }
        )

        #expect(!(await unavailable.publishCurrent(at: now)))
        #expect(await source.latestLoadCount == 0)
        #expect(await source.historyLoadCount == 0)

        let corrupt = try PublisherStoreFixture()
        defer { corrupt.remove() }
        try corrupt.write(Data("not-json".utf8))
        let corruptPublisher = makePublisher(fixture: corrupt, source: source)
        #expect(await corruptPublisher.publishCurrent(at: now))
        let repaired = try #require(try corrupt.readerStore.load())
        #expect(repaired.revision == 1)
        #expect(repaired.latest == nil)

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
            loadLatest: { try await source.loadLatest() },
            loadHistory: { await source.loadHistory() }
        )
        #expect(!(await blockedPublisher.publishCurrent(at: now)))
    }

    @Test func concurrentRequestsSerializeWholePublicationsAndIncreaseRevision()
        async throws {
        let fixture = try PublisherStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let source = BlockingPublisherSource(
            latest: .resultReady(
                try publisherLatestRecord(text: "Latest", createdAt: now)
            ),
            history: .enabledEmpty
        )
        let publisher = IOSKeyboardSnapshotPublisher(
            store: fixture.publisherStore,
            loadLatest: { await source.loadLatest() },
            loadHistory: { await source.loadHistory() }
        )

        let first = Task {
            await publisher.publishCurrent(at: now)
        }
        await source.waitUntilFirstLatestLoadStarts()

        let second = Task {
            await publisher.publishCurrent(at: now.addingTimeInterval(1))
        }
        for _ in 0..<20 {
            await Task.yield()
        }

        #expect(await source.latestLoadCount == 1)
        await source.releaseFirstLatestLoad()
        #expect(await first.value)
        #expect(await second.value)

        #expect(
            await source.events == [
                "latest-1-start",
                "latest-1-finish",
                "history-1",
                "latest-2-start",
                "latest-2-finish",
                "history-2",
            ]
        )
        let snapshot = try #require(try fixture.readerStore.load())
        #expect(snapshot.revision == 2)
        #expect(snapshot.publishedAt == now.addingTimeInterval(1))
    }
}

private enum PublisherTestError: Error {
    case injected
}

private actor PublisherSource {
    private var latest: IOSV1ForegroundVoiceLatestResultObservation
    private let history: IOSAcceptedTextHistoryRecord
    private var shouldFailNextLatestLoad = false
    private(set) var latestLoadCount = 0
    private(set) var historyLoadCount = 0

    init(
        latest: IOSV1ForegroundVoiceLatestResultObservation,
        history: IOSAcceptedTextHistoryRecord
    ) {
        self.latest = latest
        self.history = history
    }

    func loadLatest() throws -> IOSV1ForegroundVoiceLatestResultObservation {
        latestLoadCount += 1
        if shouldFailNextLatestLoad {
            shouldFailNextLatestLoad = false
            throw PublisherTestError.injected
        }
        return latest
    }

    func loadHistory() -> IOSAcceptedTextHistoryRecord {
        historyLoadCount += 1
        return history
    }

    func setLatest(_ latest: IOSV1ForegroundVoiceLatestResultObservation) {
        self.latest = latest
    }

    func failNextLatestLoad() {
        shouldFailNextLatestLoad = true
    }
}

private actor BlockingPublisherSource {
    private let latest: IOSV1ForegroundVoiceLatestResultObservation
    private let history: IOSAcceptedTextHistoryRecord
    private var firstLatestLoadStarted = false
    private var firstLatestLoadRelease: CheckedContinuation<Void, Never>?
    private var firstLatestLoadStartWaiters: [CheckedContinuation<Void, Never>] = []
    private(set) var latestLoadCount = 0
    private var historyLoadCount = 0
    private(set) var events: [String] = []

    init(
        latest: IOSV1ForegroundVoiceLatestResultObservation,
        history: IOSAcceptedTextHistoryRecord
    ) {
        self.latest = latest
        self.history = history
    }

    func loadLatest() async -> IOSV1ForegroundVoiceLatestResultObservation {
        latestLoadCount += 1
        let call = latestLoadCount
        events.append("latest-\(call)-start")

        if call == 1 {
            firstLatestLoadStarted = true
            firstLatestLoadStartWaiters.forEach { $0.resume() }
            firstLatestLoadStartWaiters.removeAll()
            await withCheckedContinuation { continuation in
                firstLatestLoadRelease = continuation
            }
        }

        events.append("latest-\(call)-finish")
        return latest
    }

    func loadHistory() -> IOSAcceptedTextHistoryRecord {
        historyLoadCount += 1
        events.append("history-\(historyLoadCount)")
        return history
    }

    func waitUntilFirstLatestLoadStarts() async {
        guard !firstLatestLoadStarted else {
            return
        }
        await withCheckedContinuation { continuation in
            firstLatestLoadStartWaiters.append(continuation)
        }
    }

    func releaseFirstLatestLoad() {
        firstLatestLoadRelease?.resume()
        firstLatestLoadRelease = nil
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
        loadLatest: { try await source.loadLatest() },
        loadHistory: { await source.loadHistory() }
    )
}

private func publisherLatestRecord(
    text: String,
    createdAt: Date
) throws -> IOSV1AcceptedOutputDeliveryRecord {
    try IOSV1AcceptedOutputDeliveryRecord(
        resultID: UUID(),
        sourceAttemptID: UUID(),
        acceptedText: text,
        createdAt: createdAt
    )
}

private func publisherHistoryEntry(
    text: String,
    createdAt: Date
) throws -> IOSAcceptedTextHistoryEntry {
    try IOSAcceptedTextHistoryEntry(
        resultID: UUID(),
        text: text,
        createdAt: createdAt
    )
}

private func publisherHistoryOrder(
    _ lhs: IOSAcceptedTextHistoryEntry,
    _ rhs: IOSAcceptedTextHistoryEntry
) -> Bool {
    if lhs.createdAt != rhs.createdAt {
        return lhs.createdAt > rhs.createdAt
    }
    return lhs.resultID.uuidString < rhs.resultID.uuidString
}
