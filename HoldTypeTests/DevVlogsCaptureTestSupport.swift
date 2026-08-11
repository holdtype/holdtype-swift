import Foundation
import HoldTypeDomain
@testable import HoldType

@MainActor
final class DevVlogsCaptureFixture {
    static let triggerApplication = DevVlogsTriggerApplication(
        bundleIdentifier: "com.example.editor",
        displayName: "Editor"
    )
    static let preferredCamera = DevVlogsCamera(id: "preferred-camera", label: "Desk Camera")
    static let attemptID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 35))

    let settings: DevVlogsSettingsStore
    let destination: DevVlogsDestinationSetupStore
    let trigger = DevVlogsTriggerApplicationProviderFake(application: triggerApplication)
    let camera = DevVlogsCameraCaptureFake()
    let leases = DevVlogsAudioReadLeaseProviderFake()
    let archive = DevVlogsArchiveFake()
    let finalizer = DevVlogsMediaFinalizerFake()
    let bookmarks = DevVlogsDestinationBookmarkResolverFake()
    let fileAccess = DevVlogsDestinationFileAccessFake()
    let destinationURL: URL
    let coordinator: DevVlogsCaptureCoordinator

    init(
        enabled: Bool = true,
        policy: DevVlogsApplicationPolicy = .init(
            mode: .allAppsExceptExcludedApps,
            selectedApps: [],
            excludedApps: []
        ),
        destinationAvailable: Bool = true,
        usesCustomDestination: Bool = false
    ) throws {
        settings = DevVlogsSettingsStore(
            isEnabled: enabled,
            preferredCamera: Self.preferredCamera,
            applicationPolicy: policy
        )
        destinationURL = URL(fileURLWithPath: "/tmp/holdtype-dev-vlogs-tests/destination")
        fileAccess.state = destinationAvailable ? .directory(isWritable: true) : .missing
        let suiteName = "DevVlogsCaptureFixture.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            throw DevVlogsCaptureTestError.fixtureUnavailable
        }
        defaults.removePersistentDomain(forName: suiteName)
        destination = DevVlogsDestinationSetupStore(
            userDefaults: defaults,
            bookmarkResolver: bookmarks,
            fileAccess: fileAccess,
            defaultDestinationURL: destinationURL
        )
        if usesCustomDestination {
            bookmarks.resolvedURL = destinationURL
            destination.selectCustomFolder(destinationURL)
        } else {
            destination.useOrCreateDefaultFolder()
        }
        coordinator = DevVlogsCaptureCoordinator(
            settingsProvider: { [settings] in settings },
            destinationProvider: { [destination] in destination },
            triggerApplicationProvider: trigger,
            cameraAuthorizationProvider: { .allowed },
            cameraCapture: camera,
            audioLeaseProvider: leases,
            archive: archive,
            mediaFinalizer: finalizer,
            now: { Date(timeIntervalSince1970: 1_700_000_000) },
            uptime: { 101 },
            attemptIDProvider: { Self.attemptID }
        )
    }

    func waitForTerminalState() async {
        for _ in 0..<40 {
            switch coordinator.state {
            case .saved, .failed:
                return
            default:
                await Task.yield()
            }
        }
    }
}

enum DevVlogsCaptureTestError: Error {
    case fixtureUnavailable
    case expectedFailure
}

@MainActor
final class DevVlogsTriggerApplicationProviderFake: DevVlogsTriggerApplicationProviding {
    var application: DevVlogsTriggerApplication?

    init(application: DevVlogsTriggerApplication?) {
        self.application = application
    }

    func currentTriggerApplication() -> DevVlogsTriggerApplication? {
        application
    }
}

@MainActor
final class DevVlogsCameraCaptureFake: DevVlogsCameraCapturing {
    let captureID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 86))
    var startError: Error?
    var stopError: Error?
    var suspendsStart = false
    private var startContinuation: CheckedContinuation<Void, Never>?
    private(set) var startCameraIDs: [String] = []
    private(set) var stopIDs: [UUID] = []
    private(set) var cancelIDs: [UUID] = []
    private(set) var cancelCurrentCount = 0

    func startCapture(
        cameraID: String,
        outputURL: URL,
        onStarted: @escaping @MainActor (TimeInterval) -> Void
    ) async throws -> UUID {
        startCameraIDs.append(cameraID)
        if let startError { throw startError }
        if suspendsStart {
            await withCheckedContinuation { startContinuation = $0 }
        }
        onStarted(100)
        return captureID
    }

    func stopCapture(id: UUID) async throws -> DevVlogsCameraCaptureResult {
        stopIDs.append(id)
        if let stopError { throw stopError }
        return DevVlogsCameraCaptureResult(
            fileURL: URL(fileURLWithPath: "/tmp/camera.mov"),
            duration: 4,
            startedAtUptime: 100
        )
    }

    func cancelCapture(id: UUID) async {
        cancelIDs.append(id)
    }

    func cancelCurrentCapture() async {
        cancelCurrentCount += 1
    }

    func resumeStart() {
        startContinuation?.resume()
        startContinuation = nil
    }
}

