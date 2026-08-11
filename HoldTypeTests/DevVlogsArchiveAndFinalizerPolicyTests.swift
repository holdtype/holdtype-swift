import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsArchiveAndFinalizerPolicyTests {
    @Test func archivePublishesOneImmutableRedactedClipDirectory() throws {
        let fileManager = FileManager.default
        let destination = fileManager.temporaryDirectory
            .appendingPathComponent("DevVlogsArchiveTests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: destination) }

        let attemptID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7, 137))
        let archive = FileSystemDevVlogsArchive(fileManager: fileManager)
        let workspace = try archive.prepareWorkspace(attemptID: attemptID, destinationURL: destination)
        try Data("camera-fragment".utf8).write(to: workspace.cameraURL)
        try Data("audio-fragment".utf8).write(to: workspace.audioURL)
        try Data("final-media".utf8).write(to: workspace.finalizedURL)
        let snapshot = DevVlogsCaptureSnapshot(
            attemptID: attemptID,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000),
            triggerApplication: .init(bundleIdentifier: "com.example.editor", displayName: "Example Editor"),
            preferredCamera: .init(id: "camera-id", label: "Desk Camera")
        )
        let media = DevVlogsFinalizedMedia(
            fileURL: workspace.finalizedURL,
            duration: 2.5,
            byteCount: 11,
            realizedVideoFormat: .init(width: 1_920, height: 1_080, nominalFrameRate: 30, codec: "hvc1")
        )

        let clip = try archive.publish(snapshot: snapshot, workspace: workspace, media: media)
        let clipDirectory = clip.fileURL.deletingLastPathComponent()
        let children = try fileManager.contentsOfDirectory(atPath: clipDirectory.path).sorted()
        let metadata = try String(
            contentsOf: clipDirectory.appendingPathComponent("metadata.json"),
            encoding: .utf8
        )

        #expect(clip.id == attemptID)
        #expect(children == ["clip.mov", "metadata.json"])
        #expect(metadata.contains("playable_1v_1a"))
        #expect(metadata.contains("realizedVideoFormat"))
        #expect(!metadata.contains("transcript"))
        #expect(!metadata.contains("finalized-dictation"))
        #expect(throws: DevVlogsArchiveError.publicationFailed) {
            try archive.publish(snapshot: snapshot, workspace: workspace, media: media)
        }
        #expect(fileManager.fileExists(atPath: clip.fileURL.path))
    }

    @Test func releaseFinalizerConfiguresVideoPassthroughWithoutForensicGate() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "HoldType/DevVlogs/DevVlogsMediaFinalizer.swift"
            ),
            encoding: .utf8
        )

        #expect(source.contains("AVAssetExportPresetPassthrough"))
        #expect(source.contains("exportSession.outputFileType = .mov"))
        #expect(source.contains("cameraAudioTracks.isEmpty"))
        #expect(source.contains("finalizedVideoTracks.count == 1"))
        #expect(source.contains("finalizedAudioTracks.count == 1"))
        #expect(source.contains("compositionVideoTrack.preferredTransform"))
        #expect(source.contains("let commonStart = max(camera.startedAtUptime, audioStartedAtUptime)"))
        #expect(source.contains("let cameraOffset = max(0, commonStart - camera.startedAtUptime)"))
        #expect(source.contains("let audioOffset = max(0, commonStart - audioStartedAtUptime)"))
        #expect(source.contains("camera.duration - cameraOffset"))
        #expect(source.contains("audioDuration - audioOffset"))
        #expect(!source.contains("videoComposition"))
        #expect(!source.contains("AVAssetExportPreset1280x720"))
        #expect(!source.contains("SampleExact"))
        #expect(!source.contains("sampleData"))

        let cameraSource = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "HoldType/DevVlogs/DevVlogsCameraCaptureService.swift"
            ),
            encoding: .utf8
        )
        #expect(cameraSource.contains("mediaType: .video"))
        #expect(!cameraSource.contains("mediaType: .audio"))
        #expect(!cameraSource.contains("AVCaptureAudioDataOutput"))
    }
}
