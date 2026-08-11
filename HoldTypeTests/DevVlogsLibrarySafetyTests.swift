import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsLibrarySafetyTests {
    @Test func confirmationRejectsReviewDirectoryAndPreservesSentinel() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let mediaURL = try await fixture.clip(id: clipID)
        let repository = DevVlogsLibraryRepository()
        let snapshot = try await repository.load(rootURL: fixture.root)
        let clip = try #require(snapshot.days.flatMap(\.clips).first { $0.clipID == clipID })
        let confirmation = try #require(DevVlogsDeleteConfirmation(clip: clip))
        let reviewURL = mediaURL.deletingLastPathComponent().appendingPathComponent("review.json")
        try FileManager.default.createDirectory(at: reviewURL, withIntermediateDirectories: false)
        let sentinel = reviewURL.appendingPathComponent("user-sentinel.txt")
        try Data("keep".utf8).write(to: sentinel)

        await #expect(throws: DevVlogsLibraryError.identityChanged) {
            try await repository.delete(
                clipID: clipID,
                displayedClipID: confirmation.displayedClipID,
                resourceIdentity: confirmation.resourceIdentity,
                rootURL: fixture.root
            )
        }

        #expect(FileManager.default.fileExists(atPath: sentinel.path))
        #expect(FileManager.default.fileExists(atPath: mediaURL.path))
    }

    @Test func confirmationRejectsHardLinkAndPreservesBothFiles() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let mediaURL = try await fixture.clip(id: clipID)
        let repository = DevVlogsLibraryRepository()
        let snapshot = try await repository.load(rootURL: fixture.root)
        let clip = try #require(snapshot.days.flatMap(\.clips).first { $0.clipID == clipID })
        let confirmation = try #require(DevVlogsDeleteConfirmation(clip: clip))
        let hardLink = fixture.root.appendingPathComponent("user-hard-link.mov")
        try FileManager.default.linkItem(at: mediaURL, to: hardLink)

        await #expect(throws: DevVlogsLibraryError.identityChanged) {
            try await repository.delete(
                clipID: clipID,
                displayedClipID: confirmation.displayedClipID,
                resourceIdentity: confirmation.resourceIdentity,
                rootURL: fixture.root
            )
        }

        #expect(FileManager.default.fileExists(atPath: mediaURL.path))
        #expect(FileManager.default.fileExists(atPath: hardLink.path))
    }

    @Test func reconstructionUsesRecordedHierarchyAcrossTimezoneChange() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let nearMidnight = Date(timeIntervalSince1970: 1_786_493_400)
        _ = try await fixture.clip(id: clipID, date: nearMidnight)
        var shiftedCalendar = Calendar(identifier: .gregorian)
        shiftedCalendar.timeZone = try #require(TimeZone(identifier: "Pacific/Honolulu"))

        let snapshot = try await DevVlogsLibraryRepository().load(
            rootURL: fixture.root,
            calendar: shiftedCalendar
        )

        let clip = try #require(snapshot.days.flatMap(\.clips).first { $0.clipID == clipID })
        #expect(clip.health == .ready)
        #expect(clip.resourceIdentity != nil)
    }

    @Test func duplicateUUIDsRemainVisibleButInvalidThroughLibraryAndPublish() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let duplicateID = UUID()
        _ = try await fixture.clip(id: duplicateID, date: fixture.date)
        _ = try await fixture.clip(id: duplicateID, date: fixture.date.addingTimeInterval(2))

        let snapshot = try await DevVlogsLibraryRepository().load(rootURL: fixture.root)
        let clips = snapshot.days.flatMap(\.clips)
        #expect(clips.count == 2)
        #expect(Set(clips.map(\.id)).count == 2)
        #expect(clips.allSatisfy { $0.health == .invalid && $0.clipID == nil })

        let publishStore = DevVlogsPublishStore(
            destinationAccessProvider: { DevVlogsCaptureDestinationAccess(url: fixture.root) },
            archiveLoader: { _ in snapshot },
            recipeRepository: DevVlogsBuildRepository(),
            mediaBuilder: UnusedMediaBuilder(),
            ownershipRegistry: DevVlogsClipOwnershipRegistry(),
            now: Date.init,
            buildIDProvider: UUID.init
        )
        publishStore.synchronize(days: snapshot.days)
        #expect(!publishStore.presentation.enables(.createVideo))
        #expect(publishStore.presentation.state.selection?.summary.clipCount == 0)
        #expect(publishStore.presentation.state.selection?.summary.invalidCount == 2)
    }

    @Test func libraryProbeTimeoutAndCancellationAreBoundedAndInvalid() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        _ = try await fixture.clip(id: UUID())
        let repository = DevVlogsLibraryRepository(
            maximumProbeWait: .milliseconds(10),
            mediaProbe: { _ in
                try await Task.sleep(for: .seconds(20))
                return DevVlogsLibraryMediaProbeResult(isPlayable: true, duration: 1, byteCount: 1)
            }
        )
        let timedOut = try await repository.load(rootURL: fixture.root)
        #expect(timedOut.days.flatMap(\.clips).allSatisfy { $0.health == .invalid })

        let cancelling = DevVlogsLibraryRepository(
            maximumProbeWait: .seconds(20),
            mediaProbe: { _ in
                try await Task.sleep(for: .seconds(20))
                return DevVlogsLibraryMediaProbeResult(isPlayable: true, duration: 1, byteCount: 1)
            }
        )
        let task = Task { try await cancelling.load(rootURL: fixture.root) }
        await Task.yield()
        task.cancel()
        await #expect(throws: CancellationError.self) { _ = try await task.value }
    }

    private final class Fixture {
        let root: URL
        let date = Date(timeIntervalSince1970: 1_754_870_400)

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("DevVlogsLibrarySafety-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func clip(id: UUID, date: Date? = nil) async throws -> URL {
            try await DevVlogsMediaFixtureFactory.makeArchivedClip(
                rootURL: root,
                clipID: id,
                createdAt: date ?? self.date,
                appName: "Codex",
                bundleIdentifier: "app.openai.codex"
            )
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }
}

@MainActor
private final class UnusedMediaBuilder: DevVlogsMediaBuilding {
    func build(
        sources: [DevVlogsBuildSource],
        outputURL: URL,
        outputPrepared: @escaping @MainActor (DevVlogsFileIdentity) async throws -> Void,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> DevVlogsBuildOutput {
        throw DevVlogsBuildError.exportFailed
    }

    func validateOutput(at url: URL) async throws -> DevVlogsBuildOutput {
        throw DevVlogsBuildError.outputInvalid
    }
}
