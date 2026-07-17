import Foundation
import HoldTypeDomain
import Testing
@testable import HoldTypePersistence

@Suite(.serialized)
struct IOSAcceptedAudioCacheTests {
    @Test func protectedRetentionUsesTheFrozenRecordingLimit() {
        let oneMinute = RecordingDurationLimit(minutes: 1)
        let fifteenMinutes = RecordingDurationLimit(minutes: 15)

        #expect(
            IOSAcceptedAudioRetention.resolved(
                requested: .recordingCachePolicy,
                finalizedDurationMilliseconds: 59_500,
                recordingDurationLimit: oneMinute
            ) == .savedFiveMinute
        )
        #expect(
            IOSAcceptedAudioRetention.resolved(
                requested: .recordingCachePolicy,
                finalizedDurationMilliseconds: 59_499,
                recordingDurationLimit: oneMinute
            ) == .recordingCachePolicy
        )
        #expect(
            IOSAcceptedAudioRetention.resolved(
                requested: .recordingCachePolicy,
                finalizedDurationMilliseconds: 899_500,
                recordingDurationLimit: fifteenMinutes
            ) == .savedFiveMinute
        )
    }

    @Test func cacheIsOffByDefaultPolicyAndMissingFilesStayUnavailable()
        async throws {
        let fixture = AudioCacheFixture()
        let policy = IOSAppSettings.defaultRecordingCachePolicy

        #expect(policy == .deleteImmediately)

        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.first
            ) == nil
        )
        #expect(
            try await fixture.cache.retainAcceptedAudio(
                Data([1, 2, 3]),
                resultID: CacheIDs.first,
                fileExtension: "m4a",
                createdAt: CacheDates.first,
                policy: policy
            ) == nil
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.first
            ) == nil
        )
    }

    @Test func enabledCacheStoresAcceptedAudioByResultIdentifier()
        async throws {
        let fixture = AudioCacheFixture()

        let url = try #require(
            try await fixture.cache.retainAcceptedAudio(
                Data([1, 2, 3]),
                resultID: CacheIDs.first,
                fileExtension: "m4a",
                createdAt: CacheDates.first,
                policy: .keepLast(10)
            )
        )

        #expect(try Data(contentsOf: url) == Data([1, 2, 3]))
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.first
            ) == url
        )
        #expect(
            try await fixture.cache.retainAcceptedAudio(
                Data([1, 2, 3]),
                resultID: CacheIDs.first,
                fileExtension: "m4a",
                createdAt: CacheDates.first,
                policy: .keepLast(10)
            ) == url
        )
    }

    @Test func boundedReconciliationIsIdempotentAndPreservesUnmanagedFiles()
        async throws {
        let fixture = AudioCacheFixture()
        let unmanagedURL = fixture.directoryURL.appendingPathComponent(
            "operator-note.txt"
        )

        _ = try await fixture.cache.retainAcceptedAudio(
            Data([1]),
            resultID: CacheIDs.first,
            fileExtension: "m4a",
            createdAt: CacheDates.first,
            policy: .unlimited
        )
        try Data("keep".utf8).write(to: unmanagedURL)
        _ = try await fixture.cache.retainAcceptedAudio(
            Data([2]),
            resultID: CacheIDs.second,
            fileExtension: "wav",
            createdAt: CacheDates.second,
            policy: .unlimited
        )
        _ = try await fixture.cache.retainAcceptedAudio(
            Data([3]),
            resultID: CacheIDs.third,
            fileExtension: "m4a",
            createdAt: CacheDates.third,
            policy: .unlimited
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.first
            ) != nil
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.second
            ) != nil
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.third
            ) != nil
        )

        try await fixture.cache.reconcile(policy: .keepLast(2))
        try await fixture.cache.reconcile(policy: .keepLast(2))

        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.first
            ) == nil
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.second
            ) != nil
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.third
            ) != nil
        )
        #expect(try Data(contentsOf: unmanagedURL) == Data("keep".utf8))

        try await fixture.cache.reconcile(policy: .deleteImmediately)
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.second
            ) == nil
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.third
            ) == nil
        )
        #expect(try Data(contentsOf: unmanagedURL) == Data("keep".utf8))
    }

    @Test func fiveMinuteSavedAudioSurvivesDefaultPolicyAndRelaunch()
        async throws {
        let fixture = AudioCacheFixture()

        let retainedURL = try #require(
            try await fixture.cache.retainAcceptedAudio(
                Data([4, 5, 6]),
                resultID: CacheIDs.first,
                fileExtension: "m4a",
                createdAt: CacheDates.first,
                policy: .deleteImmediately,
                retention: .savedFiveMinute
            )
        )
        #expect(retainedURL.lastPathComponent.hasPrefix("saved-v1-"))

        try await fixture.cache.reconcile(policy: .deleteImmediately)
        let relaunched = IOSAcceptedAudioCache(
            directoryURL: fixture.directoryURL
        )
        let saved = try await relaunched.savedRecordings()

        #expect(
            saved == [
                IOSSavedAcceptedRecording(
                    resultID: CacheIDs.first,
                    createdAt: CacheDates.first
                ),
            ]
        )
        #expect(
            try await relaunched.playableAudioFileURL(
                resultID: CacheIDs.first,
                policy: .deleteImmediately
            ) == retainedURL
        )
    }

    @Test func savedRetentionIsIndependentAndBoundedToNewestFive()
        async throws {
        let fixture = AudioCacheFixture()
        let identifiers = (1...6).map { index in
            UUID(
                uuidString: String(
                    format: "40000000-0000-0000-0000-%012d",
                    index
                )
            )!
        }

        for (offset, identifier) in identifiers.enumerated() {
            _ = try await fixture.cache.retainAcceptedAudio(
                Data([UInt8(offset + 1)]),
                resultID: identifier,
                fileExtension: "m4a",
                createdAt: Date(
                    timeIntervalSince1970: 1_700_001_000
                        + Double(offset)
                ),
                policy: .deleteImmediately,
                retention: .savedFiveMinute
            )
        }

        let saved = try await fixture.cache.savedRecordings()
        #expect(IOSAcceptedAudioCache.maximumSavedRecordingCount == 5)
        #expect(
            saved.map(\.resultID)
                == Array(Array(identifiers.dropFirst()).reversed())
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: identifiers[0]
            ) == nil
        )
    }

    @Test func exactSavedDiscardRejectsStaleSnapshotAndLeavesOrdinaryPolicyAlone()
        async throws {
        let fixture = AudioCacheFixture()
        _ = try await fixture.cache.retainAcceptedAudio(
            Data([7]),
            resultID: CacheIDs.first,
            fileExtension: "m4a",
            createdAt: CacheDates.first,
            policy: .deleteImmediately,
            retention: .savedFiveMinute
        )
        _ = try await fixture.cache.retainAcceptedAudio(
            Data([8]),
            resultID: CacheIDs.second,
            fileExtension: "m4a",
            createdAt: CacheDates.second,
            policy: .unlimited
        )
        let exact = try #require(
            try await fixture.cache.savedRecordings().first
        )
        let stale = IOSSavedAcceptedRecording(
            resultID: exact.resultID,
            createdAt: exact.createdAt.addingTimeInterval(1)
        )

        await #expect(
            throws: IOSAcceptedAudioCacheError.staleSavedRecording
        ) {
            try await fixture.cache.discardSavedRecording(ifCurrent: stale)
        }
        #expect(
            try await fixture.cache.discardSavedRecording(ifCurrent: exact)
                == .discarded
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.first
            ) == nil
        )
        #expect(
            await fixture.cache.cachedAudioFileURLIfAvailable(
                resultID: CacheIDs.second
            ) != nil
        )
    }
}

private final class AudioCacheFixture: @unchecked Sendable {
    let directoryURL: URL
    let cache: IOSAcceptedAudioCache

    init() {
        directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "ios-accepted-audio-cache-tests-\(UUID().uuidString)",
                isDirectory: true
            )
        cache = IOSAcceptedAudioCache(directoryURL: directoryURL)
    }

    deinit {
        try? FileManager.default.removeItem(at: directoryURL)
    }
}

private enum CacheIDs {
    static let first = UUID(
        uuidString: "10000000-0000-0000-0000-000000000001"
    )!
    static let second = UUID(
        uuidString: "20000000-0000-0000-0000-000000000002"
    )!
    static let third = UUID(
        uuidString: "30000000-0000-0000-0000-000000000003"
    )!
}

private enum CacheDates {
    static let first = Date(timeIntervalSince1970: 1_700_000_001)
    static let second = Date(timeIntervalSince1970: 1_700_000_002)
    static let third = Date(timeIntervalSince1970: 1_700_000_003)
}
