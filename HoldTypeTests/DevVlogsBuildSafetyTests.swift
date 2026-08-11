import Foundation
import Testing
@testable import HoldType

@MainActor
@Suite(.serialized)
struct DevVlogsBuildSafetyTests {
    @Test func mediaBuilderRejectsSourceReplacementAndSymlinkWithoutOutput() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let source = try fixture.source()
        let replacementOutput = fixture.root.appendingPathComponent("replacement-output.mov")
        let symlinkOutput = fixture.root.appendingPathComponent("symlink-output.mov")
        let outside = fixture.root.appendingPathComponent("outside.mov")
        try Data(contentsOf: source.fileURL).write(to: outside)
        try FileManager.default.removeItem(at: source.fileURL)
        try Data("replacement".utf8).write(to: source.fileURL)

        await #expect(throws: DevVlogsBuildError.sourceInvalid) {
            _ = try await AVFoundationDevVlogsMediaBuilder().build(
                sources: [source],
                outputURL: replacementOutput,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }

        try FileManager.default.removeItem(at: source.fileURL)
        try FileManager.default.createSymbolicLink(at: source.fileURL, withDestinationURL: outside)

        await #expect(throws: DevVlogsBuildError.sourceInvalid) {
            _ = try await AVFoundationDevVlogsMediaBuilder().build(
                sources: [source],
                outputURL: symlinkOutput,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }

