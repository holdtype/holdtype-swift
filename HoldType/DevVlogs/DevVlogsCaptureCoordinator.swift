import AVFoundation
import Combine
import Foundation
import HoldTypeDomain

@MainActor
protocol DevVlogsAudioReadLeasing {
    func acquireReadLease(for artifact: AudioRecordingArtifact) -> RecordingArtifactReadLease
}

@MainActor
struct DefaultDevVlogsAudioReadLeaseProvider: DevVlogsAudioReadLeasing {
    private let registry: RecordingArtifactReadLeaseRegistry

    init(registry: RecordingArtifactReadLeaseRegistry? = nil) {
        self.registry = registry ?? .shared
    }

    func acquireReadLease(for artifact: AudioRecordingArtifact) -> RecordingArtifactReadLease {
        registry.acquire(for: artifact.fileURL)
    }
}

@MainActor
protocol DevVlogsCaptureCoordinating: AnyObject {
    var state: DevVlogsCaptureState { get }

    func beginAttempt() async
    func dictationDidStart()
    func finishAttempt(audioArtifact: AudioRecordingArtifact) async
    func endAttemptWithoutAudio(reason: DevVlogsCaptureSkipReason)
    func featureDidDisable()
}

@MainActor
final class DevVlogsCaptureCoordinator: ObservableObject, DevVlogsCaptureCoordinating {
    static let shared = DevVlogsCaptureCoordinator()

    private final class ActiveAttempt {
        let snapshot: DevVlogsCaptureSnapshot
        let destinationAccess: DevVlogsCaptureDestinationAccess
        let workspace: DevVlogsArchiveWorkspace
        var cameraCaptureID: UUID?
        var audioStartedAtUptime: TimeInterval?
        var audioLease: RecordingArtifactReadLease?
        var finalizationTask: Task<Void, Never>?
        var isTerminal = false

        init(
            snapshot: DevVlogsCaptureSnapshot,
            destinationAccess: DevVlogsCaptureDestinationAccess,
            workspace: DevVlogsArchiveWorkspace
        ) {
            self.snapshot = snapshot
            self.destinationAccess = destinationAccess
            self.workspace = workspace
        }
    }

    @Published private(set) var state: DevVlogsCaptureState = .idle

    private let settingsProvider: () -> DevVlogsSettingsStore
    private let destinationProvider: () -> DevVlogsDestinationSetupStore
    private let triggerApplicationProvider: any DevVlogsTriggerApplicationProviding
    private let cameraAuthorizationProvider: () -> DevVlogsCameraAuthorizationStatus
    private let cameraCapture: any DevVlogsCameraCapturing
    private let audioLeaseProvider: any DevVlogsAudioReadLeasing
    private let archive: any DevVlogsArchiving
    private let mediaFinalizer: any DevVlogsMediaFinalizing
    private let now: () -> Date
    private let uptime: () -> TimeInterval
    private let attemptIDProvider: () -> UUID

    private var activeAttempt: ActiveAttempt?
    private var visibleAttemptID: UUID?

    convenience init() {
        self.init(
            settingsProvider: { DevVlogsSettingsStore() },
            destinationProvider: { DevVlogsDestinationSetupStore() },
            triggerApplicationProvider: WorkspaceDevVlogsTriggerApplicationProvider(),
            cameraAuthorizationProvider: {
                switch AVCaptureDevice.authorizationStatus(for: .video) {
                case .authorized:
                    return .allowed
                case .notDetermined:
                    return .notDetermined
                default:
                    return .denied
                }
            },
            cameraCapture: AVFoundationDevVlogsCameraCaptureService(),
            audioLeaseProvider: DefaultDevVlogsAudioReadLeaseProvider(),
            archive: FileSystemDevVlogsArchive(),
            mediaFinalizer: AVFoundationDevVlogsMediaFinalizer()
        )
    }

