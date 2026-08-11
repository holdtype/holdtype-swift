import AVFoundation
import Combine
import Foundation
import HoldTypeDomain

@MainActor
final class DevVlogsAudioReadLease {
    let fileURL: URL

    private let onRelease: () -> Void
    private(set) var isReleased = false

    init(fileURL: URL, onRelease: @escaping () -> Void = {}) {
        self.fileURL = fileURL
        self.onRelease = onRelease
    }

    func release() {
        guard !isReleased else {
            return
        }
        isReleased = true
        onRelease()
    }
}

@MainActor
protocol DevVlogsAudioReadLeasing {
    func acquireReadLease(for artifact: AudioRecordingArtifact) -> DevVlogsAudioReadLease
}

@MainActor
struct DefaultDevVlogsAudioReadLeaseProvider: DevVlogsAudioReadLeasing {
    func acquireReadLease(for artifact: AudioRecordingArtifact) -> DevVlogsAudioReadLease {
        DevVlogsAudioReadLease(fileURL: artifact.fileURL)
    }
}

@MainActor
protocol DevVlogsCaptureCoordinating: AnyObject {
    var state: DevVlogsCaptureState { get }

    func beginAttempt() async
    func dictationDidStart()
    func finishAttempt(audioArtifact: AudioRecordingArtifact) async
    func endAttemptWithoutAudio(reason: DevVlogsCaptureSkipReason)
}

@MainActor
final class DevVlogsCaptureCoordinator: ObservableObject, DevVlogsCaptureCoordinating {
    static let shared = DevVlogsCaptureCoordinator()

    private struct ActiveAttempt {
        let snapshot: DevVlogsCaptureSnapshot
        let destinationAccess: DevVlogsCaptureDestinationAccess
        let workspace: DevVlogsArchiveWorkspace
        let cameraCaptureID: UUID
        var audioStartedAtUptime: TimeInterval?
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
            state = .skipped(attemptID: attemptID, reason: .captureAlreadyActive)
            return
        }

        let settings = settingsProvider()
        guard settings.isEnabled else {
            state = .skipped(attemptID: attemptID, reason: .disabled)
            return
        }
        guard let triggerApplication = triggerApplicationProvider.currentTriggerApplication() else {
            state = .skipped(attemptID: attemptID, reason: .triggerApplicationUnknown)
            return
        }
        guard settings.applicationPolicy.isEligible(
            bundleIdentifier: triggerApplication.bundleIdentifier
        ) else {
            state = .skipped(attemptID: attemptID, reason: .triggerApplicationIneligible)
            return
        }
        guard let preferredCamera = settings.preferredCamera else {
            state = .skipped(attemptID: attemptID, reason: .preferredCameraUnavailable)
            return
        }
        guard cameraAuthorizationProvider() == .allowed else {
            state = .skipped(attemptID: attemptID, reason: .cameraPermissionUnavailable)
            return
        }

        let destinationAccess: DevVlogsCaptureDestinationAccess
        do {
            destinationAccess = try destinationProvider().acquireCaptureDestination()
        } catch {
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
            state = .failed(attemptID: attemptID, message: Self.message(for: error))
            return
        }

        state = .preparing(attemptID: attemptID)
        do {
            let cameraCaptureID = try await cameraCapture.startCapture(
                cameraID: preferredCamera.id,
                outputURL: workspace.cameraURL
            ) { [weak self] _ in
                guard case .preparing(let currentID) = self?.state,
                      currentID == attemptID else {
                    return
                }
                self?.state = .capturing(attemptID: attemptID)
            }
            activeAttempt = ActiveAttempt(
                snapshot: snapshot,
                destinationAccess: destinationAccess,
                workspace: workspace,
                cameraCaptureID: cameraCaptureID,
                audioStartedAtUptime: nil
            )
        } catch {
            destinationAccess.release()
            archive.abandonWorkspaceIfEmpty(workspace)
            state = .skipped(attemptID: attemptID, reason: .preferredCameraUnavailable)
        }
    }

    func dictationDidStart() {
        guard var attempt = activeAttempt else {
            return
        }
        attempt.audioStartedAtUptime = uptime()
        activeAttempt = attempt
    }

    func finishAttempt(audioArtifact: AudioRecordingArtifact) async {
        guard let attempt = takeActiveAttempt() else {
            return
        }
        state = .finalizing(attemptID: attempt.snapshot.attemptID)

        do {
            let cameraResult = try await cameraCapture.stopCapture(id: attempt.cameraCaptureID)
            guard let audioStartedAtUptime = attempt.audioStartedAtUptime else {
                throw DevVlogsMediaFinalizerError.noOverlappingMedia
            }
            let audioLease = audioLeaseProvider.acquireReadLease(for: audioArtifact)
            defer { audioLease.release() }
            try archive.stageAudio(from: audioLease.fileURL, into: attempt.workspace)
            Task { @MainActor [self] in
                await finalizeAndPublish(
                    attempt: attempt,
                    cameraResult: cameraResult,
                    audioStartedAtUptime: audioStartedAtUptime
                )
            }
        } catch {
            attempt.destinationAccess.release()
            state = .failed(
                attemptID: attempt.snapshot.attemptID,
                message: Self.message(for: error)
            )
        }
    }

    func endAttemptWithoutAudio(reason: DevVlogsCaptureSkipReason) {
        guard let attempt = takeActiveAttempt() else {
            return
        }
        state = .skipped(attemptID: attempt.snapshot.attemptID, reason: reason)
        Task { @MainActor [cameraCapture] in
            await cameraCapture.cancelCapture(id: attempt.cameraCaptureID)
            attempt.destinationAccess.release()
        }
    }

    private func takeActiveAttempt() -> ActiveAttempt? {
        let attempt = activeAttempt
        activeAttempt = nil
        return attempt
    }

    private func finalizeAndPublish(
        attempt: ActiveAttempt,
        cameraResult: DevVlogsCameraCaptureResult,
        audioStartedAtUptime: TimeInterval
    ) async {
        defer { attempt.destinationAccess.release() }
        do {
            let media = try await mediaFinalizer.finalize(
                camera: cameraResult,
                audioURL: attempt.workspace.audioURL,
                audioStartedAtUptime: audioStartedAtUptime,
                outputURL: attempt.workspace.finalizedURL
            )
            let published = try archive.publish(
                snapshot: attempt.snapshot,
                workspace: attempt.workspace,
                media: media
            )
            state = .saved(clipID: published.id)
        } catch {
            state = .failed(
                attemptID: attempt.snapshot.attemptID,
                message: Self.message(for: error)
            )
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
