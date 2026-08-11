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

        let result = try await AVFoundationDevVlogsMediaBuilder().build(
            sources: [
                DevVlogsBuildSource(clipID: firstID, fileURL: first),
                DevVlogsBuildSource(clipID: secondID, fileURL: second)
            ],
            outputURL: output,
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

        await #expect(throws: DevVlogsBuildError.incompatibleSources) {
            _ = try await AVFoundationDevVlogsMediaBuilder().build(
                sources: [
                    DevVlogsBuildSource(clipID: firstID, fileURL: first),
                    DevVlogsBuildSource(clipID: secondID, fileURL: second)
                ],
                outputURL: output,
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

        await #expect(throws: DevVlogsBuildError.outputAlreadyExists) {
            _ = try await AVFoundationDevVlogsMediaBuilder().build(
                sources: [DevVlogsBuildSource(clipID: clipID, fileURL: source)],
                outputURL: output,
                progress: { _ in }
            )
        }

        #expect(try Data(contentsOf: output) == sentinel)
        #expect(FileManager.default.fileExists(atPath: source.path))
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

        func remove() {
            try? FileManager.default.removeItem(at: root)
        }
    }
}