    init(
        settingsProvider: @escaping () -> DevVlogsSettingsStore,
        destinationProvider: @escaping () -> DevVlogsDestinationSetupStore,
        triggerApplicationProvider: any DevVlogsTriggerApplicationProviding,
        cameraAuthorizationProvider: @escaping () -> DevVlogsCameraAuthorizationStatus,
        cameraCapture: any DevVlogsCameraCapturing,
        audioLeaseProvider: any DevVlogsAudioReadLeasing,
        archive: any DevVlogsArchiving,
        mediaFinalizer: any DevVlogsMediaFinalizing,
        now: @escaping () -> Date = Date.init,
        uptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        attemptIDProvider: @escaping () -> UUID = UUID.init
    ) {
        self.settingsProvider = settingsProvider
        self.destinationProvider = destinationProvider
        self.triggerApplicationProvider = triggerApplicationProvider
        self.cameraAuthorizationProvider = cameraAuthorizationProvider
        self.cameraCapture = cameraCapture
        self.audioLeaseProvider = audioLeaseProvider
        self.archive = archive
        self.mediaFinalizer = mediaFinalizer
        self.now = now
        self.uptime = uptime
        self.attemptIDProvider = attemptIDProvider
    }

    func beginAttempt() async {
        let attemptID = attemptIDProvider()
        guard activeAttempt == nil else {
            visibleAttemptID = attemptID
            state = .skipped(attemptID: attemptID, reason: .captureAlreadyActive)
            return
        }

        let settings = settingsProvider()
        guard settings.isEnabled else {
            visibleAttemptID = attemptID
            state = .skipped(attemptID: attemptID, reason: .disabled)
            return
        }
        guard let triggerApplication = triggerApplicationProvider.currentTriggerApplication() else {
            visibleAttemptID = attemptID
            state = .skipped(attemptID: attemptID, reason: .triggerApplicationUnknown)
            return
        }
        guard settings.applicationPolicy.isEligible(
            bundleIdentifier: triggerApplication.bundleIdentifier
        ) else {
            visibleAttemptID = attemptID
            state = .skipped(attemptID: attemptID, reason: .triggerApplicationIneligible)
            return
        }
        guard let preferredCamera = settings.preferredCamera else {
            visibleAttemptID = attemptID
            state = .skipped(attemptID: attemptID, reason: .preferredCameraUnavailable)
            return
        }
        guard cameraAuthorizationProvider() == .allowed else {
            visibleAttemptID = attemptID
            state = .skipped(attemptID: attemptID, reason: .cameraPermissionUnavailable)
            return
        }

        let destinationAccess: DevVlogsCaptureDestinationAccess
        do {
            destinationAccess = try destinationProvider().acquireCaptureDestination()
        } catch {
            visibleAttemptID = attemptID
            state = .skipped(attemptID: attemptID, reason: .destinationUnavailable)
            return
        }
        let snapshot = DevVlogsCaptureSnapshot(
            attemptID: attemptID,
            startedAt: now(),
            triggerApplication: triggerApplication,
            preferredCamera: preferredCamera
        )
        let workspace: DevVlogsArchiveWorkspace
        do {
            workspace = try archive.prepareWorkspace(
                attemptID: attemptID,
                destinationURL: destinationAccess.url
            )
        } catch {
            destinationAccess.release()
            visibleAttemptID = attemptID
            state = .failed(attemptID: attemptID, message: Self.message(for: error))
            return
        }

        let attempt = ActiveAttempt(
            snapshot: snapshot,
            destinationAccess: destinationAccess,
            workspace: workspace
        )
        activeAttempt = attempt
        visibleAttemptID = attemptID
        state = .preparing(attemptID: attemptID)
        do {
            let cameraCaptureID = try await cameraCapture.startCapture(
                cameraID: preferredCamera.id,
                outputURL: workspace.cameraURL
            ) { [weak self] _ in
                guard let self, self.owns(attempt), self.visibleAttemptID == attemptID else {
                    return
                }
                self.state = .capturing(attemptID: attemptID)
            }
            guard owns(attempt) else {
                await cameraCapture.cancelCapture(id: cameraCaptureID)
                return
            }
            attempt.cameraCaptureID = cameraCaptureID
        } catch {
            guard owns(attempt) else { return }
            archive.abandonWorkspaceIfEmpty(workspace)
            terminalize(
                attempt,
                state: .skipped(attemptID: attemptID, reason: .preferredCameraUnavailable),
                tearDownCamera: false
            )
        }
    }

