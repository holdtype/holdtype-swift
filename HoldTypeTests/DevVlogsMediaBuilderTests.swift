import AVFoundation
import AppKit
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsMediaBuilderTests {
    @Test func compatiblePassthroughCreatesPlayableOrderedOneVideoOneAudioArtifact() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let firstID = UUID()
        let secondID = UUID()
        let first = try await fixture.clip(
            id: firstID,
            date: fixture.date,
            color: (220, 20, 20),
            duration: 0.6
        )
        let second = try await fixture.clip(
            id: secondID,
            date: fixture.date.addingTimeInterval(2),
            color: (20, 40, 220),
            duration: 0.8
        )
        let output = fixture.root.appendingPathComponent("compatible-output.mov")
        var progress: [Double] = []
        let firstSource = try await fixture.source(id: firstID, url: first)
        let secondSource = try await fixture.source(id: secondID, url: second)

        let result = try await AVFoundationDevVlogsMediaBuilder().build(
            sources: [firstSource, secondSource],
            outputURL: output,
            outputPrepared: { _ in },
            progress: { progress.append($0) }
        )

        let asset = AVURLAsset(url: result.fileURL)
        #expect(try await asset.load(.isPlayable))
        #expect(try await asset.loadTracks(withMediaType: .video).count == 1)
        #expect(try await asset.loadTracks(withMediaType: .audio).count == 1)
        #expect(result.duration > 1.2)
        #expect(progress.last == 1)
        let firstColor = try await color(in: asset, at: 0.1)
        let secondColor = try await color(in: asset, at: 0.9)
        #expect(firstColor.redComponent > firstColor.blueComponent)
        #expect(secondColor.blueComponent > secondColor.redComponent)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test func incompatiblePassthroughFailsWithNoOutputAndPreservesSources() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let firstID = UUID()
        let secondID = UUID()
        let first = try await fixture.clip(id: firstID, date: fixture.date, size: CGSize(width: 64, height: 64))
        let second = try await fixture.clip(
            id: secondID,
            date: fixture.date.addingTimeInterval(2),
            size: CGSize(width: 96, height: 64)
        )
        let output = fixture.root.appendingPathComponent("incompatible-output.mov")
        let firstSource = try await fixture.source(id: firstID, url: first)
        let secondSource = try await fixture.source(id: secondID, url: second)

        await #expect(throws: DevVlogsBuildError.incompatibleSources) {
            _ = try await AVFoundationDevVlogsMediaBuilder().build(
                sources: [firstSource, secondSource],
                outputURL: output,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }

        #expect(!FileManager.default.fileExists(atPath: output.path))
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test func existingOutputIsNeverOverwritten() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let source = try await fixture.clip(id: clipID, date: fixture.date)
        let output = fixture.root.appendingPathComponent("existing.mov")
        let sentinel = Data("prior-output".utf8)
        try sentinel.write(to: output)
        let buildSource = try await fixture.source(id: clipID, url: source)

        await #expect(throws: DevVlogsBuildError.outputAlreadyExists) {
            _ = try await AVFoundationDevVlogsMediaBuilder().build(
                sources: [buildSource],
                outputURL: output,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }

        #expect(try Data(contentsOf: output) == sentinel)
        #expect(FileManager.default.fileExists(atPath: source.path))
    }

    @Test func sourceReplacementDuringSignatureProbeFailsBeforeExport() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let clipID = UUID()
        let sourceURL = try await fixture.clip(id: clipID, date: fixture.date)
        let source = try await fixture.source(id: clipID, url: sourceURL)
        let sibling = fixture.root.appendingPathComponent("signature-sibling.txt")
        let output = fixture.root.appendingPathComponent("post-signature-output.mov")
        try Data("keep".utf8).write(to: sibling)
        let builder = AVFoundationDevVlogsMediaBuilder(
            maximumProbeWait: .seconds(10),
            sourceProbeBarrier: {},
            signatureProbeBarrier: {
                try FileManager.default.removeItem(at: source.fileURL)
                try Data("replacement".utf8).write(to: source.fileURL)
            },
            outputProbeBarrier: {}
        )

        await #expect(throws: DevVlogsBuildError.sourceInvalid) {
            _ = try await builder.build(
                sources: [source],
                outputURL: output,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }

        #expect(!FileManager.default.fileExists(atPath: output.path))
        #expect(try Data(contentsOf: sibling) == Data("keep".utf8))
        #expect(try Data(contentsOf: source.fileURL) == Data("replacement".utf8))
    }

    @Test func allSourcesRevalidateTogetherAfterEverySignatureProbe() async throws {
        let fixture = try Fixture()
        defer { fixture.remove() }
        let firstID = UUID()
        let secondID = UUID()
        let firstURL = try await fixture.clip(id: firstID, date: fixture.date)
        let secondURL = try await fixture.clip(
            id: secondID,
            date: fixture.date.addingTimeInterval(2)
        )
        let first = try await fixture.source(id: firstID, url: firstURL)
        let second = try await fixture.source(id: secondID, url: secondURL)
        let sibling = fixture.root.appendingPathComponent("collective-sibling.txt")
        let output = fixture.root.appendingPathComponent("collective-output.mov")
        try Data("keep".utf8).write(to: sibling)
        let gate = MediaBuilderSuspensionGate()
        var signatureCount = 0
        let builder = AVFoundationDevVlogsMediaBuilder(
            maximumProbeWait: .seconds(10),
            sourceProbeBarrier: {},
            signatureProbeBarrier: {
                signatureCount += 1
                if signatureCount == 2 { await gate.suspend() }
            },
            outputProbeBarrier: {}
        )
        let task = Task {
            try await builder.build(
                sources: [first, second],
                outputURL: output,
                outputPrepared: { _ in },
                progress: { _ in }
            )
        }
        try await waitUntil { gate.isSuspended }
        try FileManager.default.removeItem(at: first.fileURL)
        try Data("replacement".utf8).write(to: first.fileURL)
        gate.resume()

        await #expect(throws: DevVlogsBuildError.sourceInvalid) { _ = try await task.value }
        #expect(!FileManager.default.fileExists(atPath: output.path))
        #expect(try Data(contentsOf: first.fileURL) == Data("replacement".utf8))
        #expect(FileManager.default.fileExists(atPath: second.fileURL.path))
        #expect(try Data(contentsOf: sibling) == Data("keep".utf8))
    }

    private func color(in asset: AVAsset, at seconds: TimeInterval) async throws -> NSColor {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let (image, _) = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
        let bitmap = NSBitmapImageRep(cgImage: image)
        let color = try #require(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: bitmap.pixelsHigh / 2))
        return try #require(color.usingColorSpace(.deviceRGB))
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

    private final class Fixture {
        let root: URL
        let date = Date(timeIntervalSince1970: 1_754_870_400)

        init() throws {
            root = FileManager.default.temporaryDirectory
                .appendingPathComponent("DevVlogsMediaBuilderTests-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }

        func clip(
            id: UUID,
            date: Date,
            size: CGSize = CGSize(width: 64, height: 64),
            color: (UInt8, UInt8, UInt8) = (220, 20, 20),
            duration: TimeInterval = 0.6
        ) async throws -> URL {
            try await DevVlogsMediaFixtureFactory.makeArchivedClip(
                rootURL: root,
                clipID: id,
                createdAt: date,
                appName: "Codex",
                bundleIdentifier: "app.openai.codex",
                size: size,
                color: color,
                duration: duration
            )
        }

        func source(id: UUID, url: URL) async throws -> DevVlogsBuildSource {
            let snapshot = try await DevVlogsLibraryRepository().load(rootURL: root)
            let clip = try #require(snapshot.days.flatMap(\.clips).first { $0.clipID == id })
            return DevVlogsBuildSource(
                clipID: id,
                fileURL: url,
                resourceIdentity: try #require(clip.resourceIdentity)
            )
        }

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}

@MainActor
private final class MediaBuilderSuspensionGate {
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
