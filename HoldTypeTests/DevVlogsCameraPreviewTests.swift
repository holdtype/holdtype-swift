import CoreGraphics
import Foundation
import Testing
@testable import HoldType

@MainActor
struct DevVlogsCameraPreviewTests {
    private let preferred = DevVlogsCamera(id: "preferred-camera", label: "Desk Camera")

    @Test func passiveStoreCreationNeverStartsOrStopsCamera() {
        let client = PreviewClientFake()
        _ = DevVlogsCameraPreviewStore(client: client)

        #expect(client.startedCameraIDs.isEmpty)
        #expect(client.stopCount == 0)
    }

    @Test func explicitStartUsesOnlyAvailableRememberedStableID() async {
        let client = PreviewClientFake()
        let store = DevVlogsCameraPreviewStore(client: client)

        await store.startPreview(
            isEnabled: true,
            permissionStatus: .allowed,
            preferredCamera: preferred,
            availableCameras: [
                DevVlogsCamera(id: "fallback-camera", label: "Fallback"),
                DevVlogsCamera(id: preferred.id, label: "Renamed Desk Camera")
            ]
        )

        #expect(client.startedCameraIDs == [preferred.id])
        #expect(store.state == .previewing)
    }

    @Test func unavailableRememberedCameraNeverFallsBack() async {
        let client = PreviewClientFake()
        let store = DevVlogsCameraPreviewStore(client: client)

        await store.startPreview(
            isEnabled: true,
            permissionStatus: .allowed,
            preferredCamera: preferred,
            availableCameras: [DevVlogsCamera(id: "other-camera", label: "Other Camera")]
        )

        #expect(client.startedCameraIDs.isEmpty)
        guard case .failed(let message) = store.state else {
            Issue.record("Expected truthful unavailable state")
            return
        }
        #expect(message.contains("did not substitute"))
    }

    @Test func explicitStopAndLifecycleChangesReleasePreview() async {
        let client = PreviewClientFake()
        let store = DevVlogsCameraPreviewStore(client: client)

        await start(store)
        await store.stopPreview()
        #expect(store.state == .idle)
        #expect(client.stopCount == 1)

        await start(store)
        await store.reconcile(
            isEnabled: false,
            permissionStatus: .allowed,
            preferredCamera: preferred,
            availableCameras: [preferred]
        )
        #expect(store.state == .idle)
        #expect(client.stopCount == 2)

        await start(store)
        await store.reconcile(
            isEnabled: true,
            permissionStatus: .allowed,
            preferredCamera: preferred,
            availableCameras: []
        )
        guard case .failed(let message) = store.state else {
            Issue.record("Expected disconnect failure")
            return
        }
        #expect(message.contains("disconnected"))
        #expect(client.stopCount == 3)
    }

    @Test func runtimeFailureReleasesTheSessionAndReportsFailure() async {
        let client = PreviewClientFake()
        let store = DevVlogsCameraPreviewStore(client: client)
        await start(store)

        client.fail(.cameraBusy)
        await Task.yield()

        guard case .failed(let message) = store.state else {
            Issue.record("Expected runtime failure")
            return
        }
        #expect(message.contains("busy"))
        #expect(client.stopCount == 1)
    }

    @Test func productionPreviewUsesFramesWithoutRecordingPermissionOrMicrophoneAPIs() throws {
        let source = try String(
            contentsOf: sourceRoot.appendingPathComponent("HoldType/DevVlogs/DevVlogsCameraPreview.swift"),
            encoding: .utf8
        )

        #expect(source.contains("AVCaptureVideoDataOutput"))
        #expect(!source.contains("AVCaptureMovieFileOutput"))
        #expect(!source.contains("AVCaptureAudioDataOutput"))
        #expect(!source.contains("requestAccess"))
        #expect(!source.contains("startRecording"))
    }

    private func start(_ store: DevVlogsCameraPreviewStore) async {
        await store.startPreview(
            isEnabled: true,
            permissionStatus: .allowed,
            preferredCamera: preferred,
            availableCameras: [preferred]
        )
    }

    private var sourceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private final class PreviewClientFake: DevVlogsCameraPreviewing {
        private(set) var startedCameraIDs: [String] = []
        private(set) var stopCount = 0
        private var failure: (@MainActor (DevVlogsCameraPreviewError) -> Void)?

        func start(
            cameraID: String,
            onFrame: @escaping @MainActor (CGImage) -> Void,
            onFailure: @escaping @MainActor (DevVlogsCameraPreviewError) -> Void
        ) async throws {
            startedCameraIDs.append(cameraID)
            failure = onFailure
        }

        func stop() async {
            stopCount += 1
            failure = nil
        }

        func fail(_ error: DevVlogsCameraPreviewError) {
            failure?(error)
        }
    }
}
