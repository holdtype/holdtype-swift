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

    @Test func lateCompletionFromStoppedPreviewCannotClearNewerPreview() async {
        let client = InterleavingPreviewClientFake()
        let store = DevVlogsCameraPreviewStore(client: client)

        let firstStart = Task { await start(store) }
        await client.waitUntilFirstStartIsSuspended()
        let firstSessionID = client.startedSessionIDs[0]

        await store.stopPreview()
        await start(store)
        let secondSessionID = client.startedSessionIDs[1]
        #expect(store.state == .previewing)
        #expect(client.activeSessionIDs == [secondSessionID])

        client.resumeFirstStart()
        await firstStart.value
        #expect(store.state == .previewing)
        #expect(client.activeSessionIDs == [secondSessionID])
        #expect(client.stoppedSessionIDs == [firstSessionID])

        await store.stopPreview()
        #expect(store.state == .idle)
        #expect(client.activeSessionIDs.isEmpty)
        #expect(client.stoppedSessionIDs == [firstSessionID, secondSessionID])
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
        private var currentSessionID: UUID?
        private var failure: (@MainActor (DevVlogsCameraPreviewError) -> Void)?

        func start(
            sessionID: UUID,
            cameraID: String,
            onFrame: @escaping @MainActor (CGImage) -> Void,
            onFailure: @escaping @MainActor (DevVlogsCameraPreviewError) -> Void
        ) async throws {
            startedCameraIDs.append(cameraID)
            currentSessionID = sessionID
            failure = onFailure
        }

        func stop(sessionID: UUID) async {
            guard currentSessionID == sessionID else { return }
            stopCount += 1
            currentSessionID = nil
            failure = nil
        }

        func fail(_ error: DevVlogsCameraPreviewError) {
            failure?(error)
        }
    }

    private final class InterleavingPreviewClientFake: DevVlogsCameraPreviewing {
        private(set) var startedSessionIDs: [UUID] = []
        private(set) var activeSessionIDs: Set<UUID> = []
        private(set) var stoppedSessionIDs: [UUID] = []
        private var firstStartContinuation: CheckedContinuation<Void, Never>?
        private var firstStartWaiters: [CheckedContinuation<Void, Never>] = []
        private var isFirstStartSuspended = false

        func start(
            sessionID: UUID,
            cameraID: String,
            onFrame: @escaping @MainActor (CGImage) -> Void,
            onFailure: @escaping @MainActor (DevVlogsCameraPreviewError) -> Void
        ) async throws {
            startedSessionIDs.append(sessionID)
            activeSessionIDs.insert(sessionID)
            guard startedSessionIDs.count == 1 else { return }
            isFirstStartSuspended = true
            let waiters = firstStartWaiters
            firstStartWaiters.removeAll()
            waiters.forEach { $0.resume() }
            await withCheckedContinuation { continuation in
                firstStartContinuation = continuation
            }
        }

        func stop(sessionID: UUID) async {
            guard activeSessionIDs.remove(sessionID) != nil else { return }
            stoppedSessionIDs.append(sessionID)
        }

        func waitUntilFirstStartIsSuspended() async {
            guard !isFirstStartSuspended else { return }
            await withCheckedContinuation { continuation in
                firstStartWaiters.append(continuation)
            }
        }

        func resumeFirstStart() {
            let continuation = firstStartContinuation
            firstStartContinuation = nil
            continuation?.resume()
        }
    }
}
