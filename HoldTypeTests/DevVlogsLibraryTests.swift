import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsLibraryTests {
    @Test func reconstructsDaysAppsHealthAndStableOrderWithoutTranscriptData() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let oldestID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let newerID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        let newestID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3))
        let oldDate = Date(timeIntervalSince1970: 1_754_784_000)
        let newDate = Date(timeIntervalSince1970: 1_754_870_400)
        _ = try await fixture.clip(id: oldestID, date: oldDate, app: "Xcode", bundle: "com.apple.dt.Xcode")
        let missingURL = try await fixture.clip(
            id: newerID,
            date: newDate.addingTimeInterval(60),
            app: "Codex",
            bundle: "app.openai.codex"
        )
        _ = try await fixture.clip(
            id: newestID,
            date: newDate.addingTimeInterval(120),
            app: "Xcode",
            bundle: "com.apple.dt.Xcode"
        )
        try FileManager.default.removeItem(at: missingURL)
        try fixture.addCorruptClip(on: newDate, app: "Codex", bundle: "app.openai.codex")

        let snapshot = try await DevVlogsLibraryRepository().load(rootURL: fixture.root)

        #expect(snapshot.days.count == 2)
        #expect(snapshot.days[0].date > snapshot.days[1].date)
        #expect(snapshot.days[0].appGroups.map(\.displayName) == ["Codex", "Xcode"])
        #expect(snapshot.days[0].clips.map(\.health).contains(.missing))
        #expect(snapshot.days[0].clips.map(\.health).contains(.invalid))
        #expect(snapshot.days[0].clips.compactMap(\.clipID).contains(newestID))
        #expect(snapshot.days[1].clips.compactMap(\.clipID) == [oldestID])

        let metadataText = try fixture.allMetadataText()
        #expect(!metadataText.localizedCaseInsensitiveContains("transcript"))
        #expect(!metadataText.contains("dictated"))
    }

    @Test func exclusionPersistsAndDoesNotChangeSourceMedia() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let mediaURL = try await fixture.clip(id: clipID)
        let originalData = try Data(contentsOf: mediaURL)
        let repository = DevVlogsLibraryRepository()
        _ = try await repository.load(rootURL: fixture.root)

        try await repository.setExcluded(true, clipID: clipID, rootURL: fixture.root)
        let reloaded = try await DevVlogsLibraryRepository().load(rootURL: fixture.root)

        #expect(reloaded.days.first?.clips.first(where: { $0.clipID == clipID })?.isExcluded == true)
        #expect(try Data(contentsOf: mediaURL) == originalData)
    }

    @Test func exactDeleteRemovesOnlyValidatedClipAndLeavesSiblingAndExport() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let siblingID = UUID()
        let mediaURL = try await fixture.clip(id: clipID)
        let siblingURL = try await fixture.clip(id: siblingID, date: fixture.date.addingTimeInterval(30))
        let exportURL = try fixture.makeHistoricalExport(on: fixture.date)
        let repository = DevVlogsLibraryRepository()
        _ = try await repository.load(rootURL: fixture.root)

        try await repository.delete(clipID: clipID, rootURL: fixture.root)

        #expect(!FileManager.default.fileExists(atPath: mediaURL.deletingLastPathComponent().path))
        #expect(FileManager.default.fileExists(atPath: siblingURL.path))
        #expect(FileManager.default.fileExists(atPath: exportURL.path))
    }

    @Test func deleteFailsClosedForReplacementMissingCorruptAndUnknownChildren() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let replacementID = UUID()
        let replacementURL = try await fixture.clip(id: replacementID)
        let unknownChildID = UUID()
        let unknownChildURL = try await fixture.clip(
            id: unknownChildID,
            date: fixture.date.addingTimeInterval(20)
        )
        let repository = DevVlogsLibraryRepository()
        _ = try await repository.load(rootURL: fixture.root)

        try FileManager.default.removeItem(at: replacementURL)
        try Data("replacement".utf8).write(to: replacementURL)
        await #expect(throws: DevVlogsLibraryError.identityChanged) {
            try await repository.delete(clipID: replacementID, rootURL: fixture.root)
        }

        try Data("user sibling".utf8).write(
            to: unknownChildURL.deletingLastPathComponent().appendingPathComponent("notes.txt")
        )
        await #expect(throws: DevVlogsLibraryError.identityChanged) {
            try await repository.delete(clipID: unknownChildID, rootURL: fixture.root)
        }
        #expect(FileManager.default.fileExists(atPath: unknownChildURL.path))
        await #expect(throws: DevVlogsLibraryError.clipNotOwned) {
            try await repository.delete(clipID: UUID(), rootURL: fixture.root)
        }
    }

    @Test func activeFinalizingRecoveringAndBuildOwnedClipsRejectDelete() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        _ = try await fixture.clip(id: clipID)
        let repository = DevVlogsLibraryRepository()
        let registry = DevVlogsClipOwnershipRegistry()
        let store = DevVlogsLibraryStore(
            destinationAccessProvider: { DevVlogsCaptureDestinationAccess(url: fixture.root) },
            repository: repository,
            ownershipRegistry: registry
        )
        await store.refresh()
        let clip = try #require(store.snapshot.days.first?.clips.first)
        let confirmation = try #require(DevVlogsDeleteConfirmation(clip: clip))

        for operation in [
            DevVlogsClipOperation.active,
            .finalizing,
            .recovering,
            .building
        ] {
            let lease = try #require(registry.acquire(clipIDs: [clipID], operation: operation))
            #expect(store.canDelete(clip) == false)
            await #expect(throws: DevVlogsLibraryError.clipBusy) {
                try await store.delete(confirmation)
            }
            lease.release()
        }
        #expect(FileManager.default.fileExists(atPath: try #require(clip.mediaURL).path))
        #expect(confirmation.scope.contains("Dictation audio"))
        #expect(confirmation.scope.contains("completed videos"))
    }

    private final class Fixture {
        let root: URL
        let date = Date(timeIntervalSince1970: 1_754_870_400)

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("DevVlogsLibraryTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func clip(
            id: UUID,
            date: Date? = nil,
            app: String = "Codex",
            bundle: String = "app.openai.codex"
        ) async throws -> URL {
            try await DevVlogsMediaFixtureFactory.makeArchivedClip(
                rootURL: root,
                clipID: id,
                createdAt: date ?? self.date,
                appName: app,
                bundleIdentifier: bundle
            )
        }

        func addCorruptClip(on date: Date, app: String, bundle: String) throws {
            let directory = root
                .appendingPathComponent(DevVlogsArchiveNaming.yearKey(for: date))
                .appendingPathComponent(DevVlogsArchiveNaming.dayKey(for: date))
                .appendingPathComponent("apps")
                .appendingPathComponent(DevVlogsArchiveNaming.appFolder(displayName: app, bundleIdentifier: bundle))
                .appendingPathComponent("clips/broken", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data("{}".utf8).write(to: directory.appendingPathComponent("metadata.json"))
        }

        func makeHistoricalExport(on date: Date) throws -> URL {
            let output = root
                .appendingPathComponent(DevVlogsArchiveNaming.yearKey(for: date))
                .appendingPathComponent(DevVlogsArchiveNaming.dayKey(for: date))
                .appendingPathComponent("builds/historical/output.mov")
            try FileManager.default.createDirectory(
                at: output.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data("export".utf8).write(to: output)
            return output
        }

        func allMetadataText() throws -> String {
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            let urls = (enumerator?.allObjects as? [URL]) ?? []
            return try urls.filter { $0.lastPathComponent == "metadata.json" }
                .map { try String(contentsOf: $0) }
                .joined(separator: "\n")
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
