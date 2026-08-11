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

    @Test func suspendedExportCannotBeRedirectedThroughBuildDirectoryReplacement() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = DevVlogsBuildRepository()
        let created = try await fixture.recipe(in: repository)
        let staging = try await repository.prepareForBuild(workspace: created.workspace)
        let exportGate = DevVlogsTestSuspensionGate()
        let exportTask = Task {
            try Data("staged-output".utf8).write(to: staging.outputURL)
            let stagedIdentity = try #require(DevVlogsFileIdentity.capture(
                at: staging.outputURL,
                kind: .regularFile,
                requireSingleLink: true
            ))
            try await repository.registerStagedOutput(
                workspace: created.workspace,
                staging: staging,
                expectedIdentity: stagedIdentity
            )
            await exportGate.suspend()
            try await repository.promoteOutput(workspace: created.workspace, staging: staging)
        }
        try await waitUntil { exportGate.isSuspended }
        let sourceURL = try fixture.source().fileURL
        let priorOutput = fixture.root.appendingPathComponent("prior-output.mov")
        let sibling = fixture.root.appendingPathComponent("sibling.txt")
        try Data("prior".utf8).write(to: priorOutput)
        try Data("keep".utf8).write(to: sibling)

        let savedBuild = created.workspace.directoryURL
            .deletingLastPathComponent()
            .appendingPathComponent("saved-suspended-build", isDirectory: true)
        try FileManager.default.moveItem(at: created.workspace.directoryURL, to: savedBuild)
        let sentinelTarget = fixture.root.appendingPathComponent("sentinel-target", isDirectory: true)
        try FileManager.default.createDirectory(at: sentinelTarget, withIntermediateDirectories: false)
        let sentinel = sentinelTarget.appendingPathComponent("sentinel.txt")
        try Data("sentinel".utf8).write(to: sentinel)
        try FileManager.default.createSymbolicLink(
            at: created.workspace.directoryURL,
            withDestinationURL: sentinelTarget
        )

        exportGate.resume()
        await #expect(throws: DevVlogsBuildError.workspaceChanged) { try await exportTask.value }
        await #expect(throws: DevVlogsBuildError.workspaceChanged) {
            try await repository.removeStagedOutput(workspace: created.workspace, staging: staging)
        }

        #expect(!FileManager.default.fileExists(atPath: sentinelTarget.appendingPathComponent("output.mov").path))
        #expect(try Data(contentsOf: sentinel) == Data("sentinel".utf8))
        #expect(try Data(contentsOf: priorOutput) == Data("prior".utf8))
        #expect(try Data(contentsOf: sibling) == Data("keep".utf8))
        #expect(FileManager.default.fileExists(atPath: sourceURL.path))
        #expect(FileManager.default.fileExists(atPath: savedBuild.appendingPathComponent("build.json").path))
        #expect(!FileManager.default.fileExists(atPath: staging.directoryURL.path))
    }

    @Test func buildsParentSymlinkAndTemporaryReplacementPreserveSentinels() async throws {
        let fixture = try await Fixture()
        defer { fixture.remove() }
        let repository = DevVlogsBuildRepository()
        let created = try await fixture.recipe(in: repository)
        let staging = try await repository.prepareForBuild(workspace: created.workspace)
        try Data("owned-temp".utf8).write(to: staging.outputURL)
        let identity = try #require(DevVlogsFileIdentity.capture(
            at: staging.outputURL,
            kind: .regularFile,
            requireSingleLink: true
        ))
        try await repository.registerStagedOutput(
            workspace: created.workspace,
            staging: staging,
            expectedIdentity: identity
        )
        try FileManager.default.removeItem(at: staging.outputURL)
        try Data("replacement".utf8).write(to: staging.outputURL)

        await #expect(throws: DevVlogsBuildError.workspaceChanged) {
            try await repository.removeStagedOutput(workspace: created.workspace, staging: staging)
        }
        #expect(try Data(contentsOf: staging.outputURL) == Data("replacement".utf8))

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

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        _ = try #require(condition())
    }
}

@MainActor
private final class DevVlogsTestSuspensionGate {
    private var continuation: CheckedContinuation<Void, Never>?
    private(set) var isSuspended = false

    func suspend() async {
        isSuspended = true
        await withCheckedContinuation { continuation = $0 }
    }

    func resume() {
        isSuspended = false
        continuation?.resume()
        continuation = nil
    }
}