        #expect(!FileManager.default.fileExists(atPath: replacementOutput.path))
        #expect(!FileManager.default.fileExists(atPath: symlinkOutput.path))
        #expect(try Data(contentsOf: outside).count > 0)
    }

    @Test func mediaBuilderRejectsSourceHardLinkAndPreservesBothLinks() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let source = try fixture.source()
        let hardLink = fixture.root.appendingPathComponent("source-hard-link.mov")
        let output = fixture.root.appendingPathComponent("hard-link-output.mov")
        try FileManager.default.linkItem(at: source.fileURL, to: hardLink)

        await #expect(throws: DevVlogsBuildError.sourceInvalid) {
            _ = try await AVFoundationDevVlogsMediaBuilder().build(
                sources: [source],
                outputURL: output,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }

        #expect(FileManager.default.fileExists(atPath: source.fileURL.path))
        #expect(FileManager.default.fileExists(atPath: hardLink.path))
        #expect(!FileManager.default.fileExists(atPath: output.path))
    }

    @Test func workspaceSiblingAndReplacementFailClosedAndSurvive() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = DevVlogsBuildRepository()
        let created = try await fixture.recipe(in: repository)
        let sibling = created.workspace.directoryURL.appendingPathComponent("user-note.txt")
        try Data("keep".utf8).write(to: sibling)

        await #expect(throws: DevVlogsBuildError.workspaceChanged) {
            try await repository.prepareForBuild(workspace: created.workspace)
        }
        #expect(try Data(contentsOf: sibling) == Data("keep".utf8))

        try FileManager.default.removeItem(at: sibling)
        let savedDirectory = created.workspace.directoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("saved-workspace")
        try FileManager.default.moveItem(at: created.workspace.directoryURL, to: savedDirectory)
        try FileManager.default.createDirectory(
            at: created.workspace.directoryURL,
            withIntermediateDirectories: false
        )
        let replacementRecipe = created.workspace.directoryURL.appendingPathComponent("build.json")
        try Data("replacement".utf8).write(to: replacementRecipe)

        await #expect(throws: DevVlogsBuildError.workspaceChanged) {
            _ = try await repository.update(
                created.recipe,
                lifecycle: .failed,
                failureCategory: "test",
                outputFileName: nil,
                workspace: created.workspace
            )
        }
        #expect(FileManager.default.fileExists(atPath: savedDirectory.appendingPathComponent("build.json").path))
        #expect(try Data(contentsOf: replacementRecipe) == Data("replacement".utf8))
    }

    @Test func buildsParentSymlinkAndTemporaryReplacementPreserveSentinels() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = DevVlogsBuildRepository()
        let created = try await fixture.recipe(in: repository)
        try Data("owned-temp".utf8).write(to: created.workspace.temporaryOutputURL)
        let identity = try #require(DevVlogsFileIdentity.capture(
            at: created.workspace.temporaryOutputURL,
            kind: .regularFile,
            requireSingleLink: true
        ))
        try await repository.registerTemporaryOutput(
            workspace: created.workspace,
            expectedIdentity: identity
        )
        try FileManager.default.removeItem(at: created.workspace.temporaryOutputURL)
        try Data("replacement".utf8).write(to: created.workspace.temporaryOutputURL)

        await #expect(throws: DevVlogsBuildError.workspaceChanged) {
            try await repository.removeTemporaryOutput(workspace: created.workspace)
        }
        #expect(try Data(contentsOf: created.workspace.temporaryOutputURL) == Data("replacement".utf8))

        let buildsURL = created.workspace.directoryURL.deletingLastPathComponent()
        let savedBuildsURL = buildsURL.deletingLastPathComponent().appendingPathComponent("saved-builds")
        try FileManager.default.moveItem(at: buildsURL, to: savedBuildsURL)
        let outside = fixture.root.appendingPathComponent("outside-builds", isDirectory: true)
        try FileManager.default.createDirectory(at: outside, withIntermediateDirectories: false)
        let sentinel = outside.appendingPathComponent("sentinel.txt")
        try Data("keep".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(at: buildsURL, withDestinationURL: outside)

        await #expect(throws: DevVlogsBuildError.workspaceChanged) {
            try await repository.prepareForBuild(workspace: created.workspace)
        }
        #expect(try Data(contentsOf: sentinel) == Data("keep".utf8))
        #expect(FileManager.default.fileExists(
            atPath: savedBuildsURL.appendingPathComponent(created.workspace.buildID.uuidString.lowercased()).path
        ))
    }

    @Test func sourceProbeTimeoutAndCancellationPreserveSourceAndNoOutput() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let source = try fixture.source()
        let timeoutOutput = fixture.root.appendingPathComponent("source-timeout.mov")
        let timeoutBuilder = AVFoundationDevVlogsMediaBuilder(
            maximumProbeWait: .milliseconds(10),
            sourceProbeBarrier: { try await Task.sleep(for: .seconds(20)) },
            outputProbeBarrier: {}
        )
        await #expect(throws: DevVlogsBuildError.timedOut) {
            _ = try await timeoutBuilder.build(
                sources: [source],
                outputURL: timeoutOutput,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }

        let cancelOutput = fixture.root.appendingPathComponent("source-cancel.mov")
        let cancelBuilder = AVFoundationDevVlogsMediaBuilder(
            maximumProbeWait: .seconds(20),
            sourceProbeBarrier: { try await Task.sleep(for: .seconds(20)) },
            outputProbeBarrier: {}
        )
        let task = Task {
            try await cancelBuilder.build(
                sources: [source],
                outputURL: cancelOutput,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        await #expect(throws: DevVlogsBuildError.cancelled) { _ = try await task.value }
        #expect(FileManager.default.fileExists(atPath: source.fileURL.path))
        #expect(!FileManager.default.fileExists(atPath: timeoutOutput.path))
        #expect(!FileManager.default.fileExists(atPath: cancelOutput.path))
    }

    @Test func completedOutputProbeTimeoutAndCancellationRemainUnavailable() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let output = try fixture.source().fileURL
        let timeoutBuilder = AVFoundationDevVlogsMediaBuilder(
            maximumProbeWait: .milliseconds(10),
            sourceProbeBarrier: {},
            outputProbeBarrier: { try await Task.sleep(for: .seconds(20)) }
        )
        await #expect(throws: DevVlogsBuildError.timedOut) {
            _ = try await timeoutBuilder.validateOutput(at: output)
        }

        let cancelBuilder = AVFoundationDevVlogsMediaBuilder(
            maximumProbeWait: .seconds(20),
            sourceProbeBarrier: {},
            outputProbeBarrier: { try await Task.sleep(for: .seconds(20)) }
        )
        let task = Task { try await cancelBuilder.validateOutput(at: output) }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()
        await #expect(throws: DevVlogsBuildError.cancelled) { _ = try await task.value }
        #expect(FileManager.default.fileExists(atPath: output.path))
    }

    private final class Fixture {
        let root: URL
        let clipID = UUID()
        let date = Date(timeIntervalSince1970: 1_754_870_400)
        let day: DevVlogsLibraryDay

        init() async throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("DevVlogsBuildSafety-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            _ = try await DevVlogsMediaFixtureFactory.makeArchivedClip(
                rootURL: root,
                clipID: clipID,
                createdAt: date,
                appName: "Codex",
                bundleIdentifier: "app.openai.codex"
            )
            let snapshot = try await DevVlogsLibraryRepository().load(rootURL: root)
            day = try #require(snapshot.days.first)
        }

        func source() throws -> DevVlogsBuildSource {
            let clip = try #require(day.clips.first { $0.clipID == clipID })
            return DevVlogsBuildSource(
                clipID: clipID,
                fileURL: try #require(clip.mediaURL),
                resourceIdentity: try #require(clip.resourceIdentity)
            )
        }

        func recipe(
            in repository: DevVlogsBuildRepository
        ) async throws -> (recipe: DevVlogsBuildRecipe, workspace: DevVlogsBuildWorkspace) {
            try await repository.createRecipe(
                rootURL: root,
                day: day,
                orderedClipIDs: [clipID],
                buildID: UUID(),
                createdAt: date.addingTimeInterval(10)
            )
        }

        func remove() { try? FileManager.default.removeItem(at: root) }
    }
}