    func dictationDidStart() {
        guard let attempt = activeAttempt, !attempt.isTerminal else { return }
        attempt.audioStartedAtUptime = uptime()
    }

    func finishAttempt(audioArtifact: AudioRecordingArtifact) async {
        guard let attempt = activeAttempt, !attempt.isTerminal else { return }
        guard attempt.finalizationTask == nil else { return }
        if visibleAttemptID == attempt.snapshot.attemptID {
            state = .finalizing(attemptID: attempt.snapshot.attemptID)
        }
        attempt.audioLease = audioLeaseProvider.acquireReadLease(for: audioArtifact)
        attempt.finalizationTask = Task { @MainActor [weak self, attempt] in
            await self?.finalizeAndPublish(attempt: attempt)
        }
    }

    func endAttemptWithoutAudio(reason: DevVlogsCaptureSkipReason) {
        guard let attempt = activeAttempt, !attempt.isTerminal else { return }
        terminalize(
            attempt,
            state: .skipped(attemptID: attempt.snapshot.attemptID, reason: reason),
            tearDownCamera: true
        )
    }

    func featureDidDisable() {
        guard let attempt = activeAttempt, !attempt.isTerminal else { return }
        terminalize(
            attempt,
            state: .skipped(attemptID: attempt.snapshot.attemptID, reason: .disabled),
            tearDownCamera: true
        )
    }

    private func finalizeAndPublish(attempt: ActiveAttempt) async {
        do {
            guard let cameraCaptureID = attempt.cameraCaptureID,
                  let audioStartedAtUptime = attempt.audioStartedAtUptime,
                  let audioLease = attempt.audioLease else {
                throw DevVlogsMediaFinalizerError.noOverlappingMedia
            }
            let cameraResult = try await cameraCapture.stopCapture(id: cameraCaptureID)
            guard owns(attempt) else { return }
            attempt.cameraCaptureID = nil
            try archive.stageAudio(from: audioLease.fileURL, into: attempt.workspace)
            let media = try await mediaFinalizer.finalize(
                camera: cameraResult,
                audioURL: attempt.workspace.audioURL,
                audioStartedAtUptime: audioStartedAtUptime,
                outputURL: attempt.workspace.finalizedURL
            )
            guard owns(attempt) else { return }
            let published = try archive.publish(
                snapshot: attempt.snapshot,
                workspace: attempt.workspace,
                media: media
            )
            terminalize(attempt, state: .saved(clipID: published.id), tearDownCamera: false)
        } catch {
            guard owns(attempt) else { return }
            terminalize(
                attempt,
                state: .failed(
                    attemptID: attempt.snapshot.attemptID,
                    message: Self.message(for: error)
                ),
                tearDownCamera: true
            )
        }
    }

    private func owns(_ attempt: ActiveAttempt) -> Bool {
        activeAttempt === attempt && !attempt.isTerminal
    }

    private func terminalize(
        _ attempt: ActiveAttempt,
        state terminalState: DevVlogsCaptureState,
        tearDownCamera: Bool
    ) {
        guard owns(attempt) else { return }
        attempt.isTerminal = true
        activeAttempt = nil
        attempt.finalizationTask?.cancel()
        attempt.finalizationTask = nil
        attempt.audioLease?.release()
        attempt.audioLease = nil
        attempt.destinationAccess.release()
        if visibleAttemptID == attempt.snapshot.attemptID {
            state = terminalState
        }
        guard tearDownCamera else { return }
        let cameraCaptureID = attempt.cameraCaptureID
        Task { @MainActor [cameraCapture] in
            if let cameraCaptureID {
                await cameraCapture.cancelCapture(id: cameraCaptureID)
            } else {
                await cameraCapture.cancelCurrentCapture()
            }
        }
    }

    private static func message(for error: Error) -> String {
        if let localized = error as? LocalizedError,
           let description = localized.errorDescription,
           !description.isEmpty {
            return description
        }
        return "The vlog clip could not be saved."
    }
}
