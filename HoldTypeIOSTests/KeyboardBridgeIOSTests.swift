//
//  KeyboardBridgeIOSTests.swift
//  HoldTypeIOSTests
//
//  Created by Codex on 7/9/26.
//

import Foundation
import Testing

struct KeyboardBridgeIOSTests {

    @Test func itemPreservesExactTextAndRejectsUnsafePayloads() throws {
        let createdAt = Date(timeIntervalSince1970: 1_750_000_000)
        let exactText = "  First line\n\tSecond line 😀  "
        let item = try KeyboardBridgeItem.latest(
            resultID: UUID(),
            text: exactText,
            createdAt: createdAt
        )

        #expect(item.text == exactText)
        #expect(
            item.expiresAt == createdAt.addingTimeInterval(
                KeyboardBridgeConfiguration.latestLifetime
            )
        )
        #expect(throws: KeyboardBridgeItem.ValidationError.emptyText) {
            try KeyboardBridgeItem.latest(
                resultID: UUID(),
                text: " \n\t ",
                createdAt: createdAt
            )
        }
        #expect(
            throws: KeyboardBridgeItem.ValidationError.textTooLarge(
                maximumUTF8Bytes: KeyboardBridgeConfiguration.maximumTextUTF8Bytes
            )
        ) {
            try KeyboardBridgeItem.latest(
                resultID: UUID(),
                text: String(
                    repeating: "a",
                    count: KeyboardBridgeConfiguration.maximumTextUTF8Bytes + 1
                ),
                createdAt: createdAt
            )
        }
        #expect(throws: KeyboardBridgeItem.ValidationError.unsafeControlScalar(0)) {
            try KeyboardBridgeItem.latest(
                resultID: UUID(),
                text: "unsafe\u{0000}text",
                createdAt: createdAt
            )
        }
    }

    @Test func storeRoundTripsProjectionAndExpiryBoundariesAreExclusive() throws {
        let fixture = try BridgeStoreFixture()
        defer { fixture.remove() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let latest = try KeyboardBridgeItem.latest(
            resultID: UUID(),
            text: "Latest exact text",
            createdAt: now
        )
        let newerRecent = try KeyboardBridgeItem.recent(
            resultID: UUID(),
            text: "Newer",
            createdAt: now.addingTimeInterval(-60)
        )
        let olderRecent = try KeyboardBridgeItem.recent(
            resultID: UUID(),
            text: "Older",
            createdAt: now.addingTimeInterval(-120)
        )
        let snapshot = try KeyboardBridgeSnapshot(
            revision: 42,
            publishedAt: now,
            historyEnabled: true,
            latest: latest,
            recentResults: [newerRecent, olderRecent]
        )

        try fixture.store.save(snapshot)
        let loaded = try #require(try fixture.store.load())

        #expect(loaded == snapshot)
        #expect(
            loaded.latestForInsertion(
                at: latest.expiresAt.addingTimeInterval(-0.001)
            ) == latest
        )
        #expect(loaded.latestForInsertion(at: latest.expiresAt) == nil)
        #expect(
            loaded.validRecentResults(at: olderRecent.expiresAt).map(\.resultID) == [
                newerRecent.resultID
            ]
        )
        #expect(loaded.validRecentResults(at: newerRecent.expiresAt).isEmpty)
    }

    @Test func snapshotRejectsInvalidHistoryShapeAndExtendedLifetimes() throws {
        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let recentID = UUID()
        let recent = try KeyboardBridgeItem.recent(
            resultID: recentID,
            text: "Recent",
            createdAt: now
        )
        let older = try KeyboardBridgeItem.recent(
            resultID: UUID(),
            text: "Older",
            createdAt: now.addingTimeInterval(-60)
        )
        let extendedLatest = try KeyboardBridgeItem(
            resultID: UUID(),
            text: "Latest",
            createdAt: now,
            expiresAt: now.addingTimeInterval(
                KeyboardBridgeConfiguration.latestLifetime + 1
            )
        )
        let extendedRecent = try KeyboardBridgeItem(
            resultID: UUID(),
            text: "Extended recent",
            createdAt: now,
            expiresAt: now.addingTimeInterval(
                KeyboardBridgeConfiguration.recentResultLifetime + 1
            )
        )

        #expect(throws: KeyboardBridgeSnapshot.ValidationError.invalidLatestLifetime) {
            try KeyboardBridgeSnapshot(
                revision: 1,
                historyEnabled: true,
                latest: extendedLatest,
                recentResults: []
            )
        }
        #expect(
            throws: KeyboardBridgeSnapshot.ValidationError.invalidRecentResultLifetime(
                extendedRecent.resultID
            )
        ) {
            try KeyboardBridgeSnapshot(
                revision: 1,
                historyEnabled: true,
                latest: nil,
                recentResults: [extendedRecent]
            )
        }
        #expect(
            throws: KeyboardBridgeSnapshot.ValidationError.historyDisabledWithRecentResults
        ) {
            try KeyboardBridgeSnapshot(
                revision: 1,
                historyEnabled: false,
                latest: nil,
                recentResults: [recent]
            )
        }
        #expect(
            throws: KeyboardBridgeSnapshot.ValidationError.duplicateRecentResult(recentID)
        ) {
            try KeyboardBridgeSnapshot(
                revision: 1,
                historyEnabled: true,
                latest: nil,
                recentResults: [recent, recent]
            )
        }
        #expect(throws: KeyboardBridgeSnapshot.ValidationError.recentResultsNotNewestFirst) {
            try KeyboardBridgeSnapshot(
                revision: 1,
                historyEnabled: true,
                latest: nil,
                recentResults: [older, recent]
            )
        }

        let tooMany = try (0...KeyboardBridgeConfiguration.maximumRecentResults).map {
            try KeyboardBridgeItem.recent(
                resultID: UUID(),
                text: "Item \($0)",
                createdAt: now.addingTimeInterval(TimeInterval(-$0))
            )
        }
        #expect(
            throws: KeyboardBridgeSnapshot.ValidationError.tooManyRecentResults(
                maximum: KeyboardBridgeConfiguration.maximumRecentResults
            )
        ) {
            try KeyboardBridgeSnapshot(
                revision: 1,
                historyEnabled: true,
                latest: nil,
                recentResults: tooMany
            )
        }

        let disabled = try KeyboardBridgeSnapshot(
            revision: 1,
            historyEnabled: false,
            latest: nil,
            recentResults: []
        )
        #expect(disabled.validRecentResults(at: now).isEmpty)
    }

    @Test func missingCorruptOversizedAndIncompatibleFilesStayDistinct() throws {
        let fixture = try BridgeStoreFixture()
        defer { fixture.remove() }

        #expect(try fixture.store.load() == nil)

        try fixture.write(Data("not-json".utf8))
        #expect(throws: KeyboardBridgeStoreError.snapshotDecodeFailed) {
            try fixture.store.load()
        }

        try fixture.write(
            Data(
                repeating: 0x20,
                count: KeyboardBridgeConfiguration.maximumSnapshotBytes + 1
            )
        )
        #expect(
            throws: KeyboardBridgeStoreError.snapshotTooLarge(
                maximumBytes: KeyboardBridgeConfiguration.maximumSnapshotBytes,
                actualBytes: KeyboardBridgeConfiguration.maximumSnapshotBytes + 1
            )
        ) {
            try fixture.store.load()
        }

        try fixture.write(Data("{\"revision\":3,\"schemaVersion\":99}".utf8))
        #expect(
            throws: KeyboardBridgeStoreError.incompatibleSchemaVersion(
                found: 99,
                supported: KeyboardBridgeSnapshot.currentSchemaVersion
            )
        ) {
            try fixture.store.load()
        }
    }

    @Test func firstV2SaveReplacesV1AndRevisionsIncreaseStrictly() throws {
        let fixture = try BridgeStoreFixture()
        defer { fixture.remove() }

        try fixture.write(Data("{\"revision\":41,\"schemaVersion\":1}".utf8))
        #expect(try fixture.store.nextRevision() == 42)

        let snapshot = try KeyboardBridgeSnapshot(
            revision: 42,
            publishedAt: Date(timeIntervalSince1970: 1_750_000_000),
            historyEnabled: false,
            latest: nil,
            recentResults: []
        )
        try fixture.store.save(snapshot)

        #expect(try fixture.store.load() == snapshot)
        #expect(try fixture.store.nextRevision() == 43)
        #expect(
            throws: KeyboardBridgeStoreError.nonIncreasingRevision(
                current: 42,
                proposed: 42
            )
        ) {
            try fixture.store.save(snapshot)
        }

        let object = try #require(
            JSONSerialization.jsonObject(with: fixture.data()) as? [String: Any]
        )
        #expect(object["schemaVersion"] as? Int == 2)
        #expect(object["phase"] == nil)
    }

    @Test func canonicalWriterRepairsCorruptCacheButNotFutureSchema()
        throws {
        let fixture = try BridgeStoreFixture()
        defer { fixture.remove() }
        let replacement = try KeyboardBridgeSnapshot(
            revision: 1,
            publishedAt: Date(timeIntervalSince1970: 1_750_000_000),
            historyEnabled: false,
            latest: nil,
            recentResults: []
        )

        try fixture.write(Data("not-json".utf8))
        #expect(try fixture.store.nextRevision() == 1)
        try fixture.store.save(replacement)
        #expect(try fixture.store.load() == replacement)

        try fixture.write(
            Data(
                repeating: 0x20,
                count: KeyboardBridgeConfiguration.maximumSnapshotBytes + 1
            )
        )
        #expect(try fixture.store.nextRevision() == 1)
        try fixture.store.save(replacement)
        #expect(try fixture.store.load() == replacement)

        try fixture.write(Data("{\"revision\":3,\"schemaVersion\":99}".utf8))
        #expect(
            throws: KeyboardBridgeStoreError.incompatibleSchemaVersion(
                found: 99,
                supported: KeyboardBridgeSnapshot.currentSchemaVersion
            )
        ) {
            try fixture.store.save(replacement)
        }
    }
}

private struct BridgeStoreFixture {
    let directoryURL: URL
    let store: KeyboardBridgeStore

    init() throws {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        store = KeyboardBridgeStore(
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

    func data() throws -> Data {
        try Data(contentsOf: snapshotURL)
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
