import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsPublishStoreTests {
    @Test func defaultsToReadyNonexcludedClipsAndAllowsSelectionAndReorder() throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = UUID()
        let second = UUID()
        let excluded = UUID()
        let missing = UUID()
        let day = fixture.day(
            clips: [
                fixture.clip(id: second, offset: 20),
                fixture.clip(id: missing, offset: 30, health: .missing),
                fixture.clip(id: first, offset: 10),
                fixture.clip(id: excluded, offset: 40, isExcluded: true)
            ]
        )
        let store = fixture.store(builder: FakeMediaBuilder())

        store.synchronize(days: [day])

        var selection = try #require(store.presentation.state.selection)
        #expect(selection.clips.map(\.id) == [first, second, missing, excluded].map(idString))
        #expect(selection.clips.filter(\.isSelected).map(\.id) == [first, second].map(idString))
        #expect(store.presentation.enables(.createVideo))

        store.setIncluded(true, clipID: excluded)
        store.move(clipID: excluded, direction: -1)
        store.setIncluded(true, clipID: missing)
        #expect(!store.presentation.enables(.createVideo))

        store.setIncluded(false, clipID: missing)
        selection = try #require(store.presentation.state.selection)
        #expect(selection.clips.map(\.id) == [first, second, excluded, missing].map(idString))
        #expect(selection.clips.filter(\.isSelected).map(\.id) == [first, second, excluded].map(idString))
        #expect(store.presentation.enables(.createVideo))
    }

    @Test func persistsRecipeBeforeRenderAndRetriesTheSameIdentity() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let first = UUID()
        let second = UUID()
        let buildID = UUID()
        let builder = FakeMediaBuilder(outcomes: [.failure(.incompatibleSources), .success])
        let store = fixture.store(builder: builder, buildID: buildID)
        store.synchronize(days: [fixture.day(clips: [
            fixture.clip(id: second, offset: 20),
            fixture.clip(id: first, offset: 10)
        ])])

        store.createVideo()
        try await waitUntil { store.presentation.enables(.retry) }
        #expect(builder.recipeExistedForEveryBuild)
        #expect(builder.calls == 1)

        store.retry()
        try await waitUntil { store.presentation.enables(.share) }

        #expect(builder.calls == 2)
        let recipes = try fixture.recipes()
        let recipe = try #require(recipes.first)
        #expect(recipes.count == 1)
        #expect(recipe.id == buildID)
        #expect(recipe.orderedClipIDs == [first, second])
        #expect(recipe.lifecycle == .ready)
        #expect(recipe.outputFileName == "output.mov")
        #expect(FileManager.default.fileExists(atPath: fixture.outputURL(for: buildID).path))
    }

    @Test func cancellationPreservesRecipeSourcesAndPriorOutput() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let buildID = UUID()
        let libraryClip = fixture.clip(id: clipID, offset: 10)
        let sourceURL = try #require(libraryClip.mediaURL)
        let priorOutput = fixture.root.appendingPathComponent("prior-output.mov")
        try Data("prior".utf8).write(to: priorOutput)
        let builder = FakeMediaBuilder(outcomes: [.suspend])
        let registry = DevVlogsClipOwnershipRegistry()
        let store = fixture.store(builder: builder, buildID: buildID, registry: registry)
        store.synchronize(days: [fixture.day(clips: [libraryClip])])

        store.createVideo()
        try await waitUntil { store.presentation.state.isBuilding }
        store.cancel()
        try await waitUntil { store.presentation.enables(.retry) }

        let recipe = try #require(fixture.recipes().first)
        #expect(recipe.lifecycle == .cancelled)
        #expect(recipe.id == buildID)
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(try Data(contentsOf: priorOutput) == Data("prior".utf8))
        #expect(!FileManager.default.fileExists(atPath: fixture.outputURL(for: buildID).path))
        #expect(registry.operation(for: clipID) == nil)
    }

    @Test func probeTimeoutSavesFailureAndReleasesBuildOwnership() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let registry = DevVlogsClipOwnershipRegistry()
        let store = fixture.store(
            builder: FakeMediaBuilder(outcomes: [.failure(.timedOut)]),
            registry: registry
        )
        store.synchronize(days: [fixture.day(clips: [fixture.clip(id: clipID, offset: 10)])])

        store.createVideo()
        try await waitUntil { store.presentation.enables(.retry) }

        #expect(try #require(fixture.recipes().first).lifecycle == .failed)
        #expect(registry.operation(for: clipID) == nil)
        #expect(store.presentation.enables(.share) == false)
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        try await confirmation("bounded state transition", expectedCount: 1) { confirmation in
            let deadline = ContinuousClock.now + timeout
            while ContinuousClock.now < deadline {
                if condition() {
                    confirmation()
                    return
                }
                try await Task.sleep(for: .milliseconds(20))
            }
        }
    }

    @MainActor
    private final class Fixture {
        let root: URL
        let date = Date(timeIntervalSince1970: 1_754_870_400)

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("DevVlogsPublishStoreTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func store(
            builder: FakeMediaBuilder,
            buildID: UUID = UUID(),
            registry: DevVlogsClipOwnershipRegistry? = nil
        ) -> DevVlogsPublishStore {
            DevVlogsPublishStore(
                destinationAccessProvider: { DevVlogsCaptureDestinationAccess(url: self.root) },
                recipeRepository: DevVlogsBuildRepository(),
                mediaBuilder: builder,
                ownershipRegistry: registry ?? DevVlogsClipOwnershipRegistry(),
                now: { self.date.addingTimeInterval(100) },
                buildIDProvider: { buildID }
            )
        }

        func day(clips: [DevVlogsLibraryClip]) -> DevVlogsLibraryDay {
            DevVlogsLibraryDay(
                id: DevVlogsArchiveNaming.dayKey(for: date),
                date: date,
                appGroups: [
                    DevVlogsLibraryAppGroup(
                        id: "app.openai.codex",
                        displayName: "Codex",
                        bundleIdentifier: "app.openai.codex",
                        clips: clips
                    )
                ]
            )
        }

        func clip(
            id: UUID,
            offset: TimeInterval,
            health: DevVlogsLibraryHealth = .ready,
            isExcluded: Bool = false
        ) -> DevVlogsLibraryClip {
            let relativeDirectory = relativeDirectory(for: id, offset: offset)
            let directoryURL = root.appendingPathComponent(relativeDirectory, isDirectory: true)
            try! FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let mediaURL = directoryURL.appendingPathComponent("clip.mov")
            let metadataURL = directoryURL.appendingPathComponent("metadata.json")
            if !FileManager.default.fileExists(atPath: mediaURL.path), health != .missing {
                try! Data("source".utf8).write(to: mediaURL)
            }
            if !FileManager.default.fileExists(atPath: metadataURL.path) {
                try! Data("metadata".utf8).write(to: metadataURL)
            }
            let resourceIdentity = health == .ready
                ? DevVlogsClipResourceIdentity.capture(
                    rootURL: root,
                    relativeDirectory: relativeDirectory,
                    reviewExists: false
                )
                : nil
            return DevVlogsLibraryClip(
                id: idString(id),
                clipID: id,
                createdAt: date.addingTimeInterval(offset),
                triggerBundleIdentifier: "app.openai.codex",
                triggerApplicationName: "Codex",
                duration: 1,
                byteCount: 10,
                health: health,
                isExcluded: isExcluded,
                mediaURL: health == .missing ? nil : mediaURL,
                relativeDirectory: relativeDirectory,
                resourceIdentity: resourceIdentity
            )
        }

        func mediaURL(for id: UUID) -> URL {
            root
                .appendingPathComponent(relativeDirectory(for: id, offset: 10), isDirectory: true)
                .appendingPathComponent("clip.mov")
        }

        private func relativeDirectory(for id: UUID, offset: TimeInterval) -> String {
            let year = DevVlogsArchiveNaming.yearKey(for: date)
            let day = DevVlogsArchiveNaming.dayKey(for: date)
            let app = DevVlogsArchiveNaming.appFolder(
                displayName: "Codex",
                bundleIdentifier: "app.openai.codex"
            )
            let seconds = Int(offset).quotientAndRemainder(dividingBy: 60)
            let clipName = String(
                format: "12-%02d-%02d--%@",
                seconds.quotient,
                seconds.remainder,
                idString(id)
            )
            return "\(year)/\(day)/apps/\(app)/clips/\(clipName)"
        }

        func outputURL(for buildID: UUID) -> URL {
            root
                .appendingPathComponent(DevVlogsArchiveNaming.yearKey(for: date))
                .appendingPathComponent(DevVlogsArchiveNaming.dayKey(for: date))
                .appendingPathComponent("builds")
                .appendingPathComponent(idString(buildID))
                .appendingPathComponent("output.mov")
        }

        func recipes() throws -> [DevVlogsBuildRecipe] {
            let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
            let urls = (enumerator?.allObjects as? [URL]) ?? []
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try urls.filter { $0.lastPathComponent == "build.json" }
                .map { try decoder.decode(DevVlogsBuildRecipe.self, from: Data(contentsOf: $0)) }
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}

@MainActor
private final class FakeMediaBuilder: DevVlogsMediaBuilding {
    enum Outcome {
        case success
        case failure(DevVlogsBuildError)
        case suspend
    }

    private(set) var calls = 0
    private(set) var recipeExistedForEveryBuild = true
    private var outcomes: [Outcome]

    init(outcomes: [Outcome] = [.success]) {
        self.outcomes = outcomes
    }

    func build(
        sources: [DevVlogsBuildSource],
        outputURL: URL,
        outputPrepared: @escaping @MainActor (DevVlogsFileIdentity) async throws -> Void,
        progress: @escaping @MainActor (Double) -> Void
    ) async throws -> DevVlogsBuildOutput {
        calls += 1
        let recipeURL = outputURL.deletingLastPathComponent().appendingPathComponent("build.json")
        recipeExistedForEveryBuild = recipeExistedForEveryBuild
            && FileManager.default.fileExists(atPath: recipeURL.path)
        let outcome = outcomes.isEmpty ? .success : outcomes.removeFirst()
        switch outcome {
        case .success:
            try Data("valid-output".utf8).write(to: outputURL)
            let identity = try #require(DevVlogsFileIdentity.capture(
                at: outputURL,
                kind: .regularFile,
                requireSingleLink: true
            ))
            try await outputPrepared(identity)
            progress(1)
            return DevVlogsBuildOutput(fileURL: outputURL, duration: 2, byteCount: 12)
        case .failure(let error):
            throw error
        case .suspend:
            try await Task.sleep(for: .seconds(20))
            throw DevVlogsBuildError.exportFailed
        }
    }

    func validateOutput(at url: URL) async throws -> DevVlogsBuildOutput {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw DevVlogsBuildError.outputInvalid
        }
        return DevVlogsBuildOutput(fileURL: url, duration: 2, byteCount: 12)
    }
}

private func idString(_ id: UUID) -> String {
    id.uuidString.lowercased()
}
