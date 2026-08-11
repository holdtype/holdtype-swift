import Foundation
import HoldTypeDomain
import Testing
@testable import HoldType

@MainActor
struct DevVlogsCaptureCoordinatorTests {
    private let audioArtifact = AudioRecordingArtifact(
        fileURL: URL(fileURLWithPath: "/tmp/finalized-dictation.m4a"),
        duration: 3,
        byteCount: 2_048
    )

    @Test func cameraOperationGateReturnsAtItsBoundAndCancelsPendingWork() async {
        let gate = DevVlogsCameraStartOperationGate()
        let clock = ContinuousClock()
        let start = clock.now

        await #expect(throws: DevVlogsCameraCaptureError.startFailed) {
            try await gate.wait(
                timeout: .milliseconds(20),
                operation: {
                    try await Task.sleep(for: .seconds(10))
                },
                onLateSuccess: {}
            )
        }

        #expect(clock.now - start < .seconds(1))
    }

    @Test func cameraStopTimeoutForcesProductionServiceTeardown() async throws {
        let session = DevVlogsNeverReturningCameraSession()
        let service = AVFoundationDevVlogsCameraCaptureService(
            maximumOperationWait: .milliseconds(20),
            sessionFactory: { _, _ in session }
        )
        let captureID = try await service.startCapture(
            cameraID: "camera",
            outputURL: URL(fileURLWithPath: "/tmp/camera.mov"),
            onStarted: { _ in }
        )

        await #expect(throws: DevVlogsCameraCaptureError.stopFailed) {
            try await service.stopCapture(id: captureID)
        }

        #expect(session.forceStopCount == 1)
        #expect(session.isTornDown)
    }

    @Test func disabledAndIneligibleAttemptsSkipBeforeCameraOrDestination() async throws {
        let disabled = try DevVlogsCaptureFixture(enabled: false)
        await disabled.coordinator.beginAttempt()

        #expect(disabled.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .disabled
        ))
        #expect(disabled.camera.startCameraIDs.isEmpty)
        #expect(disabled.archive.prepareCount == 0)

        let ineligible = try DevVlogsCaptureFixture(policy: .defaultPolicy)
        await ineligible.coordinator.beginAttempt()

        #expect(ineligible.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .triggerApplicationIneligible
        ))
        #expect(ineligible.camera.startCameraIDs.isEmpty)
        #expect(ineligible.archive.prepareCount == 0)
    }

    @Test func unavailableDestinationSkipsWithoutStartingOrFallingBack() async throws {
        let fixture = try DevVlogsCaptureFixture(destinationAvailable: false)

        await fixture.coordinator.beginAttempt()

        #expect(fixture.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .destinationUnavailable
        ))
        #expect(fixture.camera.startCameraIDs.isEmpty)
        #expect(fixture.archive.prepareCount == 0)
    }

    @Test func preferredCameraFailureSkipsWithoutTryingAnotherCamera() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.camera.startError = DevVlogsCameraCaptureError.cameraBusy

        await fixture.coordinator.beginAttempt()

        #expect(fixture.camera.startCameraIDs == [DevVlogsCaptureFixture.preferredCamera.id])
        #expect(fixture.archive.abandonCount == 1)
        #expect(fixture.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .preferredCameraUnavailable
        ))
    }

    @Test func frozenSnapshotPublishesOnceAndReleasesTheAudioLeaseOnce() async throws {
        let fixture = try DevVlogsCaptureFixture()
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()

        fixture.settings.setPreferredCamera(.init(id: "later-camera", label: "Later"))
        fixture.trigger.application = .init(bundleIdentifier: "com.example.later", displayName: "Later")

        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await fixture.waitForTerminalState()
        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await fixture.waitForTerminalState()

        #expect(fixture.camera.stopIDs == [fixture.camera.captureID])
        #expect(fixture.leases.acquireCount == 1)
        #expect(!fixture.leases.registry.isProtected(audioArtifact.fileURL))
        #expect(fixture.archive.stageCount == 1)
        #expect(fixture.finalizer.callCount == 1)
        #expect(fixture.archive.publishSnapshots.count == 1)
        #expect(fixture.archive.publishSnapshots.first?.preferredCamera == DevVlogsCaptureFixture.preferredCamera)
        #expect(fixture.archive.publishSnapshots.first?.triggerApplication == DevVlogsCaptureFixture.triggerApplication)
        #expect(fixture.coordinator.state == .saved(clipID: DevVlogsCaptureFixture.attemptID))
    }

    @Test func finalizerFailureIsTerminalWithoutPublicationAndKeepsFragmentsOwnedByArchive() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.finalizer.error = DevVlogsMediaFinalizerError.passthroughUnavailable
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()

        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await fixture.waitForTerminalState()

        #expect(!fixture.leases.registry.isProtected(audioArtifact.fileURL))
        #expect(fixture.archive.stageCount == 1)
        #expect(fixture.archive.publishSnapshots.isEmpty)
        #expect(fixture.archive.abandonCount == 0)
        #expect(fixture.coordinator.state == .failed(
            attemptID: DevVlogsCaptureFixture.attemptID,
            message: "The captured video could not be finalized without re-encoding."
        ))
    }

    @Test func finalizerTimeoutReleasesLeaseWithoutPublication() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.finalizer.error = DevVlogsMediaFinalizerError.timedOut
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()

        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await fixture.waitForTerminalState()

        #expect(!fixture.leases.registry.isProtected(audioArtifact.fileURL))
        #expect(fixture.archive.publishSnapshots.isEmpty)
        #expect(fixture.coordinator.state == .failed(
            attemptID: DevVlogsCaptureFixture.attemptID,
            message: "Finalizing the vlog clip timed out."
        ))
    }

    @Test func disablingWhilePreparingStopsOnlyTheVlogAttempt() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.camera.suspendsStart = true
        let beginTask = Task { await fixture.coordinator.beginAttempt() }
        await waitUntil { fixture.coordinator.state == .preparing(
            attemptID: DevVlogsCaptureFixture.attemptID
        ) }

        fixture.coordinator.featureDidDisable()
        await Task.yield()

        #expect(fixture.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .disabled
        ))
        #expect(fixture.camera.cancelCurrentCount == 1)
        fixture.camera.resumeStart()
        await beginTask.value
        #expect(fixture.camera.cancelIDs == [fixture.camera.captureID])
    }

    @Test func disablingWhileCapturingStopsOnlyTheVlogAttempt() async throws {
        let fixture = try DevVlogsCaptureFixture()
        await fixture.coordinator.beginAttempt()

        fixture.coordinator.featureDidDisable()
        await Task.yield()

        #expect(fixture.camera.cancelIDs == [fixture.camera.captureID])
        #expect(fixture.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .disabled
        ))
        #expect(fixture.leases.acquireCount == 0)
    }

    @Test func disablingWhileFinalizingReleasesLeaseAndSuppressesStaleSuccess() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.finalizer.suspends = true
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()
        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await waitUntil { fixture.finalizer.callCount == 1 }

        fixture.coordinator.featureDidDisable()

        #expect(!fixture.leases.registry.isProtected(audioArtifact.fileURL))
        #expect(fixture.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .disabled
        ))
        fixture.finalizer.resumeSuccess()
        await Task.yield()
        #expect(fixture.archive.publishSnapshots.isEmpty)
        #expect(fixture.coordinator.state == .skipped(
            attemptID: DevVlogsCaptureFixture.attemptID,
            reason: .disabled
        ))
    }

    @Test func teardownWhileFinalizingReleasesLeaseAndDestination() async throws {
        let fixture = try DevVlogsCaptureFixture(usesCustomDestination: true)
        fixture.finalizer.suspends = true
        let initialStopCount = fixture.bookmarks.stopCount
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()
        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await waitUntil { fixture.finalizer.callCount == 1 }

        fixture.coordinator.endAttemptWithoutAudio(reason: .dictationDidNotComplete)

        #expect(!fixture.leases.registry.isProtected(audioArtifact.fileURL))
        #expect(fixture.bookmarks.stopCount == initialStopCount + 1)
        fixture.finalizer.resumeSuccess()
    }

    @Test func audioLeaseReleasesWhenStagingFails() async throws {
        let fixture = try DevVlogsCaptureFixture()
        fixture.archive.stageError = DevVlogsCaptureTestError.expectedFailure
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.dictationDidStart()

        await fixture.coordinator.finishAttempt(audioArtifact: audioArtifact)
        await fixture.waitForTerminalState()

        #expect(fixture.leases.acquireCount == 1)
        #expect(!fixture.leases.registry.isProtected(audioArtifact.fileURL))
        #expect(fixture.finalizer.callCount == 0)
        #expect(fixture.archive.publishSnapshots.isEmpty)
        #expect(fixture.coordinator.state == .failed(
            attemptID: DevVlogsCaptureFixture.attemptID,
            message: "The vlog clip could not be saved."
        ))
    }

    @Test func endingWithoutAudioCancelsOnceAndNeverAcquiresTheLease() async throws {
        let fixture = try DevVlogsCaptureFixture()
        await fixture.coordinator.beginAttempt()
        fixture.coordinator.endAttemptWithoutAudio(reason: .dictationDidNotComplete)
        fixture.coordinator.endAttemptWithoutAudio(reason: .dictationDidNotComplete)
        await Task.yield()

        #expect(fixture.camera.cancelIDs == [fixture.camera.captureID])
        #expect(fixture.leases.acquireCount == 0)
        #expect(fixture.finalizer.callCount == 0)
        #expect(fixture.archive.publishSnapshots.isEmpty)
    }

    @Test func customDestinationAccessReleasesOnSkippedTerminal() async throws {
        let fixture = try DevVlogsCaptureFixture(usesCustomDestination: true)
        let initialStartCount = fixture.bookmarks.startCount
        let initialStopCount = fixture.bookmarks.stopCount
        await fixture.coordinator.beginAttempt()

        fixture.coordinator.endAttemptWithoutAudio(reason: .dictationDidNotComplete)
        await Task.yield()

        #expect(fixture.bookmarks.startCount == initialStartCount + 1)
        #expect(fixture.bookmarks.stopCount == initialStopCount + 1)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async {
        for _ in 0..<40 {
            if condition() { return }
            await Task.yield()
        }
    }
}