@MainActor
final class DevVlogsNeverReturningCameraSession: DevVlogsCameraSessionControlling {
    private var stopContinuation: CheckedContinuation<DevVlogsCameraCaptureResult, Error>?
    private(set) var forceStopCount = 0
    private(set) var isTornDown = false

    func start(cameraID: String) async throws {}

    func stop() async throws -> DevVlogsCameraCaptureResult {
        try await withCheckedThrowingContinuation { stopContinuation = $0 }
    }

    func forceStop() {
        guard !isTornDown else { return }
        forceStopCount += 1
        isTornDown = true
        stopContinuation?.resume(throwing: DevVlogsCameraCaptureError.stopFailed)
        stopContinuation = nil
    }
}

@MainActor
final class DevVlogsAudioReadLeaseProviderFake: DevVlogsAudioReadLeasing {
    let registry = RecordingArtifactReadLeaseRegistry()
    private(set) var acquireCount = 0

    func acquireReadLease(for artifact: AudioRecordingArtifact) -> RecordingArtifactReadLease {
        acquireCount += 1
        return registry.acquire(for: artifact.fileURL)
    }
}

@MainActor
final class DevVlogsArchiveFake: DevVlogsArchiving {
    var stageError: Error?
    private(set) var prepareCount = 0
    private(set) var stageCount = 0
    private(set) var abandonCount = 0
    private(set) var publishSnapshots: [DevVlogsCaptureSnapshot] = []

    func prepareWorkspace(
        attemptID: UUID,
        destinationURL: URL
    ) throws -> DevVlogsArchiveWorkspace {
        prepareCount += 1
        let root = destinationURL.appendingPathComponent(attemptID.uuidString)
        return DevVlogsArchiveWorkspace(
            rootURL: root,
            cameraURL: root.appendingPathComponent("camera.mov"),
            audioURL: root.appendingPathComponent("dictation.m4a"),
            finalizedURL: root.appendingPathComponent("final.mov")
        )
    }

    func stageAudio(from sourceURL: URL, into workspace: DevVlogsArchiveWorkspace) throws {
        stageCount += 1
        if let stageError { throw stageError }
    }

    func abandonWorkspaceIfEmpty(_ workspace: DevVlogsArchiveWorkspace) {
        abandonCount += 1
    }

    func publish(
        snapshot: DevVlogsCaptureSnapshot,
        workspace: DevVlogsArchiveWorkspace,
        media: DevVlogsFinalizedMedia
    ) throws -> DevVlogsPublishedClip {
        publishSnapshots.append(snapshot)
        return DevVlogsPublishedClip(id: snapshot.attemptID, fileURL: media.fileURL)
    }
}

@MainActor
final class DevVlogsMediaFinalizerFake: DevVlogsMediaFinalizing {
    var error: Error?
    var suspends = false
    private(set) var callCount = 0
    private var continuation: CheckedContinuation<DevVlogsFinalizedMedia, Error>?

    func finalize(
        camera: DevVlogsCameraCaptureResult,
        audioURL: URL,
        audioStartedAtUptime: TimeInterval,
        outputURL: URL
    ) async throws -> DevVlogsFinalizedMedia {
        callCount += 1
        if let error { throw error }
        let media = DevVlogsFinalizedMedia(
            fileURL: outputURL,
            duration: 3,
            byteCount: 1_024,
            realizedVideoFormat: .init(width: 1_920, height: 1_080, nominalFrameRate: 30, codec: "hvc1")
        )
        if suspends {
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }
        return media
    }

    func resumeSuccess() {
        continuation?.resume(
            returning: DevVlogsFinalizedMedia(
                fileURL: URL(fileURLWithPath: "/tmp/final.mov"),
                duration: 3,
                byteCount: 1_024,
                realizedVideoFormat: .init(
                    width: 1_920,
                    height: 1_080,
                    nominalFrameRate: 30,
                    codec: "hvc1"
                )
            )
        )
        continuation = nil
    }
}

final class DevVlogsDestinationBookmarkResolverFake: DevVlogsDestinationBookmarkResolving {
    var resolvedURL = URL(fileURLWithPath: "/tmp/holdtype-dev-vlogs-tests/destination")
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func bookmarkData(for url: URL) throws -> Data { Data([1]) }
    func resolveBookmarkData(_ data: Data) throws -> DevVlogsBookmarkResolution {
        DevVlogsBookmarkResolution(url: resolvedURL, isStale: false)
    }
    func startAccessingSecurityScopedResource(at url: URL) -> Bool {
        startCount += 1
        return true
    }
    func stopAccessingSecurityScopedResource(at url: URL) {
        stopCount += 1
    }
}

final class DevVlogsDestinationFileAccessFake: DevVlogsDestinationFileAccessing {
    var state: DevVlogsDestinationDirectoryState = .directory(isWritable: true)
    func directoryState(at url: URL) -> DevVlogsDestinationDirectoryState { state }
    func createDirectory(at url: URL) throws {}
}
